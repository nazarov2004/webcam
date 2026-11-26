import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';

class _OnboardPage {
  const _OnboardPage(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

/// Three-page introduction. Skip and Get Started both persist completion.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _OnboardPage(
      Icons.videocam_rounded,
      'Turn your phone into a webcam',
      'LensCast turns the camera you already own into a crisp, low-latency '
          'webcam for your computer.',
    ),
    _OnboardPage(
      Icons.wifi_tethering_rounded,
      'Connect wirelessly or over USB',
      'Pair over Wi-Fi with automatic discovery, scan a QR code, or use a '
          'supported USB tethering connection.',
    ),
    _OnboardPage(
      Icons.live_tv_rounded,
      'Use it in OBS and any app',
      'Send clean video and audio straight into OBS, Zoom, Meet, Teams and '
          'more — no cloud in the middle.',
    ),
  ];

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    await ref.read(settingsServiceProvider).completeOnboarding();
    if (mounted) context.go('/permissions');
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: AppSpacing.normal,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.2),
                                AppColors.secondary.withValues(alpha: 0.12),
                              ],
                            ),
                          ),
                          child: Icon(p.icon,
                              size: 64, color: AppColors.primary),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        Text(p.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.lg),
                        Text(p.body,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _index;
                      return AnimatedContainer(
                        duration: AppSpacing.fast,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : theme.dividerColor,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_isLast ? 'Get Started' : 'Next'),
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