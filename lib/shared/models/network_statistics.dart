import 'package:flutter/foundation.dart';

/// Real-time transport statistics gathered from the WebRTC connection.
///
/// These are populated from `RTCRtpReceiver`/`RTCRtpSender` stats and the
/// peer connection state. No value here is faked; fields remain at zero until
/// a real connection reports them.
@immutable
class NetworkStatistics {
  const NetworkStatistics({
    this.currentFps = 0,
    this.actualBitrateKbps = 0,
    this.roundTripTimeMs = 0,
    this.packetLossPercent = 0,
    this.jitterMs = 0,
    this.connectionType = '—',
    this.width = 0,
    this.height = 0,
    this.framesDecoded = 0,
  });

  final int currentFps;
  final double actualBitrateKbps;
  final double roundTripTimeMs;
  final double packetLossPercent;
  final double jitterMs;
  final String connectionType;
  final int width;
  final int height;
  final int framesDecoded;

  String get resolutionLabel =>
      width > 0 && height > 0 ? '$width×$height' : '—';

  String get bitrateLabel => actualBitrateKbps >= 1000
      ? '${(actualBitrateKbps / 1000).toStringAsFixed(1)} Mbps'
      : '${actualBitrateKbps.toStringAsFixed(0)} kbps';

  /// A coarse 0..1 quality score derived from loss, jitter and RTT.
  double get qualityScore {
    final lossPenalty = (packetLossPercent / 10).clamp(0.0, 1.0);
    final jitterPenalty = (jitterMs / 100).clamp(0.0, 1.0);
    final rttPenalty = (roundTripTimeMs / 500).clamp(0.0, 1.0);
    final score = 1.0 - ((lossPenalty + jitterPenalty + rttPenalty) / 3);
    return score.clamp(0.0, 1.0);
  }

  NetworkStatistics copyWith({
    int? currentFps,
    double? actualBitrateKbps,
    double? roundTripTimeMs,
    double? packetLossPercent,
    double? jitterMs,
    String? connectionType,
    int? width,
    int? height,
    int? framesDecoded,
  }) {
    return NetworkStatistics(
      currentFps: currentFps ?? this.currentFps,
      actualBitrateKbps: actualBitrateKbps ?? this.actualBitrateKbps,
      roundTripTimeMs: roundTripTimeMs ?? this.roundTripTimeMs,
      packetLossPercent: packetLossPercent ?? this.packetLossPercent,
      jitterMs: jitterMs ?? this.jitterMs,
      connectionType: connectionType ?? this.connectionType,
      width: width ?? this.width,
      height: height ?? this.height,
      framesDecoded: framesDecoded ?? this.framesDecoded,
    );
  }

  static const empty = NetworkStatistics();
}