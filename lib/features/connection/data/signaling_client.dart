import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/network/signaling_protocol.dart';
import '../../../core/utils/log.dart';

/// WebSocket signaling client running on the mobile sender.
class SignalingClient {
  SignalingClient();

  static const _tag = 'SignalingClient';

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _heartbeatTimer;

  final _messages = StreamController<SignalMessage>.broadcast();
  final _connectedController = StreamController<bool>.broadcast();

  Stream<SignalMessage> get messages => _messages.stream;
  Stream<bool> get connectedStream => _connectedController.stream;

  bool _connected = false;
  bool get isConnected => _connected;

  Future<void> connect({
    required String host,
    required int port,
    String? token,
    String? pin,
    required String deviceName,
    required String deviceModel,
  }) async {
    await disconnect();
    final uri = Uri.parse('ws://$host:$port/ws?role=mobile');
    Log.info(_tag, 'Connecting to $uri');
    final channel = WebSocketChannel.connect(uri);
    await channel.ready.timeout(AppConstants.connectTimeout);
    _channel = channel;
    _connected = true;
    _connectedController.add(true);

    _sub = channel.stream.listen(
      (data) {
        final msg = SignalMessage.tryDecode(data);
        if (msg == null) return;
        if (msg.type == SignalType.pong) return;
        _messages.add(msg);
      },
      onDone: () {
        Log.info(_tag, 'Signaling socket closed');
        _handleClose();
      },
      onError: (Object e) {
        Log.warn(_tag, 'Signaling socket error: $e');
        _handleClose();
      },
    );

    send(SignalMessage(
      type: SignalType.pair,
      payload: {
        'token': ?token,
        'pin': ?pin,
        'deviceName': deviceName,
        'deviceModel': deviceModel,
        'platform': 'android',
      },
    ));

    _heartbeatTimer = Timer.periodic(AppConstants.heartbeatInterval, (_) {
      send(const SignalMessage(type: SignalType.heartbeat));
    });
  }

  void send(SignalMessage msg) {
    final ch = _channel;
    if (ch == null || !_connected) return;
    try {
      ch.sink.add(msg.encode());
    } catch (e) {
      Log.warn(_tag, 'Send failed: $e');
    }
  }

  void _handleClose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_connected) {
      _connected = false;
      _connectedController.add(false);
    }
    _channel = null;
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (_connected) {
      _connected = false;
      _connectedController.add(false);
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _messages.close();
    await _connectedController.close();
  }
}
