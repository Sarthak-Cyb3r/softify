import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/services/sync/listen_together_proto.dart';
import 'package:softify/services/sync/listen_together_protocol.dart';
import 'package:softify/services/sync/listen_together_service.dart';

class MockListenTogetherSocket implements IListenTogetherSocket {
  final _controller = StreamController<dynamic>.broadcast();
  final List<String> sentMessages = [];
  bool isClosed = false;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void add(dynamic data) {
    sentMessages.add(data.toString());
  }

  void deliverFromServer(String json) {
    _controller.add(json);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    isClosed = true;
    await _controller.close();
  }
}

void main() {
  group('ListenTogether Protocol Serialization & Deserialization', () {
    test('ListenTogetherUser serialization round-trip', () {
      const user = ListenTogetherUser(
        userId: 'u_123',
        username: 'Alice',
        isHost: true,
        isConnected: true,
        avatarUrl: 'https://softify.app/avatar.png',
        joinedAt: 1700000000000,
      );

      final json = user.toJson();
      final decoded = ListenTogetherUser.fromJson(json);

      expect(decoded.userId, equals('u_123'));
      expect(decoded.username, equals('Alice'));
      expect(decoded.isHost, isTrue);
      expect(decoded.isConnected, isTrue);
      expect(decoded.avatarUrl, equals('https://softify.app/avatar.png'));
      expect(decoded.joinedAt, equals(1700000000000));
    });

    test('SyncTrackInfo serialization and Track entity conversion', () {
      const syncTrack = SyncTrackInfo(
        id: 'track_abc',
        title: 'Midnight City',
        artist: 'M83',
        album: 'Hurry Up, We\'re Dreaming',
        durationMs: 243000,
        thumbnailUrl: 'https://i.ytimg.com/vi/track_abc/hqdefault.jpg',
        suggestedBy: 'user_99',
      );

      final json = syncTrack.toJson();
      final decoded = SyncTrackInfo.fromJson(json);

      expect(decoded.id, equals('track_abc'));
      expect(decoded.title, equals('Midnight City'));
      expect(decoded.artist, equals('M83'));
      expect(decoded.album, equals('Hurry Up, We\'re Dreaming'));
      expect(decoded.durationMs, equals(243000));
      expect(decoded.thumbnailUrl, equals('https://i.ytimg.com/vi/track_abc/hqdefault.jpg'));
      expect(decoded.suggestedBy, equals('user_99'));

      final trackEntity = decoded.toTrack();
      expect(trackEntity.id, equals('track_abc'));
      expect(trackEntity.title, equals('Midnight City'));
      expect(trackEntity.artist, equals('M83'));
      expect(trackEntity.duration, equals(const Duration(milliseconds: 243000)));

      final reconverted = SyncTrackInfo.fromTrack(trackEntity, suggestedBy: 'user_99');
      expect(reconverted.id, equals(decoded.id));
      expect(reconverted.title, equals(decoded.title));
      expect(reconverted.suggestedBy, equals('user_99'));
    });

    test('ListenTogetherRoom serialization round-trip', () {
      const room = ListenTogetherRoom(
        roomCode: 'SOFT99',
        hostId: 'host_1',
        users: [
          ListenTogetherUser(userId: 'host_1', username: 'HostUser', isHost: true),
          ListenTogetherUser(userId: 'guest_2', username: 'GuestUser', isHost: false),
        ],
        currentTrack: SyncTrackInfo(
          id: 't_1',
          title: 'Starboy',
          artist: 'The Weeknd',
          durationMs: 230000,
        ),
        isPlaying: true,
        positionMs: 45000,
        lastUpdateEpochMs: 1729000000000,
        volume: 0.85,
        queue: [
          SyncTrackInfo(id: 't_2', title: 'Blinding Lights', artist: 'The Weeknd', durationMs: 200000),
        ],
        revision: 4,
      );

      final json = room.toJson();
      final decoded = ListenTogetherRoom.fromJson(json);

      expect(decoded.roomCode, equals('SOFT99'));
      expect(decoded.hostId, equals('host_1'));
      expect(decoded.users.length, equals(2));
      expect(decoded.currentTrack?.title, equals('Starboy'));
      expect(decoded.isPlaying, isTrue);
      expect(decoded.positionMs, equals(45000));
      expect(decoded.volume, closeTo(0.85, 0.001));
      expect(decoded.queue.length, equals(1));
      expect(decoded.revision, equals(4));
    });

    test('Buffer Barrier payloads serialization round-trip', () {
      // BufferWaitPayload
      const waitPayload = BufferWaitPayload(
        trackId: 'track_123',
        targetTimestamp: 1729000005000,
        waitingFor: ['u1', 'u2', 'u3'],
      );
      final waitJson = waitPayload.toJson();
      final decodedWait = BufferWaitPayload.fromJson(waitJson);
      expect(decodedWait.trackId, equals('track_123'));
      expect(decodedWait.targetTimestamp, equals(1729000005000));
      expect(decodedWait.waitingFor, equals(['u1', 'u2', 'u3']));

      // BufferReadyPayload
      const readyPayload = BufferReadyPayload(
        trackId: 'track_123',
        userId: 'u1',
        readyEpochMs: 1729000004500,
      );
      final readyJson = readyPayload.toJson();
      final decodedReady = BufferReadyPayload.fromJson(readyJson);
      expect(decodedReady.trackId, equals('track_123'));
      expect(decodedReady.userId, equals('u1'));
      expect(decodedReady.readyEpochMs, equals(1729000004500));

      // BufferCompletePayload
      const completePayload = BufferCompletePayload(
        trackId: 'track_123',
        startPlaybackAtEpochMs: 1729000005250,
        positionMs: 0,
      );
      final completeJson = completePayload.toJson();
      final decodedComplete = BufferCompletePayload.fromJson(completeJson);
      expect(decodedComplete.trackId, equals('track_123'));
      expect(decodedComplete.startPlaybackAtEpochMs, equals(1729000005250));
      expect(decodedComplete.positionMs, equals(0));
    });

    test('PlaybackActionPayload and Envelope round-trip', () {
      const action = PlaybackActionPayload(
        action: PlaybackActions.seek,
        trackId: 'track_99',
        positionMs: 65432,
        serverTime: 1729000010000,
        revision: 8,
        capturedAtServerTime: 1729000009950,
      );

      final msg = ListenTogetherMessage(
        type: MessageTypes.playbackAction,
        payload: action.toJson(),
      );

      final jsonStr = msg.toJsonString();
      final parsed = ListenTogetherMessage.parse(jsonStr);

      expect(parsed.type, equals(MessageTypes.playbackAction));
      final decodedAction = PlaybackActionPayload.fromJson(parsed.payload);
      expect(decodedAction.action, equals(PlaybackActions.seek));
      expect(decodedAction.trackId, equals('track_99'));
      expect(decodedAction.positionMs, equals(65432));
      expect(decodedAction.serverTime, equals(1729000010000));
      expect(decodedAction.revision, equals(8));
      expect(decodedAction.capturedAtServerTime, equals(1729000009950));
    });

    test('TrackSuggestion serialization round-trip', () {
      const suggestion = TrackSuggestion(
        suggestionId: 'sugg_1',
        fromUserId: 'guest_user',
        fromUsername: 'Bob',
        track: SyncTrackInfo(
          id: 'track_sugg',
          title: 'Resonance',
          artist: 'HOME',
          durationMs: 212000,
        ),
        reason: 'Fits the chill vibe',
        status: 'pending',
      );

      final json = suggestion.toJson();
      final decoded = TrackSuggestion.fromJson(json);

      expect(decoded.suggestionId, equals('sugg_1'));
      expect(decoded.fromUserId, equals('guest_user'));
      expect(decoded.fromUsername, equals('Bob'));
      expect(decoded.track.title, equals('Resonance'));
      expect(decoded.reason, equals('Fits the chill vibe'));
      expect(decoded.status, equals('pending'));
    });
  });

  group('ServerClock & Clock Skew Estimation', () {
    test('Calculates smoothed clock offset and clock skew with simulated delays', () {
      int localMonotonic = 1000;
      final clock = ServerClock(() => localMonotonic);

      expect(clock.now(), isNull);
      expect(clock.clockSkewMs, isNull);

      // Pong arrival:
      // client dispatched ping at local = 1000
      // server received ping at server = 10000
      // server dispatched pong at server = 10010 (processing time = 10ms)
      // client receives pong at local = 1120 (total roundtrip = 120ms, network RTT = 110ms)
      localMonotonic = 1120;
      final isFirst = clock.recordPong(
        clientTime: 1000,
        serverReceiveTime: 10000,
        serverSendTime: 10010,
      );

      expect(isFirst, isTrue);

      // networkRTT = 120 - 10 = 110ms
      // sampleOffset = 10010 + 55 - 1120 = 8945ms
      // estimated server now = localMonotonic (1120) + 8945 = 10065ms
      expect(clock.now(), equals(10065));
      expect(clock.serverOffsetMs, equals(8945.0));
      // clockSkew = clientTime - serverTime = -8945ms (client is behind server by 8945ms)
      expect(clock.clockSkewMs, equals(-8945.0));

      // Test position estimation
      // position = 500ms at effectiveAtServerTime = 10000ms
      // current server time = 10065ms -> position delta = +65ms -> 565ms
      expect(clock.positionAt(position: 500, effectiveAtServerTime: 10000, isPlaying: true), equals(565));

      // Advance local time by 100ms
      localMonotonic += 100;
      expect(clock.now(), equals(10165));
      expect(clock.positionAt(position: 500, effectiveAtServerTime: 10000, isPlaying: true), equals(665));
      // Paused track does not advance
      expect(clock.positionAt(position: 500, effectiveAtServerTime: 10000, isPlaying: false), equals(500));
    });

    test('Moving average weights jittery vs low-latency pong samples', () {
      int localMonotonic = 2000;
      final clock = ServerClock(() => localMonotonic);

      // Best sample: network RTT = 40ms, serverOffset = 50000
      localMonotonic = 2050; // roundtrip 50ms, processing 10ms -> network 40ms
      clock.recordPong(
        clientTime: 2000,
        serverReceiveTime: 52020,
        serverSendTime: 52030,
      );
      final initialOffset = clock.serverOffsetMs!;
      expect(clock.bestRoundTripMs, equals(40));

      // Subsequent sample with high jitter: network RTT = 250ms (> best + 50ms margin)
      localMonotonic = 3000;
      final pingSentAt = localMonotonic;
      localMonotonic = 3260; // roundtrip 260ms, processing 10ms -> network 250ms
      clock.recordPong(
        clientTime: pingSentAt,
        serverReceiveTime: 53120,
        serverSendTime: 53130,
      );

      // High jitter sample gets only 0.05 weight (EMA smoothing)
      expect(clock.serverOffsetMs, isNot(equals(initialOffset)));
      expect((clock.serverOffsetMs! - initialOffset).abs(), lessThan(50.0));
    });

    test('Rejects invalid and stale ping/pong samples', () {
      int localMonotonic = 100000;
      final clock = ServerClock(() => localMonotonic);

      // Client time is 0
      expect(clock.recordPong(clientTime: 0, serverReceiveTime: 1000, serverSendTime: 1001), isFalse);
      // Client time in future
      expect(clock.recordPong(clientTime: 100001, serverReceiveTime: 1000, serverSendTime: 1001), isFalse);
      // Server send before receive
      expect(clock.recordPong(clientTime: 99000, serverReceiveTime: 1001, serverSendTime: 1000), isFalse);
      // Stale sample > 60s
      localMonotonic = 200000;
      expect(clock.recordPong(clientTime: 100000, serverReceiveTime: 1000, serverSendTime: 1001), isFalse);
      expect(clock.now(), isNull);
    });

    test('Reset clears mapping', () {
      int localMonotonic = 1100;
      final clock = ServerClock(() => localMonotonic);
      clock.recordPong(clientTime: 1000, serverReceiveTime: 10000, serverSendTime: 10000);
      expect(clock.now(), isNotNull);

      clock.reset();
      expect(clock.now(), isNull);
      expect(clock.positionAt(position: 500, effectiveAtServerTime: 10000, isPlaying: true), equals(500));
    });
  });

  group('Buffer Barrier State Machine', () {
    test('Host triggers buffer barrier and waits for all peer readiness before release', () async {
      final mockSocket = MockListenTogetherSocket();
      int localTime = 100000;
      final clock = ServerClock(() => localTime);
      // Seed clock offset: serverTime = localTime + 5000ms
      clock.recordPong(
        clientTime: 99950,
        serverReceiveTime: 104990,
        serverSendTime: 105000,
        receivedAt: 100000,
      );

      final service = ListenTogetherService(serverClock: clock);
      await service.connect(
        url: 'wss://test',
        connector: (_) async => mockSocket,
      );

      // Simulate room creation
      mockSocket.deliverFromServer(
        const ListenTogetherMessage(
          type: MessageTypes.roomCreated,
          payload: {
            'room_code': 'SYNC01',
            'user_id': 'host_user',
            'session_token': 'token_xyz',
          },
        ).toJsonString(),
      );

      await pumpEventQueue();

      expect(service.isHost, isTrue);
      expect(service.currentRoomCode, equals('SYNC01'));
      expect(service.bufferBarrierState, equals(BufferBarrierState.idle));

      // Simulate guest joining room
      mockSocket.deliverFromServer(
        const ListenTogetherMessage(
          type: MessageTypes.userJoined,
          payload: {
            'user_id': 'guest_user_1',
            'username': 'Guest1',
            'is_host': false,
            'is_connected': true,
          },
        ).toJsonString(),
      );
      await pumpEventQueue();
      expect(service.currentRoom!.users.length, equals(2));

      // Host triggers buffer barrier for track 'track_abc'
      service.triggerBufferBarrier('track_abc', leadTimeMs: 200);

      // State becomes buffering
      expect(service.bufferBarrierState, equals(BufferBarrierState.buffering));
      expect(service.bufferingTrackId, equals('track_abc'));

      // Verify BUFFER_WAIT message sent
      final waitMsg = mockSocket.sentMessages
          .map((m) => ListenTogetherMessage.parse(m))
          .firstWhere((m) => m.type == MessageTypes.bufferWait);
      final waitPayload = BufferWaitPayload.fromJson(waitMsg.payload);
      expect(waitPayload.trackId, equals('track_abc'));

      // Local prebuffer completes -> ready state
      await pumpEventQueue();
      expect(service.bufferBarrierState, equals(BufferBarrierState.ready));

      // Guest sends buffer_ready
      mockSocket.deliverFromServer(
        const ListenTogetherMessage(
          type: MessageTypes.bufferReady,
          payload: {
            'track_id': 'track_abc',
            'user_id': 'guest_user_1',
          },
        ).toJsonString(),
      );
      await pumpEventQueue();

      // All peers ready -> BufferComplete emitted and playback scheduled
      final completeMsg = mockSocket.sentMessages
          .map((m) => ListenTogetherMessage.parse(m))
          .firstWhere((m) => m.type == MessageTypes.bufferComplete);
      final completePayload = BufferCompletePayload.fromJson(completeMsg.payload);
      expect(completePayload.trackId, equals('track_abc'));
      expect(completePayload.startPlaybackAtEpochMs, greaterThan(0));

      // State transitions to playing
      expect(service.bufferBarrierState, equals(BufferBarrierState.playing));

      await service.disconnect();
    });

    test('Guest receives buffer_wait, pre-buffers, emits buffer_ready, and syncs on buffer_complete', () async {
      final mockSocket = MockListenTogetherSocket();
      int localTime = 200000;
      final clock = ServerClock(() => localTime);
      // Seed server clock offset
      clock.recordPong(
        clientTime: 199950,
        serverReceiveTime: 204990,
        serverSendTime: 205000,
        receivedAt: 200000,
      );

      final service = ListenTogetherService(serverClock: clock);
      await service.connect(
        url: 'wss://test',
        connector: (_) async => mockSocket,
      );

      // Simulate join approved
      mockSocket.deliverFromServer(
        ListenTogetherMessage(
          type: MessageTypes.joinApproved,
          payload: {
            'room_code': 'ROOM88',
            'user_id': 'guest_user_2',
            'session_token': 'guest_tok',
            'state': const ListenTogetherRoom(
              roomCode: 'ROOM88',
              hostId: 'host_id',
              isPlaying: false,
            ).toJson(),
          },
        ).toJsonString(),
      );
      await pumpEventQueue();

      expect(service.isGuest, isTrue);

      // Host issues buffer_wait
      mockSocket.deliverFromServer(
        ListenTogetherMessage(
          type: MessageTypes.bufferWait,
          payload: const BufferWaitPayload(
            trackId: 'track_xyz',
            targetTimestamp: 205000,
          ).toJson(),
        ).toJsonString(),
      );
      await pumpEventQueue();

      // Guest enters buffering then ready and sends buffer_ready
      expect(service.bufferingTrackId, equals('track_xyz'));
      final readyMsg = mockSocket.sentMessages
          .map((m) => ListenTogetherMessage.parse(m))
          .firstWhere((m) => m.type == MessageTypes.bufferReady);
      final readyPayload = BufferReadyPayload.fromJson(readyMsg.payload);
      expect(readyPayload.trackId, equals('track_xyz'));
      expect(readyPayload.userId, equals('guest_user_2'));

      // Host issues buffer_complete with scheduled timestamp
      mockSocket.deliverFromServer(
        ListenTogetherMessage(
          type: MessageTypes.bufferComplete,
          payload: const BufferCompletePayload(
            trackId: 'track_xyz',
            startPlaybackAtEpochMs: 205200,
            positionMs: 0,
          ).toJson(),
        ).toJsonString(),
      );
      await pumpEventQueue();

      expect(service.bufferBarrierState, equals(BufferBarrierState.playing));
      expect(service.bufferingTrackId, isNull);

      await service.disconnect();
    });
  });

  group('Drift Detection and Resynchronization', () {
    test('Drift within 50ms soft sync threshold requires no adjustment', () {
      int localTime = 1000;
      final clock = ServerClock(() => localTime);
      // Synchronized: server time == localTime
      clock.recordPong(clientTime: 990, serverReceiveTime: 995, serverSendTime: 995, receivedAt: 1000);

      final service = ListenTogetherService(serverClock: clock);

      // Set room state: playing, position 10000ms at serverTime 1000ms
      const room = ListenTogetherRoom(
        roomCode: 'ROOM1',
        hostId: 'h1',
        isPlaying: true,
        positionMs: 10000,
        lastUpdateEpochMs: 1000,
      );
      service.handleIncomingMessage(
        ListenTogetherMessage(type: MessageTypes.roomCreated, payload: room.toJson()).toJsonString(),
      );

      // Advance time by 500ms -> target server position is 10500ms
      localTime = 1500;
      // Local position is 10480ms -> drift is +200ms (<= 50ms)
      final action = service.checkDriftAndResync(10480);
      expect(action, equals(DriftAction.none));
    });

    test('Drift between 50ms and 500ms triggers micro-nudge rate correction', () {
      int localTime = 1000;
      final clock = ServerClock(() => localTime);
      clock.recordPong(clientTime: 990, serverReceiveTime: 995, serverSendTime: 995, receivedAt: 1000);

      final service = ListenTogetherService(serverClock: clock);

      const room = ListenTogetherRoom(
        roomCode: 'ROOM1',
        hostId: 'h1',
        isPlaying: true,
        positionMs: 10000,
        lastUpdateEpochMs: 1000,
      );
      service.handleIncomingMessage(
        ListenTogetherMessage(type: MessageTypes.roomCreated, payload: room.toJson()).toJsonString(),
      );

      // Advance time by 1000ms -> target server position is 11000ms
      localTime = 2000;
      // Local position is 10800ms -> drift is +200ms (> 50ms and <= 500ms)
      final action = service.checkDriftAndResync(10800);
      expect(action, equals(DriftAction.microNudge));
    });

    test('Drift exceeding 500ms triggers immediate hard seek resynchronization', () {
      int localTime = 1000;
      final clock = ServerClock(() => localTime);
      clock.recordPong(clientTime: 990, serverReceiveTime: 995, serverSendTime: 995, receivedAt: 1000);

      final service = ListenTogetherService(serverClock: clock);

      const room = ListenTogetherRoom(
        roomCode: 'ROOM1',
        hostId: 'h1',
        isPlaying: true,
        positionMs: 10000,
        lastUpdateEpochMs: 1000,
      );
      service.handleIncomingMessage(
        ListenTogetherMessage(type: MessageTypes.roomCreated, payload: room.toJson()).toJsonString(),
      );

      // Advance time by 2000ms -> target server position is 12000ms
      localTime = 3000;
      // Local position is 10500ms -> drift is +1500ms (> 500ms threshold)
      final action = service.checkDriftAndResync(10500);
      expect(action, equals(DriftAction.hardSeek));
    });
  });

  group('Playback Control & Room Collaboration', () {
    test('Host broadcasts playback actions (play, pause, seek, changeTrack)', () async {
      final mockSocket = MockListenTogetherSocket();
      final service = ListenTogetherService();
      await service.connect(
        url: 'wss://test',
        connector: (_) async => mockSocket,
      );

      service.handleIncomingMessage(
        const ListenTogetherMessage(
          type: MessageTypes.roomCreated,
          payload: {'room_code': 'ABC123', 'user_id': 'host_1'},
        ).toJsonString(),
      );

      service.broadcastPlay(positionMs: 12000);
      final playMsg = mockSocket.sentMessages
          .map((m) => ListenTogetherMessage.parse(m))
          .lastWhere((m) => m.type == MessageTypes.playbackAction);
      expect(playMsg.payload['action'], equals(PlaybackActions.play));
      expect(playMsg.payload['position'], equals(12000));
      expect(service.currentRoom?.isPlaying, isTrue);

      service.broadcastPause(positionMs: 14500);
      final pauseMsg = mockSocket.sentMessages
          .map((m) => ListenTogetherMessage.parse(m))
          .lastWhere((m) => m.type == MessageTypes.playbackAction);
      expect(pauseMsg.payload['action'], equals(PlaybackActions.pause));
      expect(pauseMsg.payload['position'], equals(14500));
      expect(service.currentRoom?.isPlaying, isFalse);

      service.broadcastSeek(30000);
      final seekMsg = mockSocket.sentMessages
          .map((m) => ListenTogetherMessage.parse(m))
          .lastWhere((m) => m.type == MessageTypes.playbackAction);
      expect(seekMsg.payload['action'], equals(PlaybackActions.seek));
      expect(seekMsg.payload['position'], equals(30000));
      expect(service.currentRoom?.positionMs, equals(30000));

      const newTrack = SyncTrackInfo(
        id: 'new_track_1',
        title: 'New Song',
        artist: 'Artist',
        durationMs: 180000,
      );
      service.broadcastTrackChange(newTrack, positionMs: 0);
      final changeMsg = mockSocket.sentMessages
          .map((m) => ListenTogetherMessage.parse(m))
          .lastWhere((m) => m.type == MessageTypes.playbackAction);
      expect(changeMsg.payload['action'], equals(PlaybackActions.changeTrack));
      expect(changeMsg.payload['track_id'], equals('new_track_1'));
      expect(service.bufferingTrackId, equals('new_track_1'));

      await service.disconnect();
    });

    test('Handles track suggestions and approvals/rejections', () async {
      final mockSocket = MockListenTogetherSocket();
      final service = ListenTogetherService();
      await service.connect(
        url: 'wss://test',
        connector: (_) async => mockSocket,
      );

      service.handleIncomingMessage(
        const ListenTogetherMessage(
          type: MessageTypes.roomCreated,
          payload: {'room_code': 'SUGG01', 'user_id': 'host_id'},
        ).toJsonString(),
      );

      TrackSuggestion? receivedSuggestion;
      final sub = service.suggestionStream.listen((s) {
        receivedSuggestion = s;
      });

      // Simulate suggestion received from server
      mockSocket.deliverFromServer(
        ListenTogetherMessage(
          type: MessageTypes.suggestionReceived,
          payload: const TrackSuggestion(
            suggestionId: 'sugg_99',
            fromUserId: 'guest_42',
            fromUsername: 'Charlie',
            track: SyncTrackInfo(
              id: 'track_suggestion',
              title: 'Aerodynamic',
              artist: 'Daft Punk',
              durationMs: 212000,
            ),
          ).toJson(),
        ).toJsonString(),
      );

      await pumpEventQueue();
      expect(receivedSuggestion, isNotNull);
      expect(receivedSuggestion!.suggestionId, equals('sugg_99'));
      expect(receivedSuggestion!.track.title, equals('Aerodynamic'));

      service.approveSuggestion('sugg_99');
      final approveMsg = mockSocket.sentMessages
          .map((m) => ListenTogetherMessage.parse(m))
          .lastWhere((m) => m.type == MessageTypes.approveSuggestion);
      expect(approveMsg.payload['suggestion_id'], equals('sugg_99'));

      service.rejectSuggestion('sugg_99', reason: 'Already in queue');
      final rejectMsg = mockSocket.sentMessages
          .map((m) => ListenTogetherMessage.parse(m))
          .lastWhere((m) => m.type == MessageTypes.rejectSuggestion);
      expect(rejectMsg.payload['suggestion_id'], equals('sugg_99'));
      expect(rejectMsg.payload['reason'], equals('Already in queue'));

      await sub.cancel();
      await service.disconnect();
    });

    test('Host migration updates room hostId and user roles', () async {
      final mockSocket = MockListenTogetherSocket();
      final service = ListenTogetherService();
      await service.connect(
        url: 'wss://test',
        connector: (_) async => mockSocket,
      );

      mockSocket.deliverFromServer(
        ListenTogetherMessage(
          type: MessageTypes.joinApproved,
          payload: {
            'room_code': 'MIGRATE',
            'user_id': 'user_charlie',
            'session_token': 'token_charlie',
            'state': const ListenTogetherRoom(
              roomCode: 'MIGRATE',
              hostId: 'original_host',
              users: [
                ListenTogetherUser(userId: 'original_host', username: 'Host1', isHost: true),
                ListenTogetherUser(userId: 'user_charlie', username: 'Charlie', isHost: false),
              ],
            ).toJson(),
          },
        ).toJsonString(),
      );

      await pumpEventQueue();
      expect(service.isGuest, isTrue);
      expect(service.currentRoom!.hostId, equals('original_host'));

      // Host changed event transfers host role to user_charlie
      mockSocket.deliverFromServer(
        const ListenTogetherMessage(
          type: MessageTypes.hostChanged,
          payload: {'new_host_id': 'user_charlie'},
        ).toJsonString(),
      );

      await pumpEventQueue();
      expect(service.isHost, isTrue);
      expect(service.currentRoom!.hostId, equals('user_charlie'));
      final me = service.currentRoom!.users.firstWhere((u) => u.userId == 'user_charlie');
      expect(me.isHost, isTrue);

      await service.disconnect();
    });

    test('ListenTogetherProtoCodec encodes and decodes approve_join, error, and join_request', () {
      final approveBytes = ListenTogetherProtoCodec.encodeApproveJoin('user_guest_123');
      final decodedApprove = ListenTogetherProtoCodec.decodeEnvelope(Uint8List.fromList(approveBytes));
      expect(decodedApprove, isNotNull);
      expect(decodedApprove!.$1, equals('approve_join'));

      // Error wire decode
      final errWriter = ProtoWriter()
        ..writeString(1, 'room_not_found')
        ..writeString(2, 'Room not found');
      final errBytes = ListenTogetherProtoCodec.encodeEnvelope('error', errWriter.takeBytes());
      final decodedErrEnv = ListenTogetherProtoCodec.decodeEnvelope(Uint8List.fromList(errBytes));
      expect(decodedErrEnv, isNotNull);
      expect(decodedErrEnv!.$1, equals('error'));
      final errPayload = ListenTogetherProtoCodec.decodeError(decodedErrEnv.$2);
      expect(errPayload['code'], equals('room_not_found'));
      expect(errPayload['message'], equals('Room not found'));

      // Join request wire decode
      final reqWriter = ProtoWriter()
        ..writeString(1, 'user_guest_456')
        ..writeString(2, 'GuestGuy');
      final reqBytes = ListenTogetherProtoCodec.encodeEnvelope('join_request', reqWriter.takeBytes());
      final decodedReqEnv = ListenTogetherProtoCodec.decodeEnvelope(Uint8List.fromList(reqBytes));
      expect(decodedReqEnv, isNotNull);
      expect(decodedReqEnv!.$1, equals('join_request'));
      final reqPayload = ListenTogetherProtoCodec.decodeJoinRequest(decodedReqEnv.$2);
      expect(reqPayload['user_id'], equals('user_guest_456'));
      expect(reqPayload['username'], equals('GuestGuy'));

      // Capability handshake wire round-trip
      final capBytes = ListenTogetherProtoCodec.encodeClientCapabilities(
        supportsProtobuf: true,
        supportsCompression: true,
        clientVersion: '3.0.8',
      );
      final decodedCapEnv = ListenTogetherProtoCodec.decodeEnvelope(Uint8List.fromList(capBytes));
      expect(decodedCapEnv, isNotNull);
      expect(decodedCapEnv!.$1, equals('client_capabilities'));

      final serverCapWriter = ProtoWriter()
        ..writeBool(1, true)
        ..writeBool(2, true)
        ..writeString(3, 'metroserver/1.0.0');
      final serverCapBytes = ListenTogetherProtoCodec.encodeEnvelope('server_capabilities', serverCapWriter.takeBytes());
      final decodedServerCapEnv = ListenTogetherProtoCodec.decodeEnvelope(Uint8List.fromList(serverCapBytes));
      expect(decodedServerCapEnv, isNotNull);
      expect(decodedServerCapEnv!.$1, equals('server_capabilities'));
      final serverCapPayload = ListenTogetherProtoCodec.decodeServerCapabilities(decodedServerCapEnv.$2);
      expect(serverCapPayload['supports_protobuf'], isTrue);
      expect(serverCapPayload['supports_compression'], isTrue);
      expect(serverCapPayload['server_version'], equals('metroserver/1.0.0'));
    });
  });
}
