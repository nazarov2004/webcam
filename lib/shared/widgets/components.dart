import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// A pill-shaped status indicator with a colored dot.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? AppSpacing.xs : AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ] else
            Container(
              width: dense ? 6 : 8,
              height: dense ? 6 : 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A surface card with consistent rounding and optional tap handling.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: border
            ? Border.all(
                color: theme.dividerColor.withValues(alpha: 0.6),
              )
            : null,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// A section header with a title and optional trailing widget.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.xs),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// A labeled toggle row.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// A labeled slider row with a live value readout.
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.valueLabel,
    this.enabled = true,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? valueLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              valueLabel ?? value.toStringAsFixed(2),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

/// A branded loading indicator using the primary accent.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(label!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// A full-screen error state with an optional retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    this.message,
    this.suggestion,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String title;
  final String? message;
  final String? suggestion;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: AppColors.error, size: 32),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(message!,
                  textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ],
            if (suggestion != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(suggestion!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}