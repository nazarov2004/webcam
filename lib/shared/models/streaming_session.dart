import 'package:flutter/foundation.dart';

import 'device_model.dart';

/// High level connection state machine for the phone <-> desktop link.
enum ConnectionStatus {
  idle('Not connected'),
  searching('Searching for devices...'),
  deviceFound('Device found'),
  pairing('Pairing...'),
  connecting('Connecting...'),
  connected('Connected'),
  reconnecting('Reconnecting...'),
  connectionLost('Connection lost'),
  authenticationFailed('Authentication failed'),
  unsupportedNetwork('Unsupported network'),
  cameraPermissionRequired('Camera permission required');

  const ConnectionStatus(this.label);
  final String label;

  bool get isTerminalError =>
      this == authenticationFailed ||
      this == unsupportedNetwork ||
      this == connectionLost;
}

/// A single streaming session bound to a device.
@immutable
class StreamingSession {
  const StreamingSession({
    required this.sessionId,
    required this.device,
    required this.status,
    this.startedAt,
    this.width = 1280,
    this.height = 720,
    this.fps = 30,
    this.bitrateKbps = 2500,
    this.audioEnabled = true,
  });

  final String sessionId;
  final DeviceModel device;
  final ConnectionStatus status;
  final DateTime? startedAt;
  final int width;
  final int height;
  final int fps;
  final int bitrateKbps;
  final bool audioEnabled;

  bool get isActive => status == ConnectionStatus.connected;

  Duration get uptime =>
      startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!);

  StreamingSession copyWith({
    String? sessionId,
    DeviceModel? device,
    ConnectionStatus? status,
    DateTime? startedAt,
    int? width,
    int? height,
    int? fps,
    int? bitrateKbps,
    bool? audioEnabled,
  }) {
    return StreamingSession(
      sessionId: sessionId ?? this.sessionId,
      device: device ?? this.device,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      audioEnabled: audioEnabled ?? this.audioEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'device': device.toJson(),
        'status': status.name,
        'startedAt': startedAt?.toIso8601String(),
        'width': width,
        'height': height,
        'fps': fps,
        'bitrateKbps': bitrateKbps,
        'audioEnabled': audioEnabled,
      };

  factory StreamingSession.fromJson(Map<String, dynamic> json) =>
      StreamingSession(
        sessionId: json['sessionId'] as String,
        device: DeviceModel.fromJson(json['device'] as Map<String, dynamic>),
        status: ConnectionStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ConnectionStatus.idle,
        ),
        startedAt: json['startedAt'] == null
            ? null
            : DateTime.tryParse(json['startedAt'] as String),
        width: (json['width'] as int?) ?? 1280,
        height: (json['height'] as int?) ?? 720,
        fps: (json['fps'] as int?) ?? 30,
        bitrateKbps: (json['bitrateKbps'] as int?) ?? 2500,
        audioEnabled: (json['audioEnabled'] as bool?) ?? true,
      );

  bool validate() => sessionId.isNotEmpty && fps > 0;
}