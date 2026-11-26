import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Root application widget.
class LensCastApp extends ConsumerWidget {
  const LensCastApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsServiceProvider).themeMode;
    return MaterialApp.router(
      title: 'LensCast',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: AppRouter.router,
    );
  }
}