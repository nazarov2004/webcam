import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/utils/log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Log.info('LensCast', 'Starting up...');

  // Load persisted preferences before the first frame so routing and theme are
  // correct immediately. Guard with a timeout so a slow/blocked platform
  // channel can never hang startup indefinitely.
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    Log.warn('LensCast', 'SharedPreferences unavailable, using defaults: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const LensCastApp(),
    ),
  );
}