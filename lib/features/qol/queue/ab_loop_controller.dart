import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player/softify_audio_handler.dart';
import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Constants & Configuration
// ============================================================================

/// Minimum allowed duration between Point A and Point B (500ms).
const Duration kDefaultMinLoopDuration = Duration(milliseconds: 500);

/// Debounce cooldown to prevent audio engine re-seek loops.
const Duration kDefaultSeekDebounce = Duration(milliseconds: 250);

/// Persistence key for auto-seek on setting Point B.
const String kAbLoopAutoSeekPrefKey = 'ab_loop_auto_seek_on_set_b';

/// Persistence key for clearing loop on track change.
const String kAbLoopClearOnTrackChangeKey = 'ab_loop_clear_on_track_change';

// ============================================================================
// Model: AbLoopState
// ============================================================================

/// Immutable state representation for the A-B Section Loop Controller.
@immutable
class AbLoopState {
  /// Start timestamp of the loop section.
  final Duration? pointA;

  /// End timestamp of the loop section.
  final Duration? pointB;

  /// Whether loop repetition is enabled by user.
  final bool isEnabled;

  /// Number of times the loop section has repeated.
  final int loopIterationCount;

  /// Minimum duration between Point A and Point B.
  final Duration minLoopDuration;

  /// Whether an auto-seek back to Point A is currently in-flight.
  final bool isSeeking;

  /// Timestamp of the most recent auto-seek event.
  final DateTime? lastSeekTime;

  /// Whether to automatically clear loop points when the playing track changes.
  final bool clearOnTrackChange;

  /// The track ID associated with this loop.
  final String? activeTrackId;

  const AbLoopState({
    this.pointA,
    this.pointB,
    this.isEnabled = true,
    this.loopIterationCount = 0,
    this.minLoopDuration = kDefaultMinLoopDuration,
    this.isSeeking = false,
    this.lastSeekTime,
    this.clearOnTrackChange = true,
    this.activeTrackId,
  });

  /// True if Point A has been established.
  bool get hasPointA => pointA != null;

  /// True if Point B has been established.
  bool get hasPointB => pointB != null;

  /// True if both loop points have been set.
  bool get isConfigured => pointA != null && pointB != null;

  /// True if both points are set and Point B > Point A + minLoopDuration.
  bool get isValid =>
      pointA != null &&
      pointB != null &&
      (pointB! - pointA!) >= minLoopDuration;

  /// True if loop points are valid and looping is currently enabled.
  bool get isLoopingActive => isEnabled && isValid;

  /// Total duration of the active loop section (or Duration.zero if not valid).
  Duration get loopDuration {
    if (pointA != null && pointB != null && pointB! > pointA!) {
      return pointB! - pointA!;
    }
    return Duration.zero;
  }

  /// Formatted timestamp for Point A (e.g. "01:23" or "--:--").
  String get formattedPointA => AbLoopFormatter.formatTimestamp(pointA);

  /// Formatted timestamp for Point B (e.g. "01:45" or "--:--").
  String get formattedPointB => AbLoopFormatter.formatTimestamp(pointB);

  /// Formatted duration of the loop section (e.g. "22s" or "--").
  String get formattedDuration => AbLoopFormatter.formatDuration(loopDuration);

  /// Calculates playback progress through the loop as a fraction between 0.0 and 1.0.
  double progressWithinLoop(Duration currentPosition) {
    if (!isValid) return 0.0;
    final start = pointA!.inMilliseconds;
    final end = pointB!.inMilliseconds;
    final current = currentPosition.inMilliseconds;
    if (current <= start) return 0.0;
    if (current >= end) return 1.0;
    return (current - start) / (end - start);
  }

  AbLoopState copyWith({
    Duration? pointA,
    bool clearPointA = false,
    Duration? pointB,
    bool clearPointB = false,
    bool? isEnabled,
    int? loopIterationCount,
    Duration? minLoopDuration,
    bool? isSeeking,
    DateTime? lastSeekTime,
    bool? clearOnTrackChange,
    String? activeTrackId,
    bool clearActiveTrackId = false,
  }) {
    return AbLoopState(
      pointA: clearPointA ? null : (pointA ?? this.pointA),
      pointB: clearPointB ? null : (pointB ?? this.pointB),
      isEnabled: isEnabled ?? this.isEnabled,
      loopIterationCount: loopIterationCount ?? this.loopIterationCount,
      minLoopDuration: minLoopDuration ?? this.minLoopDuration,
      isSeeking: isSeeking ?? this.isSeeking,
      lastSeekTime: lastSeekTime ?? this.lastSeekTime,
      clearOnTrackChange: clearOnTrackChange ?? this.clearOnTrackChange,
      activeTrackId: clearActiveTrackId
          ? null
          : (activeTrackId ?? this.activeTrackId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbLoopState &&
          runtimeType == other.runtimeType &&
          pointA == other.pointA &&
          pointB == other.pointB &&
          isEnabled == other.isEnabled &&
          loopIterationCount == other.loopIterationCount &&
          minLoopDuration == other.minLoopDuration &&
          isSeeking == other.isSeeking &&
          clearOnTrackChange == other.clearOnTrackChange &&
          activeTrackId == other.activeTrackId;

  @override
  int get hashCode => Object.hash(
        pointA,
        pointB,
        isEnabled,
        loopIterationCount,
        minLoopDuration,
        isSeeking,
        clearOnTrackChange,
        activeTrackId,
      );

  @override
  String toString() =>
      'AbLoopState(pointA: $formattedPointA, pointB: $formattedPointB, '
      'active: $isLoopingActive, loops: $loopIterationCount)';
}

// ============================================================================
// Pure Formatter & Math Helpers
// ============================================================================

/// Pure helper providing timestamp formatting and clamping for loop controllers.
class AbLoopFormatter {
  const AbLoopFormatter._();

  /// Formats [duration] into mm:ss or hh:mm:ss. Returns "--:--" if null.
  static String formatTimestamp(
    Duration? duration, {
    bool includeMilliseconds = false,
  }) {
    if (duration == null) return '--:--';
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final String base;
    if (hours > 0) {
      base =
          '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      base =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    if (includeMilliseconds) {
      final millis = (duration.inMilliseconds % 1000) ~/ 100;
      return '$base.$millis';
    }
    return base;
  }

  /// Formats loop span into human readable shorthand (e.g. "14.5s", "2m 10s").
  static String formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--';
    final totalMs = duration.inMilliseconds;
    if (totalMs < 60000) {
      final seconds = (totalMs / 1000).toStringAsFixed(1);
      return '${seconds}s';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}

// ============================================================================
// SharedPreferences Persistence (Self-Contained)
// ============================================================================

/// Self-contained key-value preferences engine supporting mock injection for testing.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _storageFile;

  SharedPreferences._(this._store, this._storageFile);

  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) return _instance!;
    if (_mockInitialValues != null) {
      _instance = SharedPreferences._(
        Map<String, Object>.from(_mockInitialValues!),
        null,
      );
      return _instance!;
    }

    final store = <String, Object>{};
    File? file;
    try {
      final dir = Directory.systemTemp;
      file = File('${dir.path}/softify_ab_loop_prefs.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              if (value != null) store[key.toString()] = value as Object;
            });
          }
        }
      }
    } catch (_) {}

    _instance = SharedPreferences._(store, file);
    return _instance!;
  }

  bool? getBool(String key) {
    final v = _store[key];
    return v is bool ? v : null;
  }

  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    if (_storageFile == null) return;
    try {
      await _storageFile!.writeAsString(jsonEncode(_store));
    } catch (_) {}
  }
}

// ============================================================================
// Position Monitor
// ============================================================================

/// Monitors playback position updates and auto-seeks back to Point A when
/// playback reaches or exceeds Point B.
class AbLoopPositionMonitor {
  final AbLoopController controller;
  StreamSubscription<Duration>? _subscription;
  bool _isDisposed = false;

  AbLoopPositionMonitor({required this.controller});

  /// Whether the monitor is currently attached to an active position stream.
  bool get isMonitoring => _subscription != null;

  /// Attaches the monitor to a given [stream].
  void attach(Stream<Duration> stream) {
    _subscription?.cancel();
    _subscription = stream.listen((position) {
      if (!_isDisposed) {
        checkPosition(position);
      }
    });
  }

  /// Detaches the monitor from stream updates.
  void detach() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Checks the incoming [position] against active loop boundaries.
  /// Auto-seeks back to Point A if position >= Point B.
  Future<bool> checkPosition(Duration position) {
    return controller.checkPosition(position);
  }

  /// Disposes active subscriptions.
  void dispose() {
    _isDisposed = true;
    detach();
  }
}

// ============================================================================
// Controller: AbLoopController (A-B Loop Manager)
// ============================================================================

/// Primary A-B Section Loop Controller managing loop points, position monitoring,
/// auto-seeking, and loop repetition count.
class AbLoopController extends StateNotifier<AbLoopState> {
  final Ref? _ref;
  final SoftifyAudioHandler? _customHandler;
  final Future<void> Function(Duration position)? _onSeek;
  final Duration Function()? _currentPositionGetter;
  final Stream<Duration>? _positionStreamOverride;
  final Stream<Track?>? _trackStreamOverride;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Track?>? _trackSubscription;

  late final AbLoopPositionMonitor positionMonitor;

  bool _isSeeking = false;
  DateTime? _lastSeekTime;
  bool _autoSeekOnSetB = true;

  AbLoopController({
    Ref? ref,
    SoftifyAudioHandler? customHandler,
    Future<void> Function(Duration position)? onSeek,
    Duration Function()? currentPositionGetter,
    Stream<Duration>? positionStreamOverride,
    Stream<Track?>? trackStreamOverride,
    Duration minLoopDuration = kDefaultMinLoopDuration,
    bool clearOnTrackChange = true,
  })  : _ref = ref,
        _customHandler = customHandler,
        _onSeek = onSeek,
        _currentPositionGetter = currentPositionGetter,
        _positionStreamOverride = positionStreamOverride,
        _trackStreamOverride = trackStreamOverride,
        super(AbLoopState(
          minLoopDuration: minLoopDuration,
          clearOnTrackChange: clearOnTrackChange,
        )) {
    positionMonitor = AbLoopPositionMonitor(controller: this);
    _initStreams();
    _loadPreferences();
  }

  SoftifyAudioHandler? get _handler {
    if (_customHandler != null) return _customHandler;
    if (_ref != null) {
      try {
        return _ref.read(audioHandlerProvider);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Current playback position read from custom provider or audio handler.
  Duration get currentPosition {
    if (_currentPositionGetter != null) {
      return _currentPositionGetter!();
    }
    final h = _handler;
    if (h != null) {
      return h.position;
    }
    return Duration.zero;
  }

  /// Whether section looping is actively running.
  bool get isLoopingActive => state.isLoopingActive;

  /// Current Point A timestamp.
  Duration? get pointA => state.pointA;

  /// Current Point B timestamp.
  Duration? get pointB => state.pointB;

  /// Number of times the active loop has executed.
  int get loopIterationCount => state.loopIterationCount;

  void _initStreams() {
    final posStream = _positionStreamOverride ?? _handler?.positionStream;
    if (posStream != null) {
      _positionSubscription = posStream.listen(checkPosition);
    }

    final trackStream = _trackStreamOverride ?? _handler?.currentTrackStream;
    if (trackStream != null) {
      _trackSubscription = trackStream.listen(_onTrackChanged);
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoSeekOnSetB = prefs.getBool(kAbLoopAutoSeekPrefKey) ?? true;
      final clearOnChange =
          prefs.getBool(kAbLoopClearOnTrackChangeKey) ?? state.clearOnTrackChange;
      if (mounted) {
        state = state.copyWith(clearOnTrackChange: clearOnChange);
      }
    } catch (_) {}
  }

  void _onTrackChanged(Track? track) {
    if (track == null) return;
    if (state.activeTrackId != null && state.activeTrackId != track.id) {
      if (state.clearOnTrackChange) {
        clearLoop();
      }
    }
    if (state.activeTrackId != track.id) {
      state = state.copyWith(activeTrackId: track.id);
    }
  }

  /// Sets Point A to [position]. If [position] is null, captures [currentPosition].
  ///
  /// If Point B is already established and [position] >= Point B, Point B is
  /// automatically cleared so the user can establish a fresh end boundary.
  bool setPointA([Duration? position]) {
    var pos = position ?? currentPosition;
    if (pos < Duration.zero) pos = Duration.zero;

    final shouldClearB = state.pointB != null && pos >= state.pointB!;

    state = state.copyWith(
      pointA: pos,
      clearPointB: shouldClearB,
      loopIterationCount: 0,
      isEnabled: true,
    );
    return true;
  }

  /// Sets Point B to [position]. If [position] is null, captures [currentPosition].
  ///
  /// Requirements:
  /// - If Point A is not yet set, Point A is automatically set to [Duration.zero].
  /// - [position] must be strictly greater than Point A + [minLoopDuration].
  ///
  /// Returns true if Point B was accepted, false otherwise.
  bool setPointB([Duration? position]) {
    var pos = position ?? currentPosition;
    if (pos < Duration.zero) pos = Duration.zero;

    var startA = state.pointA;
    if (startA == null) {
      startA = Duration.zero;
    }

    // Validation: Point B must exceed Point A by at least minLoopDuration
    if (pos <= startA || (pos - startA) < state.minLoopDuration) {
      return false;
    }

    state = state.copyWith(
      pointA: startA,
      pointB: pos,
      isEnabled: true,
      loopIterationCount: 0,
    );

    // If current playback is already beyond Point B, jump back to Point A
    if (_autoSeekOnSetB && currentPosition >= pos) {
      seekToPointA();
    }

    return true;
  }

  /// Sets both Point A and Point B simultaneously.
  bool setLoopRange(Duration start, Duration end) {
    if (end <= start || (end - start) < state.minLoopDuration) {
      return false;
    }
    state = state.copyWith(
      pointA: start < Duration.zero ? Duration.zero : start,
      pointB: end,
      isEnabled: true,
      loopIterationCount: 0,
    );
    return true;
  }

  /// Completely clears loop points A and B, resetting iteration count.
  void clearLoop() {
    state = state.copyWith(
      clearPointA: true,
      clearPointB: true,
      loopIterationCount: 0,
      isSeeking: false,
    );
  }

  /// Clears only Point A.
  void clearPointA() {
    state = state.copyWith(
      clearPointA: true,
      loopIterationCount: 0,
    );
  }

  /// Clears only Point B.
  void clearPointB() {
    state = state.copyWith(
      clearPointB: true,
      loopIterationCount: 0,
    );
  }

  /// Toggles whether loop repetition is active when both points are configured.
  void toggleLooping([bool? enabled]) {
    final next = enabled ?? !state.isEnabled;
    state = state.copyWith(isEnabled: next);
  }

  /// Explicitly sets whether looping is enabled.
  void setLoopingEnabled(bool enabled) {
    state = state.copyWith(isEnabled: enabled);
  }

  /// Fine-tunes Point A by [delta] (e.g. `+Duration(milliseconds: 100)`).
  bool adjustPointA(Duration delta) {
    if (state.pointA == null) return false;
    var newA = state.pointA! + delta;
    if (newA < Duration.zero) newA = Duration.zero;

    if (state.pointB != null) {
      final maxA = state.pointB! - state.minLoopDuration;
      if (newA > maxA) return false;
    }

    state = state.copyWith(pointA: newA);
    return true;
  }

  /// Fine-tunes Point B by [delta] (e.g. `-Duration(milliseconds: 100)`).
  bool adjustPointB(Duration delta, [Duration? maxDuration]) {
    if (state.pointB == null) return false;
    var newB = state.pointB! + delta;

    if (state.pointA != null) {
      final minB = state.pointA! + state.minLoopDuration;
      if (newB < minB) return false;
    }

    if (maxDuration != null && newB > maxDuration) {
      newB = maxDuration;
    }

    state = state.copyWith(pointB: newB);
    return true;
  }

  /// Seeks playback to Point A immediately.
  Future<void> seekToPointA() async {
    if (state.pointA != null) {
      await seek(state.pointA!);
    }
  }

  /// Seeks playback to Point B immediately.
  Future<void> seekToPointB() async {
    if (state.pointB != null) {
      await seek(state.pointB!);
    }
  }

  /// Resets loop iteration counter to 0.
  void resetLoopCount() {
    state = state.copyWith(loopIterationCount: 0);
  }

  /// Dispatches seek request to either custom callback or audio handler.
  Future<void> seek(Duration position) async {
    if (_onSeek != null) {
      await _onSeek!(position);
      return;
    }
    final handler = _handler;
    if (handler != null) {
      await handler.seek(position);
    }
  }

  /// Core position monitor check.
  ///
  /// Evaluates if [position] >= Point B when loop is active.
  /// If threshold is reached, automatically seeks back to Point A with debounce.
  ///
  /// Returns true if an auto-seek was triggered, false otherwise.
  Future<bool> checkPosition(Duration position) async {
    if (!state.isLoopingActive) return false;
    final startA = state.pointA;
    final endB = state.pointB;
    if (startA == null || endB == null) return false;

    // Check if position reaches or exceeds Point B
    if (position >= endB) {
      if (_isSeeking) return false;

      final now = DateTime.now();
      if (_lastSeekTime != null &&
          now.difference(_lastSeekTime!) < kDefaultSeekDebounce) {
        return false;
      }

      _isSeeking = true;
      _lastSeekTime = now;

      final nextCount = state.loopIterationCount + 1;
      state = state.copyWith(
        loopIterationCount: nextCount,
        isSeeking: true,
        lastSeekTime: now,
      );

      try {
        await seek(startA);
        return true;
      } finally {
        Future.delayed(const Duration(milliseconds: 180), () {
          _isSeeking = false;
          if (mounted) {
            state = state.copyWith(isSeeking: false);
          }
        });
      }
    }

    return false;
  }

  @override
  void dispose() {
    positionMonitor.dispose();
    _positionSubscription?.cancel();
    _trackSubscription?.cancel();
    super.dispose();
  }
}

/// Alias for `AbLoopController` to satisfy manager naming requirements.
typedef AbLoopManager = AbLoopController;

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Primary provider for the A-B Section Loop Controller.
final abLoopControllerProvider =
    StateNotifierProvider<AbLoopController, AbLoopState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  final controller = AbLoopController(
    ref: ref,
    customHandler: handler,
  );
  return controller;
});

/// Convenience provider for whether A-B looping is currently active.
final isAbLoopingActiveProvider = Provider<bool>((ref) {
  return ref.watch(abLoopControllerProvider.select((s) => s.isLoopingActive));
});

/// Convenience provider observing the current [AbLoopState].
final abLoopStateProvider = Provider<AbLoopState>((ref) {
  return ref.watch(abLoopControllerProvider);
});

// ============================================================================
// UI: AbLoopFloatingWidget
// ============================================================================

/// Floating Material 3 widget providing Set A, Set B, and Clear chips for
/// interactive A-B section looping on desktop and mobile.
class AbLoopFloatingWidget extends ConsumerStatefulWidget {
  /// Optional injected controller for testing and overrides.
  final AbLoopController? controller;

  /// Optional current position override.
  final Duration? currentPosition;

  /// Optional close / dismiss callback.
  final VoidCallback? onClose;

  /// Outer margin.
  final EdgeInsetsGeometry? margin;

  /// Inner padding.
  final EdgeInsetsGeometry? padding;

  /// Whether to render a mini timeline progress indicator between A and B.
  final bool showProgressIndicator;

  /// Whether to show the loop iteration count badge.
  final bool showLoopCounter;

  /// Whether to show fine-tune nudge buttons (+/- 0.5s).
  final bool showFineTuneControls;

  /// Compact single-row layout mode.
  final bool isCompact;

  const AbLoopFloatingWidget({
    super.key,
    this.controller,
    this.currentPosition,
    this.onClose,
    this.margin,
    this.padding,
    this.showProgressIndicator = true,
    this.showLoopCounter = true,
    this.showFineTuneControls = false,
    this.isCompact = false,
  });

  @override
  ConsumerState<AbLoopFloatingWidget> createState() =>
      _AbLoopFloatingWidgetState();
}

class _AbLoopFloatingWidgetState extends ConsumerState<AbLoopFloatingWidget> {
  VoidCallback? _controllerListenerRemove;

  @override
  void initState() {
    super.initState();
    _bindCustomController();
  }

  @override
  void didUpdateWidget(covariant AbLoopFloatingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controllerListenerRemove?.call();
      _controllerListenerRemove = null;
      _bindCustomController();
    }
  }

  void _bindCustomController() {
    if (widget.controller != null) {
      _controllerListenerRemove = widget.controller!.addListener((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _controllerListenerRemove?.call();
    super.dispose();
  }

  AbLoopController _resolveController() {
    return widget.controller ?? ref.read(abLoopControllerProvider.notifier);
  }

  AbLoopState _resolveState() {
    if (widget.controller != null) {
      return widget.controller!.state;
    }
    return ref.watch(abLoopControllerProvider);
  }

  Duration _resolvePosition(AbLoopController controller) {
    if (widget.currentPosition != null) {
      return widget.currentPosition!;
    }
    if (widget.controller != null) {
      return widget.controller!.currentPosition;
    }
    final livePos = ref.watch(positionStreamProvider).valueOrNull;
    return livePos ?? controller.currentPosition;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final controller = _resolveController();
    final state = _resolveState();
    final currentPos = _resolvePosition(controller);

    if (widget.isCompact) {
      return _buildCompactBar(context, tokens, controller, state, currentPos);
    }

    return _buildExpandedCard(context, tokens, controller, state, currentPos);
  }

  // --------------------------------------------------------------------------
  // Expanded Card Layout
  // --------------------------------------------------------------------------

  Widget _buildExpandedCard(
    BuildContext context,
    AppTokens tokens,
    AbLoopController controller,
    AbLoopState state,
    Duration currentPos,
  ) {
    final hasA = state.hasPointA;
    final hasB = state.hasPointB;
    final isActive = state.isLoopingActive;

    return Container(
      margin: widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: widget.padding ?? const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(
          color: isActive
              ? tokens.accent.withAlpha(80)
              : tokens.glassBorder.withAlpha(40),
          width: 1.0,
        ),
        boxShadow: tokens.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          _buildHeaderRow(context, tokens, controller, state),
          const SizedBox(height: 10),

          // Chips Row: Set A, Set B, Clear
          _buildChipsRow(context, tokens, controller, state, currentPos),

          // Active Timeline Progress
          if (widget.showProgressIndicator && isActive) ...[
            const SizedBox(height: 10),
            _buildTimelineProgress(tokens, state, currentPos),
          ],

          // Optional Fine Tune Row
          if (widget.showFineTuneControls && (hasA || hasB)) ...[
            const SizedBox(height: 8),
            _buildFineTuneRow(tokens, controller, state),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Compact Bar Layout
  // --------------------------------------------------------------------------

  Widget _buildCompactBar(
    BuildContext context,
    AppTokens tokens,
    AbLoopController controller,
    AbLoopState state,
    Duration currentPos,
  ) {
    return Container(
      margin: widget.margin ??
          const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(
          color: state.isLoopingActive
              ? tokens.accent.withAlpha(90)
              : tokens.glassBorder.withAlpha(40),
          width: 1.0,
        ),
        boxShadow: tokens.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat_one_rounded,
            size: 16,
            color: state.isLoopingActive ? tokens.accent : tokens.textMuted,
          ),
          const SizedBox(width: 6),
          _buildSetAChip(tokens, controller, state, currentPos, compact: true),
          const SizedBox(width: 4),
          _buildSetBChip(tokens, controller, state, currentPos, compact: true),
          const SizedBox(width: 4),
          _buildClearChip(tokens, controller, state, compact: true),
          if (widget.onClose != null) ...[
            const SizedBox(width: 2),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 14),
              color: tokens.textMuted,
              splashRadius: 14,
              onPressed: widget.onClose,
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Header Row with Title, Badge, and Loop Toggle
  // --------------------------------------------------------------------------

  Widget _buildHeaderRow(
    BuildContext context,
    AppTokens tokens,
    AbLoopController controller,
    AbLoopState state,
  ) {
    return Row(
      children: [
        Icon(
          Icons.repeat_one_rounded,
          size: 18,
          color: state.isLoopingActive ? tokens.accent : tokens.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          'A-B Loop',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 8),
        _buildStatusBadge(tokens, state),
        const Spacer(),
        if (state.isValid)
          IconButton(
            key: const Key('ab_loop_toggle_button'),
            tooltip: state.isEnabled ? 'Pause Loop' : 'Resume Loop',
            icon: Icon(
              state.isEnabled
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded,
              size: 20,
              color: state.isEnabled ? tokens.accent : tokens.textMuted,
            ),
            splashRadius: 18,
            onPressed: () => controller.toggleLooping(),
          ),
        if (widget.onClose != null)
          IconButton(
            key: const Key('ab_loop_close_button'),
            tooltip: 'Close A-B Loop Panel',
            icon: const Icon(Icons.close_rounded, size: 18),
            color: tokens.textMuted,
            splashRadius: 16,
            onPressed: widget.onClose,
          ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Status Badge
  // --------------------------------------------------------------------------

  Widget _buildStatusBadge(AppTokens tokens, AbLoopState state) {
    final String label;
    final Color color;
    final Color bg;

    if (state.isLoopingActive) {
      label = widget.showLoopCounter && state.loopIterationCount > 0
          ? 'Active (${state.loopIterationCount}x)'
          : 'Active';
      color = tokens.accent;
      bg = tokens.accent.withAlpha(30);
    } else if (state.hasPointA && !state.hasPointB) {
      label = 'Set End (B)';
      color = Colors.amber;
      bg = Colors.amber.withAlpha(30);
    } else if (state.isValid && !state.isEnabled) {
      label = 'Paused';
      color = tokens.textMuted;
      bg = tokens.surfaceHighlight;
    } else {
      label = 'Off';
      color = tokens.textMuted;
      bg = tokens.surfaceHighlight;
    }

    return Container(
      key: const Key('ab_loop_status_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Chips Row: Set A, Set B, Clear
  // --------------------------------------------------------------------------

  Widget _buildChipsRow(
    BuildContext context,
    AppTokens tokens,
    AbLoopController controller,
    AbLoopState state,
    Duration currentPos,
  ) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 6.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildSetAChip(tokens, controller, state, currentPos),
        _buildSetBChip(tokens, controller, state, currentPos),
        _buildClearChip(tokens, controller, state),
        if (state.hasPointA)
          _buildQuickSeekAButton(tokens, controller, state),
        if (state.hasPointB)
          _buildQuickSeekBButton(tokens, controller, state),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Set A Chip
  // --------------------------------------------------------------------------

  Widget _buildSetAChip(
    AppTokens tokens,
    AbLoopController controller,
    AbLoopState state,
    Duration currentPos, {
    bool compact = false,
  }) {
    final hasA = state.hasPointA;

    return ActionChip(
      key: const Key('ab_loop_set_a_chip'),
      avatar: Icon(
        Icons.flag_rounded,
        size: compact ? 14 : 16,
        color: hasA ? tokens.accent : tokens.textMuted,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Set A'),
          if (hasA) ...[
            const SizedBox(width: 4),
            Text(
              '(${state.formattedPointA})',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tokens.accent,
              ),
            ),
          ],
        ],
      ),
      tooltip: hasA
          ? 'Point A is set to ${state.formattedPointA}. Tap to update to current position.'
          : 'Set Point A (start of loop) to current playback position',
      backgroundColor:
          hasA ? tokens.accent.withAlpha(30) : tokens.surfaceHighlight,
      side: BorderSide(
        color: hasA ? tokens.accent : tokens.glassBorder.withAlpha(40),
        width: hasA ? 1.4 : 0.8,
      ),
      visualDensity:
          compact ? VisualDensity.compact : VisualDensity.standard,
      onPressed: () => controller.setPointA(currentPos),
    );
  }

  // --------------------------------------------------------------------------
  // Set B Chip
  // --------------------------------------------------------------------------

  Widget _buildSetBChip(
    AppTokens tokens,
    AbLoopController controller,
    AbLoopState state,
    Duration currentPos, {
    bool compact = false,
  }) {
    final hasB = state.hasPointB;

    return ActionChip(
      key: const Key('ab_loop_set_b_chip'),
      avatar: Icon(
        Icons.flag_circle_rounded,
        size: compact ? 14 : 16,
        color: hasB ? tokens.accent : tokens.textMuted,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Set B'),
          if (hasB) ...[
            const SizedBox(width: 4),
            Text(
              '(${state.formattedPointB})',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tokens.accent,
              ),
            ),
          ],
        ],
      ),
      tooltip: hasB
          ? 'Point B is set to ${state.formattedPointB}. Tap to update to current position.'
          : 'Set Point B (end of loop) to current playback position',
      backgroundColor:
          hasB ? tokens.accent.withAlpha(30) : tokens.surfaceHighlight,
      side: BorderSide(
        color: hasB ? tokens.accent : tokens.glassBorder.withAlpha(40),
        width: hasB ? 1.4 : 0.8,
      ),
      visualDensity:
          compact ? VisualDensity.compact : VisualDensity.standard,
      onPressed: () => controller.setPointB(currentPos),
    );
  }

  // --------------------------------------------------------------------------
  // Clear Chip
  // --------------------------------------------------------------------------

  Widget _buildClearChip(
    AppTokens tokens,
    AbLoopController controller,
    AbLoopState state, {
    bool compact = false,
  }) {
    final canClear = state.hasPointA || state.hasPointB;

    return ActionChip(
      key: const Key('ab_loop_clear_chip'),
      avatar: Icon(
        Icons.close_rounded,
        size: compact ? 14 : 16,
        color: canClear ? tokens.error : tokens.textMuted.withAlpha(90),
      ),
      label: Text(
        'Clear',
        style: TextStyle(
          color: canClear ? tokens.textPrimary : tokens.textMuted,
        ),
      ),
      tooltip: 'Clear loop points A and B',
      backgroundColor: tokens.surfaceHighlight,
      side: BorderSide(
        color: tokens.glassBorder.withAlpha(30),
        width: 0.8,
      ),
      visualDensity:
          compact ? VisualDensity.compact : VisualDensity.standard,
      onPressed: () => controller.clearLoop(),
    );
  }

  // --------------------------------------------------------------------------
  // Quick Jump to A / B Buttons
  // --------------------------------------------------------------------------

  Widget _buildQuickSeekAButton(
    AppTokens tokens,
    AbLoopController controller,
    AbLoopState state,
  ) {
    return ActionChip(
      key: const Key('ab_loop_jump_a_chip'),
      avatar: const Icon(Icons.skip_previous_rounded, size: 14),
      label: const Text('Jump to A'),
      visualDensity: VisualDensity.compact,
      backgroundColor: tokens.surfaceHighlight,
      side: BorderSide(color: tokens.glassBorder.withAlpha(30), width: 0.8),
      onPressed: () => controller.seekToPointA(),
    );
  }

  Widget _buildQuickSeekBButton(
    AppTokens tokens,
    AbLoopController controller,
    AbLoopState state,
  ) {
    return ActionChip(
      key: const Key('ab_loop_jump_b_chip'),
      avatar: const Icon(Icons.skip_next_rounded, size: 14),
      label: const Text('Jump to B'),
      visualDensity: VisualDensity.compact,
      backgroundColor: tokens.surfaceHighlight,
      side: BorderSide(color: tokens.glassBorder.withAlpha(30), width: 0.8),
      onPressed: () => controller.seekToPointB(),
    );
  }

  // --------------------------------------------------------------------------
  // Timeline Progress Widget
  // --------------------------------------------------------------------------

  Widget _buildTimelineProgress(
    AppTokens tokens,
    AbLoopState state,
    Duration currentPos,
  ) {
    final progress = state.progressWithinLoop(currentPos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'A: ${state.formattedPointA}',
              style: TextStyle(
                fontSize: 11,
                color: tokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Loop: ${state.formattedDuration}',
              style: TextStyle(
                fontSize: 11,
                color: tokens.textMuted,
              ),
            ),
            Text(
              'B: ${state.formattedPointB}',
              style: TextStyle(
                fontSize: 11,
                color: tokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: tokens.surfaceHighlight,
            valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
            minHeight: 4.0,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Fine Tune Controls
  // --------------------------------------------------------------------------

  Widget _buildFineTuneRow(
    AppTokens tokens,
    AbLoopController controller,
    AbLoopState state,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state.hasPointA) ...[
          _buildNudgeButton(
            tokens,
            label: '-0.5s A',
            onTap: () => controller
                .adjustPointA(const Duration(milliseconds: -500)),
          ),
          const SizedBox(width: 4),
          _buildNudgeButton(
            tokens,
            label: '+0.5s A',
            onTap: () =>
                controller.adjustPointA(const Duration(milliseconds: 500)),
          ),
          const SizedBox(width: 12),
        ],
        if (state.hasPointB) ...[
          _buildNudgeButton(
            tokens,
            label: '-0.5s B',
            onTap: () => controller
                .adjustPointB(const Duration(milliseconds: -500)),
          ),
          const SizedBox(width: 4),
          _buildNudgeButton(
            tokens,
            label: '+0.5s B',
            onTap: () =>
                controller.adjustPointB(const Duration(milliseconds: 500)),
          ),
        ],
      ],
    );
  }

  Widget _buildNudgeButton(
    AppTokens tokens, {
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: tokens.surfaceHighlight,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: tokens.glassBorder.withAlpha(25),
            width: 0.6,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
