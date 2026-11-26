import 'package:flutter/foundation.dart';

/// Video quality profiles offered by the app.
enum QualityProfile {
  low('Low', 854, 480, 24, 800),
  balanced('Balanced', 1280, 720, 30, 2500),
  high('High', 1920, 1080, 30, 4500),
  smooth('Smooth', 1280, 720, 60, 4000),
  ultra('Ultra', 3840, 2160, 30, 16000);

  const QualityProfile(this.label, this.width, this.height, this.fps, this.bitrate);
  final String label;
  final int width;
  final int height;
  final int fps;

  /// Default bitrate in kbps.
  final int bitrate;

  String get resolutionLabel => '${height}p';
}

/// Which physical camera to use.
enum LensType {
  front('Front'),
  rear('Rear');

  const LensType(this.label);
  final String label;
}

/// Full camera + stream configuration, serializable and validated.
@immutable
class CameraConfiguration {
  const CameraConfiguration({
    this.lensType = LensType.rear,
    this.quality = QualityProfile.balanced,
    this.zoom = 1.0,
    this.exposureOffset = 0.0,
    this.mirror = false,
    this.rotateQuarterTurns = 0,
    this.lockOrientation = false,
    this.torchEnabled = false,
    this.bitrateKbps,
    this.autoBitrate = true,
    this.aspectRatio = 16 / 9,
  });

  final LensType lensType;
  final QualityProfile quality;
  final double zoom;
  final double exposureOffset;
  final bool mirror;
  final int rotateQuarterTurns;
  final bool lockOrientation;
  final bool torchEnabled;
  final int? bitrateKbps;
  final bool autoBitrate;
  final double aspectRatio;

  int get width => quality.width;
  int get height => quality.height;
  int get fps => quality.fps;
  int get effectiveBitrate => bitrateKbps ?? quality.bitrate;

  CameraConfiguration copyWith({
    LensType? lensType,
    QualityProfile? quality,
    double? zoom,
    double? exposureOffset,
    bool? mirror,
    int? rotateQuarterTurns,
    bool? lockOrientation,
    bool? torchEnabled,
    int? bitrateKbps,
    bool? autoBitrate,
    double? aspectRatio,
    bool clearBitrate = false,
  }) {
    return CameraConfiguration(
      lensType: lensType ?? this.lensType,
      quality: quality ?? this.quality,
      zoom: zoom ?? this.zoom,
      exposureOffset: exposureOffset ?? this.exposureOffset,
      mirror: mirror ?? this.mirror,
      rotateQuarterTurns: rotateQuarterTurns ?? this.rotateQuarterTurns,
      lockOrientation: lockOrientation ?? this.lockOrientation,
      torchEnabled: torchEnabled ?? this.torchEnabled,
      bitrateKbps: clearBitrate ? null : (bitrateKbps ?? this.bitrateKbps),
      autoBitrate: autoBitrate ?? this.autoBitrate,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }

  Map<String, dynamic> toJson() => {
        'lensType': lensType.name,
        'quality': quality.name,
        'width': width,
        'height': height,
        'fps': fps,
        'zoom': zoom,
        'exposureOffset': exposureOffset,
        'mirror': mirror,
        'rotateQuarterTurns': rotateQuarterTurns,
        'lockOrientation': lockOrientation,
        'torchEnabled': torchEnabled,
        'bitrateKbps': effectiveBitrate,
        'autoBitrate': autoBitrate,
        'aspectRatio': aspectRatio,
      };

  factory CameraConfiguration.fromJson(Map<String, dynamic> json) {
    final quality = QualityProfile.values.firstWhere(
      (e) => e.name == json['quality'],
      orElse: () => QualityProfile.balanced,
    );
    return CameraConfiguration(
      lensType: LensType.values.firstWhere(
        (e) => e.name == json['lensType'],
        orElse: () => LensType.rear,
      ),
      quality: quality,
      zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
      exposureOffset: (json['exposureOffset'] as num?)?.toDouble() ?? 0.0,
      mirror: (json['mirror'] as bool?) ?? false,
      rotateQuarterTurns: (json['rotateQuarterTurns'] as int?) ?? 0,
      lockOrientation: (json['lockOrientation'] as bool?) ?? false,
      torchEnabled: (json['torchEnabled'] as bool?) ?? false,
      bitrateKbps: json['bitrateKbps'] as int?,
      autoBitrate: (json['autoBitrate'] as bool?) ?? true,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 16 / 9,
    );
  }

  bool validate() => zoom >= 1.0 && fps > 0 && width > 0 && height > 0;
}