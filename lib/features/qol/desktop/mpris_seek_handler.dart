// ============================================================================
// Softify Quality of Life (QoL) - Feature 31: MPRIS D-Bus Seek Protocol Handler
// ============================================================================
// Implements the canonical MPRIS v2 Player D-Bus specification for seeking:
// - Seek(x Offset): relative offset in microseconds
// - SetPosition(o TrackId, x Position): absolute position in microseconds
// - Emits Seeked(x Position) D-Bus signal on track position changes
// - Integrates directly with Softify audio handler and Riverpod state management.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/player/softify_audio_handler.dart';
import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';

// ============================================================================
// D-Bus & MPRIS Specification Constants
// ============================================================================

/// MPRIS 2 Player interface name defined by freedesktop.org specification.
const String kMprisPlayerInterface = 'org.mpris.MediaPlayer2.Player';

/// MPRIS 2 root interface name.
const String kMprisRootInterface = 'org.mpris.MediaPlayer2';

/// Canonical D-Bus object path for MPRIS 2 media players.
const String kMprisObjectPath = '/org/mpris/MediaPlayer2';

/// Well-known TrackId representing the currently active track in MPRIS.
const String kMprisCurrentTrackPath = '/org/mpris/MediaPlayer2/CurrentTrack';

/// Well-known TrackId representing absence of a playing track in MPRIS.
const String kMprisNoTrackPath = '/org/mpris/MediaPlayer2/TrackList/NoTrack';

/// Prefix used to construct valid D-Bus object paths for Softify tracks.
const String kMprisTrackPathPrefix = '/org/softify/track/';

/// Method names on `org.mpris.MediaPlayer2.Player`.
const String kMprisMethodSeek = 'Seek';
const String kMprisMethodSetPosition = 'SetPosition';

/// Signal names on `org.mpris.MediaPlayer2.Player`.
const String kMprisSignalSeeked = 'Seeked';

/// Property names on `org.mpris.MediaPlayer2.Player`.
const String kMprisPropCanSeek = 'CanSeek';
const String kMprisPropPosition = 'Position';

/// Storage keys for persistence.
const String kMprisSeekPrefKey = 'softify_mpris_seek_enabled';
const String kMprisSeekClampPrefKey = 'softify_mpris_seek_clamp_to_duration';

// ============================================================================
// Enums & Models
// ============================================================================

/// Identifies the origin/type of seek action requested.
enum MprisSeekType {
  /// Relative offset forward/backward via `Seek(x Offset)`.
  relativeOffset,

  /// Absolute seek to a specific position via `SetPosition(o TrackId, x Position)`.
  setPosition,

  /// Manual scrub or internal discontinuity originating from Softify player UI.
  playerDiscontinuity,
}

/// Status code resulting from an MPRIS seek invocation.
enum MprisSeekStatus {
  /// Seek operation successfully applied to the audio pipeline.
  success,

  /// Seek ignored because the player capability `CanSeek` is disabled.
  ignoredCannotSeek,

  /// Seek ignored because the request TrackId does not match the active track.
  ignoredInvalidTrackId,

  /// An unexpected error occurred while executing the seek.
  error,
}

/// Detailed outcome result of an MPRIS seek request.
@immutable
class MprisSeekResult {
  /// Whether the seek was accepted and processed.
  final bool succeeded;

  /// Player position immediately prior to seeking.
  final Duration previousPosition;

  /// Clamped target position requested or computed.
  final Duration targetPosition;

  /// Current duration of the active track, if known.
  final Duration? trackDuration;

  /// Type of seek executed.
  final MprisSeekType type;

  /// Processing status enum.
  final MprisSeekStatus status;

  /// Track ID associated with the request (if SetPosition).
  final String? trackId;

  /// Optional debug or error message.
  final String? message;

  /// Microsecond offset passed for relative seeks.
  final int offsetMicroseconds;

  const MprisSeekResult({
    required this.succeeded,
    required this.previousPosition,
    required this.targetPosition,
    this.trackDuration,
    required this.type,
    required this.status,
    this.trackId,
    this.message,
    this.offsetMicroseconds = 0,
  });

  /// Target position expressed in microseconds (MPRIS standard unit).
  int get targetPositionMicroseconds => targetPosition.inMicroseconds;

  /// Previous position expressed in microseconds.
  int get previousPositionMicroseconds => previousPosition.inMicroseconds;

  /// Net position delta in microseconds.
  int get deltaMicroseconds =>
      targetPositionMicroseconds - previousPositionMicroseconds;

  MprisSeekResult copyWith({
    bool? succeeded,
    Duration? previousPosition,
    Duration? targetPosition,
    Duration? trackDuration,
    MprisSeekType? type,
    MprisSeekStatus? status,
    String? trackId,
    String? message,
    int? offsetMicroseconds,
  }) {
    return MprisSeekResult(
      succeeded: succeeded ?? this.succeeded,
      previousPosition: previousPosition ?? this.previousPosition,
      targetPosition: targetPosition ?? this.targetPosition,
      trackDuration: trackDuration ?? this.trackDuration,
      type: type ?? this.type,
      status: status ?? this.status,
      trackId: trackId ?? this.trackId,
      message: message ?? this.message,
      offsetMicroseconds: offsetMicroseconds ?? this.offsetMicroseconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MprisSeekResult &&
          runtimeType == other.runtimeType &&
          succeeded == other.succeeded &&
          previousPosition == other.previousPosition &&
          targetPosition == other.targetPosition &&
          trackDuration == other.trackDuration &&
          type == other.type &&
          status == other.status &&
          trackId == other.trackId &&
          offsetMicroseconds == other.offsetMicroseconds;

  @override
  int get hashCode => Object.hash(
        succeeded,
        previousPosition,
        targetPosition,
        trackDuration,
        type,
        status,
        trackId,
        offsetMicroseconds,
      );

  @override
  String toString() =>
      'MprisSeekResult(succeeded: $succeeded, status: $status, target: ${targetPosition.inMilliseconds}ms, delta: ${deltaMicroseconds ~/ 1000}ms, trackId: $trackId)';
}

/// Event broadcast when a seek occurs via D-Bus or player scrub.
@immutable
class MprisSeekEvent {
  final DateTime timestamp;
  final MprisSeekResult result;
  final int positionMicroseconds;

  MprisSeekEvent({
    DateTime? timestamp,
    required this.result,
    required this.positionMicroseconds,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'MprisSeekEvent(pos: ${positionMicroseconds ~/ 1000}ms, result: $result, at: $timestamp)';
}

// ============================================================================
// Pure Protocol Helper: MprisSeekProtocol
// ============================================================================

/// Pure Dart calculations and validations for the MPRIS v2 Seek protocol.
class MprisSeekProtocol {
  const MprisSeekProtocol._();

  /// Calculates clamped target position for relative seek `Seek(x Offset)`.
  ///
  /// MPRIS v2 spec:
  /// - `Offset`: Signed 64-bit integer microseconds.
  /// - If target < 0, clamped to 0.
  /// - If target > duration (and `clampToDuration` is true), clamped to duration.
  static Duration computeSeekTarget({
    required Duration currentPosition,
    required int offsetMicroseconds,
    Duration? duration,
    bool clampToDuration = true,
  }) {
    final int targetMicros = currentPosition.inMicroseconds + offsetMicroseconds;

    if (targetMicros <= 0) {
      return Duration.zero;
    }

    if (clampToDuration && duration != null && duration > Duration.zero) {
      if (targetMicros >= duration.inMicroseconds) {
        return duration;
      }
    }

    return Duration(microseconds: targetMicros);
  }

  /// Calculates clamped target position for absolute seek `SetPosition(o TrackId, x Position)`.
  ///
  /// MPRIS v2 spec:
  /// - `Position`: 64-bit integer microseconds >= 0.
  /// - Clamped between 0 and duration.
  static Duration computeSetPositionTarget({
    required int positionMicroseconds,
    Duration? duration,
    bool clampToDuration = true,
  }) {
    if (positionMicroseconds <= 0) {
      return Duration.zero;
    }

    if (clampToDuration && duration != null && duration > Duration.zero) {
      if (positionMicroseconds >= duration.inMicroseconds) {
        return duration;
      }
    }

    return Duration(microseconds: positionMicroseconds);
  }

  /// Converts an arbitrary track ID string into a RFC-compliant D-Bus Object Path.
  ///
  /// D-Bus object path requirements:
  /// - Must start with `/`
  /// - Elements must contain only `[A-Z][a-z][0-9]_`
  /// - No empty elements (no consecutive `/`)
  static String formatTrackId(String? rawTrackId) {
    if (rawTrackId == null || rawTrackId.trim().isEmpty) {
      return kMprisNoTrackPath;
    }

    final trimmed = rawTrackId.trim();
    // If already a valid absolute path like /org/mpris/... or /org/softify/..., preserve hierarchy
    if (trimmed.startsWith('/')) {
      final segments = trimmed
          .split('/')
          .where((s) => s.isNotEmpty)
          .map(sanitizeToDBusPathElement)
          .join('/');
      return '/$segments';
    }

    final sanitized = sanitizeToDBusPathElement(trimmed);
    return '$kMprisTrackPathPrefix$sanitized';
  }

  /// Sanitizes an arbitrary string into a valid D-Bus path element `[A-Za-z0-9_]+`.
  static String sanitizeToDBusPathElement(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      final isUpper = code >= 65 && code <= 90;
      final isLower = code >= 97 && code <= 122;
      final isDigit = code >= 48 && code <= 57;

      if (isUpper || isLower || isDigit) {
        buffer.writeCharCode(code);
      } else {
        buffer.write('_');
      }
    }
    final result = buffer.toString();
    return result.isEmpty ? 'track' : result;
  }

  /// Validates whether the incoming [requestTrackId] matches the currently active track.
  ///
  /// MPRIS v2 spec:
  /// "If the TrackId is not for the currently playing track, the call is ignored,
  /// because the client might not have yet received an update for the new track."
  static bool isValidTrackId({
    required String requestTrackId,
    required String? currentTrackId,
    List<String> aliases = const [],
  }) {
    final req = requestTrackId.trim();

    // The special path `/org/mpris/MediaPlayer2/CurrentTrack` is an accepted alias
    if (req == kMprisCurrentTrackPath) {
      return true;
    }

    if (aliases.contains(req)) {
      return true;
    }

    if (currentTrackId == null || currentTrackId.trim().isEmpty) {
      // If there is no current track, cannot match
      return false;
    }

    final curr = currentTrackId.trim();

    // Direct string match
    if (req == curr) {
      return true;
    }

    // Formatted D-Bus path match
    final formattedCurr = formatTrackId(curr);
    if (req == formattedCurr) {
      return true;
    }

    // Both formatted match
    if (formatTrackId(req) == formattedCurr) {
      return true;
    }

    return false;
  }

  /// Evaluates whether an observed position delta constitutes a manual discontinuity (scrub)
  /// as opposed to regular playback progression.
  static bool hasPositionDiscontinuity({
    required Duration current,
    required Duration previous,
    required bool isPlaying,
    required Duration elapsed,
    Duration tolerance = const Duration(milliseconds: 200),
    double speed = 1.0,
  }) {
    if (elapsed.isNegative) return false;

    Duration expected = previous;
    if (isPlaying) {
      expected += Duration(
        microseconds: (elapsed.inMicroseconds * speed).round(),
      );
    }

    final delta = (current.inMicroseconds - expected.inMicroseconds).abs();
    return delta > tolerance.inMicroseconds;
  }
}

// ============================================================================
// Audio Handler Abstraction: ISoftifySeekableAudioHandler
// ============================================================================

/// Contract required by [MprisSeekHandler] to decouple from concrete audio engines
/// for robust, zero-hang unit testing.
abstract class ISoftifySeekableAudioHandler {
  Future<void> seek(Duration position);
  Duration get currentPosition;
  Duration? get duration;
  String? get currentTrackId;
  bool get isPlaying;
  double get speed;

  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<PlaybackState> get playbackStateStream;
  Stream<MediaItem?> get mediaItemStream;
  Stream<Track?> get currentTrackStream;
}

/// Production adapter bridging [SoftifyAudioHandler] to [ISoftifySeekableAudioHandler].
class SoftifyAudioHandlerSeekAdapter implements ISoftifySeekableAudioHandler {
  final SoftifyAudioHandler _audioHandler;

  SoftifyAudioHandlerSeekAdapter(this._audioHandler);

  @override
  Future<void> seek(Duration position) => _audioHandler.seek(position);

  @override
  Duration get currentPosition => _audioHandler.position;

  @override
  Duration? get duration =>
      _audioHandler.mediaItem.value?.duration ??
      _audioHandler.currentTrack?.duration;

  @override
  String? get currentTrackId =>
      _audioHandler.currentTrack?.id ?? _audioHandler.mediaItem.value?.id;

  @override
  bool get isPlaying => _audioHandler.playbackState.value.playing;

  @override
  double get speed => _audioHandler.playbackState.value.speed;

  @override
  Stream<Duration> get positionStream => _audioHandler.positionStream;

  @override
  Stream<Duration?> get durationStream => _audioHandler.durationStream;

  @override
  Stream<PlaybackState> get playbackStateStream => _audioHandler.playbackState;

  @override
  Stream<MediaItem?> get mediaItemStream => _audioHandler.mediaItem;

  @override
  Stream<Track?> get currentTrackStream => _audioHandler.currentTrackStream;
}

// ============================================================================
// D-Bus Object: MprisPlayerDBusObject
// ============================================================================

/// DBusObject exported onto the session bus at `/org/mpris/MediaPlayer2`.
///
/// Implements `org.mpris.MediaPlayer2.Player` methods and properties related to seeking.
class MprisPlayerDBusObject extends DBusObject {
  final MprisSeekHandler _handler;

  MprisPlayerDBusObject(this._handler)
      : super(DBusObjectPath(kMprisObjectPath));

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface(
        kMprisPlayerInterface,
        methods: [
          DBusIntrospectMethod(
            kMprisMethodSeek,
            args: [
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.in_,
                name: 'Offset',
              ),
            ],
          ),
          DBusIntrospectMethod(
            kMprisMethodSetPosition,
            args: [
              DBusIntrospectArgument(
                DBusSignature('o'),
                DBusArgumentDirection.in_,
                name: 'TrackId',
              ),
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.in_,
                name: 'Position',
              ),
            ],
          ),
        ],
        signals: [
          DBusIntrospectSignal(
            kMprisSignalSeeked,
            args: [
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.out,
                name: 'Position',
              ),
            ],
          ),
        ],
        properties: [
          DBusIntrospectProperty(
            kMprisPropCanSeek,
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            kMprisPropPosition,
            DBusSignature('x'),
            access: DBusPropertyAccess.read,
          ),
        ],
      ),
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    // Validate interface targeting
    if (methodCall.interface != null &&
        methodCall.interface != kMprisPlayerInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }

    if (methodCall.name == kMprisMethodSeek) {
      if (methodCall.values.length != 1) {
        return DBusMethodErrorResponse.invalidArgs('Seek requires 1 argument: Offset (x)');
      }
      try {
        final offset = methodCall.values[0].asInt64();
        await _handler.handleSeek(offset);
        return DBusMethodSuccessResponse([]);
      } catch (e) {
        return DBusMethodErrorResponse.invalidArgs('Invalid Offset argument: $e');
      }
    }

    if (methodCall.name == kMprisMethodSetPosition) {
      if (methodCall.values.length != 2) {
        return DBusMethodErrorResponse.invalidArgs(
          'SetPosition requires 2 arguments: TrackId (o), Position (x)',
        );
      }
      try {
        final trackId = methodCall.values[0] is DBusObjectPath
            ? methodCall.values[0].asObjectPath().value
            : methodCall.values[0].asString();
        final position = methodCall.values[1].asInt64();
        await _handler.handleSetPosition(trackId, position);
        return DBusMethodSuccessResponse([]);
      } catch (e) {
        return DBusMethodErrorResponse.invalidArgs('Invalid SetPosition arguments: $e');
      }
    }

    return DBusMethodErrorResponse.unknownMethod(
      'Unknown method ${methodCall.name} on $kMprisPlayerInterface',
    );
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface != kMprisPlayerInterface) {
      return DBusMethodErrorResponse.unknownProperty();
    }

    if (name == kMprisPropCanSeek) {
      return DBusGetPropertyResponse(DBusBoolean(_handler.canSeek));
    } else if (name == kMprisPropPosition) {
      return DBusGetPropertyResponse(
        DBusInt64(_handler.currentPositionMicroseconds),
      );
    }

    return DBusMethodErrorResponse.unknownProperty();
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (interface != kMprisPlayerInterface) {
      return DBusGetAllPropertiesResponse({});
    }

    return DBusGetAllPropertiesResponse({
      kMprisPropCanSeek: DBusBoolean(_handler.canSeek),
      kMprisPropPosition: DBusInt64(_handler.currentPositionMicroseconds),
    });
  }

  /// Emits the MPRIS `Seeked(Position)` signal on D-Bus.
  Future<void> emitSeekedSignal(int positionMicroseconds) async {
    try {
      await emitSignal(
        kMprisPlayerInterface,
        kMprisSignalSeeked,
        [DBusInt64(positionMicroseconds)],
      );
    } catch (_) {
      // Gracefully handled if bus client is disconnected
    }
  }
}

// ============================================================================
// Service: MprisSeekHandler
// ============================================================================

/// Desktop Quality-of-Life service implementing the MPRIS v2 Seek and SetPosition protocol.
class MprisSeekHandler {
  final ISoftifySeekableAudioHandler _audioHandler;
  final DBusClient? _dbusClient;
  final Duration _positionTolerance;
  final void Function(String message)? _logger;

  late final MprisPlayerDBusObject _dbusObject;

  bool _canSeek;
  bool _clampToDuration;
  bool _isDisposed = false;
  bool _isRegistered = false;

  final StreamController<MprisSeekEvent> _seekEventController =
      StreamController<MprisSeekEvent>.broadcast();
  final StreamController<int> _seekedPositionsController =
      StreamController<int>.broadcast();

  // Internal tracking state for scrubbing discontinuity detection
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  Duration _lastReportedPosition = Duration.zero;
  DateTime _lastPositionUpdateTime = DateTime.now();
  bool _lastIsPlaying = false;
  double _lastSpeed = 1.0;

  MprisSeekHandler({
    required ISoftifySeekableAudioHandler audioHandler,
    DBusClient? dbusClient,
    bool canSeek = true,
    bool clampToDuration = true,
    Duration positionTolerance = const Duration(milliseconds: 200),
    void Function(String message)? logger,
  })  : _audioHandler = audioHandler,
        _dbusClient = dbusClient,
        _canSeek = canSeek,
        _clampToDuration = clampToDuration,
        _positionTolerance = positionTolerance,
        _logger = logger {
    _dbusObject = MprisPlayerDBusObject(this);
    _initDiscontinuityTracker();
  }

  /// Whether MPRIS clients may seek this player.
  bool get canSeek => _canSeek;

  set canSeek(bool value) {
    if (_canSeek == value) return;
    _canSeek = value;
    _notifyPropertyChange(kMprisPropCanSeek, DBusBoolean(value));
  }

  /// Whether target seek positions are clamped to the track's known duration.
  bool get clampToDuration => _clampToDuration;

  set clampToDuration(bool value) {
    _clampToDuration = value;
  }

  /// Active D-Bus object representing this MPRIS player.
  MprisPlayerDBusObject get dbusObject => _dbusObject;

  /// Current audio playback position.
  Duration get currentPosition => _audioHandler.currentPosition;

  /// Current position formatted in microseconds.
  int get currentPositionMicroseconds => currentPosition.inMicroseconds;

  /// Current track duration, if available.
  Duration? get duration => _audioHandler.duration;

  /// Active track identifier.
  String? get currentTrackId => _audioHandler.currentTrackId;

  /// Formatted D-Bus object path for the current track.
  String get currentTrackDBusPath => MprisSeekProtocol.formatTrackId(currentTrackId);

  /// Whether playback is currently active.
  bool get isPlaying => _audioHandler.isPlaying;

  /// Whether this object is currently registered on D-Bus.
  bool get isRegistered => _isRegistered;

  /// Stream of seek outcome events.
  Stream<MprisSeekEvent> get seekEvents => _seekEventController.stream;

  /// Stream of seeked positions emitted in microseconds.
  Stream<int> get seekedPositions => _seekedPositionsController.stream;

  // --------------------------------------------------------------------------
  // Core MPRIS Protocol Handlers
  // --------------------------------------------------------------------------

  /// Handles `org.mpris.MediaPlayer2.Player.Seek(x Offset)`.
  ///
  /// Seeks forward or backward by [offsetMicroseconds].
  Future<MprisSeekResult> handleSeek(int offsetMicroseconds) async {
    final prevPos = _audioHandler.currentPosition;
    final trackDur = _audioHandler.duration;

    if (!_canSeek) {
      final result = MprisSeekResult(
        succeeded: false,
        previousPosition: prevPos,
        targetPosition: prevPos,
        trackDuration: trackDur,
        type: MprisSeekType.relativeOffset,
        status: MprisSeekStatus.ignoredCannotSeek,
        offsetMicroseconds: offsetMicroseconds,
        message: 'Seek ignored: CanSeek capability is disabled.',
      );
      _log(result.toString());
      return result;
    }

    final target = MprisSeekProtocol.computeSeekTarget(
      currentPosition: prevPos,
      offsetMicroseconds: offsetMicroseconds,
      duration: trackDur,
      clampToDuration: _clampToDuration,
    );

    try {
      await _audioHandler.seek(target);
      _updateInternalTracker(target);
      await emitSeeked(target);

      final result = MprisSeekResult(
        succeeded: true,
        previousPosition: prevPos,
        targetPosition: target,
        trackDuration: trackDur,
        type: MprisSeekType.relativeOffset,
        status: MprisSeekStatus.success,
        offsetMicroseconds: offsetMicroseconds,
      );

      _recordEvent(result, target.inMicroseconds);
      _log('Seek($offsetMicroseconds us) => ${target.inMilliseconds}ms');
      return result;
    } catch (e, stack) {
      final result = MprisSeekResult(
        succeeded: false,
        previousPosition: prevPos,
        targetPosition: target,
        trackDuration: trackDur,
        type: MprisSeekType.relativeOffset,
        status: MprisSeekStatus.error,
        offsetMicroseconds: offsetMicroseconds,
        message: 'Error executing seek: $e',
      );
      _log('Error seeking: $e\n$stack');
      return result;
    }
  }

  /// Handles `org.mpris.MediaPlayer2.Player.SetPosition(o TrackId, x Position)`.
  ///
  /// Seeks to an absolute [positionMicroseconds] for the specified [trackId].
  Future<MprisSeekResult> handleSetPosition(
    String trackId,
    int positionMicroseconds,
  ) async {
    final prevPos = _audioHandler.currentPosition;
    final trackDur = _audioHandler.duration;
    final currId = _audioHandler.currentTrackId;

    if (!_canSeek) {
      final result = MprisSeekResult(
        succeeded: false,
        previousPosition: prevPos,
        targetPosition: prevPos,
        trackDuration: trackDur,
        type: MprisSeekType.setPosition,
        status: MprisSeekStatus.ignoredCannotSeek,
        trackId: trackId,
        message: 'SetPosition ignored: CanSeek capability is disabled.',
      );
      _log(result.toString());
      return result;
    }

    // MPRIS Spec: If TrackId is not for the currently playing track, the call MUST be ignored.
    final isValidTrack = MprisSeekProtocol.isValidTrackId(
      requestTrackId: trackId,
      currentTrackId: currId,
    );

    if (!isValidTrack) {
      final result = MprisSeekResult(
        succeeded: false,
        previousPosition: prevPos,
        targetPosition: prevPos,
        trackDuration: trackDur,
        type: MprisSeekType.setPosition,
        status: MprisSeekStatus.ignoredInvalidTrackId,
        trackId: trackId,
        message:
            'SetPosition ignored: request TrackId "$trackId" does not match current track "$currId".',
      );
      _log(result.toString());
      return result;
    }

    final target = MprisSeekProtocol.computeSetPositionTarget(
      positionMicroseconds: positionMicroseconds,
      duration: trackDur,
      clampToDuration: _clampToDuration,
    );

    try {
      await _audioHandler.seek(target);
      _updateInternalTracker(target);
      await emitSeeked(target);

      final result = MprisSeekResult(
        succeeded: true,
        previousPosition: prevPos,
        targetPosition: target,
        trackDuration: trackDur,
        type: MprisSeekType.setPosition,
        status: MprisSeekStatus.success,
        trackId: trackId,
      );

      _recordEvent(result, target.inMicroseconds);
      _log('SetPosition($trackId, ${target.inMilliseconds}ms) succeeded.');
      return result;
    } catch (e, stack) {
      final result = MprisSeekResult(
        succeeded: false,
        previousPosition: prevPos,
        targetPosition: target,
        trackDuration: trackDur,
        type: MprisSeekType.setPosition,
        status: MprisSeekStatus.error,
        trackId: trackId,
        message: 'Error executing SetPosition: $e',
      );
      _log('Error setting position: $e\n$stack');
      return result;
    }
  }

  /// Dispatches an arbitrary incoming [DBusMethodCall] directly to this handler.
  Future<DBusMethodResponse> handleDBusMethodCall(DBusMethodCall methodCall) {
    return _dbusObject.handleMethodCall(methodCall);
  }

  /// Emits the MPRIS `Seeked(x Position)` signal to notify external desktop controllers.
  Future<void> emitSeeked(Duration position) async {
    final micros = position.inMicroseconds;
    if (!_seekedPositionsController.isClosed) {
      _seekedPositionsController.add(micros);
    }
    await _dbusObject.emitSeekedSignal(micros);
  }

  // --------------------------------------------------------------------------
  // D-Bus Registration & Lifecycle
  // --------------------------------------------------------------------------

  /// Registers this MPRIS player object with the D-Bus session bus.
  Future<void> registerWithDBus({DBusClient? client}) async {
    final targetClient = client ?? _dbusClient;
    if (targetClient == null || _isRegistered) return;

    try {
      await targetClient.registerObject(_dbusObject);
      _isRegistered = true;
      _log('Registered MPRIS object on D-Bus at $kMprisObjectPath');
    } catch (e) {
      _log('Failed to register MPRIS object on D-Bus: $e');
    }
  }

  /// Unregisters the object from the D-Bus bus.
  Future<void> unregisterDBus() async {
    final client = _dbusObject.client ?? _dbusClient;
    if (client == null || !_isRegistered) return;

    try {
      await client.unregisterObject(_dbusObject);
      _isRegistered = false;
      _log('Unregistered MPRIS object from D-Bus');
    } catch (e) {
      _log('Error unregistering MPRIS object: $e');
    }
  }

  /// Disposes resources, subscriptions, and stream controllers.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _positionSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _seekEventController.close();
    _seekedPositionsController.close();
  }

  // --------------------------------------------------------------------------
  // Internal Helpers & Discontinuity Detection
  // --------------------------------------------------------------------------

  void _initDiscontinuityTracker() {
    _lastReportedPosition = _audioHandler.currentPosition;
    _lastPositionUpdateTime = DateTime.now();
    _lastIsPlaying = _audioHandler.isPlaying;
    _lastSpeed = _audioHandler.speed;

    _playbackStateSubscription = _audioHandler.playbackStateStream.listen((state) {
      _lastIsPlaying = state.playing;
      _lastSpeed = state.speed;
      _checkDiscontinuity(state.position);
    });

    _positionSubscription = _audioHandler.positionStream.listen((pos) {
      _checkDiscontinuity(pos);
    });
  }

  void _checkDiscontinuity(Duration newPos) {
    final now = DateTime.now();
    final elapsed = now.difference(_lastPositionUpdateTime);

    final isDiscontinuous = MprisSeekProtocol.hasPositionDiscontinuity(
      current: newPos,
      previous: _lastReportedPosition,
      isPlaying: _lastIsPlaying,
      elapsed: elapsed,
      tolerance: _positionTolerance,
      speed: _lastSpeed,
    );

    if (isDiscontinuous) {
      final prev = _lastReportedPosition;
      _lastReportedPosition = newPos;
      _lastPositionUpdateTime = now;

      final result = MprisSeekResult(
        succeeded: true,
        previousPosition: prev,
        targetPosition: newPos,
        trackDuration: _audioHandler.duration,
        type: MprisSeekType.playerDiscontinuity,
        status: MprisSeekStatus.success,
      );

      _recordEvent(result, newPos.inMicroseconds);
      emitSeeked(newPos);
    } else {
      _lastReportedPosition = newPos;
      _lastPositionUpdateTime = now;
    }
  }

  void _updateInternalTracker(Duration target) {
    _lastReportedPosition = target;
    _lastPositionUpdateTime = DateTime.now();
  }

  void _recordEvent(MprisSeekResult result, int micros) {
    if (!_seekEventController.isClosed) {
      _seekEventController.add(
        MprisSeekEvent(result: result, positionMicroseconds: micros),
      );
    }
  }

  void _notifyPropertyChange(String propName, DBusValue value) {
    try {
      _dbusObject.emitPropertiesChanged(
        kMprisPlayerInterface,
        changedProperties: {propName: value},
      );
    } catch (_) {}
  }

  void _log(String message) {
    _logger?.call('[MprisSeekHandler] $message');
  }
}

// ============================================================================
// Storage & Persistence: MprisSeekStorage
// ============================================================================

/// SharedPreferences-compatible storage for MPRIS seek configurations.
class MprisSeekStorage {
  static final MprisSeekStorage _instance = MprisSeekStorage._internal();
  factory MprisSeekStorage() => _instance;
  MprisSeekStorage._internal();

  Map<String, dynamic> _memoryCache = {};
  bool _isLoaded = false;
  File? _cacheFile;

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final dir = await getApplicationSupportDirectory();
      _cacheFile = File(p.join(dir.path, 'mpris_seek_preferences.json'));
      if (await _cacheFile!.exists()) {
        final content = await _cacheFile!.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _memoryCache = Map<String, dynamic>.from(decoded);
          }
        }
      }
    } catch (_) {
      // Memory fallback for headless/test environments
    } finally {
      _isLoaded = true;
    }
  }

  Future<bool?> getBool(String key) async {
    if (!_isLoaded) await init();
    final val = _memoryCache[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    try {
      if (_cacheFile != null) {
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache), flush: true);
      }
    } catch (_) {}
    return true;
  }

  void clearForTesting() {
    _memoryCache.clear();
    _isLoaded = false;
    _cacheFile = null;
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Provides persistent settings storage for MPRIS seek configurations.
final mprisSeekStorageProvider = Provider<MprisSeekStorage>((ref) {
  return MprisSeekStorage();
});

/// Adapts the canonical [audioHandlerProvider] into [ISoftifySeekableAudioHandler].
final mprisSeekAudioHandlerAdapterProvider =
    Provider<ISoftifySeekableAudioHandler>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return SoftifyAudioHandlerSeekAdapter(handler);
});

/// Notifier managing the `CanSeek` toggle state and disk persistence.
class MprisCanSeekNotifier extends StateNotifier<bool> {
  final MprisSeekStorage _storage;

  MprisCanSeekNotifier(this._storage) : super(true) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.getBool(kMprisSeekPrefKey);
    if (saved != null) {
      state = saved;
    }
  }

  Future<void> toggle() async {
    state = !state;
    await _storage.setBool(kMprisSeekPrefKey, state);
  }

  Future<void> setCanSeek(bool value) async {
    if (state == value) return;
    state = value;
    await _storage.setBool(kMprisSeekPrefKey, value);
  }
}

/// State notifier provider for the `CanSeek` capability flag.
final mprisCanSeekProvider =
    StateNotifierProvider<MprisCanSeekNotifier, bool>((ref) {
  final storage = ref.watch(mprisSeekStorageProvider);
  return MprisCanSeekNotifier(storage);
});

/// Main service provider managing MPRIS D-Bus seek operations.
final mprisSeekHandlerProvider = Provider<MprisSeekHandler>((ref) {
  final audioHandler = ref.watch(mprisSeekAudioHandlerAdapterProvider);
  final canSeek = ref.watch(mprisCanSeekProvider);

  final handler = MprisSeekHandler(
    audioHandler: audioHandler,
    canSeek: canSeek,
  );

  ref.onDispose(() => handler.dispose());
  return handler;
});

/// Stream provider for live MPRIS seek events.
final mprisSeekEventsStreamProvider = StreamProvider<MprisSeekEvent>((ref) {
  final handler = ref.watch(mprisSeekHandlerProvider);
  return handler.seekEvents;
});

/// State provider holding the most recent seek outcome result.
final mprisLastSeekResultProvider = StateProvider<MprisSeekResult?>((ref) => null);

// ============================================================================
// Material 3 Presentation Widgets: MprisSeekStatusTile & MprisSeekCard
// ============================================================================

/// A clean Material 3 ListTile displaying MPRIS D-Bus Seek status and capability toggle.
class MprisSeekStatusTile extends ConsumerWidget {
  const MprisSeekStatusTile({
    super.key,
    this.showDetails = true,
  });

  final bool showDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSeek = ref.watch(mprisCanSeekProvider);
    final handler = ref.watch(mprisSeekHandlerProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canSeek
              ? AppTheme.accent.withOpacity(0.25)
              : Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: canSeek
                ? AppTheme.accent.withOpacity(0.15)
                : Colors.white.withOpacity(0.04),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.swap_horiz_rounded,
            color: canSeek ? AppTheme.accent : AppTheme.textMuted,
            size: 24,
          ),
        ),
        title: Text(
          'MPRIS D-Bus Seek Protocol',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            fontFamily: AppTheme.fontUi,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              canSeek
                  ? 'Active · Responding to Seek & SetPosition D-Bus calls'
                  : 'Disabled · External desktop seek calls are ignored',
              style: TextStyle(
                color: canSeek ? AppTheme.textSecondary : AppTheme.textMuted,
                fontSize: 12.5,
              ),
            ),
            if (showDetails && canSeek) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      kMprisObjectPath,
                      style: TextStyle(
                        color: AppTheme.accentLight,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Track: ${handler.currentTrackId ?? "None"}',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Switch(
          value: canSeek,
          activeColor: AppTheme.accent,
          onChanged: (val) {
            ref.read(mprisCanSeekProvider.notifier).setCanSeek(val);
          },
        ),
      ),
    );
  }
}

/// Advanced desktop settings card with MPRIS seek diagnostic controls.
class MprisSeekCard extends ConsumerWidget {
  const MprisSeekCard({
    super.key,
    this.onFastForward,
    this.onRewind,
  });

  final VoidCallback? onFastForward;
  final VoidCallback? onRewind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSeek = ref.watch(mprisCanSeekProvider);
    final handler = ref.watch(mprisSeekHandlerProvider);
    final lastResult = ref.watch(mprisLastSeekResultProvider);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.desktop_windows_rounded, color: AppTheme.accent, size: 22),
              const SizedBox(width: 10),
              Text(
                'Linux Desktop MPRIS 2 Seek Controls',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppTheme.fontPageTitle,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: canSeek
                      ? Colors.green.withOpacity(0.15)
                      : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  canSeek ? 'CAN SEEK' : 'SEEK LOCKED',
                  style: TextStyle(
                    color: canSeek ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Allows Linux media controllers (GNOME top bar, KDE Plasma tray, Playerctl, Waybar) to scrub tracks via D-Bus.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const Divider(height: 24, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Track Path',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    handler.currentTrackDBusPath,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              Switch(
                value: canSeek,
                activeColor: AppTheme.accent,
                onChanged: (val) {
                  ref.read(mprisCanSeekProvider.notifier).setCanSeek(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.replay_10_rounded, size: 18),
                  label: const Text('-10s Seek'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  onPressed: canSeek
                      ? () async {
                          final res = await handler.handleSeek(-10000000);
                          ref.read(mprisLastSeekResultProvider.notifier).state = res;
                          onRewind?.call();
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.forward_10_rounded, size: 18),
                  label: const Text('+10s Seek'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  onPressed: canSeek
                      ? () async {
                          final res = await handler.handleSeek(10000000);
                          ref.read(mprisLastSeekResultProvider.notifier).state = res;
                          onFastForward?.call();
                        }
                      : null,
                ),
              ),
            ],
          ),
          if (lastResult != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    lastResult.succeeded
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: lastResult.succeeded
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last result: ${lastResult.status.name} · Target: ${lastResult.targetPosition.inSeconds}s (delta: ${lastResult.deltaMicroseconds ~/ 1000}ms)',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
