import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:softify/services/integrations/discord_gateway_service.dart';

class FakeDiscordWebSocket implements IDiscordWebSocket {
  final StreamController<dynamic> _controller = StreamController<dynamic>();
  final List<String> sentMessages = [];
  bool isClosed = false;
  int? closeCode;
  String? closeReason;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void send(String data) {
    sentMessages.add(data);
  }

  void pushFromServer(Map<String, dynamic> packet) {
    _controller.add(jsonEncode(packet));
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    isClosed = true;
    if (code != null) {
      closeCode = code;
    }
    if (reason != null) {
      closeReason = reason;
    }
    await _controller.close();
  }
}

void main() {
  group('DiscordSuperProperties Mobile Emulation', () {
    test('produces correct mobile emulation metadata matching Metrolist Android specs', () {
      final props = DiscordSuperProperties.android();
      final map = props.toMap();

      expect(map['os'], equals('Android'));
      expect(map['browser'], equals('Discord Android'));
      expect(map['device'], equals('Mobile'));
      expect(map['client_version'], equals('220.0'));
      expect(map['release_channel'], equals('googleRelease'));
      expect(map['system_locale'], equals('en-US'));

      // Test Base64 serialization
      final b64 = props.toBase64();
      final decodedJson = jsonDecode(utf8.decode(base64Decode(b64))) as Map<String, dynamic>;
      expect(decodedJson['browser'], equals('Discord Android'));
      expect(decodedJson['client_version'], equals('220.0'));

      // Test round-trip from JSON
      final reconstructed = DiscordSuperProperties.fromJson(decodedJson);
      expect(reconstructed.os, equals('Android'));
      expect(reconstructed.browser, equals('Discord Android'));
      expect(reconstructed.clientVersion, equals('220.0'));
    });
  });

  group('Discord Gateway Payloads', () {
    late DiscordGatewayService service;

    setUp(() {
      service = DiscordGatewayService(fixedJitter: 0.5);
    });

    tearDown(() {
      service.dispose();
    });

    test('generates valid Opcode 2 Identify payload with token and properties', () {
      final identify = service.buildIdentifyPayload('mock_discord_user_token_123');

      expect(identify['op'], equals(DiscordGatewayService.opIdentify)); // 2
      final d = identify['d'] as Map<String, dynamic>;
      expect(d['token'], equals('mock_discord_user_token_123'));
      expect(d['properties'], isA<Map<String, dynamic>>());

      final props = d['properties'] as Map<String, dynamic>;
      expect(props['os'], equals('Android'));
      expect(props['browser'], equals('Discord Android'));
      expect(props['device'], equals('Mobile'));
      expect(props['client_version'], equals('220.0'));
    });

    test('generates valid Opcode 1 Heartbeat payload with sequence number tracking', () {
      final initialHb = service.buildHeartbeatPayload(null);
      expect(initialHb['op'], equals(DiscordGatewayService.opHeartbeat)); // 1
      expect(initialHb['d'], isNull);

      final seqHb = service.buildHeartbeatPayload(42);
      expect(seqHb['op'], equals(DiscordGatewayService.opHeartbeat));
      expect(seqHb['d'], equals(42));
    });

    test('calculates heartbeat jitter delay accurately according to Discord specs', () {
      const interval = 41250;
      // Fixed jitter 0.0 -> 0 ms
      expect(DiscordGatewayService.calculateJitteredHeartbeat(interval, 0.0), equals(0));
      // Fixed jitter 0.5 -> 20625 ms
      expect(DiscordGatewayService.calculateJitteredHeartbeat(interval, 0.5), equals(20625));
      // Fixed jitter 1.0 -> 41250 ms
      expect(DiscordGatewayService.calculateJitteredHeartbeat(interval, 1.0), equals(41250));
    });

    test('builds Opcode 3 Listening presence update with timestamps and Softify StudioMaster branding', () {
      const currentTimeMs = 1700000000000;
      const positionMs = 30000; // 30s in
      const durationMs = 210000; // 3m 30s total

      final payload = service.buildPresencePayload(
        title: 'Starboy',
        artist: 'The Weeknd, Daft Punk',
        album: 'Starboy (Deluxe)',
        coverUrl: 'https://cdn.softify.app/covers/starboy.jpg',
        positionMs: positionMs,
        durationMs: durationMs,
        isPlaying: true,
        currentTimeMs: currentTimeMs,
      );

      expect(payload['op'], equals(DiscordGatewayService.opPresenceUpdate)); // 3
      final d = payload['d'] as Map<String, dynamic>;
      expect(d['status'], equals('online'));
      expect(d['activities'], isNotEmpty);

      final activity = (d['activities'] as List).first as Map<String, dynamic>;
      expect(activity['name'], equals('Softify'));
      expect(activity['type'], equals(DiscordGatewayService.activityListening)); // 2
      expect(activity['details'], equals('Starboy'));
      expect(activity['state'], equals('The Weeknd, Daft Punk'));

      final timestamps = activity['timestamps'] as Map<String, dynamic>;
      expect(timestamps['start'], equals(currentTimeMs - positionMs));
      expect(timestamps['end'], equals(currentTimeMs + (durationMs - positionMs)));

      final assets = activity['assets'] as Map<String, dynamic>;
      expect(assets['large_image'], equals('https://cdn.softify.app/covers/starboy.jpg'));
      expect(assets['large_text'], equals('Starboy (Deluxe)'));
      expect(assets['small_image'], equals('softify_logo'));
      expect(assets['small_text'], equals('Softify StudioMaster 320kbps'));
    });

    test('builds empty activities presence when paused or cleared', () {
      final pausedPayload = service.buildPresencePayload(
        title: 'Starboy',
        artist: 'The Weeknd',
        isPlaying: false,
      );

      final d = pausedPayload['d'] as Map<String, dynamic>;
      expect(d['activities'], isEmpty);
      expect(d['status'], equals('online'));
    });
  });

  group('Discord Gateway WebSocket Lifecycle & Watchdog', () {
    late FakeDiscordWebSocket fakeSocket;
    late DiscordGatewayService service;

    setUp(() {
      fakeSocket = FakeDiscordWebSocket();
      service = DiscordGatewayService(
        fixedJitter: 0.1,
        socketConnector: (uri) async => fakeSocket,
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('full handshake flow: Hello -> Identify -> Ready -> Presence', () async {
      final statuses = <DiscordGatewayStatus>[];
      service.statusStream.listen(statuses.add);

      await service.connect(token: 'secret_user_token');
      expect(service.status, equals(DiscordGatewayStatus.connected));

      // 1. Gateway sends Opcode 10 Hello
      fakeSocket.pushFromServer({
        'op': DiscordGatewayService.opHello,
        'd': {'heartbeat_interval': 100},
      });

      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Verify Identify packet was sent
      expect(fakeSocket.sentMessages.isNotEmpty, isTrue);
      final identifySent = jsonDecode(fakeSocket.sentMessages.first) as Map<String, dynamic>;
      expect(identifySent['op'], equals(DiscordGatewayService.opIdentify));
      expect(identifySent['d']['token'], equals('secret_user_token'));

      // 2. Gateway sends Dispatch READY event
      fakeSocket.pushFromServer({
        'op': DiscordGatewayService.opDispatch,
        's': 1,
        't': 'READY',
        'd': {
          'session_id': 'sess_xyz987',
        },
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.status, equals(DiscordGatewayStatus.ready));
      expect(service.sessionId, equals('sess_xyz987'));
      expect(service.lastSequenceNumber, equals(1));

      // 3. Update Presence over connected socket
      await service.updatePresence(
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
      );

      final presencePacket = jsonDecode(fakeSocket.sentMessages.last) as Map<String, dynamic>;
      expect(presencePacket['op'], equals(DiscordGatewayService.opPresenceUpdate));
      final act = (presencePacket['d']['activities'] as List).first as Map<String, dynamic>;
      expect(act['details'], equals('Blinding Lights'));

      // 4. Clear Presence
      await service.clearPresence();
      final clearPacket = jsonDecode(fakeSocket.sentMessages.last) as Map<String, dynamic>;
      expect(clearPacket['d']['activities'], isEmpty);
    });

    test('Heartbeat ACK watchdog detects zombie connections and closes socket', () async {
      service = DiscordGatewayService(
        fixedJitter: 0.0,
        socketConnector: (uri) async => fakeSocket,
      );

      await service.connect(token: 'token_watchdog');

      // Hello with very short interval (40ms) for deterministic testing
      fakeSocket.pushFromServer({
        'op': DiscordGatewayService.opHello,
        'd': {'heartbeat_interval': 40},
      });

      // Wait for initial heartbeat (jitter=0 -> immediate)
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Acknowledge the first heartbeat
      fakeSocket.pushFromServer({
        'op': DiscordGatewayService.opHeartbeatAck,
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.lastHeartbeatAcked, isTrue);

      // Now wait past the next interval WITHOUT acknowledging
      await Future<void>.delayed(const Duration(milliseconds: 90));

      // Watchdog should have closed the socket with reconnect code 4000
      expect(fakeSocket.isClosed, isTrue);
      expect(fakeSocket.closeCode, equals(4000));
    });
  });
}
