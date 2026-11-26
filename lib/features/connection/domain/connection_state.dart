import 'package:flutter/foundation.dart';

import '../../../shared/models/device_model.dart';
import '../../../shared/models/network_statistics.dart';
import '../../../shared/models/streaming_session.dart';

/// Connection UI state for the phone side.
@immutable
class ConnectionState {
  const ConnectionState({
    this.status = ConnectionStatus.idle,
    this.devices = const [],
    this.session,
    this.error,
    this.isDiscovering = false,
    this.stats = NetworkStatistics.empty,
    this.obsActive = false,
  });

  final ConnectionStatus status;
  final List<DeviceModel> devices;
  final StreamingSession? session;
  final String? error;
  final bool isDiscovering;
  final NetworkStatistics stats;
  final bool obsActive;

  ConnectionState copyWith({
    ConnectionStatus? status,
    List<DeviceModel>? devices,
    StreamingSession? session,
    bool clearSession = false,
    String? error,
    bool clearError = false,
    bool? isDiscovering,
    NetworkStatistics? stats,
    bool? obsActive,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      devices: devices ?? this.devices,
      session: clearSession ? null : (session ?? this.session),
      error: clearError ? null : (error ?? this.error),
      isDiscovering: isDiscovering ?? this.isDiscovering,
      stats: stats ?? this.stats,
      obsActive: obsActive ?? this.obsActive,
    );
  }
}