import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/device_info_service.dart';
import '../core/services/settings_service.dart';

/// Holds SharedPreferences once loaded in main(). If startup could not load
/// them (timeout/error), this stays unset and SettingsService falls back to
/// in-memory defaults so the app remains bootable.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

final settingsServiceProvider =
    ChangeNotifierProvider<SettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsService(prefs);
});

/// The host device info, loaded once.
final deviceInfoProvider = FutureProvider<DeviceInfo>((ref) {
  return DeviceInfoService.read();
});