import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/network/signaling_protocol.dart';
import '../../../core/services/device_info_service.dart';
import '../../../core/utils/log.dart';
import '../../../shared/models/camera_configuration.dart';
import '../../../shared/models/device_model.dart';
import '../../../shared/models/network_statistics.dart';
import '../../../shared/models/streaming_session.dart';
import '../../camera/data/camera_service.dart';
import '../../camera/presentation/camera_controller.dart';
import '../../streaming/data/webrtc_sender_service.dart';
import '../data/discovery_service.dart';
import '../data/signaling_client.dart';
import '../domain/connection_state.dart';

/// Coordinates device discovery, pairing, WebSocket signaling and WebRTC
/// streaming from the mobile device to LensCast Desktop (and OBS).
class ConnectionController extends StateNotifier<ConnectionState> {
  ConnectionController(
    this._discovery,
    this._cameraService,
    this._cameraController,
  ) : super(const ConnectionState()) {
    _signaling = SignalingClient();
    _sender = WebRtcSenderService(onSendSignal: _signaling.send);
    _signalSub = _signaling.messages.listen(_handleSignalMessage);
    _connSub = _signaling.connectedStream.listen(_handleSocketConnected);
    _sender.addListener(_syncSenderStats);
    _cameraService.addListener(_onCameraChanged);
  }

  static const _tag = 'ConnectionController';
  final DiscoveryService _discovery;
  final CameraService _cameraService;
  final CameraController _cameraController;

  late final SignalingClient _signaling;
  late final WebRtcSenderService _sender;
  StreamSubscription<DeviceModel>? _discoverySub;
  StreamSubscription<SignalMessage>? _signalSub;
  StreamSubscription<bool>? _connSub;

  String? _lastHost;
  int _lastPort = AppConstants.defaultDesktopPort;
  String? _lastToken;
  String? _lastPin;
  bool _manualDisconnect = false;
  Timer? _reconnectTimer;

  bool get isDiscovering => state.isDiscovering;

  void _syncSenderStats() {
    state = state.copyWith(stats: _sender.stats);
  }

  void _onCameraChanged() {
    final stream = _cameraService.stream;
    if (stream != null && _sender.isStreaming) {
      _sender.replaceStreamTracks(stream);
      _sender.setTargetBitrateKbps(_cameraService.config.effectiveBitrate);
    }
  }

  Future<void> startDiscovery() async {
    if (state.isDiscovering) return;
    state = state.copyWith(
      isDiscovering: true,
      status: ConnectionStatus.searching,
      clearError: true,
      devices: const [],
    );
    await _discoverySub?.cancel();
    _discoverySub = _discovery.start().listen(
      (device) {
        final exists = state.devices.any((d) => d.id == device.id);
        if (exists) return;
        state = state.copyWith(
          devices: [...state.devices, device],
          status: ConnectionStatus.deviceFound,
        );
      },
      onError: (Object e) {
        Log.error(_tag, 'Discovery error', e);
        state = state.copyWith(
          isDiscovering: false,
          error: AppError.from(e).userMessage,
        );
      },
    );
    Timer(const Duration(seconds: 15), stopDiscovery);
  }

  Future<void> stopDiscovery() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    if (state.isDiscovering) {
      state = state.copyWith(isDiscovering: false);
    }
  }

  /// Validates an IP address and tests TCP reachability to [port].
  Future<bool> testManualConnection(String ip, int port) async {
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      clearError: true,
    );
    final parsed = InternetAddress.tryParse(ip.trim());
    if (parsed == null) {
      state = state.copyWith(
        status: ConnectionStatus.idle,
        error: 'Enter a valid IPv4 address, e.g. 192.168.1.20',
      );
      return false;
    }
    Socket? socket;
    try {
      socket = await Socket.connect(
        parsed,
        port,
        timeout: AppConstants.connectTimeout,
      );
      final device = DeviceModel(
        id: '$ip:$port',
        name: 'LensCast Desktop ($ip)',
        ipAddress: ip.trim(),
        platform: 'windows',
        connectionType: ConnectionType.manualIp,
      );
      state = state.copyWith(
        status: ConnectionStatus.deviceFound,
        devices: [device],
      );
      Log.info(_tag, 'Manual connection reachable at $ip:$port');
      return true;
    } catch (e) {
      Log.warn(_tag, 'Manual connection failed: $e');
      state = state.copyWith(
        status: ConnectionStatus.idle,
        error:
            'Could not reach $ip:$port. Check the IP, port and that LensCast '
            'Desktop is running and the firewall allows it.',
      );
      return false;
    } finally {
      socket?.destroy();
    }
  }

  /// Connects using a scanned QR code payload.
  Future<void> connectWithQr(QrPairingPayload qr) async {
    final device = DeviceModel(
      id: '${qr.host}:${qr.port}',
      name: qr.deviceName,
      ipAddress: qr.host,
      platform: 'windows',
      connectionType: ConnectionType.qr,
    );
    await connectToDevice(device, port: qr.port, token: qr.token, pin: qr.pin);
  }

  /// Pairs and starts WebRTC streaming to [device] using [token] or [pin].
  Future<void> connectToDevice(
    DeviceModel device, {
    int? port,
    String? token,
    String? pin,
  }) async {
    final host = device.ipAddress;
    if (host == null || host.isEmpty) {
      state = state.copyWith(
        status: ConnectionStatus.idle,
        error: 'Selected device has no IP address.',
      );
      return;
    }

    final resolvedPort = port ?? _parsePortFromId(device.id);
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    _lastHost = host;
    _lastPort = resolvedPort;
    _lastToken = token;
    _lastPin = pin;

    state = state.copyWith(
      status: ConnectionStatus.pairing,
      clearError: true,
      session: StreamingSession(
        sessionId: 'pending',
        device: device,
        status: ConnectionStatus.pairing,
      ),
    );

    try {
      await _cameraController.initialize();
      final info = await DeviceInfoService.read();
      await _signaling.connect(
        host: host,
        port: resolvedPort,
        token: token,
        pin: pin,
        deviceName: info.displayName,
        deviceModel: info.model,
      );
    } catch (e) {
      Log.error(_tag, 'Connection failed', e);
      state = state.copyWith(
        status: ConnectionStatus.connectionLost,
        error: AppError.from(e).userMessage,
      );
    }
  }

  int _parsePortFromId(String id) {
    final parts = id.split(':');
    if (parts.length == 2) {
      final parsed = int.tryParse(parts[1]);
      if (parsed != null && parsed > 0) return parsed;
    }
    return AppConstants.defaultDesktopPort;
  }

  Future<void> _handleSignalMessage(SignalMessage msg) async {
    switch (msg.type) {
      case SignalType.paired:
        final sessionId = (msg.payload['sessionId'] as String?) ?? 'active';
        final token = msg.payload['token'] as String?;
        if (token != null) _lastToken = token;
        final currentSession = state.session;
        if (currentSession != null) {
          state = state.copyWith(
            status: ConnectionStatus.connecting,
            session: currentSession.copyWith(
              sessionId: sessionId,
              status: ConnectionStatus.connecting,
              startedAt: DateTime.now(),
            ),
          );
        }
        final stream = _cameraService.stream;
        if (stream != null) {
          _sender.setTargetBitrateKbps(_cameraService.config.effectiveBitrate);
          await _sender.startPeer(target: PeerTarget.desktop, stream: stream);
          state = state.copyWith(
            status: ConnectionStatus.connected,
            session: state.session?.copyWith(status: ConnectionStatus.connected),
          );
        }
        break;

      case SignalType.authFailed:
        _manualDisconnect = true;
        await _sender.closeAll();
        await _signaling.disconnect();
        state = state.copyWith(
          status: ConnectionStatus.authenticationFailed,
          clearSession: true,
          error: (msg.payload['reason'] as String?) ??
              'Invalid pairing PIN or expired QR token.',
        );
        break;

      case SignalType.answer:
        await _sender.handleAnswer(
          target: msg.target ?? PeerTarget.desktop,
          payload: msg.payload,
        );
        break;

      case SignalType.ice:
        await _sender.handleIceCandidate(
          target: msg.target ?? PeerTarget.desktop,
          payload: msg.payload,
        );
        break;

      case SignalType.obsReady:
        state = state.copyWith(obsActive: true);
        final stream = _cameraService.stream;
        if (stream != null) {
          await _sender.startPeer(target: PeerTarget.obs, stream: stream);
        }
        break;

      case SignalType.obsClosed:
        state = state.copyWith(obsActive: false);
        await _sender.closePeer(PeerTarget.obs);
        break;

      case SignalType.cameraControl:
        await _applyRemoteControl(msg.payload);
        break;
    }
  }

  Future<void> _applyRemoteControl(Map<String, dynamic> payload) async {
    final action = payload['action'] as String?;
    switch (action) {
      case 'switch_lens':
        await _cameraController.switchLens();
        break;
      case 'mirror':
        await _cameraController.toggleMirror();
        break;
      case 'rotate':
        await _cameraController.rotate();
        break;
      case 'torch':
        await _cameraController.toggleTorch();
        break;
      case 'mic':
        await _cameraController.toggleMic();
        break;
      case 'zoom':
        final v = payload['value'];
        if (v is num) await _cameraController.setZoom(v.toDouble());
        break;
      case 'exposure':
        final v = payload['value'];
        if (v is num) await _cameraController.setExposure(v.toDouble());
        break;
      case 'quality':
        final name = payload['value'] as String?;
        if (name != null) {
          final profile = QualityProfile.values.firstWhere(
            (q) => q.name == name,
            orElse: () => QualityProfile.balanced,
          );
          await _cameraController.setQuality(profile);
        }
        break;
    }
  }

  void _handleSocketConnected(bool connected) {
    if (!connected && !_manualDisconnect && _lastHost != null) {
      state = state.copyWith(
        status: ConnectionStatus.reconnecting,
        obsActive: false,
      );
      _sender.closeAll();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_manualDisconnect || _lastHost == null) return;
      final device = state.session?.device ??
          DeviceModel(
            id: '$_lastHost:$_lastPort',
            name: 'LensCast Desktop',
            ipAddress: _lastHost,
            platform: 'windows',
          );
      await connectToDevice(
        device,
        port: _lastPort,
        token: _lastToken,
        pin: _lastPin,
      );
    });
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _signaling.send(const SignalMessage(type: SignalType.disconnect));
    await _sender.closeAll();
    await _signaling.disconnect();
    state = state.copyWith(
      status: ConnectionStatus.idle,
      clearSession: true,
      obsActive: false,
      stats: NetworkStatistics.empty,
    );
  }

  void reset() {
    disconnect();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _discoverySub?.cancel();
    _signalSub?.cancel();
    _connSub?.cancel();
    _sender.removeListener(_syncSenderStats);
    _cameraService.removeListener(_onCameraChanged);
    _sender.dispose();
    _signaling.dispose();
    _discovery.stop();
    super.dispose();
  }
}

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final service = DiscoveryService();
  ref.onDispose(service.stop);
  return service;
});

final connectionControllerProvider =
    StateNotifierProvider<ConnectionController, ConnectionState>((ref) {
  final controller = ConnectionController(
    ref.watch(discoveryServiceProvider),
    ref.watch(cameraServiceProvider),
    ref.watch(cameraControllerProvider.notifier),
  );
  ref.onDispose(controller.stopDiscovery);
  return controller;
});
