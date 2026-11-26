import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/models/camera_configuration.dart';
import '../../../../shared/widgets/components.dart';
import '../camera_controller.dart';

/// The control dock shown under the studio preview.
class StudioControls extends ConsumerWidget {
  const StudioControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = ref.watch(cameraControllerProvider);
    final c = ref.read(cameraControllerProvider.notifier);
    final caps = cam.capabilities;
    final config = cam.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Camera'),
        AppCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _CircleControl(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Switch',
                    onTap: c.switchLens,
                  ),
                  _CircleControl(
                    icon: config.torchEnabled
                        ? Icons.flashlight_on_rounded
                        : Icons.flashlight_off_rounded,
                    label: 'Flash',
                    enabled: caps.hasTorch,
                    active: config.torchEnabled,
                    onTap: c.toggleTorch,
                  ),
                  _CircleControl(
                    icon: Icons.flip_rounded,
                    label: 'Mirror',
                    active: config.mirror,
                    onTap: c.toggleMirror,
                  ),
                  _CircleControl(
                    icon: Icons.rotate_90_degrees_ccw_rounded,
                    label: 'Rotate',
                    onTap: c.rotate,
                  ),
                ],
              ),
              if (caps.hasZoom) ...[
                const SizedBox(height: AppSpacing.md),
                LabeledSlider(
                  label: 'Zoom',
                  value: config.zoom,
                  min: caps.minZoom,
                  max: caps.maxZoom > caps.minZoom
                      ? caps.maxZoom
                      : caps.minZoom + 1,
                  valueLabel: '${config.zoom.toStringAsFixed(1)}×',
                  divisions: 20,
                  onChanged: c.setZoom,
                ),
              ],
              if (caps.hasExposureControl) ...[
                const SizedBox(height: AppSpacing.md),
                LabeledSlider(
                  label: 'Exposure',
                  value: config.exposureOffset,
                  min: -2,
                  max: 2,
                  divisions: 16,
                  onChanged: c.setExposure,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Video Quality'),
        AppCard(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: QualityProfile.values.map((q) {
              final selected = config.quality == q;
              return _ChoiceChip(
                label: '${q.label} · ${q.resolutionLabel}',
                selected: selected,
                onTap: () => c.setQuality(q),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _CircleControl extends StatelessWidget {
  const _CircleControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = !enabled
        ? theme.textTheme.bodySmall?.color
        : active
            ? AppColors.primary
            : theme.colorScheme.onSurface;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        onTap: enabled ? onTap : null,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : theme.cardColor,
                border: Border.all(
                  color: active
                      ? AppColors.primary
                      : theme.dividerColor.withValues(alpha: 0.6),
                ),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.16)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : theme.dividerColor.withValues(alpha: 0.6),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: selected ? AppColors.primary : null,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}