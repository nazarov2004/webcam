import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Describes the host device for display and capability gating.
@immutable
class DeviceInfo {
  const DeviceInfo({
    required this.model,
    required this.os,
    required this.osVersion,
    required this.platform,
    this.isPhysicalDevice = true,
  });

  final String model;
  final String os;
  final String osVersion;
  final String platform;
  final bool isPhysicalDevice;

  String get displayName => '$model · $os $osVersion';
}

/// Reads device / OS information in a platform safe way.
abstract final class DeviceInfoService {
  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  static Future<DeviceInfo> read() async {
    if (kIsWeb) {
      return const DeviceInfo(
        model: 'Web',
        os: 'Web',
        osVersion: '',
        platform: 'web',
        isPhysicalDevice: false,
      );
    }
    if (Platform.isAndroid) {
      final info = await _plugin.androidInfo;
      return DeviceInfo(
        model: info.model,
        os: 'Android',
        osVersion: info.version.release,
        platform: 'android',
        isPhysicalDevice: info.isPhysicalDevice,
      );
    }
    if (Platform.isWindows) {
      final info = await _plugin.windowsInfo;
      return DeviceInfo(
        model: info.computerName,
        os: 'Windows',
        osVersion: '${info.releaseId} (${info.buildNumber})',
        platform: 'windows',
      );
    }
    return DeviceInfo(
      model: 'Unknown',
      os: defaultTargetPlatform.name,
      osVersion: '',
      platform: defaultTargetPlatform.name,
    );
  }
}