import 'package:flutter/foundation.dart';

/// The transport used to reach a peer.
enum ConnectionType {
  wifi('Wi-Fi'),
  usbTethering('USB Tethering'),
  manualIp('Manual IP'),
  qr('QR Code'),
  unknown('Unknown');

  const ConnectionType(this.label);
  final String label;

  static ConnectionType fromName(String? name) =>
      ConnectionType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ConnectionType.unknown,
      );
}

/// A discovered or paired remote device (the Windows desktop, from the phone's
/// perspective, or a phone from the desktop's perspective).
@immutable
class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.name,
    this.model,
    this.platform = 'windows',
    this.ipAddress,
    this.connectionType = ConnectionType.unknown,
    this.isConnected = false,
    this.lastConnected,
  });

  final String id;
  final String name;
  final String? model;
  final String platform;
  final String? ipAddress;
  final ConnectionType connectionType;
  final bool isConnected;
  final DateTime? lastConnected;

  DeviceModel copyWith({
    String? id,
    String? name,
    String? model,
    String? platform,
    String? ipAddress,
    ConnectionType? connectionType,
    bool? isConnected,
    DateTime? lastConnected,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      model: model ?? this.model,
      platform: platform ?? this.platform,
      ipAddress: ipAddress ?? this.ipAddress,
      connectionType: connectionType ?? this.connectionType,
      isConnected: isConnected ?? this.isConnected,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'model': model,
        'platform': platform,
        'ipAddress': ipAddress,
        'connectionType': connectionType.name,
        'isConnected': isConnected,
        'lastConnected': lastConnected?.toIso8601String(),
      };

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Unknown device',
        model: json['model'] as String?,
        platform: (json['platform'] as String?) ?? 'windows',
        ipAddress: json['ipAddress'] as String?,
        connectionType: ConnectionType.fromName(json['connectionType'] as String?),
        isConnected: (json['isConnected'] as bool?) ?? false,
        lastConnected: json['lastConnected'] == null
            ? null
            : DateTime.tryParse(json['lastConnected'] as String),
      );

  bool validate() => id.isNotEmpty && name.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is DeviceModel && other.id == id && other.ipAddress == ipAddress;

  @override
  int get hashCode => Object.hash(id, ipAddress);
}