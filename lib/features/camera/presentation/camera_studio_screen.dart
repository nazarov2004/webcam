import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/camera_preview.dart';
import '../../../shared/widgets/components.dart';
import 'camera_controller.dart';
import 'widgets/studio_controls.dart';

/// Full camera studio: large preview + control dock.
///
/// When [embedded] is true it omits its own AppBar (used inside the HomeShell)
/// and only starts the camera while [isActive] is true (its tab is selected),
/// so capture never begins during app startup.
class CameraStudioScreen extends ConsumerStatefulWidget {
  const CameraStudioScreen({
    super.key,
    this.embedded = false,
    this.isActive = true,
  });
  final bool embedded;
  final bool isActive;

  @override
  ConsumerState<CameraStudioScreen> createState() => _CameraStudioScreenState();
}

class _CameraStudioScreenState extends ConsumerState<CameraStudioScreen> {
  @override
  void initState() {
    super.initState();
    // Standalone route starts immediately; embedded waits until active.
    if (!widget.embedded && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
    }
  }

  @override
  void didUpdateWidget(covariant CameraStudioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
    }
    if (!widget.isActive && oldWidget.isActive) {
      // Leaving the tab releases the camera so other consumers can use it.
      ref.read(cameraControllerProvider.notifier).releaseCamera();
    }
  }

  Future<void> _startCamera() async {
    if (!mounted) return;
    await ref.read(cameraControllerProvider.notifier).initialize();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cam = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final stream = controller.mediaStream;

    final body = RefreshIndicator(
      onRefresh: () => controller.initialize(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          AspectRatio(
            aspectRatio: cam.config.aspectRatio,
            child: CameraPreview(
              stream: stream,
              mirror: cam.config.mirror,
              rotateQuarterTurns: cam.config.rotateQuarterTurns,
              overlay: Stack(
                children: [
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: StatusPill(
                      label: cam.initialized ? 'Live' : 'Offline',
                      color: cam.initialized
                          ? AppColors.success
                          : AppColors.textMuted,
                      dense: true,
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.md,
                    right: AppSpacing.md,
                    child: StatusPill(
                      label:
                          '${cam.config.height}p · ${cam.config.fps} FPS',
                      color: AppColors.secondary,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (cam.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ErrorState(
                title: cam.error!.userMessage,
                message: cam.error!.message,
                suggestion: cam.error!.suggestion,
                onRetry: cam.error!.retryable
                    ? () => controller.initialize()
                    : null,
              ),
            ),
          const StudioControls(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Only controls supported by your hardware are shown. Unavailable '
            'controls are hidden automatically.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return Scaffold(body: body);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Studio')),
      body: body,
    );
  }
}