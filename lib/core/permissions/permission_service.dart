import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../errors/app_error.dart';

/// The set of runtime permissions the app needs, with user-facing rationale.
enum AppPermission {
  camera(
    Permission.camera,
    'Camera',
    'LensCast uses your camera to send video to your computer as a webcam.',
  ),
  microphone(
    Permission.microphone,
    'Microphone',
    'LensCast sends your microphone audio alongside the video. You can disable it any time.',
  ),
  notification(
    Permission.notification,
    'Notifications',
    'A notification keeps the stream running reliably while the app is in the background.',
  );

  const AppPermission(this.platform, this.label, this.rationale);
  final Permission platform;
  final String label;
  final String rationale;
}

/// Result of requesting a single permission.
class PermissionResult {
  const PermissionResult(this.permission, this.status);
  final AppPermission permission;
  final PermissionStatus status;

  bool get isGranted => status.isGranted;
  bool get isPermanentlyDenied => status.isPermanentlyDenied;
}

/// Wraps permission_handler with rationale metadata and error mapping.
abstract final class PermissionService {
  /// On a real device these are required; on desktop/web they are no-ops.
  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<PermissionResult> request(AppPermission p) async {
    if (!_isMobile) {
      return PermissionResult(p, PermissionStatus.granted);
    }
    final status = await p.platform.request();
    return PermissionResult(p, status);
  }

  static Future<PermissionResult> current(AppPermission p) async {
    if (!_isMobile) {
      return PermissionResult(p, PermissionStatus.granted);
    }
    return PermissionResult(p, await p.platform.status);
  }

  /// Requests camera + microphone, returning the first denial (if any).
  static Future<PermissionResult?> requestCore() async {
    for (final p in [AppPermission.camera, AppPermission.microphone]) {
      final result = await request(p);
      if (!result.isGranted) return result;
    }
    return null;
  }

  static Future<void> openSettings() => openAppSettings();

  static AppError toAppError(PermissionResult r) {
    final isCamera = r.permission == AppPermission.camera;
    return AppError(
      code: isCamera
          ? ErrorCodes.cameraPermissionDenied
          : ErrorCodes.microphonePermissionDenied,
      message: '${r.permission.label} permission ${r.status.name}',
      userMessage:
          '${r.permission.label} access is needed for LensCast to work.',
      suggestion: r.isPermanentlyDenied
          ? 'Enable ${r.permission.label} in Settings, then return.'
          : 'Grant ${r.permission.label} access to continue.',
      retryable: true,
    );
  }
}