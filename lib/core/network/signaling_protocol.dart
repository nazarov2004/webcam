import 'dart:convert';

/// Message types exchanged over the local WebSocket signaling channel.
abstract final class SignalType {
  static const String pair = 'pair';
  static const String paired = 'paired';
  static const String authFailed = 'auth_failed';
  static const String offer = 'offer';
  static const String answer = 'answer';
  static const String ice = 'ice';
  static const String cameraControl = 'camera_control';
  static const String stats = 'stats';
  static const String heartbeat = 'heartbeat';
  static const String pong = 'pong';
  static const String obsReady = 'obs_ready';
  static const String obsClosed = 'obs_closed';
  static const String disconnect = 'disconnect';
}

/// Target WebRTC peer on the mobile sender.
abstract final class PeerTarget {
  static const String desktop = 'desktop';
  static const String obs = 'obs';
}

/// Typed signaling message envelope.
class SignalMessage {
  const SignalMessage({
    required this.type,
    this.target,
    this.payload = const {},
  });

  final String type;
  final String? target;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (target != null) 'target': target,
        'payload': payload,
      };

  String encode() => jsonEncode(toJson());

  static SignalMessage? tryDecode(dynamic raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map<String, dynamic>) return null;
      final type = decoded['type'];
      if (type is! String || type.isEmpty) return null;
      final target = decoded['target'] as String?;
      final payload = decoded['payload'];
      return SignalMessage(
        type: type,
        target: target,
        payload: payload is Map<String, dynamic> ? payload : const {},
      );
    } catch (_) {
      return null;
    }
  }
}

/// Payload encoded inside the Desktop QR code for one-scan pairing.
class QrPairingPayload {
  const QrPairingPayload({
    required this.host,
    required this.port,
    required this.sessionId,
    required this.token,
    this.pin,
    this.deviceName = 'LensCast Desktop',
  });

  final String host;
  final int port;
  final String sessionId;
  final String token;
  final String? pin;
  final String deviceName;

  Map<String, dynamic> toJson() => {
        'app': 'lenscast',
        'v': 1,
        'host': host,
        'port': port,
        'sessionId': sessionId,
        'token': token,
        if (pin != null) 'pin': pin,
        'name': deviceName,
      };

  String encode() => jsonEncode(toJson());

  static QrPairingPayload? tryDecode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      if (map['app'] != 'lenscast') return null;
      final host = map['host'];
      final port = map['port'];
      final sessionId = map['sessionId'];
      final token = map['token'];
      if (host is! String ||
          host.isEmpty ||
          port is! int ||
          sessionId is! String ||
          token is! String) {
        return null;
      }
      return QrPairingPayload(
        host: host,
        port: port,
        sessionId: sessionId,
        token: token,
        pin: map['pin'] as String?,
        deviceName: (map['name'] as String?) ?? 'LensCast Desktop',
      );
    } catch (_) {
      return null;
    }
  }
}
