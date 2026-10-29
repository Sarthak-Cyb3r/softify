import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../data/player/softify_audio_handler.dart';
import '../automix_service.dart';
import 'listen_together_protocol.dart';
import 'listen_together_proto.dart';

/// Abstract socket connection for Listen Together real-time synchronization.
abstract class IListenTogetherSocket {
  Stream<dynamic> get stream;
  void add(dynamic data);
  Future<void> close([int? code, String? reason]);
}

/// Standard dart:io WebSocket implementation.
class IoListenTogetherSocket implements IListenTogetherSocket {
  final WebSocket _socket;

  IoListenTogetherSocket(this._socket);

  @override
  Stream<dynamic> get stream => _socket;

  @override
  void add(dynamic data) => _socket.add(data);

  @override
  Future<void> close([int? code, String? reason]) => _socket.close(code, reason);
}

typedef ListenTogetherSocketConnector = Future<IListenTogetherSocket> Function(
    String url);

/// Precise wall-clock to monotonic server clock estimator.
/// Directly mirrors Metrolist's ServerClock algorithm with exponential moving average (EMA)
/// and round-trip network jitter rejection.
class ServerClock {
  final int Function() _monotonicTimeMs;

  ServerClock([int Function()? monotonicTimeMs])
      : _monotonicTimeMs = monotonicTimeMs ??
            (() => DateTime.now().millisecondsSinceEpoch);

  double? _serverOffsetMs;
  int _bestRoundTripMs = 999999999;

  static const int maxSampleAgeMs = 60000;
  static const int goodSampleMarginMs = 50;

  double? get serverOffsetMs => _serverOffsetMs;

  /// Clock skew relative to server: clientTime - serverTime.
  /// Skew is positive if client clock is ahead of server clock.
  double? get clockSkewMs => _serverOffsetMs != null ? -_serverOffsetMs! : null;

  int get bestRoundTripMs => _bestRoundTripMs;

  void reset() {
    _serverOffsetMs = null;
    _bestRoundTripMs = 999999999;
  }

  /// Records a ping/pong timing exchange and updates the smoothed server offset.
  ///
  /// [clientTime]: monotonic timestamp when ping was dispatched.
  /// [serverReceiveTime]: epoch ms when server received the ping.
  /// [serverSendTime]: epoch ms when server dispatched the pong.
  /// [receivedAt]: monotonic timestamp when pong arrived locally (defaults to now).
  ///
  /// Returns `true` if this was the very first accepted sample (useful to trigger sync).
  bool recordPong({
    required int clientTime,
    required int serverReceiveTime,
    required int serverSendTime,
    int? receivedAt,
  }) {
    final now = receivedAt ?? _monotonicTimeMs();
    if (clientTime <= 0 || clientTime > now || (now - clientTime) > maxSampleAgeMs) {
      return false;
    }
    if (serverReceiveTime <= 0 || serverSendTime < serverReceiveTime) {
      return false;
    }

    final roundTrip = now - clientTime;
    final serverProcessing = serverSendTime - serverReceiveTime;
    final networkRoundTrip = math.max(0, roundTrip - serverProcessing);
    final sampleOffset = serverSendTime + (networkRoundTrip / 2.0) - now;
    final previousOffset = _serverOffsetMs;

    if (networkRoundTrip < _bestRoundTripMs) {
      _bestRoundTripMs = networkRoundTrip;
    }

    final weight = (networkRoundTrip <= _bestRoundTripMs + goodSampleMarginMs)
        ? 0.25
        : 0.05;

    _serverOffsetMs = previousOffset != null
        ? previousOffset + weight * (sampleOffset - previousOffset)
        : sampleOffset;

    return previousOffset == null;
  }

  /// Estimated current server time in epoch milliseconds.
  int? now() {
    final offset = _serverOffsetMs;
    if (offset == null) return null;
    return (_monotonicTimeMs() + offset).round();
  }

  /// Translates a reference playback position to the current server wall-clock.
  int positionAt({
    required int position,
    required int? effectiveAtServerTime,
    required bool isPlaying,
  }) {
    if (!isPlaying || effectiveAtServerTime == null || effectiveAtServerTime <= 0) {
      return position;
    }
    final serverNow = now();
    if (serverNow == null) return position;
    return position + math.max(0, serverNow - effectiveAtServerTime);
  }
}

/// Action determined by drift detection analysis.
enum DriftAction {
  none,
  microNudge,
  hardSeek,
}

/// High-precision collaborative listening synchronization service for Softify.
/// Reverse-engineered from Metrolist's Listen Together architecture.
class ListenTogetherService {
  static final ListenTogetherService instance = ListenTogetherService._internal();

  ListenTogetherService._internal({
    this.automixService,
    this.audioHandler,
    ServerClock? serverClock,
  }) : serverClock = serverClock ?? ServerClock();

  factory ListenTogetherService({
    AutomixService? automixService,
    SoftifyAudioHandler? audioHandler,
    ServerClock? serverClock,
  }) {
    return ListenTogetherService._internal(
      automixService: automixService,
      audioHandler: audioHandler,
      serverClock: serverClock,
    );
  }

  final AutomixService? automixService;
  final SoftifyAudioHandler? audioHandler;
  final ServerClock serverClock;

  // Connection & Room state
  SyncConnectionState _connectionState = SyncConnectionState.disconnected;
  SyncRole _role = SyncRole.none;
  ListenTogetherRoom? _currentRoom;
  BufferBarrierState _bufferBarrierState = BufferBarrierState.idle;
  String? _userId;
  String? _sessionToken;
  String? _serverUrl;
  int _pingSequence = 0;
  int _lastRevision = 0;

  // Telemetry backend integration for durable room storage & admin analytics
  static const String defaultTelemetryBackendUrl =
      'https://server-eight-gamma-81.vercel.app';
  String _telemetryBackendUrl = defaultTelemetryBackendUrl;
  String? _localUsername;

  void setTelemetryBackendUrl(String url) {
    if (url.trim().isNotEmpty) {
      _telemetryBackendUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    }
  }

  void _postRoomTelemetry(String path, Map<String, dynamic> data) {
    Future.microtask(() async {
      try {
        final uri = Uri.parse('$_telemetryBackendUrl$path');
        await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // Fire-and-forget telemetry; fail silently so playback sync is never impaired
      }
    });
  }

  // Buffer barrier coordination
  String? _bufferingTrackId;
  final Set<String> _readyUsers = <String>{};
  Timer? _barrierTimeoutTimer;
  Timer? _scheduledPlaybackTimer;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 6;
  static const int pingIntervalMs = 5000;
  static const int defaultBarrierTimeoutMs = 5000;
  static const int defaultLeadTimeMs = 200;

  // Drift thresholds
  static const int softSyncThresholdMs = 50;
  static const int hardSyncThresholdMs = 500;
  static const double microNudgeSpeedAdjustment = 0.02;

  IListenTogetherSocket? _socket;
  StreamSubscription? _socketSubscription;
  ListenTogetherSocketConnector? _socketConnector;

  // Stream controllers
  final _connectionStateController =
      StreamController<SyncConnectionState>.broadcast();
  final _roleController = StreamController<SyncRole>.broadcast();
  final _roomController = StreamController<ListenTogetherRoom?>.broadcast();
  final _bufferBarrierController =
      StreamController<BufferBarrierState>.broadcast();
  final _messageController =
      StreamController<ListenTogetherMessage>.broadcast();
  final _suggestionController =
      StreamController<TrackSuggestion>.broadcast();

  // Public streams
  Stream<SyncConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<SyncRole> get roleStream => _roleController.stream;
  Stream<ListenTogetherRoom?> get roomStream => _roomController.stream;
  Stream<BufferBarrierState> get bufferBarrierStream =>
      _bufferBarrierController.stream;
  Stream<ListenTogetherMessage> get messageStream => _messageController.stream;
  Stream<TrackSuggestion> get suggestionStream => _suggestionController.stream;

  // Public getters
  SyncConnectionState get connectionState => _connectionState;
  SyncRole get role => _role;
  ListenTogetherRoom? get currentRoom => _currentRoom;
  BufferBarrierState get bufferBarrierState => _bufferBarrierState;
  String? get userId => _userId;
  String? get currentRoomCode => _currentRoom?.roomCode;
  bool get isInRoom => _currentRoom != null;
  bool get isHost => _role == SyncRole.host;
  bool get isGuest => _role == SyncRole.guest;
  int? get serverTimeNow => serverClock.now();
  double? get clockSkewMs => serverClock.clockSkewMs;
  String? get bufferingTrackId => _bufferingTrackId;
  Set<String> get readyUsers => Set.unmodifiable(_readyUsers);

  void _setConnectionState(SyncConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void _setRole(SyncRole role) {
    if (_role == role) return;
    _role = role;
    _roleController.add(role);
  }

  void _setRoom(ListenTogetherRoom? room) {
    _currentRoom = room;
    _roomController.add(room);
  }

  void _setBufferBarrierState(BufferBarrierState state) {
    if (_bufferBarrierState == state) return;
    _bufferBarrierState = state;
    _bufferBarrierController.add(state);
  }

  /// Connects to the Listen Together server WebSocket.
  Future<void> connect({
    String url = 'wss://metroserverx.meowery.eu/ws',
    ListenTogetherSocketConnector? connector,
  }) async {
    if (_connectionState == SyncConnectionState.connected ||
        _connectionState == SyncConnectionState.connecting) {
      return;
    }

    _serverUrl = url;
    _socketConnector = connector ?? _defaultConnector;
    _setConnectionState(SyncConnectionState.connecting);
    serverClock.reset();

    try {
      final socket = await _socketConnector!(url);
      _socket = socket;
      _reconnectAttempts = 0;
      _setConnectionState(SyncConnectionState.connected);

      _socketSubscription = socket.stream.listen(
        (data) {
          if (data is List<int>) {
            _handleBinaryMessage(Uint8List.fromList(data));
          } else if (data is String) {
            handleIncomingMessage(data);
          }
        },
        onError: (err) {
          _handleConnectionFailure(err.toString());
        },
        onDone: () {
          _handleDisconnect();
        },
      );

      _startPingScheduler();

      // If we had a prior session, attempt re-joining or reconnect
      if (_sessionToken != null && _currentRoom != null) {
        sendMessage(
          MessageTypes.reconnect,
          {'session_token': _sessionToken},
        );
      }
    } catch (e) {
      _handleConnectionFailure(e.toString());
    }
  }

  static Future<IListenTogetherSocket> _defaultConnector(String url) async {
    final ws = await WebSocket.connect(url);
    return IoListenTogetherSocket(ws);
  }

  /// Disconnects from WebSocket and clears transient room state.
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _barrierTimeoutTimer?.cancel();
    _scheduledPlaybackTimer?.cancel();

    serverClock.reset();
    _lastRevision = 0;
    _sessionToken = null;
    _bufferingTrackId = null;
    _readyUsers.clear();

    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close(1000, 'User disconnect');
    _socket = null;

    _setConnectionState(SyncConnectionState.disconnected);
    _setRole(SyncRole.none);
    _setRoom(null);
    _setBufferBarrierState(BufferBarrierState.idle);
  }

  void _handleConnectionFailure(String reason) {
    _setConnectionState(SyncConnectionState.error);
    _triggerAutoReconnect();
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    if (_sessionToken != null && _currentRoom != null) {
      _triggerAutoReconnect();
    } else {
      _setConnectionState(SyncConnectionState.disconnected);
    }
  }

  void _triggerAutoReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      _setConnectionState(SyncConnectionState.disconnected);
      return;
    }

    _setConnectionState(SyncConnectionState.reconnecting);
    final delayMs = (1000 * math.pow(2, _reconnectAttempts)).toInt().clamp(1000, 30000);
    _reconnectAttempts++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_serverUrl != null) {
        connect(url: _serverUrl!, connector: _socketConnector);
      }
    });
  }

  void _startPingScheduler() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(milliseconds: pingIntervalMs), (_) {
      sendPing();
    });
    // Send immediate ping upon socket establishment
    sendPing();
  }

  /// Dispatches ping with local timestamp for RTT and clock skew estimation.
  void sendPing() {
    if (_connectionState != SyncConnectionState.connected) return;
    _pingSequence++;
    final payload = PingPayload(
      clientTime: DateTime.now().millisecondsSinceEpoch,
      sequence: _pingSequence,
    );
    sendMessage(MessageTypes.ping, payload.toJson());

    // Asynchronously report heartbeat to Softify server for live dashboard accuracy
    if (_currentRoom != null && _pingSequence % 3 == 0) {
      _postRoomTelemetry('/api/rooms/heartbeat', {
        'roomCode': _currentRoom!.roomCode,
        'activeUsers': _currentRoom!.users.map((u) => u.userId).toList(),
        'positionMs': _currentRoom!.positionMs,
      });
    }
  }

  /// Sends a ListenTogetherMessage envelope (binary Protobuf for Io sockets, JSON for mocks).
  void sendMessage(String type, Map<String, dynamic> payload) {
    if (_socket == null) return;
    if (_socket is IoListenTogetherSocket) {
      try {
        List<int> bytes;
        switch (type) {
          case MessageTypes.createRoom:
            bytes = ListenTogetherProtoCodec.encodeCreateRoom(payload['username']?.toString() ?? 'User');
            break;
          case MessageTypes.joinRoom:
            bytes = ListenTogetherProtoCodec.encodeJoinRoom(
                payload['room_code']?.toString() ?? '', payload['username']?.toString() ?? 'User');
            break;
          case MessageTypes.leaveRoom:
            bytes = ListenTogetherProtoCodec.encodeLeaveRoom();
            break;
          case MessageTypes.approveJoin:
            bytes = ListenTogetherProtoCodec.encodeApproveJoin(payload['user_id']?.toString() ?? '');
            break;
          case MessageTypes.rejectJoin:
            bytes = ListenTogetherProtoCodec.encodeRejectJoin(
                payload['user_id']?.toString() ?? '', payload['reason']?.toString() ?? '');
            break;
          case MessageTypes.ping:
            bytes = ListenTogetherProtoCodec.encodePing(payload['client_time'] ?? 0, payload['sequence'] ?? 0);
            break;
          case MessageTypes.bufferReady:
            bytes = ListenTogetherProtoCodec.encodeBufferReady(payload['track_id']?.toString() ?? '');
            break;
          case MessageTypes.reconnect:
            bytes = ListenTogetherProtoCodec.encodeReconnect(payload['session_token']?.toString() ?? '');
            break;
          case MessageTypes.playbackAction:
            bytes = ListenTogetherProtoCodec.encodePlaybackAction(
              action: payload['action']?.toString() ?? 'play',
              trackId: payload['track_id']?.toString(),
              position: payload['position'] as int?,
              trackInfo: payload['track_info'] is Map<String, dynamic>
                  ? payload['track_info'] as Map<String, dynamic>
                  : null,
              serverTime: payload['server_time'] as int?,
              revision: payload['revision'] as int?,
            );
            break;
          default:
            final message = ListenTogetherMessage(type: type, payload: payload);
            _socket!.add(message.toJsonString());
            return;
        }
        _socket!.add(bytes);
        return;
      } catch (_) {}
    }

    final message = ListenTogetherMessage(type: type, payload: payload);
    _socket!.add(message.toJsonString());
  }

  // --- Room Operations ---

  /// Request room creation as host and await confirmation.
  Future<ListenTogetherRoom> createRoom({required String username}) async {
    _localUsername = username;
    if (_connectionState != SyncConnectionState.connected) {
      await connect();
    }
    _setRole(SyncRole.host);

    final completer = Completer<ListenTogetherRoom>();
    StreamSubscription? sub;
    Timer? timeoutTimer;

    sub = roomStream.listen((room) {
      if (room != null && !completer.isCompleted) {
        timeoutTimer?.cancel();
        completer.complete(room);
        sub?.cancel();
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        sub?.cancel();
        if (_currentRoom != null) {
          completer.complete(_currentRoom!);
        } else {
          completer.completeError(TimeoutException('Room creation timed out'));
        }
      }
    });

    sendMessage(MessageTypes.createRoom, {'username': username});
    return completer.future;
  }

  /// Request to join an existing room by room code and await approval.
  Future<ListenTogetherRoom> joinRoom({
    required String roomCode,
    required String username,
  }) async {
    _localUsername = username;
    if (_connectionState != SyncConnectionState.connected) {
      await connect();
    }
    _setRole(SyncRole.guest);

    final completer = Completer<ListenTogetherRoom>();
    StreamSubscription? roomSub;
    StreamSubscription? msgSub;
    Timer? timeoutTimer;

    roomSub = roomStream.listen((room) {
      if (room != null && !completer.isCompleted) {
        timeoutTimer?.cancel();
        completer.complete(room);
        roomSub?.cancel();
        msgSub?.cancel();
      }
    });

    msgSub = messageStream.listen((msg) {
      if ((msg.type == MessageTypes.error || msg.type == 'join_rejected') &&
          !completer.isCompleted) {
        timeoutTimer?.cancel();
        final err = msg.payload['message'] ?? msg.payload['code'] ?? msg.payload['reason'] ?? 'Failed to join room';
        completer.completeError(Exception(err));
        roomSub?.cancel();
        msgSub?.cancel();
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (!completer.isCompleted) {
        roomSub?.cancel();
        msgSub?.cancel();
        if (_currentRoom != null) {
          completer.complete(_currentRoom!);
        } else {
          completer.completeError(TimeoutException('Join room request timed out'));
        }
      }
    });

    sendMessage(
      MessageTypes.joinRoom,
      {'room_code': roomCode.toUpperCase(), 'username': username},
    );
    return completer.future;
  }

  /// Voluntarily leaves the current room.
  Future<void> leaveRoom() async {
    if (isInRoom) {
      final code = _currentRoom?.roomCode;
      if (code != null && _userId != null) {
        _postRoomTelemetry('/api/rooms/leave', {
          'roomCode': code,
          'userId': _userId,
        });
        if (isHost) {
          _postRoomTelemetry('/api/rooms/close', {
            'roomCode': code,
            'reason': 'host_closed',
          });
        }
      }
      sendMessage(MessageTypes.leaveRoom, {});
    }
    _setRoom(null);
    _setRole(SyncRole.none);
    _setBufferBarrierState(BufferBarrierState.idle);
  }

  // --- Buffer Barrier Synchronization Engine ---

  /// Triggers a buffer barrier synchronization cycle.
  /// Called when a track changes or a new audio stream must be buffered across peers.
  void triggerBufferBarrier(
    String trackId, {
    List<String>? waitingFor,
    int leadTimeMs = defaultLeadTimeMs,
  }) {
    _barrierTimeoutTimer?.cancel();
    _scheduledPlaybackTimer?.cancel();
    _bufferingTrackId = trackId;
    _readyUsers.clear();

    _setBufferBarrierState(BufferBarrierState.buffering);

    // Audio pre-buffering initiation
    final currentTrack = _currentRoom?.currentTrack;
    if (currentTrack != null) {
      automixService?.markPrebuffering(currentTrack.toTrack());
    }
    audioHandler?.pause();

    if (isHost) {
      final peers = waitingFor ??
          _currentRoom?.users
              .where((u) => u.isConnected)
              .map((u) => u.userId)
              .toList() ??
          [];

      final waitPayload = BufferWaitPayload(
        trackId: trackId,
        targetTimestamp: serverTimeNow ?? DateTime.now().millisecondsSinceEpoch,
        waitingFor: peers,
      );
      sendMessage(MessageTypes.bufferWait, waitPayload.toJson());

      // Arm barrier safety timeout: don't let a slow peer block the room forever
      _barrierTimeoutTimer =
          Timer(const Duration(milliseconds: defaultBarrierTimeoutMs), () {
        _releaseBufferBarrier(leadTimeMs: leadTimeMs);
      });
    }

    // Local client starts buffering immediately
    _simulateLocalPrebuffer(trackId);
  }

  void _simulateLocalPrebuffer(String trackId) {
    // In production, YouTubeExplode stream audio chunks or MediaKit decoders fill buffer
    // Once decoded/ready:
    scheduleMicrotask(() {
      if (_bufferingTrackId == trackId) {
        onLocalBufferReady(trackId);
      }
    });
  }

  /// Signals that the local client has finished pre-buffering the audio stream.
  void onLocalBufferReady(String trackId) {
    if (_bufferingTrackId != trackId) return;

    _setBufferBarrierState(BufferBarrierState.ready);
    automixService?.markPrebufferReady();

    final readyPayload = BufferReadyPayload(
      trackId: trackId,
      userId: _userId ?? '',
      readyEpochMs: serverTimeNow ?? DateTime.now().millisecondsSinceEpoch,
    );

    sendMessage(MessageTypes.bufferReady, readyPayload.toJson());

    if (isHost) {
      if (_userId != null) _readyUsers.add(_userId!);
      _checkBarrierAllReady();
    }
  }

  void _checkBarrierAllReady() {
    if (!isHost || _currentRoom == null) return;

    final connectedUsers = _currentRoom!.users
        .where((u) => u.isConnected)
        .map((u) => u.userId)
        .toSet();

    if (_readyUsers.containsAll(connectedUsers)) {
      _barrierTimeoutTimer?.cancel();
      _releaseBufferBarrier();
    }
  }

  void _releaseBufferBarrier({int leadTimeMs = defaultLeadTimeMs}) {
    if (!isHost) return;
    final trackId = _bufferingTrackId;
    if (trackId == null) return;

    final startAt = (serverTimeNow ?? DateTime.now().millisecondsSinceEpoch) +
        leadTimeMs;

    final completePayload = BufferCompletePayload(
      trackId: trackId,
      startPlaybackAtEpochMs: startAt,
      positionMs: 0,
    );

    sendMessage(MessageTypes.bufferComplete, completePayload.toJson());
    _executeScheduledPlayback(completePayload);
  }

  void _executeScheduledPlayback(BufferCompletePayload payload) {
    _barrierTimeoutTimer?.cancel();
    _setBufferBarrierState(BufferBarrierState.playing);

    final targetServerTime = payload.startPlaybackAtEpochMs;
    final currentServerTime =
        serverTimeNow ?? DateTime.now().millisecondsSinceEpoch;
    final delayMs = targetServerTime - currentServerTime;

    void startAudio() {
      audioHandler?.seek(Duration(milliseconds: payload.positionMs));
      audioHandler?.play();
      _updateRoomPlayingState(true, payload.positionMs);
    }

    if (delayMs > 0) {
      _scheduledPlaybackTimer = Timer(Duration(milliseconds: delayMs), startAudio);
    } else {
      startAudio();
    }
  }

  void _updateRoomPlayingState(bool isPlaying, int positionMs) {
    if (_currentRoom != null) {
      final updated = _currentRoom!.copyWith(
        isPlaying: isPlaying,
        positionMs: positionMs,
        lastUpdateEpochMs: serverTimeNow ?? DateTime.now().millisecondsSinceEpoch,
      );
      _setRoom(updated);
    }
  }

  // --- Drift Detection & Micro-Correction ---

  /// Computes drift against server time and applies correction (micro-nudge or hard seek).
  DriftAction checkDriftAndResync(int currentLocalPositionMs) {
    if (_currentRoom == null || !_currentRoom!.isPlaying) {
      return DriftAction.none;
    }

    final targetPos = serverClock.positionAt(
      position: _currentRoom!.positionMs,
      effectiveAtServerTime: _currentRoom!.lastUpdateEpochMs,
      isPlaying: _currentRoom!.isPlaying,
    );

    final drift = targetPos - currentLocalPositionMs;
    final absDrift = drift.abs();

    if (absDrift <= softSyncThresholdMs) {
      // In sync: restore normal playback speed
      audioHandler?.setSpeed(1.0);
      return DriftAction.none;
    } else if (absDrift <= hardSyncThresholdMs) {
      // Moderate drift: micro-nudge speed +-2%
      final adjustedSpeed =
          drift > 0 ? 1.0 + microNudgeSpeedAdjustment : 1.0 - microNudgeSpeedAdjustment;
      audioHandler?.setSpeed(adjustedSpeed);
      return DriftAction.microNudge;
    } else {
      // Hard drift: seek directly to target position
      audioHandler?.setSpeed(1.0);
      audioHandler?.seek(Duration(milliseconds: targetPos));
      return DriftAction.hardSeek;
    }
  }

  // --- Playback Action Broadcasting ---

  void broadcastPlay({int? positionMs}) {
    final now = serverTimeNow ?? DateTime.now().millisecondsSinceEpoch;
    _lastRevision++;
    final payload = PlaybackActionPayload(
      action: PlaybackActions.play,
      positionMs: positionMs ?? _currentRoom?.positionMs ?? 0,
      serverTime: now,
      revision: _lastRevision,
    );
    sendMessage(MessageTypes.playbackAction, payload.toJson());
    _updateRoomPlayingState(true, payload.positionMs ?? 0);
  }

  void broadcastPause({int? positionMs}) {
    final now = serverTimeNow ?? DateTime.now().millisecondsSinceEpoch;
    _lastRevision++;
    final payload = PlaybackActionPayload(
      action: PlaybackActions.pause,
      positionMs: positionMs ?? _currentRoom?.positionMs ?? 0,
      serverTime: now,
      revision: _lastRevision,
    );
    sendMessage(MessageTypes.playbackAction, payload.toJson());
    _updateRoomPlayingState(false, payload.positionMs ?? 0);
  }

  void broadcastSeek(int positionMs) {
    final now = serverTimeNow ?? DateTime.now().millisecondsSinceEpoch;
    _lastRevision++;
    final payload = PlaybackActionPayload(
      action: PlaybackActions.seek,
      positionMs: positionMs,
      serverTime: now,
      revision: _lastRevision,
    );
    sendMessage(MessageTypes.playbackAction, payload.toJson());
    _updateRoomPlayingState(_currentRoom?.isPlaying ?? false, positionMs);
  }

  void broadcastTrackChange(SyncTrackInfo track, {int positionMs = 0}) {
    final now = serverTimeNow ?? DateTime.now().millisecondsSinceEpoch;
    _lastRevision++;
    final payload = PlaybackActionPayload(
      action: PlaybackActions.changeTrack,
      trackId: track.id,
      trackInfo: track,
      positionMs: positionMs,
      serverTime: now,
      revision: _lastRevision,
    );
    sendMessage(MessageTypes.playbackAction, payload.toJson());

    if (_currentRoom != null) {
      _setRoom(_currentRoom!.copyWith(
        currentTrack: track,
        positionMs: positionMs,
        lastUpdateEpochMs: now,
        revision: _lastRevision,
      ));

      _postRoomTelemetry('/api/rooms/song-played', {
        'roomCode': _currentRoom!.roomCode,
        'track': {
          'id': track.id,
          'title': track.title,
          'artist': track.artist,
          'album': track.album,
          'durationMs': track.durationMs,
          'thumbnailUrl': track.thumbnailUrl,
        },
      });
    }

    triggerBufferBarrier(track.id);
  }

  void suggestTrack(SyncTrackInfo track, {String? reason}) {
    final payload = {
      'track_info': track.toJson(),
      if (reason != null) 'reason': reason,
    };
    sendMessage(MessageTypes.suggestTrack, payload);
  }

  void approveSuggestion(String suggestionId) {
    sendMessage(
      MessageTypes.approveSuggestion,
      {'suggestion_id': suggestionId},
    );
  }

  void rejectSuggestion(String suggestionId, {String? reason}) {
    sendMessage(
      MessageTypes.rejectSuggestion,
      {'suggestion_id': suggestionId, if (reason != null) 'reason': reason},
    );
  }

  void approveJoin(String userId) {
    sendMessage(MessageTypes.approveJoin, {'user_id': userId});
  }

  void rejectJoin(String userId, {String? reason}) {
    sendMessage(
      MessageTypes.rejectJoin,
      {'user_id': userId, if (reason != null) 'reason': reason},
    );
  }

  void kickUser(String userId, {String? reason}) {
    sendMessage(
      MessageTypes.kickUser,
      {'user_id': userId, if (reason != null) 'reason': reason},
    );
  }

  // --- Wire Message Dispatcher ---

  void _handleBinaryMessage(Uint8List data) {
    final decoded = ListenTogetherProtoCodec.decodeEnvelope(data);
    if (decoded == null) return;
    final (type, payloadBytes) = decoded;

    Map<String, dynamic> payload = {};
    switch (type) {
      case 'error':
        payload = ListenTogetherProtoCodec.decodeError(payloadBytes);
        break;
      case 'join_request':
        payload = ListenTogetherProtoCodec.decodeJoinRequest(payloadBytes);
        break;
      case 'join_rejected':
        payload = ListenTogetherProtoCodec.decodeJoinRejected(payloadBytes);
        break;
      case 'room_created':
        payload = ListenTogetherProtoCodec.decodeRoomCreated(payloadBytes);
        break;
      case 'join_approved':
        payload = ListenTogetherProtoCodec.decodeJoinApproved(payloadBytes);
        break;
      case 'user_joined':
        payload = ListenTogetherProtoCodec.decodeUserJoined(payloadBytes);
        break;
      case 'user_left':
        payload = ListenTogetherProtoCodec.decodeUserLeft(payloadBytes);
        break;
      case 'pong':
        payload = ListenTogetherProtoCodec.decodePong(payloadBytes);
        break;
      case 'sync_playback':
        payload = ListenTogetherProtoCodec.decodePlaybackAction(payloadBytes);
        break;
      default:
        break;
    }

    final msg = ListenTogetherMessage(type: type, payload: payload);
    _processMessage(msg);
  }

  /// Handles incoming JSON envelope and updates synchronization models.
  void handleIncomingMessage(String rawJson) {
    ListenTogetherMessage msg;
    try {
      msg = ListenTogetherMessage.parse(rawJson);
    } catch (_) {
      return;
    }
    _processMessage(msg);
  }

  void _processMessage(ListenTogetherMessage msg) {
    _messageController.add(msg);

    switch (msg.type) {
      case MessageTypes.roomCreated:
        _userId = msg.payload['user_id']?.toString() ??
            msg.payload['userId']?.toString();
        _sessionToken = msg.payload['session_token']?.toString();
        final roomCode = (msg.payload['room_code'] ??
                msg.payload['roomCode'] ??
                '')
            .toString();
        _setRole(SyncRole.host);
        if (msg.payload.containsKey('is_playing') ||
            msg.payload.containsKey('isPlaying') ||
            msg.payload.containsKey('state')) {
          final roomJson = msg.payload['state'] is Map<String, dynamic>
              ? msg.payload['state'] as Map<String, dynamic>
              : msg.payload;
          _setRoom(ListenTogetherRoom.fromJson(roomJson));
        } else {
          _setRoom(ListenTogetherRoom(
            roomCode: roomCode,
            hostId: _userId ?? '',
            users: [
              ListenTogetherUser(
                userId: _userId ?? '',
                username: _localUsername ?? 'Host',
                isHost: true,
                joinedAt: DateTime.now().millisecondsSinceEpoch,
              )
            ],
          ));
        }
        _postRoomTelemetry('/api/rooms/create', {
          'roomCode': roomCode.toUpperCase(),
          'hostUserId': _userId,
          'hostUsername': _localUsername ?? 'Host',
          'hostDeviceModel': Platform.isAndroid
              ? 'Android Device'
              : (Platform.isLinux ? 'Linux Desktop' : Platform.operatingSystem),
          'hostPlatform': Platform.operatingSystem,
          'isPublic': true,
        });
        break;

      case MessageTypes.joinRequest:
        final guestId = msg.payload['user_id']?.toString();
        if (isHost && guestId != null && guestId.isNotEmpty) {
          approveJoin(guestId);
        }
        break;

      case MessageTypes.joinApproved:
        _userId = msg.payload['user_id']?.toString();
        _sessionToken = msg.payload['session_token']?.toString();
        final roomCode = (msg.payload['room_code'] ?? '').toString();
        if (msg.payload['state'] != null) {
          _setRoom(ListenTogetherRoom.fromJson(
              msg.payload['state'] as Map<String, dynamic>));
        } else {
          _setRoom(ListenTogetherRoom(
            roomCode: roomCode,
            hostId: '',
            users: [
              ListenTogetherUser(
                userId: _userId ?? '',
                username: _localUsername ?? 'Guest',
                isHost: false,
                joinedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            ],
          ));
        }
        _setRole(SyncRole.guest);
        _postRoomTelemetry('/api/rooms/join', {
          'roomCode': roomCode.toUpperCase(),
          'userId': _userId,
          'username': _localUsername ?? 'Guest',
          'deviceModel': Platform.isAndroid
              ? 'Android Device'
              : (Platform.isLinux ? 'Linux Desktop' : Platform.operatingSystem),
          'platform': Platform.operatingSystem,
        });
        break;

      case MessageTypes.userJoined:
        if (_currentRoom != null) {
          final user = ListenTogetherUser.fromJson(msg.payload);
          final updated = List<ListenTogetherUser>.from(_currentRoom!.users)
            ..removeWhere((u) => u.userId == user.userId)
            ..add(user);
          _setRoom(_currentRoom!.copyWith(users: updated));
          _postRoomTelemetry('/api/rooms/join', {
            'roomCode': _currentRoom!.roomCode,
            'userId': user.userId,
            'username': user.username,
            'deviceModel': 'Connected Member',
            'platform': 'unknown',
          });
        }
        break;

      case MessageTypes.userLeft:
        if (_currentRoom != null) {
          final leftId = (msg.payload['user_id'] ?? '').toString();
          final updated = _currentRoom!.users
              .where((u) => u.userId != leftId)
              .toList();
          _setRoom(_currentRoom!.copyWith(users: updated));
          _postRoomTelemetry('/api/rooms/leave', {
            'roomCode': _currentRoom!.roomCode,
            'userId': leftId,
          });
        }
        break;

      case MessageTypes.pong:
        final pong = PongPayload.fromJson(msg.payload);
        final firstSample = serverClock.recordPong(
          clientTime: pong.clientTime,
          serverReceiveTime: pong.serverReceiveTime,
          serverSendTime: pong.serverSendTime,
        );
        if (firstSample && isGuest) {
          sendMessage(MessageTypes.requestSync, {});
        }
        break;

      case MessageTypes.syncPlayback:
        final action = PlaybackActionPayload.fromJson(msg.payload);
        _handlePlaybackSync(action);
        break;

      case MessageTypes.bufferWait:
        final waitPayload = BufferWaitPayload.fromJson(msg.payload);
        _bufferingTrackId = waitPayload.trackId;
        _setBufferBarrierState(BufferBarrierState.buffering);
        audioHandler?.pause();
        _simulateLocalPrebuffer(waitPayload.trackId);
        break;

      case MessageTypes.bufferReady:
        final readyPayload = BufferReadyPayload.fromJson(msg.payload);
        if (readyPayload.userId.isNotEmpty) {
          _readyUsers.add(readyPayload.userId);
        }
        if (isHost) {
          _checkBarrierAllReady();
        }
        break;

      case MessageTypes.bufferComplete:
        final completePayload = BufferCompletePayload.fromJson(msg.payload);
        _bufferingTrackId = null;
        _executeScheduledPlayback(completePayload);
        break;

      case MessageTypes.syncState:
        final syncState = PlaybackSyncState.fromJson(msg.payload);
        if (syncState.revision >= _lastRevision) {
          _lastRevision = syncState.revision;
          if (_currentRoom != null) {
            _setRoom(_currentRoom!.copyWith(
              currentTrack: syncState.currentTrack,
              isPlaying: syncState.isPlaying,
              positionMs: syncState.positionMs,
              lastUpdateEpochMs: syncState.lastUpdateEpochMs,
              queue: syncState.queue ?? _currentRoom!.queue,
              volume: syncState.volume,
              revision: syncState.revision,
            ));
          }
          if (isGuest) {
            if (syncState.isPlaying) {
              audioHandler?.play();
            } else {
              audioHandler?.pause();
            }
          }
        }
        break;

      case MessageTypes.suggestionReceived:
        final suggestion = TrackSuggestion.fromJson(msg.payload);
        _suggestionController.add(suggestion);
        break;

      case MessageTypes.kicked:
        leaveRoom();
        break;

      case MessageTypes.hostChanged:
        final newHostId = (msg.payload['new_host_id'] ?? '').toString();
        if (_currentRoom != null) {
          final updatedUsers = _currentRoom!.users
              .map((u) => u.copyWith(isHost: u.userId == newHostId))
              .toList();
          _setRoom(_currentRoom!.copyWith(
            hostId: newHostId,
            users: updatedUsers,
          ));
        }
        if (_userId == newHostId) {
          _setRole(SyncRole.host);
        } else {
          _setRole(SyncRole.guest);
        }
        break;
    }
  }

  void _handlePlaybackSync(PlaybackActionPayload action) {
    if (action.revision < _lastRevision && action.revision != 0) return;
    _lastRevision = action.revision;

    switch (action.action) {
      case PlaybackActions.play:
        audioHandler?.play();
        _updateRoomPlayingState(true, action.positionMs ?? 0);
        break;
      case PlaybackActions.pause:
        audioHandler?.pause();
        _updateRoomPlayingState(false, action.positionMs ?? 0);
        break;
      case PlaybackActions.seek:
        final pos = action.positionMs ?? 0;
        audioHandler?.seek(Duration(milliseconds: pos));
        _updateRoomPlayingState(_currentRoom?.isPlaying ?? false, pos);
        break;
      case PlaybackActions.changeTrack:
        if (action.trackInfo != null) {
          _bufferingTrackId = action.trackInfo!.id;
          _setBufferBarrierState(BufferBarrierState.buffering);
          audioHandler?.pause();
          if (_currentRoom != null) {
            _setRoom(_currentRoom!.copyWith(
              currentTrack: action.trackInfo,
              positionMs: action.positionMs ?? 0,
              lastUpdateEpochMs: action.serverTime ?? 0,
            ));

            _postRoomTelemetry('/api/rooms/song-played', {
              'roomCode': _currentRoom!.roomCode,
              'track': {
                'id': action.trackInfo!.id,
                'title': action.trackInfo!.title,
                'artist': action.trackInfo!.artist,
                'album': action.trackInfo!.album,
                'durationMs': action.trackInfo!.durationMs,
                'thumbnailUrl': action.trackInfo!.thumbnailUrl,
              },
            });
          }
          _simulateLocalPrebuffer(action.trackInfo!.id);
        }
        break;
      case PlaybackActions.syncQueue:
        if (_currentRoom != null && action.queue != null) {
          _setRoom(_currentRoom!.copyWith(queue: action.queue!));
        }
        break;
    }
  }
}
