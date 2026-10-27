import 'dart:convert';
import '../../domain/entities/track.dart';

/// Protocol message types exchanged between client and server.
/// Matched identically with Metrolist Listen Together protocol specification.
class MessageTypes {
  // Client -> Server
  static const String createRoom = 'create_room';
  static const String joinRoom = 'join_room';
  static const String leaveRoom = 'leave_room';
  static const String approveJoin = 'approve_join';
  static const String rejectJoin = 'reject_join';
  static const String playbackAction = 'playback_action';
  static const String bufferReady = 'buffer_ready';
  static const String kickUser = 'kick_user';
  static const String transferHost = 'transfer_host';
  static const String ping = 'ping';
  static const String chat = 'chat';
  static const String requestSync = 'request_sync';
  static const String reconnect = 'reconnect';
  static const String suggestTrack = 'suggest_track';
  static const String approveSuggestion = 'approve_suggestion';
  static const String rejectSuggestion = 'reject_suggestion';

  // Server -> Client
  static const String roomCreated = 'room_created';
  static const String joinRequest = 'join_request';
  static const String joinApproved = 'join_approved';
  static const String joinRejected = 'join_rejected';
  static const String userJoined = 'user_joined';
  static const String userLeft = 'user_left';
  static const String syncPlayback = 'sync_playback';
  static const String bufferWait = 'buffer_wait';
  static const String bufferComplete = 'buffer_complete';
  static const String error = 'error';
  static const String pong = 'pong';
  static const String hostChanged = 'host_changed';
  static const String kicked = 'kicked';
  static const String syncState = 'sync_state';
  static const String reconnected = 'reconnected';
  static const String userReconnected = 'user_reconnected';
  static const String userDisconnected = 'user_disconnected';
  static const String suggestionReceived = 'suggestion_received';
  static const String suggestionApproved = 'suggestion_approved';
  static const String suggestionRejected = 'suggestion_rejected';
}

/// Collaborative playback actions controlled by the host or approved guests.
class PlaybackActions {
  static const String play = 'play';
  static const String pause = 'pause';
  static const String seek = 'seek';
  static const String skipNext = 'skip_next';
  static const String skipPrev = 'skip_prev';
  static const String changeTrack = 'change_track';
  static const String queueAdd = 'queue_add';
  static const String queueRemove = 'queue_remove';
  static const String queueClear = 'queue_clear';
  static const String syncQueue = 'sync_queue';
  static const String setVolume = 'set_volume';
}

/// User role in a Listen Together collaborative room.
enum SyncRole {
  host,
  guest,
  none,
}

/// Barrier synchronization state for synchronized audio stream loading.
enum BufferBarrierState {
  idle,
  buffering,
  ready,
  playing,
}

/// Socket connection status.
enum SyncConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Information about a connected participant in a Listen Together room.
class ListenTogetherUser {
  final String userId;
  final String username;
  final bool isHost;
  final bool isConnected;
  final String? avatarUrl;
  final int? joinedAt;

  const ListenTogetherUser({
    required this.userId,
    required this.username,
    this.isHost = false,
    this.isConnected = true,
    this.avatarUrl,
    this.joinedAt,
  });

  ListenTogetherUser copyWith({
    String? userId,
    String? username,
    bool? isHost,
    bool? isConnected,
    String? avatarUrl,
    int? joinedAt,
  }) {
    return ListenTogetherUser(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      isHost: isHost ?? this.isHost,
      isConnected: isConnected ?? this.isConnected,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'is_host': isHost,
        'is_connected': isConnected,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (joinedAt != null) 'joined_at': joinedAt,
      };

  factory ListenTogetherUser.fromJson(Map<String, dynamic> json) {
    return ListenTogetherUser(
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      username: (json['username'] ?? 'Anonymous').toString(),
      isHost: json['is_host'] == true || json['isHost'] == true,
      isConnected: json['is_connected'] != false && json['isConnected'] != false,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      joinedAt: (json['joined_at'] ?? json['joinedAt']) as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListenTogetherUser &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          username == other.username &&
          isHost == other.isHost &&
          isConnected == other.isConnected;

  @override
  int get hashCode =>
      userId.hashCode ^ username.hashCode ^ isHost.hashCode ^ isConnected.hashCode;
}

/// Serialized track metadata exchanged across the wire.
class SyncTrackInfo {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String thumbnailUrl;
  final String? suggestedBy;

  const SyncTrackInfo({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    required this.durationMs,
    this.thumbnailUrl = '',
    this.suggestedBy,
  });

  SyncTrackInfo copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? thumbnailUrl,
    String? suggestedBy,
  }) {
    return SyncTrackInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      suggestedBy: suggestedBy ?? this.suggestedBy,
    );
  }

  Track toTrack() => Track(
        id: id,
        sourceId: id,
        title: title,
        artist: artist,
        album: album.isNotEmpty ? album : null,
        duration: Duration(milliseconds: durationMs),
        coverUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : null,
      );

  static SyncTrackInfo fromTrack(Track track, {String? suggestedBy}) =>
      SyncTrackInfo(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album ?? '',
        durationMs: track.duration.inMilliseconds,
        thumbnailUrl: track.coverUrl ?? '',
        suggestedBy: suggestedBy,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'duration': durationMs,
        'thumbnail': thumbnailUrl,
        if (suggestedBy != null) 'suggested_by': suggestedBy,
      };

  factory SyncTrackInfo.fromJson(Map<String, dynamic> json) {
    return SyncTrackInfo(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      artist: (json['artist'] ?? '').toString(),
      album: (json['album'] ?? '').toString(),
      durationMs: ((json['duration'] ?? json['durationMs']) as num?)?.toInt() ?? 0,
      thumbnailUrl: (json['thumbnail'] ?? json['thumbnailUrl'] ?? '').toString(),
      suggestedBy: (json['suggested_by'] ?? json['suggestedBy']) as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncTrackInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          artist == other.artist &&
          durationMs == other.durationMs;

  @override
  int get hashCode =>
      id.hashCode ^ title.hashCode ^ artist.hashCode ^ durationMs.hashCode;
}

/// Full snapshot of a Listen Together room state.
class ListenTogetherRoom {
  final String roomCode;
  final String hostId;
  final List<ListenTogetherUser> users;
  final SyncTrackInfo? currentTrack;
  final bool isPlaying;
  final int positionMs;
  final int lastUpdateEpochMs;
  final double volume;
  final List<SyncTrackInfo> queue;
  final int revision;

  const ListenTogetherRoom({
    required this.roomCode,
    required this.hostId,
    this.users = const [],
    this.currentTrack,
    this.isPlaying = false,
    this.positionMs = 0,
    this.lastUpdateEpochMs = 0,
    this.volume = 1.0,
    this.queue = const [],
    this.revision = 0,
  });

  ListenTogetherRoom copyWith({
    String? roomCode,
    String? hostId,
    List<ListenTogetherUser>? users,
    SyncTrackInfo? currentTrack,
    bool? isPlaying,
    int? positionMs,
    int? lastUpdateEpochMs,
    double? volume,
    List<SyncTrackInfo>? queue,
    int? revision,
  }) {
    return ListenTogetherRoom(
      roomCode: roomCode ?? this.roomCode,
      hostId: hostId ?? this.hostId,
      users: users ?? this.users,
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      lastUpdateEpochMs: lastUpdateEpochMs ?? this.lastUpdateEpochMs,
      volume: volume ?? this.volume,
      queue: queue ?? this.queue,
      revision: revision ?? this.revision,
    );
  }

  Map<String, dynamic> toJson() => {
        'room_code': roomCode,
        'host_id': hostId,
        'users': users.map((u) => u.toJson()).toList(),
        if (currentTrack != null) 'current_track': currentTrack!.toJson(),
        'is_playing': isPlaying,
        'position': positionMs,
        'last_update': lastUpdateEpochMs,
        'volume': volume,
        'queue': queue.map((t) => t.toJson()).toList(),
        'revision': revision,
      };

  factory ListenTogetherRoom.fromJson(Map<String, dynamic> json) {
    return ListenTogetherRoom(
      roomCode: (json['room_code'] ?? json['roomCode'] ?? '').toString(),
      hostId: (json['host_id'] ?? json['hostId'] ?? '').toString(),
      users: (json['users'] as List<dynamic>?)
              ?.map((e) => ListenTogetherUser.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      currentTrack: json['current_track'] != null
          ? SyncTrackInfo.fromJson(json['current_track'] as Map<String, dynamic>)
          : (json['currentTrack'] != null
              ? SyncTrackInfo.fromJson(json['currentTrack'] as Map<String, dynamic>)
              : null),
      isPlaying: json['is_playing'] == true || json['isPlaying'] == true,
      positionMs: ((json['position'] ?? json['positionMs']) as num?)?.toInt() ?? 0,
      lastUpdateEpochMs:
          ((json['last_update'] ?? json['lastUpdateEpochMs']) as num?)?.toInt() ?? 0,
      volume: ((json['volume']) as num?)?.toDouble() ?? 1.0,
      queue: (json['queue'] as List<dynamic>?)
              ?.map((e) => SyncTrackInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      revision: ((json['revision']) as num?)?.toInt() ?? 0,
    );
  }
}

/// Compact playback synchronization payload for heartbeat and incremental state updates.
class PlaybackSyncState {
  final SyncTrackInfo? currentTrack;
  final bool isPlaying;
  final int positionMs;
  final int lastUpdateEpochMs;
  final List<SyncTrackInfo>? queue;
  final double volume;
  final int revision;

  const PlaybackSyncState({
    this.currentTrack,
    required this.isPlaying,
    required this.positionMs,
    required this.lastUpdateEpochMs,
    this.queue,
    this.volume = 1.0,
    this.revision = 0,
  });

  Map<String, dynamic> toJson() => {
        if (currentTrack != null) 'current_track': currentTrack!.toJson(),
        'is_playing': isPlaying,
        'position': positionMs,
        'last_update': lastUpdateEpochMs,
        if (queue != null) 'queue': queue!.map((t) => t.toJson()).toList(),
        'volume': volume,
        'revision': revision,
      };

  factory PlaybackSyncState.fromJson(Map<String, dynamic> json) {
    return PlaybackSyncState(
      currentTrack: json['current_track'] != null
          ? SyncTrackInfo.fromJson(json['current_track'] as Map<String, dynamic>)
          : null,
      isPlaying: json['is_playing'] == true || json['isPlaying'] == true,
      positionMs: ((json['position'] ?? json['positionMs']) as num?)?.toInt() ?? 0,
      lastUpdateEpochMs:
          ((json['last_update'] ?? json['lastUpdateEpochMs']) as num?)?.toInt() ?? 0,
      queue: (json['queue'] as List<dynamic>?)
          ?.map((e) => SyncTrackInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      volume: ((json['volume']) as num?)?.toDouble() ?? 1.0,
      revision: ((json['revision']) as num?)?.toInt() ?? 0,
    );
  }
}

/// Track suggestion submitted by a guest for host evaluation.
class TrackSuggestion {
  final String suggestionId;
  final String fromUserId;
  final String fromUsername;
  final SyncTrackInfo track;
  final String? reason;
  final String status; // pending, approved, rejected

  const TrackSuggestion({
    required this.suggestionId,
    required this.fromUserId,
    required this.fromUsername,
    required this.track,
    this.reason,
    this.status = 'pending',
  });

  TrackSuggestion copyWith({
    String? suggestionId,
    String? fromUserId,
    String? fromUsername,
    SyncTrackInfo? track,
    String? reason,
    String? status,
  }) {
    return TrackSuggestion(
      suggestionId: suggestionId ?? this.suggestionId,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUsername: fromUsername ?? this.fromUsername,
      track: track ?? this.track,
      reason: reason ?? this.reason,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'suggestion_id': suggestionId,
        'from_user_id': fromUserId,
        'from_username': fromUsername,
        'track_info': track.toJson(),
        if (reason != null) 'reason': reason,
        'status': status,
      };

  factory TrackSuggestion.fromJson(Map<String, dynamic> json) {
    final trackJson = (json['track_info'] ?? json['track'] ?? <String, dynamic>{})
        as Map<String, dynamic>;
    return TrackSuggestion(
      suggestionId: (json['suggestion_id'] ?? json['suggestionId'] ?? '').toString(),
      fromUserId: (json['from_user_id'] ?? json['fromUserId'] ?? '').toString(),
      fromUsername: (json['from_username'] ?? json['fromUsername'] ?? '').toString(),
      track: SyncTrackInfo.fromJson(trackJson),
      reason: json['reason'] as String?,
      status: (json['status'] ?? 'pending').toString(),
    );
  }
}

/// Buffer Barrier Payload: issued when playback halts to pre-buffer the upcoming stream.
class BufferWaitPayload {
  final String trackId;
  final int targetTimestamp;
  final List<String> waitingFor;

  const BufferWaitPayload({
    required this.trackId,
    this.targetTimestamp = 0,
    this.waitingFor = const [],
  });

  Map<String, dynamic> toJson() => {
        'track_id': trackId,
        'target_timestamp': targetTimestamp,
        'waiting_for': waitingFor,
      };

  factory BufferWaitPayload.fromJson(Map<String, dynamic> json) {
    final rawWaiting = json['waiting_for'] ?? json['waitingFor'];
    final waitingList = rawWaiting is List
        ? rawWaiting.map((e) => e.toString()).toList()
        : const <String>[];
    return BufferWaitPayload(
      trackId: (json['track_id'] ?? json['trackId'] ?? '').toString(),
      targetTimestamp:
          ((json['target_timestamp'] ?? json['targetTimestamp']) as num?)?.toInt() ?? 0,
      waitingFor: waitingList,
    );
  }
}

/// Buffer Barrier Payload: emitted by a client once its audio stream pre-buffer is full.
class BufferReadyPayload {
  final String trackId;
  final String userId;
  final int readyEpochMs;

  const BufferReadyPayload({
    required this.trackId,
    this.userId = '',
    this.readyEpochMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'track_id': trackId,
        if (userId.isNotEmpty) 'user_id': userId,
        if (readyEpochMs > 0) 'ready_epoch_ms': readyEpochMs,
      };

  factory BufferReadyPayload.fromJson(Map<String, dynamic> json) {
    return BufferReadyPayload(
      trackId: (json['track_id'] ?? json['trackId'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      readyEpochMs:
          ((json['ready_epoch_ms'] ?? json['readyEpochMs']) as num?)?.toInt() ?? 0,
    );
  }
}

/// Buffer Barrier Payload: broadcast when all clients reported buffer_ready.
class BufferCompletePayload {
  final String trackId;
  final int startPlaybackAtEpochMs;
  final int positionMs;

  const BufferCompletePayload({
    required this.trackId,
    this.startPlaybackAtEpochMs = 0,
    this.positionMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'track_id': trackId,
        'start_playback_at': startPlaybackAtEpochMs,
        'position': positionMs,
      };

  factory BufferCompletePayload.fromJson(Map<String, dynamic> json) {
    return BufferCompletePayload(
      trackId: (json['track_id'] ?? json['trackId'] ?? '').toString(),
      startPlaybackAtEpochMs: ((json['start_playback_at'] ??
              json['startPlaybackAtEpochMs'] ??
              json['startPlaybackAt']) as num?)
          ?.toInt() ??
          0,
      positionMs: ((json['position'] ?? json['positionMs']) as num?)?.toInt() ?? 0,
    );
  }
}

/// Detailed payload for fine-grained playback actions.
class PlaybackActionPayload {
  final String action;
  final String? trackId;
  final int? positionMs;
  final SyncTrackInfo? trackInfo;
  final bool insertNext;
  final List<SyncTrackInfo>? queue;
  final String? queueTitle;
  final double? volume;
  final int? serverTime;
  final int revision;
  final int? capturedAtServerTime;

  const PlaybackActionPayload({
    required this.action,
    this.trackId,
    this.positionMs,
    this.trackInfo,
    this.insertNext = false,
    this.queue,
    this.queueTitle,
    this.volume,
    this.serverTime,
    this.revision = 0,
    this.capturedAtServerTime,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        if (trackId != null) 'track_id': trackId,
        if (positionMs != null) 'position': positionMs,
        if (trackInfo != null) 'track_info': trackInfo!.toJson(),
        if (insertNext) 'insert_next': insertNext,
        if (queue != null) 'queue': queue!.map((t) => t.toJson()).toList(),
        if (queueTitle != null) 'queue_title': queueTitle,
        if (volume != null) 'volume': volume,
        if (serverTime != null) 'server_time': serverTime,
        'revision': revision,
        if (capturedAtServerTime != null)
          'captured_at_server_time': capturedAtServerTime,
      };

  factory PlaybackActionPayload.fromJson(Map<String, dynamic> json) {
    return PlaybackActionPayload(
      action: (json['action'] ?? '').toString(),
      trackId: json['track_id'] as String? ?? json['trackId'] as String?,
      positionMs: ((json['position'] ?? json['positionMs']) as num?)?.toInt(),
      trackInfo: json['track_info'] != null
          ? SyncTrackInfo.fromJson(json['track_info'] as Map<String, dynamic>)
          : null,
      insertNext: json['insert_next'] == true || json['insertNext'] == true,
      queue: (json['queue'] as List<dynamic>?)
          ?.map((e) => SyncTrackInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      queueTitle: json['queue_title'] as String? ?? json['queueTitle'] as String?,
      volume: (json['volume'] as num?)?.toDouble(),
      serverTime: ((json['server_time'] ?? json['serverTime']) as num?)?.toInt(),
      revision: ((json['revision']) as num?)?.toInt() ?? 0,
      capturedAtServerTime: ((json['captured_at_server_time'] ??
              json['capturedAtServerTime']) as num?)
          ?.toInt(),
    );
  }
}

/// Clock sync ping sent from client.
class PingPayload {
  final int clientTime;
  final int sequence;

  const PingPayload({
    required this.clientTime,
    required this.sequence,
  });

  Map<String, dynamic> toJson() => {
        'client_time': clientTime,
        'sequence': sequence,
      };

  factory PingPayload.fromJson(Map<String, dynamic> json) {
    return PingPayload(
      clientTime: ((json['client_time'] ?? json['clientTime']) as num?)?.toInt() ?? 0,
      sequence: ((json['sequence']) as num?)?.toInt() ?? 0,
    );
  }
}

/// Clock sync pong received from server.
class PongPayload {
  final int clientTime;
  final int serverReceiveTime;
  final int serverSendTime;
  final int sequence;

  const PongPayload({
    required this.clientTime,
    required this.serverReceiveTime,
    required this.serverSendTime,
    required this.sequence,
  });

  Map<String, dynamic> toJson() => {
        'client_time': clientTime,
        'server_receive_time': serverReceiveTime,
        'server_send_time': serverSendTime,
        'sequence': sequence,
      };

  factory PongPayload.fromJson(Map<String, dynamic> json) {
    return PongPayload(
      clientTime: ((json['client_time'] ?? json['clientTime']) as num?)?.toInt() ?? 0,
      serverReceiveTime: ((json['server_receive_time'] ?? json['serverReceiveTime']) as num?)?.toInt() ?? 0,
      serverSendTime: ((json['server_send_time'] ?? json['serverSendTime']) as num?)?.toInt() ?? 0,
      sequence: ((json['sequence']) as num?)?.toInt() ?? 0,
    );
  }
}

/// Envelope representing every wire message in Listen Together.
class ListenTogetherMessage {
  final String type;
  final Map<String, dynamic> payload;
  final bool compressed;

  const ListenTogetherMessage({
    required this.type,
    required this.payload,
    this.compressed = false,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'payload': payload,
        'compressed': compressed,
      };

  String toJsonString() => jsonEncode(toJson());

  factory ListenTogetherMessage.fromJson(Map<String, dynamic> json) {
    final payloadRaw = json['payload'];
    Map<String, dynamic> payloadMap;
    if (payloadRaw is Map<String, dynamic>) {
      payloadMap = payloadRaw;
    } else if (payloadRaw is String) {
      try {
        payloadMap = jsonDecode(payloadRaw) as Map<String, dynamic>;
      } catch (_) {
        payloadMap = <String, dynamic>{};
      }
    } else {
      payloadMap = <String, dynamic>{};
    }

    return ListenTogetherMessage(
      type: (json['type'] ?? '').toString(),
      payload: payloadMap,
      compressed: json['compressed'] == true,
    );
  }

  factory ListenTogetherMessage.parse(String jsonString) {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    return ListenTogetherMessage.fromJson(decoded);
  }
}
