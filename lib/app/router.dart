import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../desktop/presentation/desktop_shell.dart';
import '../features/connection/presentation/qr_scanner_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/permissions/presentation/permissions_screen.dart';
import '../features/settings/presentation/general_settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../shared/shell/home_shell.dart';

/// Central route table and platform-aware initial route.
abstract final class AppRouter {
  static final _root = GlobalKey<NavigatorState>();

  static String get _initialLocation =>
      !kIsWeb && Platform.isWindows ? '/desktop' : '/splash';

  static final router = GoRouter(
    navigatorKey: _root,
    initialLocation: _initialLocation,
    routes: [
      GoRoute(
        path: '/desktop',
        builder: (_, _) => const DesktopShell(),
      ),
      GoRoute(
        path: '/splash',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/permissions',
        builder: (_, _) => const PermissionsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const GeneralSettingsScreen(),
      ),
      GoRoute(
        path: '/studio',
        builder: (_, _) => const HomeShell(initialIndex: 1),
      ),
      GoRoute(
        path: '/connection',
        builder: (_, _) => const HomeShell(initialIndex: 2),
      ),
      GoRoute(
        path: '/scan-qr',
        builder: (_, _) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const HomeShell(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
}
