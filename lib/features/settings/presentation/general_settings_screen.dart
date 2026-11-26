import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/components.dart';
import '../../../shared/widgets/lenscast_logo.dart';

/// App-wide settings, persisted through [SettingsService].
class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsServiceProvider);
    final device = ref.watch(deviceInfoProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            Text('Settings', style: theme.textTheme.displaySmall),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Appearance'),
            AppCard(
              child: Column(
                children: [
                  ToggleRow(
                    icon: Icons.dark_mode_rounded,
                    title: 'Dark mode',
                    subtitle: 'Studio-friendly dark interface',
                    value: settings.themeMode == ThemeMode.dark,
                    onChanged: (v) => settings.setThemeMode(
                        v ? ThemeMode.dark : ThemeMode.light),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Camera & Streaming'),
            AppCard(
              child: Column(
                children: [
                  ToggleRow(
                    icon: Icons.videocam_rounded,
                    title: 'Auto-start camera',
                    value: settings.autoStartCamera,
                    onChanged: settings.setAutoStartCamera,
                  ),
                  const Divider(),
                  ToggleRow(
                    icon: Icons.brightness_6_rounded,
                    title: 'Keep screen awake',
                    value: settings.keepScreenAwake,
                    onChanged: settings.setKeepScreenAwake,
                  ),
                  const Divider(),
                  ToggleRow(
                    icon: Icons.replay_rounded,
                    title: 'Auto reconnect',
                    value: settings.autoReconnect,
                    onChanged: settings.setAutoReconnect,
                  ),
                  const Divider(),
                  ToggleRow(
                    icon: Icons.save_rounded,
                    title: 'Save last camera',
                    value: settings.saveLastCamera,
                    onChanged: settings.setSaveLastCamera,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Audio'),
            AppCard(
              child: Column(
                children: [
                  ToggleRow(
                    icon: Icons.mic_rounded,
                    title: 'Enable microphone',
                    value: settings.audioEnabled,
                    onChanged: settings.setAudioEnabled,
                  ),
                  const Divider(),
                  ToggleRow(
                    title: 'Noise suppression',
                    value: settings.noiseSuppression,
                    onChanged: settings.setNoiseSuppression,
                  ),
                  const Divider(),
                  ToggleRow(
                    title: 'Echo cancellation',
                    value: settings.echoCancellation,
                    onChanged: settings.setEchoCancellation,
                  ),
                  const Divider(),
                  ToggleRow(
                    title: 'Automatic gain control',
                    value: settings.autoGainControl,
                    onChanged: settings.setAutoGainControl,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'About'),
            AppCard(
              child: Row(
                children: [
                  const LensCastLogo(size: 40, showGlow: false),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LensCast',
                            style: theme.textTheme.titleMedium),
                        Text(
                          device.maybeWhen(
                            data: (d) => d.displayName,
                            orElse: () => 'Loading device info...',
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: 'v1.0.0',
                    color: AppColors.secondary,
                    dense: true,
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