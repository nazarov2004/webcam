import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_constants.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/lenscast_logo.dart';

/// First screen. Performs real startup work (settings already loaded in main),
/// then routes to onboarding or home based on persisted state.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppSpacing.slow,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Give the branding a beat to breathe, then route.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    final settings = ref.read(settingsServiceProvider);
    if (settings.onboardingComplete) {
      context.go('/');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LensCastLogo(size: 96),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your phone. A pro webcam.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xxxl),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}