/// Application-wide constants.
abstract final class AppConstants {
  static const String appName = 'LensCast';
  static const String org = 'com.lenscast';

  /// mDNS service type used for LAN discovery of the desktop receiver.
  static const String discoveryServiceType = '_lenscast._tcp';

  /// Default signaling / receiver port for the Windows desktop application.
  static const int defaultDesktopPort = 8765;

  /// Default session token length (bytes -> hex chars).
  static const int sessionTokenBytes = 16;

  /// Pairing token validity window.
  static const Duration pairingTokenTtl = Duration(minutes: 10);

  /// Heartbeat interval for the signaling connection.
  static const Duration heartbeatInterval = Duration(seconds: 5);

  /// Connection timeout before surfacing an error.
  static const Duration connectTimeout = Duration(seconds: 12);

  static const List<String> supportedPlatforms = ['android', 'windows'];
}