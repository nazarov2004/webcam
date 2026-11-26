import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../shared/widgets/components.dart';

/// Requests camera, microphone and notification permissions with rationale.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {
  final Map<AppPermission, bool> _granted = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncCurrent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncCurrent();
    }
  }

  Future<void> _request(AppPermission p) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await PermissionService.request(p);
      if (!mounted) return;
      setState(() => _granted[p] = result.isGranted);
      if (result.isPermanentlyDenied) {
        _showDenied(result);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showDenied(PermissionResult r) {
    final err = PermissionService.toAppError(r);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${err.userMessage} ${err.suggestion ?? ''}'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: PermissionService.openSettings,
        ),
      ),
    );
  }

  Future<void> _requestAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      for (final p in AppPermission.values) {
        final result = await PermissionService.request(p);
        if (!mounted) return;
        setState(() => _granted[p] = result.isGranted);
        if (!result.isGranted &&
            result.isPermanentlyDenied &&
            p != AppPermission.notification) {
          _showDenied(result);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continue() => context.go('/');

  Future<void> _syncCurrent() async {
    final map = <AppPermission, bool>{};
    for (final p in AppPermission.values) {
      final r = await PermissionService.current(p);
      map[p] = r.isGranted;
    }
    if (mounted) setState(() => _granted.addAll(map));
  }

  bool get _cameraGranted => _granted[AppPermission.camera] ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text('Permissions', style: theme.textTheme.displaySmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'LensCast needs a few permissions to send your camera and '
                'audio to your computer.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ListView.separated(
                  itemCount: AppPermission.values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (_, i) {
                    final p = AppPermission.values[i];
                    final granted = _granted[p] ?? false;
                    return AppCard(
                      onTap: _busy || granted ? null : () => _request(p),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: granted
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.primary.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                            child: Icon(
                              _iconFor(p),
                              color: granted
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.label,
                                    style: theme.textTheme.titleMedium),
                                const SizedBox(height: 2),
                                Text(p.rationale,
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          if (granted)
                            const Icon(Icons.check_circle,
                                color: AppColors.success)
                          else
                            Text('Allow',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: AppColors.primary,
                                )),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!_cameraGranted)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _requestAll,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Grant all'),
                ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _busy ? null : _continue,
                child: Text(_cameraGranted ? 'Continue' : 'Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(AppPermission p) {
    switch (p) {
      case AppPermission.camera:
        return Icons.photo_camera_rounded;
      case AppPermission.microphone:
        return Icons.mic_rounded;
      case AppPermission.notification:
        return Icons.notifications_rounded;
    }
  }
}
