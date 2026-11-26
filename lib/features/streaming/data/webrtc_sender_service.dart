import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/network/signaling_protocol.dart';
import '../../../core/utils/log.dart';
import '../../../shared/models/network_statistics.dart';

/// Manages WebRTC peer connections from the mobile sender to Desktop and OBS.
///
/// Shares the single [MediaStream] owned by [CameraService] without ever
/// opening a second camera capture pipeline.
class WebRtcSenderService extends ChangeNotifier {
  WebRtcSenderService({required this.onSendSignal});

  static const _tag = 'WebRtcSender';
  final void Function(SignalMessage msg) onSendSignal;

  final Map<String, RTCPeerConnection> _peers = {};
  MediaStream? _localStream;
  Timer? _statsTimer;
  NetworkStatistics _stats = NetworkStatistics.empty;

  int _targetMaxBitrateBps = 2500000;
  int _currentMaxBitrateBps = 2500000;
  int _prevBytesSent = 0;
  DateTime? _prevStatsTime;

  NetworkStatistics get stats => _stats;
  bool get isStreaming => _peers.containsKey(PeerTarget.desktop);

  void setTargetBitrateKbps(int kbps) {
    _targetMaxBitrateBps = (kbps * 1000).clamp(300000, 12000000);
    _currentMaxBitrateBps = _targetMaxBitrateBps;
    _applyVideoBitrate(_currentMaxBitrateBps);
  }

  /// Starts streaming [stream] to [target] (`desktop` or `obs`).
  Future<void> startPeer({
    required String target,
    required MediaStream stream,
  }) async {
    _localStream = stream;
    await closePeer(target);

    final pc = await createPeerConnection({
      'iceServers': <Map<String, dynamic>>[],
      'sdpSemantics': 'unified-plan',
    });
    _peers[target] = pc;

    for (final track in stream.getTracks()) {
      await pc.addTrack(track, stream);
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      onSendSignal(SignalMessage(
        type: SignalType.ice,
        target: target,
        payload: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      ));
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      Log.info(_tag, 'Peer[$target] state: ${state.name}');
      notifyListeners();
    };

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    onSendSignal(SignalMessage(
      type: SignalType.offer,
      target: target,
      payload: {
        'type': offer.type,
        'sdp': offer.sdp,
      },
    ));

    await _applyVideoBitrate(_currentMaxBitrateBps);
    if (target == PeerTarget.desktop) {
      _startStatsPolling();
    }
    notifyListeners();
  }

  Future<void> handleAnswer({
    required String target,
    required Map<String, dynamic> payload,
  }) async {
    final pc = _peers[target];
    final sdp = payload['sdp'] as String?;
    final type = (payload['type'] as String?) ?? 'answer';
    if (pc == null || sdp == null) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
  }

  Future<void> handleIceCandidate({
    required String target,
    required Map<String, dynamic> payload,
  }) async {
    final pc = _peers[target];
    final candidate = payload['candidate'] as String?;
    if (pc == null || candidate == null) return;
    try {
      await pc.addCandidate(RTCIceCandidate(
        candidate,
        payload['sdpMid'] as String?,
        payload['sdpMLineIndex'] as int?,
      ));
    } catch (e) {
      Log.warn(_tag, 'Failed to add ICE[$target]: $e');
    }
  }

  /// Replaces tracks in all active peers when the camera re-initializes
  /// (e.g. switching lens or resolution) without tearing down WebRTC.
  Future<void> replaceStreamTracks(MediaStream newStream) async {
    _localStream = newStream;
    final videoTrack = newStream.getVideoTracks().firstOrNull;
    final audioTrack = newStream.getAudioTracks().firstOrNull;
    for (final pc in _peers.values) {
      final senders = await pc.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'video' && videoTrack != null) {
          await sender.replaceTrack(videoTrack);
        } else if (sender.track?.kind == 'audio' && audioTrack != null) {
          await sender.replaceTrack(audioTrack);
        }
      }
    }
  }

  Future<void> _applyVideoBitrate(int maxBitrateBps) async {
    for (final pc in _peers.values) {
      try {
        final senders = await pc.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            final params = sender.parameters;
            if (params.encodings != null && params.encodings!.isNotEmpty) {
              for (final enc in params.encodings!) {
                enc.maxBitrate = maxBitrateBps;
              }
              await sender.setParameters(params);
            }
          }
        }
      } catch (_) {}
    }
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _prevBytesSent = 0;
    _prevStatsTime = null;
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollStats());
  }

  Future<void> _pollStats() async {
    final pc = _peers[PeerTarget.desktop];
    if (pc == null) return;
    try {
      final reports = await pc.getStats();
      int fps = _stats.currentFps;
      int width = _stats.width;
      int height = _stats.height;
      double rttMs = _stats.roundTripTimeMs;
      double jitterMs = _stats.jitterMs;
      double lossPct = _stats.packetLossPercent;
      double bitrateKbps = _stats.actualBitrateKbps;

      for (final report in reports) {
        final values = report.values;
        if (report.type == 'outbound-rtp' && values['kind'] == 'video') {
          final f = values['framesPerSecond'];
          if (f is num) fps = f.round();
          final w = values['frameWidth'];
          if (w is num) width = w.toInt();
          final h = values['frameHeight'];
          if (h is num) height = h.toInt();

          final bytes = (values['bytesSent'] as num?)?.toInt() ?? 0;
          final now = DateTime.now();
          if (_prevStatsTime != null && bytes >= _prevBytesSent) {
            final elapsedSec =
                now.difference(_prevStatsTime!).inMilliseconds / 1000.0;
            if (elapsedSec > 0.1) {
              bitrateKbps =
                  ((bytes - _prevBytesSent) * 8.0 / 1000.0) / elapsedSec;
            }
          }
          _prevBytesSent = bytes;
          _prevStatsTime = now;
        } else if (report.type == 'remote-inbound-rtp' &&
            values['kind'] == 'video') {
          final rtt = values['roundTripTime'];
          if (rtt is num) rttMs = rtt.toDouble() * 1000.0;
          final j = values['jitter'];
          if (j is num) jitterMs = j.toDouble() * 1000.0;
          final fl = values['fractionLost'];
          if (fl is num) lossPct = (fl.toDouble() * 100.0).clamp(0.0, 100.0);
        } else if (report.type == 'candidate-pair' &&
            values['state'] == 'succeeded') {
          final rtt = values['currentRoundTripTime'];
          if (rtt is num && rttMs == 0) rttMs = rtt.toDouble() * 1000.0;
        }
      }

      _adaptBitrate(lossPct: lossPct, rttMs: rttMs);

      _stats = NetworkStatistics(
        currentFps: fps,
        actualBitrateKbps: bitrateKbps,
        roundTripTimeMs: rttMs,
        packetLossPercent: lossPct,
        jitterMs: jitterMs,
        connectionType: 'WebRTC LAN',
        width: width,
        height: height,
      );
      onSendSignal(SignalMessage(
        type: SignalType.stats,
        payload: {
          'fps': fps,
          'bitrateKbps': bitrateKbps,
          'rttMs': rttMs,
          'packetLoss': lossPct,
          'jitterMs': jitterMs,
          'width': width,
          'height': height,
        },
      ));
      notifyListeners();
    } catch (_) {}
  }

  void _adaptBitrate({required double lossPct, required double rttMs}) {
    if (lossPct > 5.0 || rttMs > 250.0) {
      final reduced = (_currentMaxBitrateBps * 0.75).round().clamp(
            400000,
            _targetMaxBitrateBps,
          );
      if (reduced != _currentMaxBitrateBps) {
        _currentMaxBitrateBps = reduced;
        _applyVideoBitrate(reduced);
        Log.info(_tag, 'Adaptive bitrate reduced to ${reduced ~/ 1000} kbps');
      }
    } else if (lossPct < 1.0 &&
        rttMs < 100.0 &&
        _currentMaxBitrateBps < _targetMaxBitrateBps) {
      final increased = (_currentMaxBitrateBps * 1.15).round().clamp(
            400000,
            _targetMaxBitrateBps,
          );
      if (increased != _currentMaxBitrateBps) {
        _currentMaxBitrateBps = increased;
        _applyVideoBitrate(increased);
      }
    }
  }

  MediaStream? get currentStream => _localStream;

  Future<void> closePeer(String target) async {
    final pc = _peers.remove(target);
    if (target == PeerTarget.desktop) {
      _statsTimer?.cancel();
      _statsTimer = null;
      _stats = NetworkStatistics.empty;
    }
    try {
      await pc?.close();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> closeAll() async {
    _statsTimer?.cancel();
    _statsTimer = null;
    _stats = NetworkStatistics.empty;
    final entries = _peers.values.toList();
    _peers.clear();
    for (final pc in entries) {
      try {
        await pc.close();
      } catch (_) {}
    }
    notifyListeners();
  }

  @override
  void dispose() {
    closeAll();
    super.dispose();
  }
}
