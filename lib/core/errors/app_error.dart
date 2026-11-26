/// A typed, user-facing error with a recoverable action.
///
/// Every error carries:
///  - [message]: short technical reason (for logs / developer console).
///  - [userMessage]: human friendly explanation.
///  - [suggestion]: recommended fix shown to the user.
///  - [code]: stable machine readable identifier.
///  - [retryable]: whether a Retry action makes sense.
class AppError implements Exception {
  const AppError({
    required this.code,
    required this.message,
    required this.userMessage,
    this.suggestion,
    this.retryable = false,
    this.cause,
  });

  final String code;
  final String message;
  final String userMessage;
  final String? suggestion;
  final bool retryable;
  final Object? cause;

  @override
  String toString() => 'AppError($code): $message';

  /// Maps a raw error into a structured [AppError] so the UI can react.
  factory AppError.from(Object error, {String? fallbackCode}) {
    if (error is AppError) return error;
    return AppError(
      code: fallbackCode ?? 'unknown',
      message: error.toString(),
      userMessage: 'Something went wrong.',
      suggestion: 'Please try again.',
      retryable: true,
      cause: error,
    );
  }
}

/// Stable error codes used across the app.
abstract final class ErrorCodes {
  static const String cameraUnavailable = 'camera_unavailable';
  static const String cameraPermissionDenied = 'camera_permission_denied';
  static const String microphonePermissionDenied = 'mic_permission_denied';
  static const String noNetwork = 'no_network';
  static const String deviceNotFound = 'device_not_found';
  static const String invalidPairingCode = 'invalid_pairing_code';
  static const String invalidIp = 'invalid_ip';
  static const String connectionTimeout = 'connection_timeout';
  static const String negotiationFailed = 'negotiation_failed';
  static const String unsupportedResolution = 'unsupported_resolution';
  static const String unsupportedFps = 'unsupported_fps';
  static const String encoderUnavailable = 'encoder_unavailable';
  static const String microphoneUnavailable = 'mic_unavailable';
  static const String appBackgrounded = 'app_backgrounded';
  static const String phoneOverheated = 'phone_overheated';
  static const String batteryCritical = 'battery_critical';
  static const String desktopUnavailable = 'desktop_unavailable';
  static const String obsEndpointUnavailable = 'obs_endpoint_unavailable';
  static const String unknown = 'unknown';
}