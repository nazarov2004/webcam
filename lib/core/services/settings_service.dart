import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide persisted preferences behind a simple typed API.
abstract final class SettingsKeys {
  static const themeMode = 'theme_mode';
  static const keepScreenAwake = 'keep_screen_awake';
  static const autoReconnect = 'auto_reconnect';
  static const autoStartCamera = 'auto_start_camera';
  static const saveLastCamera = 'save_last_camera';
  static const startupQuality = 'startup_quality';
  static const onboardingComplete = 'onboarding_complete';
  static const lastDesktopIp = 'last_desktop_ip';
  static const lastDesktopPort = 'last_desktop_port';
  static const pairedDevices = 'paired_devices';
  static const audioEnabled = 'audio_enabled';
  static const noiseSuppression = 'noise_suppression';
  static const echoCancellation = 'echo_cancellation';
  static const autoGainControl = 'auto_gain_control';
}

/// Holds the current user preferences and persists changes via
/// [SharedPreferences].
///
/// If [prefs] is null (platform channel unavailable at startup), an in-memory
/// map is used so the app stays fully bootable without persistence and never
/// blocks or crashes on a missing/broken platform channel.
class SettingsService extends ChangeNotifier {
  SettingsService(SharedPreferences? prefs)
      : _prefs = prefs,
        _mem = <String, Object>{};

  final SharedPreferences? _prefs;
  final Map<String, Object> _mem;

  // --- typed read/write helpers with in-memory fallback -------------------

  bool? _getBool(String key) =>
      _prefs?.getBool(key) ?? (_mem[key] as bool?);

  String? _getString(String key) =>
      _prefs?.getString(key) ?? (_mem[key] as String?);

  int? _getInt(String key) => _prefs?.getInt(key) ?? (_mem[key] as int?);

  Future<void> _setBool(String key, bool v) async {
    _mem[key] = v;
    await _prefs?.setBool(key, v);
  }

  Future<void> _setString(String key, String v) async {
    _mem[key] = v;
    await _prefs?.setString(key, v);
  }

  Future<void> _setInt(String key, int v) async {
    _mem[key] = v;
    await _prefs?.setInt(key, v);
  }

  // --- cached settings ----------------------------------------------------

  late ThemeMode _themeMode =
      _readEnum(SettingsKeys.themeMode, ThemeMode.dark);
  late bool _keepScreenAwake =
      _getBool(SettingsKeys.keepScreenAwake) ?? true;
  late bool _autoReconnect = _getBool(SettingsKeys.autoReconnect) ?? true;
  late bool _autoStartCamera = _getBool(SettingsKeys.autoStartCamera) ?? true;
  late bool _saveLastCamera = _getBool(SettingsKeys.saveLastCamera) ?? true;
  late String _startupQuality =
      _getString(SettingsKeys.startupQuality) ?? 'balanced';
  late bool _audioEnabled = _getBool(SettingsKeys.audioEnabled) ?? true;
  late bool _noiseSuppression =
      _getBool(SettingsKeys.noiseSuppression) ?? true;
  late bool _echoCancellation =
      _getBool(SettingsKeys.echoCancellation) ?? true;
  late bool _autoGainControl = _getBool(SettingsKeys.autoGainControl) ?? true;

  ThemeMode get themeMode => _themeMode;
  bool get keepScreenAwake => _keepScreenAwake;
  bool get autoReconnect => _autoReconnect;
  bool get autoStartCamera => _autoStartCamera;
  bool get saveLastCamera => _saveLastCamera;
  String get startupQuality => _startupQuality;
  bool get audioEnabled => _audioEnabled;
  bool get noiseSuppression => _noiseSuppression;
  bool get echoCancellation => _echoCancellation;
  bool get autoGainControl => _autoGainControl;

  String? get lastDesktopIp => _getString(SettingsKeys.lastDesktopIp);
  int get lastDesktopPort => _getInt(SettingsKeys.lastDesktopPort) ?? 8765;

  bool get onboardingComplete =>
      _getBool(SettingsKeys.onboardingComplete) ?? false;

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    await _setString(SettingsKeys.themeMode, value.name);
    notifyListeners();
  }

  Future<void> setKeepScreenAwake(bool value) async {
    _keepScreenAwake = value;
    await _setBool(SettingsKeys.keepScreenAwake, value);
    notifyListeners();
  }

  Future<void> setAutoReconnect(bool value) async {
    _autoReconnect = value;
    await _setBool(SettingsKeys.autoReconnect, value);
    notifyListeners();
  }

  Future<void> setAutoStartCamera(bool value) async {
    _autoStartCamera = value;
    await _setBool(SettingsKeys.autoStartCamera, value);
    notifyListeners();
  }

  Future<void> setSaveLastCamera(bool value) async {
    _saveLastCamera = value;
    await _setBool(SettingsKeys.saveLastCamera, value);
    notifyListeners();
  }

  Future<void> setStartupQuality(String value) async {
    _startupQuality = value;
    await _setString(SettingsKeys.startupQuality, value);
    notifyListeners();
  }

  Future<void> setAudioEnabled(bool value) async {
    _audioEnabled = value;
    await _setBool(SettingsKeys.audioEnabled, value);
    notifyListeners();
  }

  Future<void> setNoiseSuppression(bool value) async {
    _noiseSuppression = value;
    await _setBool(SettingsKeys.noiseSuppression, value);
    notifyListeners();
  }

  Future<void> setEchoCancellation(bool value) async {
    _echoCancellation = value;
    await _setBool(SettingsKeys.echoCancellation, value);
    notifyListeners();
  }

  Future<void> setAutoGainControl(bool value) async {
    _autoGainControl = value;
    await _setBool(SettingsKeys.autoGainControl, value);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await _setBool(SettingsKeys.onboardingComplete, true);
  }

  Future<void> rememberDesktop(String ip, int port) async {
    await _setString(SettingsKeys.lastDesktopIp, ip);
    await _setInt(SettingsKeys.lastDesktopPort, port);
  }

  ThemeMode _readEnum(String key, ThemeMode fallback) {
    final raw = _getString(key);
    return ThemeMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => fallback,
    );
  }
}