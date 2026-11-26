import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/errors/app_error.dart';
import '../../../shared/models/camera_configuration.dart';
import '../data/camera_service.dart';

/// Immutable UI state for the camera studio.
@immutable
class CameraState {
  const CameraState({
    this.initialized = false,
    this.initializing = false,
    this.config = const CameraConfiguration(),
    this.capabilities = const CameraCapabilities(),
    this.error,
    this.micEnabled = true,
    this.facingUser = false,
  });

  final bool initialized;
  final bool initializing;
  final CameraConfiguration config;
  final CameraCapabilities capabilities;
  final AppError? error;
  final bool micEnabled;
  final bool facingUser;

  CameraState copyWith({
    bool? initialized,
    bool? initializing,
    CameraConfiguration? config,
    CameraCapabilities? capabilities,
    AppError? error,
    bool clearError = false,
    bool? micEnabled,
    bool? facingUser,
  }) {
    return CameraState(
      initialized: initialized ?? this.initialized,
      initializing: initializing ?? this.initializing,
      config: config ?? this.config,
      capabilities: capabilities ?? this.capabilities,
      error: clearError ? null : (error ?? this.error),
      micEnabled: micEnabled ?? this.micEnabled,
      facingUser: facingUser ?? this.facingUser,
    );
  }
}

/// Controller that owns a single [CameraService] and exposes [CameraState].
class CameraController extends StateNotifier<CameraState> {
  CameraController(this._service) : super(const CameraState()) {
    _service.addListener(_syncFromService);
  }

  final CameraService _service;

  MediaStream? get mediaStream => _service.stream;

  void _syncFromService() {
    state = state.copyWith(
      initialized: _service.isInitialized,
      config: _service.config,
      capabilities: _service.capabilities,
    );
  }

  Future<void> initialize({bool audio = true}) async {
    if (state.initializing || state.initialized) return;
    state = state.copyWith(initializing: true, clearError: true);
    try {
      await _service.initialize(state.config, audio: audio);
      state = state.copyWith(
        initializing: false,
        initialized: true,
        micEnabled: audio,
        facingUser: state.config.lensType == LensType.front,
      );
    } catch (e) {
      state = state.copyWith(
        initializing: false,
        error: AppError.from(e, fallbackCode: ErrorCodes.cameraUnavailable),
      );
    }
  }

  Future<void> switchLens() async {
    final next =
        state.config.lensType == LensType.rear ? LensType.front : LensType.rear;
    state = state.copyWith(config: state.config.copyWith(lensType: next));
    await _service.switchLens(next);
    state = state.copyWith(facingUser: next == LensType.front);
  }

  Future<void> setQuality(QualityProfile q) async {
    state = state.copyWith(config: state.config.copyWith(quality: q));
    await _service.setQuality(q);
  }

  Future<void> setZoom(double v) async {
    state = state.copyWith(config: state.config.copyWith(zoom: v));
    await _service.setZoom(v);
  }

  Future<void> setExposure(double v) async {
    state = state.copyWith(config: state.config.copyWith(exposureOffset: v));
    await _service.setExposureOffset(v);
  }

  Future<void> toggleTorch() async {
    final next = !state.config.torchEnabled;
    state = state.copyWith(config: state.config.copyWith(torchEnabled: next));
    await _service.setTorch(next);
  }

  Future<void> toggleMirror() async {
    final next = !state.config.mirror;
    state = state.copyWith(config: state.config.copyWith(mirror: next));
    await _service.setMirror(next);
  }

  Future<void> rotate() async {
    final next = (state.config.rotateQuarterTurns + 1) % 4;
    state = state.copyWith(
      config: state.config.copyWith(rotateQuarterTurns: next),
    );
  }

  Future<void> toggleMic() async {
    final next = !state.micEnabled;
    state = state.copyWith(micEnabled: next);
    await _service.setMicrophoneEnabled(next);
  }

  /// Temporarily releases the camera hardware (e.g. before opening QR scanner).
  Future<void> releaseCamera() async {
    await _service.release();
    state = state.copyWith(initialized: false, initializing: false);
  }

  @override
  void dispose() {
    _service.removeListener(_syncFromService);
    _service.dispose();
    super.dispose();
  }
}

final cameraServiceProvider = Provider<CameraService>((ref) {
  // The controller owns the lifecycle and disposes the service.
  return CameraService();
});

final cameraControllerProvider =
    StateNotifierProvider<CameraController, CameraState>((ref) {
  return CameraController(ref.watch(cameraServiceProvider));
});