import 'dart:io';

import 'package:bonsoir/bonsoir.dart';

import '../../app/constants/app_constants.dart';
import '../../core/utils/log.dart';

/// Broadcasts the LensCast Desktop receiver on the local network via mDNS
/// and resolves local IPv4 addresses for QR pairing & manual IP fallback.
class DesktopDiscoveryService {
  DesktopDiscoveryService();

  static const _tag = 'DesktopDiscovery';
  BonsoirBroadcast? _broadcast;

  Future<void> startBroadcast({
    required String name,
    required int port,
  }) async {
    await stopBroadcast();
    try {
      final service = BonsoirService(
        name: name,
        type: AppConstants.discoveryServiceType,
        port: port,
      );
      final broadcast = BonsoirBroadcast(service: service, printLogs: false);
      await broadcast.initialize();
      await broadcast.start();
      _broadcast = broadcast;
      Log.info(_tag, 'mDNS broadcast started: $name on port $port');
    } catch (e) {
      Log.warn(_tag, 'mDNS broadcast unavailable (manual/QR still work): $e');
    }
  }

  Future<void> stopBroadcast() async {
    try {
      await _broadcast?.stop();
    } catch (_) {}
    _broadcast = null;
  }

  /// Returns non-loopback IPv4 addresses sorted with private LAN IPs first.
  Future<List<String>> localIpv4Addresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final ips = <String>[];
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('169.254.')) {
            ips.add(addr.address);
          }
        }
      }
      ips.sort((a, b) => _scoreIp(b).compareTo(_scoreIp(a)));
      return ips;
    } catch (e) {
      Log.warn(_tag, 'Failed to list network interfaces: $e');
      return const [];
    }
  }

  int _scoreIp(String ip) {
    if (ip.startsWith('192.168.')) return 3;
    if (ip.startsWith('10.')) return 2;
    if (ip.startsWith('172.')) return 1;
    return 0;
  }
}
