import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/network/signaling_protocol.dart';
import '../../../shared/models/device_model.dart';
import '../../../shared/models/network_statistics.dart';
import '../../../shared/models/streaming_session.dart';
import '../../../shared/widgets/components.dart';
import '../../camera/presentation/camera_controller.dart';
import 'connection_controller.dart';

/// Connection hub: QR scan, device search, manual IP + PIN, and USB networking.
class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _ip = TextEditingController();
  final _port = TextEditingController(text: '8765');
  final _pin = TextEditingController();
  bool _testing = false;

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final camCtrl = ref.read(cameraControllerProvider.notifier);
    final wasActive = ref.read(cameraControllerProvider).initialized;
    if (wasActive) {
      await camCtrl.releaseCamera();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted) return;
    final result = await context.push<QrPairingPayload>('/scan-qr');
    if (!mounted) return;
    if (result != null) {
      await ref
          .read(connectionControllerProvider.notifier)
          .connectWithQr(result);
    } else if (wasActive) {
      await camCtrl.initialize();
    }
  }

  Future<void> _testAndConnectManual() async {
    setState(() => _testing = true);
    final port = int.tryParse(_port.text) ?? 8765;
    final controller = ref.read(connectionControllerProvider.notifier);
    final ok = await controller.testManualConnection(_ip.text, port);
    if (!mounted) return;
    setState(() => _testing = false);
    if (ok) {
      final pin = _pin.text.trim();
      if (pin.length == 6) {
        await controller.connectToDevice(
          DeviceModel(
            id: '${_ip.text.trim()}:$port',
            name: 'LensCast Desktop (${_ip.text.trim()})',
            ipAddress: _ip.text.trim(),
            connectionType: ConnectionType.manualIp,
          ),
          port: port,
          pin: pin,
        );
      } else {
        _snack('Desktop reachable. Enter the 6-digit PIN to pair.');
      }
    }
  }

  Future<void> _pairWithPin(DeviceModel device) async {
    final pinCtrl = TextEditingController(text: _pin.text);
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pair with ${device.name}'),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '6-digit Pairing PIN',
            hintText: 'Shown in LensCast Desktop',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, pinCtrl.text.trim()),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    pinCtrl.dispose();
    if (pin == null || pin.isEmpty || !mounted) return;
    await ref
        .read(connectionControllerProvider.notifier)
        .connectToDevice(device, pin: pin);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(connectionControllerProvider);
    final controller = ref.read(connectionControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            Text('Connect', style: theme.textTheme.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Pair your phone with LensCast Desktop on your computer.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  color: AppColors.error.withValues(alpha: 0.12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                _ConnectionStatusBanner(status: state.status),
                if (state.obsActive) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const StatusPill(
                    label: 'OBS Active',
                    color: AppColors.secondary,
                    dense: true,
                  ),
                ],
              ],
            ),
            if (state.session != null) ...[
              const SizedBox(height: AppSpacing.md),
              _SessionCard(
                session: state.session!,
                stats: state.stats,
                onDisconnect: controller.disconnect,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'QR Code'),
            AppCard(
              onTap: _scanQr,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan QR Code',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text('Instant one-scan pairing with LensCast Desktop',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Search Devices'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.isDiscovering
                              ? 'Searching your network...'
                              : 'Find LensCast Desktop automatically',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      FilledButton(
                        onPressed: state.isDiscovering
                            ? controller.stopDiscovery
                            : controller.startDiscovery,
                        child: Text(state.isDiscovering ? 'Stop' : 'Search'),
                      ),
                    ],
                  ),
                  if (state.devices.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    ...state.devices.map((d) => _DeviceTile(
                          device: d,
                          onTap: () => _pairWithPin(d),
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Manual Connection'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (kDebugMode) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        avatar: const Icon(Icons.developer_mode_rounded, size: 16),
                        label: const Text('Emulator Host (10.0.2.2)'),
                        onPressed: () {
                          _ip.text = '10.0.2.2';
                          _port.text = '8765';
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  TextField(
                    controller: _ip,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Computer IP address',
                      hintText: '192.168.1.20',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _port,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _pin,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Pairing PIN',
                            hintText: '6 digits',
                            counterText: '',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _testing ? null : _testAndConnectManual,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find_rounded),
                    label: const Text('Connect & Stream'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'USB Networking (Advanced)'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.usb_rounded, color: AppColors.secondary),
                      const SizedBox(width: AppSpacing.sm),
                      Text('USB Tethering or ADB Tunnel',
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '1. USB Tethering: Enable USB tethering in Android Settings, then '
                    'enter your PC\'s USB network IP above.\n'
                    '2. ADB Tunnel (USB Debugging): Run "adb reverse tcp:8765 tcp:8765" '
                    'on your PC, then connect to 127.0.0.1:8765.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatusBanner extends StatelessWidget {
  const _ConnectionStatusBanner({required this.status});
  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectionStatus.connected => AppColors.success,
      ConnectionStatus.searching ||
      ConnectionStatus.pairing ||
      ConnectionStatus.connecting ||
      ConnectionStatus.reconnecting =>
        AppColors.warning,
      ConnectionStatus.connectionLost ||
      ConnectionStatus.authenticationFailed ||
      ConnectionStatus.unsupportedNetwork =>
        AppColors.error,
      _ => AppColors.textMuted,
    };
    return StatusPill(label: status.label, color: color);
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onTap});
  final DeviceModel device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: ListTile(
          onTap: onTap,
          leading: const Icon(Icons.desktop_windows_rounded,
              color: AppColors.primary),
          title: Text(device.name, style: theme.textTheme.titleMedium),
          subtitle: Text(
            '${device.connectionType.label} · ${device.ipAddress ?? '—'}',
            style: theme.textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.stats,
    required this.onDisconnect,
  });
  final StreamingSession session;
  final NetworkStatistics stats;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = session.status == ConnectionStatus.connected;
    return AppCard(
      color: (isConnected ? AppColors.success : AppColors.primary)
          .withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.sensors_rounded : Icons.link_rounded,
                color: isConnected ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected
                          ? 'Streaming to ${session.device.name}'
                          : 'Connecting to ${session.device.name}...',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected
                          ? '${stats.resolutionLabel} · ${stats.currentFps} FPS · '
                              '${stats.bitrateLabel} · RTT ${stats.roundTripTimeMs.toStringAsFixed(0)} ms'
                          : 'Establishing WebRTC media session...',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onDisconnect,
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
