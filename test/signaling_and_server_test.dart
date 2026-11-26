import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lenscast/core/network/signaling_protocol.dart';
import 'package:lenscast/desktop/local_server/local_receiver_server.dart';

void main() {
  group('Signaling protocol', () {
    test('SignalMessage round-trips JSON', () {
      const msg = SignalMessage(
        type: SignalType.offer,
        target: PeerTarget.obs,
        payload: {'type': 'offer', 'sdp': 'v=0...'},
      );
      final decoded = SignalMessage.tryDecode(msg.encode());
      expect(decoded, isNotNull);
      expect(decoded!.type, SignalType.offer);
      expect(decoded.target, PeerTarget.obs);
      expect(decoded.payload['sdp'], 'v=0...');
    });

    test('SignalMessage rejects invalid JSON', () {
      expect(SignalMessage.tryDecode('not-json'), isNull);
      expect(SignalMessage.tryDecode('{"payload":{}}'), isNull);
    });

    test('QrPairingPayload round-trips JSON', () {
      const qr = QrPairingPayload(
        host: '192.168.1.42',
        port: 8765,
        sessionId: 'sess-1',
        token: 'tok-abc',
        pin: '123456',
        deviceName: 'Studio PC',
      );
      final decoded = QrPairingPayload.tryDecode(qr.encode());
      expect(decoded, isNotNull);
      expect(decoded!.host, '192.168.1.42');
      expect(decoded.port, 8765);
      expect(decoded.token, 'tok-abc');
      expect(decoded.pin, '123456');
      expect(decoded.deviceName, 'Studio PC');
    });

    test('QrPairingPayload rejects non-lenscast QR', () {
      expect(QrPairingPayload.tryDecode('https://example.com'), isNull);
      expect(QrPairingPayload.tryDecode('{"app":"other"}'), isNull);
    });
  });

  group('LocalReceiverServer', () {
    late LocalReceiverServer server;

    setUp(() async {
      server = LocalReceiverServer(requestedPort: 0, deviceName: 'TestPC');
      await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('GET /health returns ready JSON', () async {
      final client = HttpClient();
      final req = await client.get('127.0.0.1', server.port, '/health');
      final res = await req.close();
      expect(res.statusCode, HttpStatus.ok);
      final body = jsonDecode(await res.transform(utf8.decoder).join())
          as Map<String, dynamic>;
      expect(body['app'], 'lenscast');
      expect(body['status'], 'ready');
      expect(body['port'], server.port);
      client.close();
    });

    test('GET /obs rejects missing or invalid token', () async {
      final client = HttpClient();
      final req1 = await client.get('127.0.0.1', server.port, '/obs');
      final res1 = await req1.close();
      expect(res1.statusCode, HttpStatus.forbidden);

      final req2 =
          await client.get('127.0.0.1', server.port, '/obs?token=wrong');
      final res2 = await req2.close();
      expect(res2.statusCode, HttpStatus.forbidden);
      client.close();
    });

    test('GET /obs with valid token returns HTML5 WebRTC receiver', () async {
      final client = HttpClient();
      final req = await client.get(
        '127.0.0.1',
        server.port,
        '/obs?token=${server.sessionToken}',
      );
      final res = await req.close();
      expect(res.statusCode, HttpStatus.ok);
      final html = await res.transform(utf8.decoder).join();
      expect(html, contains('RTCPeerConnection'));
      expect(html, contains('LensCast OBS Source'));
      client.close();
    });

    test('WebSocket rejects wrong PIN and accepts valid PIN + relays OBS',
        () async {
      // 1. Wrong PIN
      final badWs = await WebSocket.connect(
        'ws://127.0.0.1:${server.port}/ws?role=mobile',
      );
      badWs.add(const SignalMessage(
        type: SignalType.pair,
        payload: {'pin': '000000'},
      ).encode());
      final badReply = SignalMessage.tryDecode(await badWs.first);
      expect(badReply?.type, SignalType.authFailed);

      // 2. Valid PIN
      final mobileWs = await WebSocket.connect(
        'ws://127.0.0.1:${server.port}/ws?role=mobile',
      );
      final mobileMsgs = mobileWs
          .map(SignalMessage.tryDecode)
          .where((m) => m != null)
          .cast<SignalMessage>()
          .asBroadcastStream();

      final pairedFuture = mobileMsgs.firstWhere((m) => m.type == SignalType.paired);
      mobileWs.add(SignalMessage(
        type: SignalType.pair,
        payload: {'pin': server.pairingPin, 'deviceName': 'Pixel Test'},
      ).encode());
      final paired = await pairedFuture;
      expect(paired.payload['sessionId'], server.sessionId);
      expect(server.hasMobileClient, isTrue);

      // 3. OBS connects -> mobile receives obsReady -> offer/answer relay
      final obsReadyFuture =
          mobileMsgs.firstWhere((m) => m.type == SignalType.obsReady);
      final obsWs = await WebSocket.connect(
        'ws://127.0.0.1:${server.port}/ws?role=obs&token=${server.sessionToken}',
      );
      final obsMsgs = obsWs
          .map(SignalMessage.tryDecode)
          .where((m) => m != null)
          .cast<SignalMessage>()
          .asBroadcastStream();
      await obsReadyFuture;

      final obsOfferFuture =
          obsMsgs.firstWhere((m) => m.type == SignalType.offer);
      mobileWs.add(const SignalMessage(
        type: SignalType.offer,
        target: PeerTarget.obs,
        payload: {'type': 'offer', 'sdp': 'obs-sdp-offer'},
      ).encode());
      final obsOffer = await obsOfferFuture;
      expect(obsOffer.payload['sdp'], 'obs-sdp-offer');

      final mobileAnswerFuture =
          mobileMsgs.firstWhere((m) => m.type == SignalType.answer);
      obsWs.add(const SignalMessage(
        type: SignalType.answer,
        target: PeerTarget.obs,
        payload: {'type': 'answer', 'sdp': 'obs-sdp-answer'},
      ).encode());
      final mobileAnswer = await mobileAnswerFuture;
      expect(mobileAnswer.payload['sdp'], 'obs-sdp-answer');

      await obsWs.close();
      await mobileWs.close();
    });
  });
}
