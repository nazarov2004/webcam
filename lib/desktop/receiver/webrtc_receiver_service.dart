import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/network/signaling_protocol.dart';
import '../../core/utils/log.dart';
import '../../shared/models/network_statistics.dart';

/// Receives the WebRTC audio/video stream from the mobile sender on Windows.
class WebRtcReceiverService extends ChangeNotifier {
  WebRtcReceiverService({required this.onSendSignal});

  static const _tag = 'WebRtcReceiver';
  final void Function(SignalMessage msg) onSendSignal;

  RTCPeerConnection? _pc;
  MediaStream? _remoteStream;
  RTCPeerConnectionState _connectionState =
      RTCPeerConnectionState.RTCPeerConnectionStateNew;
  NetworkStatistics _stats = NetworkStatistics.empty;
  Timer? _statsTimer;

  int _prevBytesReceived = 0;
  DateTime? _prevStatsTime;

  MediaStream? get remoteStream => _remoteStream;
  RTCPeerConnectionState get connectionState => _connectionState;
  NetworkStatistics get stats => _stats;

  Future<void> handleOffer(Map<String, dynamic> payload) async {
    final sdp = payload['sdp'] as String?;
    final type = (payload['type'] as String?) ?? 'offer';
    if (sdp == null || sdp.isEmpty) return;

    await closePeer();
    final pc = await createPeerConnection({
      'iceServers': <Map<String, dynamic>>[],
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        Log.info(_tag, 'Remote stream attached (${event.track.kind})');
        notifyListeners();
      }
    };

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      onSendSignal(SignalMessage(
        type: SignalType.ice,
        target: PeerTarget.desktop,
        payload: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      ));
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      _connectionState = state;
      Log.info(_tag, 'Peer state: ${state.name}');
      notifyListeners();
    };

    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    onSendSignal(SignalMessage(
      type: SignalType.answer,
      target: PeerTarget.desktop,
      payload: {
        'type': answer.type,
        'sdp': answer.sdp,
      },
    ));

    _startStatsPolling();
  }

  Future<void> handleIceCandidate(Map<String, dynamic> payload) async {
    final pc = _pc;
    final candidate = payload['candidate'] as String?;
    if (pc == null || candidate == null) return;
    try {
      await pc.addCandidate(RTCIceCandidate(
        candidate,
        payload['sdpMid'] as String?,
        payload['sdpMLineIndex'] as int?,
      ));
    } catch (e) {
      Log.warn(_tag, 'Failed to add ICE candidate: $e');
    }
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _prevBytesReceived = 0;
    _prevStatsTime = null;
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollStats());
  }

  Future<void> _pollStats() async {
    final pc = _pc;
    if (pc == null) return;
    try {
      final reports = await pc.getStats();
      int fps = _stats.currentFps;
      int width = _stats.width;
      int height = _stats.height;
      int framesDecoded = _stats.framesDecoded;
      double jitterMs = _stats.jitterMs;
      double rttMs = _stats.roundTripTimeMs;
      double lossPct = _stats.packetLossPercent;
      double bitrateKbps = _stats.actualBitrateKbps;

      for (final report in reports) {
        final values = report.values;
        if (report.type == 'inbound-rtp' && values['kind'] == 'video') {
          final f = values['framesPerSecond'];
          if (f is num) fps = f.round();
          final w = values['frameWidth'];
          if (w is num) width = w.toInt();
          final h = values['frameHeight'];
          if (h is num) height = h.toInt();
          final fd = values['framesDecoded'];
          if (fd is num) framesDecoded = fd.toInt();
          final j = values['jitter'];
          if (j is num) jitterMs = j.toDouble() * 1000.0;

          final packetsLost = (values['packetsLost'] as num?)?.toDouble() ?? 0;
          final packetsReceived =
              (values['packetsReceived'] as num?)?.toDouble() ?? 0;
          final total = packetsLost + packetsReceived;
          if (total > 0) {
            lossPct = (packetsLost / total * 100.0).clamp(0.0, 100.0);
          }

          final bytes = (values['bytesReceived'] as num?)?.toInt() ?? 0;
          final now = DateTime.now();
          if (_prevStatsTime != null && bytes >= _prevBytesReceived) {
            final elapsedSec =
                now.difference(_prevStatsTime!).inMilliseconds / 1000.0;
            if (elapsedSec > 0.1) {
              bitrateKbps =
                  ((bytes - _prevBytesReceived) * 8.0 / 1000.0) / elapsedSec;
            }
          }
          _prevBytesReceived = bytes;
          _prevStatsTime = now;
        } else if (report.type == 'candidate-pair' &&
            values['state'] == 'succeeded') {
          final rtt = values['currentRoundTripTime'];
          if (rtt is num) rttMs = rtt.toDouble() * 1000.0;
        }
      }

      _stats = NetworkStatistics(
        currentFps: fps,
        actualBitrateKbps: bitrateKbps,
        roundTripTimeMs: rttMs,
        packetLossPercent: lossPct,
        jitterMs: jitterMs,
        connectionType: 'WebRTC LAN',
        width: width,
        height: height,
        framesDecoded: framesDecoded,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> closePeer() async {
    _statsTimer?.cancel();
    _statsTimer = null;
    _remoteStream = null;
    _stats = NetworkStatistics.empty;
    _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateClosed;
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    notifyListeners();
  }

  @override
  void dispose() {
    closePeer();
    super.dispose();
  }
}
