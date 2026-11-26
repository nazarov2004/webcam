import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/log.dart';
import '../../../shared/models/camera_configuration.dart';

/// Snapshot of the live camera capabilities reported by the platform.
@immutable
class CameraCapabilities {
  const CameraCapabilities({
    this.hasTorch = false,
    this.hasZoom = false,
    this.hasFocus = false,
    this.minZoom = 1.0,
    this.maxZoom = 1.0,
    this.hasExposureControl = false,
  });

  final bool hasTorch;
  final bool hasZoom;
  final bool hasFocus;
  final double minZoom;
  final double maxZoom;
  final bool hasExposureControl;
}

/// Owns the single, authoritative local media capture pipeline.
///
/// Design rule from the spec: never open multiple independent camera capture
/// pipelines. This service is the only place `getUserMedia` is called for the
/// camera, and the resulting [MediaStream] is shared with both the local
/// preview and the WebRTC sender.
class CameraService extends ChangeNotifier {
  CameraService();

  static const _tag = 'CameraService';

  MediaStream? _stream;
  MediaStreamTrack? _videoTrack;
  CameraCapabilities _capabilities = const CameraCapabilities();
  CameraConfiguration _config = const CameraConfiguration();
  bool _micEnabled = true;

  MediaStream? get stream => _stream;
  MediaStreamTrack? get videoTrack => _videoTrack;
  CameraCapabilities get capabilities => _capabilities;
  CameraConfiguration get config => _config;
  bool get isInitialized => _stream != null;

  /// Opens the camera (and optionally the microphone) with the given config.
  Future<void> initialize(CameraConfiguration config, {bool audio = true}) async {
    _config = config;
    _micEnabled = audio;
    await _open(config, audio: audio);
  }

  Future<void> _open(CameraConfiguration config, {required bool audio}) async {
    try {
      _stopTracks();
      final media = await navigator.mediaDevices.getUserMedia({
        'audio': audio
            ? {
                'echoCancellation': true,
                'noiseSuppression': true,
                'channelCount': 1,
              }
            : false,
        'video': {
          'facingMode': config.lensType == LensType.front ? 'user' : 'environment',
          'width': {'ideal': config.width},
          'height': {'ideal': config.height},
          'frameRate': {'ideal': config.fps, 'max': config.fps},
        },
      }).timeout(const Duration(seconds: 10));
      _stream = media;
      _videoTrack = media.getVideoTracks().firstOrNull;
      _capabilities = _readCapabilities(_videoTrack);
      Log.info(_tag, 'Camera opened ${config.width}x${config.height}@${config.fps}');
      notifyListeners();
    } catch (e) {
      Log.error(_tag, 'Failed to open camera', e);
      throw AppError(
        code: ErrorCodes.cameraUnavailable,
        message: e.toString(),
        userMessage: 'The camera could not be started.',
        suggestion: 'Close other apps using the camera and try again.',
        retryable: true,
        cause: e,
      );
    }
  }

  CameraCapabilities _readCapabilities(MediaStreamTrack? track) {
    if (track == null) return const CameraCapabilities();
    final caps = track.getConstraints();
    final settings = track.getSettings();
    final zoom = settings['zoom'];
    final hasZoom = zoom is num && zoom > 1;
    return CameraCapabilities(
      hasTorch: caps.containsKey('torch') || settings.containsKey('torch'),
      hasZoom: hasZoom,
      hasFocus: caps.containsKey('focusMode'),
      minZoom: hasZoom ? 1.0 : 1.0,
      maxZoom: hasZoom ? zoom.toDouble() : 1.0,
      hasExposureControl: caps.containsKey('exposureCompensation'),
    );
  }

  /// Switches between front and rear cameras while keeping the same stream
  /// object identity for downstream consumers where possible.
  Future<void> switchLens(LensType lens) async {
    if (lens == _config.lensType) return;
    final next = _config.copyWith(lensType: lens, zoom: 1.0);
    _config = next;
    await _open(next, audio: _micEnabled);
  }

  Future<void> setQuality(QualityProfile quality) async {
    final next = _config.copyWith(quality: quality, clearBitrate: false);
    _config = next;
    await _open(next, audio: _micEnabled);
  }

  Future<void> setZoom(double value) async {
    final clamped = value.clamp(_capabilities.minZoom, _capabilities.maxZoom);
    _config = _config.copyWith(zoom: clamped);
    final track = _videoTrack;
    if (track != null) await Helper.setZoom(track, clamped);
  }

  Future<void> setTorch(bool enabled) async {
    if (!_capabilities.hasTorch) return;
    _config = _config.copyWith(torchEnabled: enabled);
    await _videoTrack?.setTorch(enabled);
  }

  Future<void> setMirror(bool mirror) async {
    _config = _config.copyWith(mirror: mirror);
  }

  Future<void> setExposureOffset(double value) async {
    if (!_capabilities.hasExposureControl) return;
    _config = _config.copyWith(exposureOffset: value);
    await _applyConstraints({
      'advanced': [{'exposureCompensation': value}]
    });
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    _micEnabled = enabled;
    final audioTrack = _stream?.getAudioTracks().firstOrNull;
    if (audioTrack != null) audioTrack.enabled = enabled;
  }

  Future<void> _applyConstraints(Map<String, dynamic> constraints) async {
    try {
      await _videoTrack?.applyConstraints(constraints);
    } catch (e) {
      Log.warn(_tag, 'applyConstraints failed: $e');
    }
  }

  void _stopTracks() {
    _stream?.getTracks().forEach((t) => t.stop());
    _stream = null;
    _videoTrack = null;
  }

  /// Releases the hardware camera so another consumer (e.g. QR scanner) can
  /// open it without a Camera2/CameraX conflict.
  Future<void> release() async {
    _stopTracks();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTracks();
    super.dispose();
  }
}