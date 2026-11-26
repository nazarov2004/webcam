import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/utils/log.dart';
import '../../../shared/models/device_model.dart';

/// Discovers LensCast desktop receivers on the LAN using mDNS (Bonsoir 7.x).
///
/// Performs real network discovery; devices are only emitted when a Bonsoir
/// service is actually resolved on the network.
class DiscoveryService {
  DiscoveryService();

  static const _tag = 'DiscoveryService';
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _sub;

  /// Starts discovery and emits [DeviceModel]s as receivers are resolved.
  Stream<DeviceModel> start() {
    final controller = StreamController<DeviceModel>.broadcast(
      onCancel: stop,
    );
    final discovery = BonsoirDiscovery(
      type: AppConstants.discoveryServiceType,
      printLogs: false,
    );
    _discovery = discovery;
    _sub = discovery.eventStream?.listen((event) {
      if (event is BonsoirDiscoveryServiceResolvedEvent) {
        final model = _map(event.service);
        if (model != null && !controller.isClosed) {
          Log.info(_tag, 'Discovered ${model.name} @ ${model.ipAddress}');
          controller.add(model);
        }
      } else if (event is BonsoirDiscoveryServiceFoundEvent) {
        // Not yet resolved (no IP); wait for the resolved event.
        Log.debug(_tag, 'Service found, awaiting resolution');
      }
    });
    discovery.start().catchError((Object e) {
      Log.error(_tag, 'Discovery start failed', e);
      if (!controller.isClosed) controller.addError(e);
    });
    return controller.stream;
  }

  DeviceModel? _map(BonsoirService service) {
    try {
      final host = service.hostAddress;
      if (host == null || host.isEmpty) return null;
      return DeviceModel(
        id: '$host:${service.port}',
        name: service.name.isNotEmpty ? service.name : 'LensCast Desktop',
        platform: 'windows',
        ipAddress: host,
        connectionType: ConnectionType.wifi,
      );
    } catch (e) {
      Log.warn(_tag, 'Failed to map service: $e');
      return null;
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _discovery?.stop();
    _discovery = null;
  }
}