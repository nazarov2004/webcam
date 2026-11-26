import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/models/camera_configuration.dart';
import '../../shared/widgets/camera_preview.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/lenscast_logo.dart';
import 'desktop_controller.dart';

/// Windows Desktop Receiver studio control panel.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(desktopControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(desktopControllerProvider);
    final controller = ref.read(desktopControllerProvider.notifier);

    return Scaffold(
      body: Row(
        children: [
          _LeftSidebar(
            selectedIndex: _navIndex,
            onSelect: (i) => setState(() => _navIndex = i),
            state: state,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: switch (_navIndex) {
              0 => _DashboardView(state: state, controller: controller),
              1 => _DevicesPairingView(state: state, controller: controller),
              2 => _ObsIntegrationView(state: state, controller: controller),
              _ => _SettingsHelpView(state: state),
            },
          ),
          if (_navIndex == 0) ...[
            const VerticalDivider(width: 1),
            _RightControlsSidebar(state: state, controller: controller),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            StatusPill(
              label: state.mobileConnected
                  ? 'Connected: ${state.connectedDeviceName ?? "Phone"}'
                  : (state.serverRunning
                      ? 'Listening on :${state.port}'
                      : 'Receiver Offline'),
              color: state.mobileConnected
                  ? AppColors.success
                  : (state.serverRunning
                      ? AppColors.secondary
                      : AppColors.error),
              dense: true,
            ),
            const SizedBox(width: AppSpacing.md),
            if (state.obsConnected)
              const StatusPill(
                label: 'OBS Source Active',
                color: AppColors.primary,
                dense: true,
              ),
            const Spacer(),
            if (state.mobileConnected)
              TextButton.icon(
                onPressed: controller.disconnectPhone,
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text('Disconnect Phone'),
              ),
          ],
        ),
      ),
    );
  }
}

class _LeftSidebar extends StatelessWidget {
  const _LeftSidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.state,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final DesktopState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const items = [
      (Icons.dashboard_rounded, 'Dashboard'),
      (Icons.devices_rounded, 'Devices & QR'),
      (Icons.live_tv_rounded, 'OBS Integration'),
      (Icons.settings_rounded, 'Settings & Help'),
    ];

    return SizedBox(
      width: 220,
      child: Container(
        color: theme.colorScheme.surface,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const LensCastLogo(size: 32, showGlow: false),
                const SizedBox(width: AppSpacing.sm),
                Text('LensCast', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Desktop Receiver', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xl),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: ListTile(
                  selected: selectedIndex == i,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  leading: Icon(
                    items[i].$1,
                    color: selectedIndex == i ? AppColors.primary : null,
                  ),
                  title: Text(
                    items[i].$2,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          selectedIndex == i ? FontWeight.w600 : FontWeight.w400,
                      color: selectedIndex == i
                          ? AppColors.primary
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  onTap: () => onSelect(i),
                ),
              ),
            const Spacer(),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Pair PIN', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    state.pairingPin.isNotEmpty ? state.pairingPin : '—',
                    style: theme.textTheme.titleLarge?.copyWith(
                      letterSpacing: 3,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.selectedIp}:${state.port}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({required this.state, required this.controller});
  final DesktopState state;
  final DesktopController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stream = controller.remoteStream;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                color: AppColors.error.withValues(alpha: 0.12),
                child: Text(state.error!,
                    style: const TextStyle(color: AppColors.error)),
              ),
            ),
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: CameraPreview(
                stream: stream,
                placeholder: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phonelink_setup_rounded,
                      size: 56,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      state.mobileConnected
                          ? 'Receiving WebRTC stream...'
                          : 'Waiting for your phone to connect',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Open "Devices & QR" to scan the QR code, or enter '
                      '${state.selectedIp}:${state.port} with PIN ${state.pairingPin}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                overlay: Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.md,
                  child: StatusPill(
                    label: stream != null ? 'LIVE' : 'STANDBY',
                    color: stream != null ? AppColors.success : AppColors.warning,
                    dense: true,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              children: [
                _Metric('Device', state.connectedDeviceName ?? '—'),
                _Metric('Resolution', state.stats.resolutionLabel),
                _Metric('FPS', '${state.stats.currentFps}'),
                _Metric('Bitrate', state.stats.bitrateLabel),
                _Metric(
                  'Latency',
                  '${state.stats.roundTripTimeMs.toStringAsFixed(0)} ms',
                ),
                _Metric(
                  'Packet Loss',
                  '${state.stats.packetLossPercent.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RightControlsSidebar extends StatelessWidget {
  const _RightControlsSidebar({required this.state, required this.controller});
  final DesktopState state;
  final DesktopController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = state.mobileConnected;

    return SizedBox(
      width: 260,
      child: Container(
        color: theme.colorScheme.surface,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ListView(
          children: [
            Text('Remote Camera', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              enabled
                  ? 'Controls apply live on your phone.'
                  : 'Connect a phone to control camera settings.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.cameraswitch_rounded, size: 18),
                  label: const Text('Switch Lens'),
                  onPressed: enabled
                      ? () => controller.sendCameraControl('switch_lens')
                      : null,
                ),
                ActionChip(
                  avatar: const Icon(Icons.flip_rounded, size: 18),
                  label: const Text('Mirror'),
                  onPressed: enabled
                      ? () => controller.sendCameraControl('mirror')
                      : null,
                ),
                ActionChip(
                  avatar: const Icon(Icons.rotate_right_rounded, size: 18),
                  label: const Text('Rotate 90°'),
                  onPressed: enabled
                      ? () => controller.sendCameraControl('rotate')
                      : null,
                ),
                ActionChip(
                  avatar: const Icon(Icons.flashlight_on_rounded, size: 18),
                  label: const Text('Torch'),
                  onPressed: enabled
                      ? () => controller.sendCameraControl('torch')
                      : null,
                ),
                ActionChip(
                  avatar: const Icon(Icons.mic_rounded, size: 18),
                  label: const Text('Toggle Mic'),
                  onPressed: enabled
                      ? () => controller.sendCameraControl('mic')
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Quality Profile', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<QualityProfile>(
              initialValue: state.remoteQuality,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: QualityProfile.values
                  .map((q) => DropdownMenuItem(
                        value: q,
                        child: Text(q.label),
                      ))
                  .toList(),
              onChanged: enabled
                  ? (q) {
                      if (q != null) {
                        controller.sendCameraControl('quality', q);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Zoom (${state.remoteZoom.toStringAsFixed(1)}x)',
              style: theme.textTheme.titleSmall,
            ),
            Slider(
              value: state.remoteZoom,
              min: 1.0,
              max: 4.0,
              divisions: 12,
              onChanged: enabled
                  ? (v) => controller.sendCameraControl('zoom', v)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicesPairingView extends StatelessWidget {
  const _DevicesPairingView({required this.state, required this.controller});
  final DesktopState state;
  final DesktopController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Devices & QR Pairing', style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                children: [
                  if (state.sessionToken.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: QrImageView(
                        data: state.qrData,
                        size: 200,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Scan with LensCast Mobile',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: controller.rotateCredentials,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('New QR & PIN'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manual / LAN Connection',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    Text('Temporary Pairing PIN: ${state.pairingPin}',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: AppColors.secondary)),
                    const SizedBox(height: AppSpacing.md),
                    Text('Port: ${state.port}',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.md),
                    Text('Available Local IPv4 Addresses:',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: state.localIps
                          .map((ip) => ChoiceChip(
                                label: Text(ip),
                                selected: state.selectedIp == ip,
                                onSelected: (_) => controller.selectIp(ip),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      state.mobileConnected
                          ? 'Connected Phone: ${state.connectedDeviceName} '
                              '(${state.connectedDeviceModel ?? "Android"})'
                          : 'No phone connected yet.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ObsIntegrationView extends StatelessWidget {
  const _ObsIntegrationView({required this.state, required this.controller});
  final DesktopState state;
  final DesktopController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Text('OBS Studio Integration', style: theme.textTheme.displaySmall),
            const Spacer(),
            StatusPill(
              label: state.obsConnected ? 'OBS Connected' : 'Waiting for OBS',
              color:
                  state.obsConnected ? AppColors.success : AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Browser Source URL', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(
                state.obsUrl,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondary,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: state.obsUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('OBS URL copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy URL'),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              ToggleRow(
                title: 'Enable Audio in OBS',
                subtitle: 'Include phone microphone in Browser Source',
                value: state.obsAudioEnabled,
                onChanged: controller.setObsAudio,
              ),
              const Divider(),
              ToggleRow(
                title: 'Clean Output Mode',
                subtitle: 'Hide status overlay in OBS Browser Source',
                value: state.obsCleanOutput,
                onChanged: controller.setObsClean,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OBS Studio Setup Instructions',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              const Text(
                '1. Open OBS Studio.\n'
                '2. Go to the Sources dock.\n'
                '3. Click + (Add) → Browser.\n'
                '4. Paste the LensCast Browser Source URL above.\n'
                '5. Set Width: 1920 and Height: 1080 (or 1280×720).\n'
                '6. Set FPS: 30 (or 60 if streaming 60 FPS).\n'
                '7. Check "Control audio via OBS" if using phone mic.\n'
                '8. Click OK — your phone camera appears immediately.\n'
                '9. To use in Zoom/Meet/Teams/Discord, click "Start Virtual Camera" in OBS.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsHelpView extends ConsumerWidget {
  const _SettingsHelpView({required this.state});
  final DesktopState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsServiceProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Settings & Help', style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: ToggleRow(
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            subtitle: 'Studio-friendly dark interface',
            value: settings.themeMode == ThemeMode.dark,
            onChanged: (v) =>
                settings.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Virtual Camera & Conferencing Apps',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'In v1.0, LensCast outputs to Zoom, Google Meet, Microsoft Teams, '
                'Discord, and Telegram Desktop via OBS Studio\'s built-in Virtual Camera '
                '(add the LensCast Browser Source in OBS, then click Start Virtual Camera). '
                'A standalone signed DirectShow/Media Foundation driver is planned for Phase 7.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
