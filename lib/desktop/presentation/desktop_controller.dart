import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../app/constants/app_constants.dart';
import '../../core/network/signaling_protocol.dart';
import '../../core/utils/log.dart';
import '../../shared/models/camera_configuration.dart';
import '../../shared/models/network_statistics.dart';
import '../local_server/local_receiver_server.dart';
import '../receiver/webrtc_receiver_service.dart';
import '../services/desktop_discovery_service.dart';

@immutable
class DesktopState {
  const DesktopState({
    this.serverRunning = false,
    this.port = AppConstants.defaultDesktopPort,
    this.localIps = const [],
    this.selectedIp = '127.0.0.1',
    this.sessionId = '',
    this.sessionToken = '',
    this.pairingPin = '',
    this.mobileConnected = false,
    this.connectedDeviceName,
    this.connectedDeviceModel,
    this.obsConnected = false,
    this.obsAudioEnabled = true,
    this.obsCleanOutput = true,
    this.stats = NetworkStatistics.empty,
    this.remoteZoom = 1.0,
    this.remoteQuality = QualityProfile.balanced,
    this.error,
  });

  final bool serverRunning;
  final int port;
  final List<String> localIps;
  final String selectedIp;
  final String sessionId;
  final String sessionToken;
  final String pairingPin;
  final bool mobileConnected;
  final String? connectedDeviceName;
  final String? connectedDeviceModel;
  final bool obsConnected;
  final bool obsAudioEnabled;
  final bool obsCleanOutput;
  final NetworkStatistics stats;
  final double remoteZoom;
  final QualityProfile remoteQuality;
  final String? error;

  String get obsUrl {
    final a = obsAudioEnabled ? '1' : '0';
    final c = obsCleanOutput ? '1' : '0';
    return 'http://127.0.0.1:$port/obs?token=$sessionToken&audio=$a&clean=$c';
  }

  String get qrData => QrPairingPayload(
        host: selectedIp,
        port: port,
        sessionId: sessionId,
        token: sessionToken,
        pin: pairingPin,
        deviceName: Platform.localHostname,
      ).encode();

  DesktopState copyWith({
    bool? serverRunning,
    int? port,
    List<String>? localIps,
    String? selectedIp,
    String? sessionId,
    String? sessionToken,
    String? pairingPin,
    bool? mobileConnected,
    String? connectedDeviceName,
    String? connectedDeviceModel,
    bool clearDevice = false,
    bool? obsConnected,
    bool? obsAudioEnabled,
    bool? obsCleanOutput,
    NetworkStatistics? stats,
    double? remoteZoom,
    QualityProfile? remoteQuality,
    String? error,
    bool clearError = false,
  }) {
    return DesktopState(
      serverRunning: serverRunning ?? this.serverRunning,
      port: port ?? this.port,
      localIps: localIps ?? this.localIps,
      selectedIp: selectedIp ?? this.selectedIp,
      sessionId: sessionId ?? this.sessionId,
      sessionToken: sessionToken ?? this.sessionToken,
      pairingPin: pairingPin ?? this.pairingPin,
      mobileConnected: mobileConnected ?? this.mobileConnected,
      connectedDeviceName:
          clearDevice ? null : (connectedDeviceName ?? this.connectedDeviceName),
      connectedDeviceModel:
          clearDevice ? null : (connectedDeviceModel ?? this.connectedDeviceModel),
      obsConnected: obsConnected ?? this.obsConnected,
      obsAudioEnabled: obsAudioEnabled ?? this.obsAudioEnabled,
      obsCleanOutput: obsCleanOutput ?? this.obsCleanOutput,
      stats: stats ?? this.stats,
      remoteZoom: remoteZoom ?? this.remoteZoom,
      remoteQuality: remoteQuality ?? this.remoteQuality,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DesktopController extends StateNotifier<DesktopState> {
  DesktopController() : super(const DesktopState()) {
    _server = LocalReceiverServer(
      deviceName: Platform.localHostname,
    );
    _receiver = WebRtcReceiverService(onSendSignal: _server.sendToMobile);
    _receiver.addListener(_syncReceiver);
    _signalSub = _server.mobileSignals.listen(_handleMobileSignal);
    _mobileConnSub = _server.mobileConnectionStream.listen(_handleMobileConn);
    _obsConnSub = _server.obsConnectedStream.listen((connected) {
      state = state.copyWith(obsConnected: connected);
    });
  }

  static const _tag = 'DesktopController';
  late final LocalReceiverServer _server;
  late final WebRtcReceiverService _receiver;
  final DesktopDiscoveryService _discovery = DesktopDiscoveryService();

  StreamSubscription<SignalMessage>? _signalSub;
  StreamSubscription<Map<String, dynamic>?>? _mobileConnSub;
  StreamSubscription<bool>? _obsConnSub;

  MediaStream? get remoteStream => _receiver.remoteStream;

  void _syncReceiver() {
    state = state.copyWith(stats: _receiver.stats);
  }

  Future<void> initialize() async {
    if (_server.isRunning) return;
    try {
      await _server.start();
      final ips = await _discovery.localIpv4Addresses();
      final primaryIp = ips.isNotEmpty ? ips.first : '127.0.0.1';
      await _discovery.startBroadcast(
        name: 'LensCast (${Platform.localHostname})',
        port: _server.port,
      );
      state = state.copyWith(
        serverRunning: true,
        port: _server.port,
        localIps: ips,
        selectedIp: primaryIp,
        sessionId: _server.sessionId,
        sessionToken: _server.sessionToken,
        pairingPin: _server.pairingPin,
        clearError: true,
      );
    } catch (e) {
      Log.error(_tag, 'Failed to start desktop receiver', e);
      state = state.copyWith(
        serverRunning: false,
        error: 'Could not start receiver on port ${AppConstants.defaultDesktopPort}: $e',
      );
    }
  }

  void selectIp(String ip) {
    state = state.copyWith(selectedIp: ip);
  }

  void rotateCredentials() {
    _server.rotateCredentials();
    _receiver.closePeer();
    state = state.copyWith(
      sessionId: _server.sessionId,
      sessionToken: _server.sessionToken,
      pairingPin: _server.pairingPin,
      mobileConnected: false,
      clearDevice: true,
    );
  }

  void disconnectPhone() {
    _server.sendToMobile(const SignalMessage(type: SignalType.disconnect));
    _receiver.closePeer();
    state = state.copyWith(
      mobileConnected: false,
      clearDevice: true,
      stats: NetworkStatistics.empty,
    );
  }

  void setObsAudio(bool enabled) {
    _server.obsAudioEnabled = enabled;
    state = state.copyWith(obsAudioEnabled: enabled);
  }

  void setObsClean(bool clean) {
    _server.obsCleanOutput = clean;
    state = state.copyWith(obsCleanOutput: clean);
  }

  void sendCameraControl(String action, [dynamic value]) {
    if (!state.mobileConnected) return;
    if (action == 'zoom' && value is num) {
      state = state.copyWith(remoteZoom: value.toDouble());
    } else if (action == 'quality' && value is QualityProfile) {
      state = state.copyWith(remoteQuality: value);
      _server.sendToMobile(SignalMessage(
        type: SignalType.cameraControl,
        payload: {'action': action, 'value': value.name},
      ));
      return;
    }
    _server.sendToMobile(SignalMessage(
      type: SignalType.cameraControl,
      payload: {'action': action, 'value': ?value},
    ));
  }

  void _handleMobileConn(Map<String, dynamic>? info) {
    if (info == null) {
      _receiver.closePeer();
      state = state.copyWith(
        mobileConnected: false,
        clearDevice: true,
        stats: NetworkStatistics.empty,
      );
    } else {
      state = state.copyWith(
        mobileConnected: true,
        connectedDeviceName: (info['deviceName'] as String?) ?? 'Android Phone',
        connectedDeviceModel: info['deviceModel'] as String?,
      );
    }
  }

  Future<void> _handleMobileSignal(SignalMessage msg) async {
    switch (msg.type) {
      case SignalType.offer:
        await _receiver.handleOffer(msg.payload);
        break;
      case SignalType.ice:
        await _receiver.handleIceCandidate(msg.payload);
        break;
      case SignalType.disconnect:
        await _receiver.closePeer();
        state = state.copyWith(
          mobileConnected: false,
          clearDevice: true,
          stats: NetworkStatistics.empty,
        );
        break;
    }
  }

  @override
  void dispose() {
    _signalSub?.cancel();
    _mobileConnSub?.cancel();
    _obsConnSub?.cancel();
    _receiver.removeListener(_syncReceiver);
    _receiver.dispose();
    _discovery.stopBroadcast();
    _server.stop();
    super.dispose();
  }
}

final desktopControllerProvider =
    StateNotifierProvider<DesktopController, DesktopState>((ref) {
  return DesktopController();
});
