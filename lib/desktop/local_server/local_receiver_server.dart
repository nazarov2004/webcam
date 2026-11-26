import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../app/constants/app_constants.dart';
import '../../core/network/signaling_protocol.dart';
import '../../core/utils/log.dart';
import 'obs_html.dart';

/// Local HTTP + WebSocket signaling server for LensCast Desktop.
///
/// Hosts:
/// - `GET /health` for reachability checks
/// - `GET /obs?token=...` for OBS Studio Browser Source (loopback-only)
/// - `WS /ws` for mobile signaling and OBS WebRTC relay
class LocalReceiverServer {
  LocalReceiverServer({
    this.requestedPort = AppConstants.defaultDesktopPort,
    this.deviceName = 'LensCast Desktop',
  });

  static const _tag = 'LocalReceiverServer';
  final int requestedPort;
  final String deviceName;

  HttpServer? _server;
  WebSocket? _mobileSocket;
  WebSocket? _obsSocket;
  bool _mobileAuthenticated = false;

  late String _sessionId;
  late String _sessionToken;
  late String _pairingPin;

  bool obsAudioEnabled = true;
  bool obsCleanOutput = true;

  final _mobileSignalController = StreamController<SignalMessage>.broadcast();
  final _obsStatusController = StreamController<bool>.broadcast();
  final _mobileConnectionController =
      StreamController<Map<String, dynamic>?>.broadcast();

  Stream<SignalMessage> get mobileSignals => _mobileSignalController.stream;
  Stream<bool> get obsConnectedStream => _obsStatusController.stream;
  Stream<Map<String, dynamic>?> get mobileConnectionStream =>
      _mobileConnectionController.stream;

  bool get isRunning => _server != null;
  int get port => _server?.port ?? requestedPort;
  String get sessionId => _sessionId;
  String get sessionToken => _sessionToken;
  String get pairingPin => _pairingPin;
  bool get hasMobileClient => _mobileSocket != null && _mobileAuthenticated;
  bool get hasObsClient => _obsSocket != null;

  String obsUrl({bool? audio, bool? clean}) {
    final a = (audio ?? obsAudioEnabled) ? '1' : '0';
    final c = (clean ?? obsCleanOutput) ? '1' : '0';
    return 'http://127.0.0.1:$port/obs?token=$_sessionToken&audio=$a&clean=$c';
  }

  Future<void> start() async {
    if (_server != null) return;
    _generateCredentials();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, requestedPort);
    Log.info(_tag, 'Listening on port $port');
    _server!.listen(
      _handleRequest,
      onError: (Object e) => Log.error(_tag, 'HTTP server error', e),
    );
  }

  void rotateCredentials() {
    _generateCredentials();
    _disconnectMobile();
    _disconnectObs();
  }

  void _generateCredentials() {
    final rng = Random.secure();
    final bytes = List<int>.generate(
      AppConstants.sessionTokenBytes,
      (_) => rng.nextInt(256),
    );
    _sessionToken = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _pairingPin = (100000 + rng.nextInt(900000)).toString();
    _sessionId = const Uuid().v4();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    if (WebSocketTransformer.isUpgradeRequest(request) && path == '/ws') {
      await _handleWebSocketUpgrade(request);
      return;
    }

    if (request.method == 'GET' && path == '/health') {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'app': 'lenscast',
          'status': 'ready',
          'port': port,
          'name': deviceName,
        }));
      await request.response.close();
      return;
    }

    if (request.method == 'GET' && path == '/obs') {
      final remote = request.connectionInfo?.remoteAddress;
      if (remote == null || !remote.isLoopback) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write('OBS endpoint is restricted to localhost.');
        await request.response.close();
        return;
      }

      final token = request.uri.queryParameters['token'];
      if (token == null || token != _sessionToken) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write('Invalid or expired session token.');
        await request.response.close();
        return;
      }

      final audioParam = request.uri.queryParameters['audio'];
      final cleanParam = request.uri.queryParameters['clean'];
      final audio = audioParam != null ? audioParam != '0' : obsAudioEnabled;
      final clean = cleanParam != null ? cleanParam != '0' : obsCleanOutput;

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..headers.set('Cache-Control', 'no-store')
        ..write(buildObsReceiverHtml(
          token: _sessionToken,
          audioEnabled: audio,
          cleanOutput: clean,
        ));
      await request.response.close();
      return;
    }

    request.response
      ..statusCode = HttpStatus.notFound
      ..write('Not found');
    await request.response.close();
  }

  Future<void> _handleWebSocketUpgrade(HttpRequest request) async {
    final role = request.uri.queryParameters['role'] ?? 'mobile';
    if (role == 'obs') {
      final remote = request.connectionInfo?.remoteAddress;
      final token = request.uri.queryParameters['token'];
      if (remote == null || !remote.isLoopback || token != _sessionToken) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write('Unauthorized OBS WebSocket');
        await request.response.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(request);
      _attachObsSocket(ws);
      return;
    }

    final ws = await WebSocketTransformer.upgrade(request);
    _attachMobileSocket(ws);
  }

  void _attachObsSocket(WebSocket ws) {
    _obsSocket?.close();
    _obsSocket = ws;
    _obsStatusController.add(true);
    Log.info(_tag, 'OBS Browser Source connected');

    if (hasMobileClient) {
      sendToMobile(const SignalMessage(
        type: SignalType.obsReady,
        target: PeerTarget.obs,
      ));
    }

    ws.listen(
      (data) {
        final msg = SignalMessage.tryDecode(data);
        if (msg == null) return;
        if (msg.type == SignalType.answer || msg.type == SignalType.ice) {
          sendToMobile(SignalMessage(
            type: msg.type,
            target: PeerTarget.obs,
            payload: msg.payload,
          ));
        }
      },
      onDone: () {
        if (_obsSocket == ws) {
          _obsSocket = null;
          _obsStatusController.add(false);
          Log.info(_tag, 'OBS Browser Source disconnected');
          if (hasMobileClient) {
            sendToMobile(const SignalMessage(
              type: SignalType.obsClosed,
              target: PeerTarget.obs,
            ));
          }
        }
      },
      onError: (_) {
        if (_obsSocket == ws) {
          _obsSocket = null;
          _obsStatusController.add(false);
        }
      },
    );
  }

  void _attachMobileSocket(WebSocket ws) {
    _mobileSocket?.close();
    _mobileSocket = ws;
    _mobileAuthenticated = false;
    Log.info(_tag, 'Mobile WebSocket connected, awaiting pairing');

    ws.listen(
      (data) {
        final msg = SignalMessage.tryDecode(data);
        if (msg == null) return;

        if (!_mobileAuthenticated) {
          if (msg.type == SignalType.pair) {
            final token = msg.payload['token'] as String?;
            final pin = msg.payload['pin'] as String?;
            final valid = (token != null && token == _sessionToken) ||
                (pin != null && pin == _pairingPin);
            if (!valid) {
              ws.add(const SignalMessage(
                type: SignalType.authFailed,
                payload: {'reason': 'Invalid pairing token or PIN.'},
              ).encode());
              ws.close(WebSocketStatus.policyViolation, 'Auth failed');
              return;
            }
            _mobileAuthenticated = true;
            ws.add(SignalMessage(
              type: SignalType.paired,
              payload: {
                'sessionId': _sessionId,
                'token': _sessionToken,
                'deviceName': deviceName,
              },
            ).encode());
            _mobileConnectionController.add(msg.payload);
            Log.info(_tag, 'Mobile paired: ${msg.payload['deviceName'] ?? 'Phone'}');
            if (_obsSocket != null) {
              ws.add(const SignalMessage(
                type: SignalType.obsReady,
                target: PeerTarget.obs,
              ).encode());
            }
          }
          return;
        }

        if (msg.type == SignalType.heartbeat) {
          ws.add(const SignalMessage(type: SignalType.pong).encode());
          return;
        }

        if (msg.target == PeerTarget.obs) {
          _obsSocket?.add(msg.encode());
          return;
        }

        if (msg.type == SignalType.disconnect) {
          _obsSocket?.add(const SignalMessage(type: SignalType.disconnect).encode());
        }

        _mobileSignalController.add(msg);
      },
      onDone: () {
        if (_mobileSocket == ws) {
          _mobileSocket = null;
          _mobileAuthenticated = false;
          _obsSocket?.add(const SignalMessage(type: SignalType.disconnect).encode());
          _mobileConnectionController.add(null);
          Log.info(_tag, 'Mobile disconnected');
        }
      },
      onError: (Object e) {
        Log.warn(_tag, 'Mobile WebSocket error: $e');
        if (_mobileSocket == ws) {
          _mobileSocket = null;
          _mobileAuthenticated = false;
          _mobileConnectionController.add(null);
        }
      },
    );
  }

  void sendToMobile(SignalMessage msg) {
    final ws = _mobileSocket;
    if (ws == null || !_mobileAuthenticated) return;
    try {
      ws.add(msg.encode());
    } catch (e) {
      Log.warn(_tag, 'Failed to send to mobile: $e');
    }
  }

  void _disconnectMobile() {
    _mobileSocket?.close();
    _mobileSocket = null;
    _mobileAuthenticated = false;
    _mobileConnectionController.add(null);
  }

  void _disconnectObs() {
    _obsSocket?.close();
    _obsSocket = null;
    _obsStatusController.add(false);
  }

  Future<void> stop() async {
    _disconnectMobile();
    _disconnectObs();
    await _server?.close(force: true);
    _server = null;
    await _mobileSignalController.close();
    await _obsStatusController.close();
    await _mobileConnectionController.close();
    Log.info(_tag, 'Server stopped');
  }
}
