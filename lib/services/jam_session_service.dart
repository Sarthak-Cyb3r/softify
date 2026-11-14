import 'dart:async';
import 'dart:math';

import '../domain/entities/track.dart';

/// Participant in a collaborative Softify Jam session.
class JamParticipant {
  final String participantId;
  final String displayName;
  final String avatarUrl;
  final bool isHost;
  final DateTime joinedAt;

  const JamParticipant({
    required this.participantId,
    required this.displayName,
    this.avatarUrl = '',
    this.isHost = false,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
        'participantId': participantId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'isHost': isHost,
        'joinedAt': joinedAt.millisecondsSinceEpoch,
      };

  factory JamParticipant.fromJson(Map<String, dynamic> json) {
    return JamParticipant(
      participantId: json['participantId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Guest',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      isHost: json['isHost'] as bool? ?? false,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(
          json['joinedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
    );
  }
}

/// Jam session state tracking active session, queue, and participants.
class JamSessionState {
  final String sessionId;
  final String sessionCode;
  final bool isHost;
  final JamParticipant host;
  final List<JamParticipant> participants;
  final List<Track> sharedQueue;
  final Track? currentTrack;
  final int currentPositionMs;
  final bool isPaused;

  const JamSessionState({
    required this.sessionId,
    required this.sessionCode,
    required this.isHost,
    required this.host,
    this.participants = const [],
    this.sharedQueue = const [],
    this.currentTrack,
    this.currentPositionMs = 0,
    this.isPaused = false,
  });

  static final JamSessionState inactive = JamSessionState(
    sessionId: '',
    sessionCode: '',
    isHost: false,
    host: JamParticipant(
      participantId: '',
      displayName: '',
      joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );

  bool get isActive => sessionId.isNotEmpty;
}

/// Spotify Jam-style collaborative listening session service.
/// Coordinates multi-user real-time shared queue and host-controlled playback.
class JamSessionService {
  static final JamSessionService instance = JamSessionService._internal();

  JamSessionService._internal();

  JamSessionState _currentState = JamSessionState.inactive;
  final _stateController = StreamController<JamSessionState>.broadcast();

  Stream<JamSessionState> get sessionStream => _stateController.stream;
  JamSessionState get currentSession => _currentState;

  /// Starts a new Jam session as host.
  Future<JamSessionState> startJamAsHost({
    required String hostId,
    required String hostName,
    String hostAvatar = '',
  }) async {
    final code = _generateSessionCode();
    final host = JamParticipant(
      participantId: hostId,
      displayName: hostName,
      avatarUrl: hostAvatar,
      isHost: true,
      joinedAt: DateTime.now(),
    );

    _currentState = JamSessionState(
      sessionId: 'jam_${DateTime.now().millisecondsSinceEpoch}',
      sessionCode: code,
      isHost: true,
      host: host,
      participants: [host],
      sharedQueue: [],
    );

    _stateController.add(_currentState);
    return _currentState;
  }

  /// Joins an existing Jam session using session code.
  Future<bool> joinJam({
    required String sessionCode,
    required String participantId,
    required String displayName,
    String avatarUrl = '',
  }) async {
    // In local architecture, connects to host node
    final guest = JamParticipant(
      participantId: participantId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isHost: false,
      joinedAt: DateTime.now(),
    );

    _currentState = JamSessionState(
      sessionId: 'jam_remote_$sessionCode',
      sessionCode: sessionCode,
      isHost: false,
      host: JamParticipant(
        participantId: 'host',
        displayName: 'Host',
        isHost: true,
        joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      participants: [guest],
      sharedQueue: [],
    );

    _stateController.add(_currentState);
    return true;
  }

  /// Appends a track to the shared collaborative Jam queue.
  void addTrackToQueue(Track track, String addedByParticipantId) {
    if (!_currentState.isActive) return;

    final updatedQueue = List<Track>.from(_currentState.sharedQueue)..add(track);

    _currentState = JamSessionState(
      sessionId: _currentState.sessionId,
      sessionCode: _currentState.sessionCode,
      isHost: _currentState.isHost,
      host: _currentState.host,
      participants: _currentState.participants,
      sharedQueue: updatedQueue,
      currentTrack: _currentState.currentTrack,
      currentPositionMs: _currentState.currentPositionMs,
      isPaused: _currentState.isPaused,
    );

    _stateController.add(_currentState);
  }

  /// Updates host playback status for synchronized group listening.
  void updateHostPlayback({
    Track? currentTrack,
    required int positionMs,
    required bool isPaused,
  }) {
    if (!_currentState.isActive || !_currentState.isHost) return;

    _currentState = JamSessionState(
      sessionId: _currentState.sessionId,
      sessionCode: _currentState.sessionCode,
      isHost: _currentState.isHost,
      host: _currentState.host,
      participants: _currentState.participants,
      sharedQueue: _currentState.sharedQueue,
      currentTrack: currentTrack ?? _currentState.currentTrack,
      currentPositionMs: positionMs,
      isPaused: isPaused,
    );

    _stateController.add(_currentState);
  }

  /// Leaves or terminates the Jam session.
  void endJam() {
    _currentState = JamSessionState.inactive;
    _stateController.add(_currentState);
  }

  String _generateSessionCode() {
    final rand = Random();
    final digits = List.generate(6, (_) => rand.nextInt(10)).join();
    return digits;
  }

  void dispose() {
    _stateController.close();
  }
}
