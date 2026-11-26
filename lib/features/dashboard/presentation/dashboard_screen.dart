import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/camera_preview.dart';
import '../../../shared/widgets/components.dart';
import '../../../shared/widgets/lenscast_logo.dart';
import '../../camera/presentation/camera_controller.dart';

/// Home dashboard: live preview + primary connection actions.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // The dashboard is a launch surface: it must NOT auto-open the camera.
  // Starting capture (getUserMedia + native WebRTC init) is deferred until the
  // user explicitly opens Camera Studio. This keeps startup off the platform
  // thread and avoids ANRs on devices/emulators without a camera.
  Future<void> _refreshStatus() async {
    // Only read current permission status; never trigger capture here.
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cam = ref.watch(cameraControllerProvider);
    final stream = ref.read(cameraControllerProvider.notifier).mediaStream;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshStatus,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              Row(
                children: [
                  const LensCastLogo(size: 36, showGlow: false),
                  const SizedBox(width: AppSpacing.md),
                  Text('LensCast', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _PreviewCard(stream: stream, cam: cam),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Connect to your computer'),
              _ConnectAction(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Scan QR Code',
                subtitle: 'Point your camera at the code on your PC',
                onTap: () => context.go('/connection'),
              ),
              const SizedBox(height: AppSpacing.md),
              _ConnectAction(
                icon: Icons.wifi_find_rounded,
                title: 'Search Devices',
                subtitle: 'Auto-discover LensCast on your network',
                onTap: () => context.go('/connection'),
              ),
              const SizedBox(height: AppSpacing.md),
              _ConnectAction(
                icon: Icons.lan_outlined,
                title: 'Manual Connection',
                subtitle: 'Enter your computer IP and port',
                onTap: () => context.go('/connection'),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () => context.go('/studio'),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Open Camera Studio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.stream, required this.cam});
  final MediaStream? stream;
  final CameraState cam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = cam.config;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CameraPreview(
              stream: stream,
              mirror: settings.mirror,
              rotateQuarterTurns: settings.rotateQuarterTurns,
              placeholder: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_off_rounded,
                      size: 40, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Camera is off',
                      style: theme.textTheme.bodyMedium),
                ],
              ),
              overlay: Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                child: StatusPill(
                  label: cam.initialized ? 'Live' : 'Offline',
                  color: cam.initialized ? AppColors.success : AppColors.textMuted,
                  dense: true,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                _Stat(label: 'Camera',
                    value: settings.lensType.label),
                const _StatDivider(),
                _Stat(label: 'Resolution',
                    value: '${settings.height}p'),
                const _StatDivider(),
                _Stat(label: 'FPS', value: '${settings.fps}'),
                const _StatDivider(),
                _Stat(
                  label: 'Status',
                  value: cam.initialized ? 'Streaming ready' : 'Idle',
                  accent: cam.initialized
                      ? AppColors.success
                      : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.accent});
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.titleMedium?.copyWith(color: accent),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
      );
}

class _ConnectAction extends StatelessWidget {
  const _ConnectAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: theme.textTheme.bodySmall?.color),
        ],
      ),
    );
  }
}