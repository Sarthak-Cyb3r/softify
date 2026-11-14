import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player/softify_audio_handler.dart';
import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Model: QueueSnapshot
// ============================================================================

/// Represents an immutable snapshot of the playback queue at a given point in time.
///
/// Contains the ordered list of [Track]s, the active playback [currentIndex],
/// an optional human-readable [description] describing the mutation that produced it,
/// and a [timestamp].
@immutable
class QueueSnapshot {
  /// The immutable list of tracks in the queue at snapshot time.
  final List<Track> tracks;

  /// The active playing index within [tracks], or -1 if no track is active.
  final int currentIndex;

  /// An optional user-facing or telemetry description (e.g. "Shuffled queue",
  /// "Removed track 3", "Added album").
  final String? description;

  /// Time when the snapshot was recorded.
  final DateTime timestamp;

  QueueSnapshot({
    required List<Track> tracks,
    this.currentIndex = 0,
    this.description,
    DateTime? timestamp,
  })  : tracks = List<Track>.unmodifiable(tracks),
        timestamp = timestamp ?? DateTime.now();

  /// Constant empty queue snapshot.
  static final QueueSnapshot empty = QueueSnapshot(
    tracks: const [],
    currentIndex: -1,
    description: 'Empty Queue',
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// Total number of tracks in this snapshot.
  int get length => tracks.length;

  /// Whether this snapshot has no tracks.
  bool get isEmpty => tracks.isEmpty;

  /// Whether this snapshot contains one or more tracks.
  bool get isNotEmpty => tracks.isNotEmpty;

  /// The track currently active at [currentIndex], or null if out of range.
  Track? get currentTrack =>
      (currentIndex >= 0 && currentIndex < tracks.length)
          ? tracks[currentIndex]
          : null;

  /// Returns a copy of this snapshot with updated values.
  QueueSnapshot copyWith({
    List<Track>? tracks,
    int? currentIndex,
    String? description,
    DateTime? timestamp,
  }) {
    return QueueSnapshot(
      tracks: tracks ?? this.tracks,
      currentIndex: currentIndex ?? this.currentIndex,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QueueSnapshot) return false;
    if (currentIndex != other.currentIndex) return false;
    if (tracks.length != other.tracks.length) return false;
    for (int i = 0; i < tracks.length; i++) {
      if (tracks[i].id != other.tracks[i].id) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int tracksHash = 0;
    for (final t in tracks) {
      tracksHash = tracksHash ^ t.id.hashCode;
    }
    return Object.hash(currentIndex, tracksHash);
  }

  @override
  String toString() =>
      'QueueSnapshot(tracks: ${tracks.length}, currentIndex: $currentIndex, description: $description)';
}

// ============================================================================
// State: QueueHistoryState
// ============================================================================

/// State representing the undo/redo stack of queue snapshots.
///
/// Implements a bounded history stack capped at [maxHistory] (default 25) steps.
@immutable
class QueueHistoryState {
  /// History snapshots recorded before the current state (available for undo).
  final List<QueueSnapshot> past;

  /// The current active queue snapshot, or null if no snapshot has been pushed.
  final QueueSnapshot? current;

  /// Future snapshots recorded ahead of current (available for redo).
  final List<QueueSnapshot> future;

  /// Maximum capacity of total history snapshots (past + current + future).
  final int maxHistory;

  const QueueHistoryState({
    this.past = const [],
    this.current,
    this.future = const [],
    this.maxHistory = 25,
  });

  /// Whether an undo operation can be performed.
  bool get canUndo => past.isNotEmpty;

  /// Whether a redo operation can be performed.
  bool get canRedo => future.isNotEmpty;

  /// The number of previous snapshots available for undo.
  int get pastCount => past.length;

  /// The number of future snapshots available for redo.
  int get futureCount => future.length;

  /// Current 1-based step position within the active history timeline.
  ///
  /// Returns 0 if no snapshot exists.
  int get currentStep {
    if (current == null && past.isEmpty) return 0;
    return past.length + (current != null ? 1 : 0);
  }

  /// Total number of distinct steps present in the stack.
  int get totalSteps {
    return past.length + (current != null ? 1 : 0) + future.length;
  }

  /// Human-readable step counter label (e.g. "Step 3 / 8" or "0 / 0").
  String get stepCounterLabel {
    if (totalSteps == 0) return '0 / 0';
    return 'Step $currentStep / $totalSteps';
  }

  /// Compact step counter label (e.g. "3 / 8").
  String get shortStepCounterLabel {
    if (totalSteps == 0) return '0 / 0';
    return '$currentStep / $totalSteps';
  }

  /// Complete list of snapshots in historical order: `[...past, current, ...future]`.
  List<QueueSnapshot> get allSnapshots => [
        ...past,
        if (current != null) current!,
        ...future,
      ];

  /// Creates a copy of this state with updated fields.
  QueueHistoryState copyWith({
    List<QueueSnapshot>? past,
    QueueSnapshot? current,
    List<QueueSnapshot>? future,
    int? maxHistory,
  }) {
    return QueueHistoryState(
      past: past ?? this.past,
      current: current ?? this.current,
      future: future ?? this.future,
      maxHistory: maxHistory ?? this.maxHistory,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QueueHistoryState) return false;
    if (maxHistory != other.maxHistory) return false;
    if (current != other.current) return false;
    if (past.length != other.past.length) return false;
    if (future.length != other.future.length) return false;

    for (int i = 0; i < past.length; i++) {
      if (past[i] != other.past[i]) return false;
    }
    for (int i = 0; i < future.length; i++) {
      if (future[i] != other.future[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(past),
        current,
        Object.hashAll(future),
        maxHistory,
      );

  @override
  String toString() =>
      'QueueHistoryState(past: ${past.length}, current: $current, future: ${future.length}, max: $maxHistory)';
}

// ============================================================================
// StateNotifier: QueueHistoryNotifier
// ============================================================================

/// Riverpod [StateNotifier] managing the queue history undo/redo stack.
///
/// Features:
/// - Maximum of 25 history steps (configurable via [maxHistory]).
/// - First-in-first-out pruning when snapshot capacity is reached.
/// - Duplicate consecutive snapshot suppression.
/// - Full undo/redo navigation with state updates.
/// - Optional integration with [SoftifyAudioHandler] via [undoAndApply] and [redoAndApply].
class QueueHistoryNotifier extends StateNotifier<QueueHistoryState> {
  final Ref? _ref;
  final int _maxHistory;
  bool _isApplyingHistoryAction = false;

  QueueHistoryNotifier({
    Ref? ref,
    int maxHistory = 25,
    QueueSnapshot? initialSnapshot,
  })  : _ref = ref,
        _maxHistory = maxHistory,
        super(
          QueueHistoryState(
            past: const [],
            current: initialSnapshot,
            future: const [],
            maxHistory: maxHistory,
          ),
        );

  /// Configured maximum history steps.
  int get maxHistory => _maxHistory;

  /// Whether undo is currently possible.
  bool get canUndo => state.canUndo;

  /// Whether redo is currently possible.
  bool get canRedo => state.canRedo;

  /// Current active snapshot.
  QueueSnapshot? get currentSnapshot => state.current;

  /// Flag indicating whether an undo or redo mutation is actively being applied
  /// to the underlying audio handler.
  bool get isApplyingHistoryAction => _isApplyingHistoryAction;

  /// Pushes a new [snapshot] onto the history stack.
  ///
  /// - If [ignoreDuplicates] is true and [snapshot] matches the current snapshot,
  ///   this call is a no-op.
  /// - When a new snapshot is pushed, any existing [future] (redo history) is discarded.
  /// - If total snapshots exceed [_maxHistory] (25 steps), the oldest snapshot
  ///   in [past] is evicted.
  void pushSnapshot(
    QueueSnapshot snapshot, {
    bool ignoreDuplicates = true,
  }) {
    if (ignoreDuplicates && state.current != null && state.current == snapshot) {
      return;
    }

    if (state.current == null) {
      state = state.copyWith(
        current: snapshot,
        future: const [],
      );
      return;
    }

    final newPast = List<QueueSnapshot>.from(state.past)..add(state.current!);

    // Ensure total snapshots (past + current) does not exceed _maxHistory
    if (newPast.length >= _maxHistory) {
      final excess = newPast.length - (_maxHistory - 1);
      if (excess > 0) {
        newPast.removeRange(0, excess);
      }
    }

    state = state.copyWith(
      past: newPast,
      current: snapshot,
      future: const [],
    );
  }

  /// Convenience method to push a list of tracks with an active playback index.
  void pushTracks(
    List<Track> tracks, {
    int currentIndex = 0,
    String? description,
    bool ignoreDuplicates = true,
  }) {
    pushSnapshot(
      QueueSnapshot(
        tracks: tracks,
        currentIndex: currentIndex,
        description: description,
      ),
      ignoreDuplicates: ignoreDuplicates,
    );
  }

  /// Moves back one step in history.
  ///
  /// Pops the last snapshot from [past], makes it [current], and pushes the
  /// previous [current] onto the head of [future].
  ///
  /// Returns the newly restored [QueueSnapshot], or null if [canUndo] is false.
  QueueSnapshot? undo() {
    if (!canUndo) return null;

    final target = state.past.last;
    final newPast = List<QueueSnapshot>.from(state.past)..removeLast();
    final newFuture = <QueueSnapshot>[
      if (state.current != null) state.current!,
      ...state.future,
    ];

    state = state.copyWith(
      past: newPast,
      current: target,
      future: newFuture,
    );

    return target;
  }

  /// Moves forward one step in history.
  ///
  /// Pops the first snapshot from [future], makes it [current], and pushes the
  /// previous [current] to the tail of [past].
  ///
  /// Returns the newly restored [QueueSnapshot], or null if [canRedo] is false.
  QueueSnapshot? redo() {
    if (!canRedo) return null;

    final target = state.future.first;
    final newFuture = List<QueueSnapshot>.from(state.future)..removeAt(0);
    final newPast = <QueueSnapshot>[
      ...state.past,
      if (state.current != null) state.current!,
    ];

    state = state.copyWith(
      past: newPast,
      current: target,
      future: newFuture,
    );

    return target;
  }

  /// Performs [undo] and applies the restored queue to the given [handler]
  /// or to the resolved [SoftifyAudioHandler] from Riverpod.
  Future<QueueSnapshot?> undoAndApply([SoftifyAudioHandler? handler]) async {
    if (!canUndo) return null;
    final targetHandler = handler ?? _resolveAudioHandler();
    final snapshot = undo();
    if (snapshot != null && targetHandler != null) {
      _isApplyingHistoryAction = true;
      try {
        await targetHandler.setQueue(
          snapshot.tracks,
          startIndex: snapshot.currentIndex >= 0 ? snapshot.currentIndex : 0,
        );
      } finally {
        _isApplyingHistoryAction = false;
      }
    }
    return snapshot;
  }

  /// Performs [redo] and applies the restored queue to the given [handler]
  /// or to the resolved [SoftifyAudioHandler] from Riverpod.
  Future<QueueSnapshot?> redoAndApply([SoftifyAudioHandler? handler]) async {
    if (!canRedo) return null;
    final targetHandler = handler ?? _resolveAudioHandler();
    final snapshot = redo();
    if (snapshot != null && targetHandler != null) {
      _isApplyingHistoryAction = true;
      try {
        await targetHandler.setQueue(
          snapshot.tracks,
          startIndex: snapshot.currentIndex >= 0 ? snapshot.currentIndex : 0,
        );
      } finally {
        _isApplyingHistoryAction = false;
      }
    }
    return snapshot;
  }

  /// Clears past and future undo/redo stacks.
  ///
  /// If [keepCurrent] is true, preserves the current snapshot.
  void clearHistory({bool keepCurrent = true}) {
    state = state.copyWith(
      past: const [],
      current: keepCurrent ? state.current : null,
      future: const [],
    );
  }

  /// Resets the notifier to an empty state with no snapshots.
  void reset() {
    state = QueueHistoryState(
      past: const [],
      current: null,
      future: const [],
      maxHistory: _maxHistory,
    );
  }

  SoftifyAudioHandler? _resolveAudioHandler() {
    if (_ref == null) return null;
    try {
      return _ref.read(audioHandlerProvider);
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Global StateNotifierProvider for [QueueHistoryNotifier].
final queueHistoryProvider =
    StateNotifierProvider<QueueHistoryNotifier, QueueHistoryState>((ref) {
  return QueueHistoryNotifier(ref: ref);
});

/// Selects whether queue history can be undone.
final canUndoQueueProvider = Provider<bool>((ref) {
  return ref.watch(queueHistoryProvider.select((s) => s.canUndo));
});

/// Selects whether queue history can be redone.
final canRedoQueueProvider = Provider<bool>((ref) {
  return ref.watch(queueHistoryProvider.select((s) => s.canRedo));
});

/// Selects the formatted step counter string (e.g. "Step 3 / 8").
final queueHistoryStepProvider = Provider<String>((ref) {
  return ref.watch(queueHistoryProvider.select((s) => s.stepCounterLabel));
});

// ============================================================================
// UI Widget: QueueUndoRedoBar
// ============================================================================

/// Production Material 3 toolbar widget displaying undo and redo buttons alongside
/// a history step counter.
///
/// Supports:
/// - Desktop keyboard shortcuts (Ctrl+Z for undo, Ctrl+Y or Ctrl+Shift+Z for redo).
/// - Tooltips indicating the target snapshot description.
/// - Enabled / disabled visual styling following [AppTokens].
/// - Optional custom callbacks [onUndo] and [onRedo].
class QueueUndoRedoBar extends ConsumerWidget {
  /// Optional custom callback invoked when the undo button is pressed.
  /// If omitted, defaults to [QueueHistoryNotifier.undoAndApply].
  final VoidCallback? onUndo;

  /// Optional custom callback invoked when the redo button is pressed.
  /// If omitted, defaults to [QueueHistoryNotifier.redoAndApply].
  final VoidCallback? onRedo;

  /// Whether to display the history step counter pill.
  final bool showStepCounter;

  /// Whether to display the current snapshot description beneath the buttons.
  final bool showSnapshotDescription;

  /// Whether to render in a compact layout suitable for sidebars or bottom sheets.
  final bool compact;

  /// Custom padding around the bar.
  final EdgeInsetsGeometry? padding;

  /// Optional widget displayed to the left of the undo button.
  final Widget? leading;

  /// Optional widget displayed to the right of the redo button.
  final Widget? trailing;

  const QueueUndoRedoBar({
    super.key,
    this.onUndo,
    this.onRedo,
    this.showStepCounter = true,
    this.showSnapshotDescription = false,
    this.compact = false,
    this.padding,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(queueHistoryProvider);
    final notifier = ref.read(queueHistoryProvider.notifier);
    final tokens = context.tokens;

    final canUndo = state.canUndo;
    final canRedo = state.canRedo;

    void handleUndo() {
      if (!canUndo) return;
      HapticFeedback.lightImpact();
      if (onUndo != null) {
        onUndo!();
      } else {
        notifier.undoAndApply();
      }
    }

    void handleRedo() {
      if (!canRedo) return;
      HapticFeedback.lightImpact();
      if (onRedo != null) {
        onRedo!();
      } else {
        notifier.redoAndApply();
      }
    }

    final undoTooltip = canUndo
        ? 'Undo queue change (Ctrl+Z)${state.past.isNotEmpty && state.past.last.description != null ? ' - ${state.past.last.description}' : ''}'
        : 'Nothing to undo';

    final redoTooltip = canRedo
        ? 'Redo queue change (Ctrl+Y)${state.future.isNotEmpty && state.future.first.description != null ? ' - ${state.future.first.description}' : ''}'
        : 'Nothing to redo';

    final content = Container(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: compact ? 8.0 : 12.0,
            vertical: compact ? 4.0 : 8.0,
          ),
      decoration: BoxDecoration(
        color: tokens.surface.withAlpha(compact ? 0 : 200),
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(
          color: tokens.glassBorder.withAlpha(25),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],

              // Undo Button
              Tooltip(
                message: undoTooltip,
                child: IconButton(
                  key: const Key('queue_undo_button'),
                  icon: const Icon(Icons.undo_rounded),
                  iconSize: compact ? 18 : 20,
                  color: canUndo
                      ? tokens.textPrimary
                      : tokens.textMuted.withAlpha(90),
                  onPressed: canUndo ? handleUndo : null,
                  splashRadius: 20,
                  visualDensity: compact
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                ),
              ),

              const SizedBox(width: 4),

              // Step Counter
              if (showStepCounter) ...[
                QueueHistoryStepCounter(
                  key: const Key('queue_history_step_counter'),
                  stepLabel: state.stepCounterLabel,
                  compact: compact,
                ),
                const SizedBox(width: 4),
              ],

              // Redo Button
              Tooltip(
                message: redoTooltip,
                child: IconButton(
                  key: const Key('queue_redo_button'),
                  icon: const Icon(Icons.redo_rounded),
                  iconSize: compact ? 18 : 20,
                  color: canRedo
                      ? tokens.textPrimary
                      : tokens.textMuted.withAlpha(90),
                  onPressed: canRedo ? handleRedo : null,
                  splashRadius: 20,
                  visualDensity: compact
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                ),
              ),

              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          if (showSnapshotDescription &&
              state.current?.description != null &&
              state.current!.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                state.current!.description!,
                key: const Key('queue_history_description_text'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );

    // Provide keyboard shortcuts for desktop Linux productivity
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): handleUndo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): handleRedo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            handleRedo,
      },
      child: content,
    );
  }
}

// ============================================================================
// UI Widget: QueueHistoryStepCounter
// ============================================================================

/// Compact visual pill badge displaying the current step count (e.g. "Step 2 / 5").
class QueueHistoryStepCounter extends StatelessWidget {
  final String stepLabel;
  final bool compact;

  const QueueHistoryStepCounter({
    super.key,
    required this.stepLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6.0 : 10.0,
        vertical: compact ? 2.0 : 4.0,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceHighlight,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: tokens.glassBorder.withAlpha(30),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: compact ? 12 : 14,
            color: tokens.accent,
          ),
          const SizedBox(width: 4),
          Text(
            stepLabel,
            key: const Key('queue_history_step_counter_text'),
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
