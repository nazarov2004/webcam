import 'package:flutter_test/flutter_test.dart';
import 'package:lenscast/shared/models/camera_configuration.dart';
import 'package:lenscast/shared/models/device_model.dart';
import 'package:lenscast/shared/models/network_statistics.dart';

void main() {
  group('CameraConfiguration', () {
    test('serializes and deserializes round-trip', () {
      const config = CameraConfiguration(
        quality: QualityProfile.high,
        zoom: 1.5,
        mirror: true,
      );
      final json = config.toJson();
      final restored = CameraConfiguration.fromJson(json);
      expect(restored.quality, QualityProfile.high);
      expect(restored.zoom, 1.5);
      expect(restored.mirror, true);
      expect(restored.width, 1920);
      expect(restored.fps, 30);
      expect(restored.validate(), true);
    });

    test('effective bitrate falls back to profile', () {
      const config = CameraConfiguration(quality: QualityProfile.balanced);
      expect(config.effectiveBitrate, QualityProfile.balanced.bitrate);
    });
  });

  group('DeviceModel', () {
    test('validates and round-trips', () {
      const device = DeviceModel(
        id: '192.168.1.5:8765',
        name: 'Desktop',
        ipAddress: '192.168.1.5',
        connectionType: ConnectionType.wifi,
      );
      expect(device.validate(), true);
      final restored =
          DeviceModel.fromJson(device.toJson());
      expect(restored.id, device.id);
      expect(restored.connectionType, ConnectionType.wifi);
    });

    test('invalid device fails validation', () {
      const device = DeviceModel(id: '', name: '');
      expect(device.validate(), false);
    });
  });

  group('NetworkStatistics', () {
    test('quality score is bounded 0..1', () {
      const stats = NetworkStatistics(
        packetLossPercent: 5,
        jitterMs: 40,
        roundTripTimeMs: 200,
      );
      expect(stats.qualityScore, inInclusiveRange(0.0, 1.0));
    });

    test('empty stats have zeroed values', () {
      expect(NetworkStatistics.empty.currentFps, 0);
      expect(NetworkStatistics.empty.resolutionLabel, '—');
    });
  });
}