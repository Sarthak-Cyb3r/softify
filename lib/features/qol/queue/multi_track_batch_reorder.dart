import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/player/softify_audio_handler.dart';
import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/shared/app_surface.dart';

// ============================================================================
// Constants & SharedPreferences Keys
// ============================================================================

/// SharedPreferences key for preserving current track when moving selected to top.
const String kBatchReorderPreserveCurrentKey =
    'softify_queue_batch_preserve_current_track';

/// SharedPreferences key for requiring confirmation before batch deletion.
const String kBatchReorderConfirmDeleteKey =
    'softify_queue_batch_confirm_delete';

// ============================================================================
// SharedPreferences Persistence Storage Layer
// ============================================================================

/// Lightweight disk-backed and memory-cached storage interface for queue
/// batch reorder preferences.
class QueueBatchReorderPrefsStorage {
  static final QueueBatchReorderPrefsStorage _instance =
      QueueBatchReorderPrefsStorage._internal();
  factory QueueBatchReorderPrefsStorage() => _instance;
  QueueBatchReorderPrefsStorage._internal();

  static Map<String, Object>? _mockInitialValues;

  Map<String, dynamic> _memoryCache = {};
  bool _isLoaded = false;
  File? _cacheFile;

  /// Sets mock initial values for unit and widget tests.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance._memoryCache = Map<String, dynamic>.from(values);
    _instance._isLoaded = true;
  }

  /// Resets the cached store and mock environment.
  static void reset() {
    _mockInitialValues = null;
    _instance._memoryCache.clear();
    _instance._isLoaded = false;
    _instance._cacheFile = null;
  }

  /// Initializes storage and loads cached values from disk.
  Future<void> init() async {
    if (_isLoaded) return;
    if (_mockInitialValues != null) {
      _memoryCache = Map<String, dynamic>.from(_mockInitialValues!);
      _isLoaded = true;
      return;
    }

    try {
      final dir = await getApplicationSupportDirectory();
      _cacheFile = File(p.join(dir.path, 'shared_preferences.json'));
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
      // Fallback seamlessly to memory cache in test environments
    } finally {
      _isLoaded = true;
    }
  }

  /// Reads a boolean setting from persistent storage.
  Future<bool?> getBool(String key) async {
    if (!_isLoaded) await init();
    final val = _memoryCache[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return null;
  }

  /// Writes a boolean setting to persistent storage and disk cache.
  Future<bool> setBool(String key, bool value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    if (_mockInitialValues != null) return true;

    try {
      if (_cacheFile != null) {
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache));
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// State: QueueMultiSelectState
// ============================================================================

/// Immutable state snapshot of multi-track queue selection.
@immutable
class QueueMultiSelectState {
  /// The set of currently selected zero-based queue indices.
  final Set<int> selectedIndices;

  /// The most recently clicked or toggled index, used as pivot for Shift-click
  /// contiguous range selection.
  final int? lastToggledIndex;

  /// Total count of items in the queue when state was last synced.
  final int totalItems;

  const QueueMultiSelectState({
    this.selectedIndices = const <int>{},
    this.lastToggledIndex,
    this.totalItems = 0,
  });

  /// Total count of currently selected queue items.
  int get selectedCount => selectedIndices.length;

  /// Whether at least one item is currently selected.
  bool get hasSelection => selectedIndices.isNotEmpty;

  /// Whether selection mode is active.
  bool get isSelectionModeActive => selectedIndices.isNotEmpty;

  /// Determines whether the given [index] is currently selected.
  bool isSelected(int index) => selectedIndices.contains(index);

  /// Determines if all items in a queue of [count] items are selected.
  bool isAllSelected(int count) => count > 0 && selectedIndices.length == count;

  /// Returns selected indices sorted in ascending numerical order.
  List<int> get sortedIndices => selectedIndices.toList()..sort();

  /// Creates a copy of this state with optional updated parameters.
  QueueMultiSelectState copyWith({
    Set<int>? selectedIndices,
    int? lastToggledIndex,
    bool clearLastToggledIndex = false,
    int? totalItems,
  }) {
    return QueueMultiSelectState(
      selectedIndices: selectedIndices != null
          ? Set<int>.unmodifiable(selectedIndices)
          : this.selectedIndices,
      lastToggledIndex: clearLastToggledIndex
          ? null
          : (lastToggledIndex ?? this.lastToggledIndex),
      totalItems: totalItems ?? this.totalItems,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QueueMultiSelectState) return false;
    if (lastToggledIndex != other.lastToggledIndex) return false;
    if (totalItems != other.totalItems) return false;
    if (selectedIndices.length != other.selectedIndices.length) return false;
    return selectedIndices.containsAll(other.selectedIndices);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(sortedIndices),
        lastToggledIndex,
        totalItems,
      );

  @override
  String toString() =>
      'QueueMultiSelectState(selectedCount: $selectedCount, indices: $sortedIndices, lastToggled: $lastToggledIndex)';
}

// ============================================================================
// Model: QueueBatchActionResult
// ============================================================================

/// Immutable result object describing the outcome of a batch queue operation.
@immutable
class QueueBatchActionResult {
  /// The newly computed reordered or pruned queue of tracks.
  final List<Track> updatedQueue;

  /// The updated set of selected indices corresponding to the tracks in [updatedQueue].
  final Set<int> newSelectedIndices;

  /// The adjusted currently playing index within [updatedQueue], or null if unchanged/untracked.
  final int? newCurrentIndex;

  /// Tracks that were removed or moved during this operation.
  final List<Track> affectedTracks;

  /// Whether the queue order or content actually changed.
  final bool hasChanged;

  const QueueBatchActionResult({
    required this.updatedQueue,
    required this.newSelectedIndices,
    this.newCurrentIndex,
    this.affectedTracks = const <Track>[],
    this.hasChanged = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QueueBatchActionResult) return false;
    if (hasChanged != other.hasChanged) return false;
    if (newCurrentIndex != other.newCurrentIndex) return false;
    if (updatedQueue.length != other.updatedQueue.length) return false;
    if (newSelectedIndices.length != other.newSelectedIndices.length) return false;
    return newSelectedIndices.containsAll(other.newSelectedIndices);
  }

  @override
  int get hashCode => Object.hash(
        updatedQueue.length,
        newSelectedIndices.length,
        newCurrentIndex,
        hasChanged,
      );
}

// ============================================================================
// Pure Logic Helper: QueueBatchReorderHelper
// ============================================================================

/// Pure Dart helper providing algorithmic calculations for multi-track batch
/// selection, reordering, and removal without audio engine side-effects.
class QueueBatchReorderHelper {
  const QueueBatchReorderHelper._();

  /// Removes all tracks at [selectedIndices] from [queue].
  ///
  /// Adjusts [currentIndex] accordingly so playback continues seamlessly on the
  /// appropriate track.
  static QueueBatchActionResult removeSelected(
    List<Track> queue,
    Set<int> selectedIndices, {
    int? currentIndex,
  }) {
    if (queue.isEmpty || selectedIndices.isEmpty) {
      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(queue),
        newSelectedIndices: const <int>{},
        newCurrentIndex: currentIndex,
        affectedTracks: const <Track>[],
        hasChanged: false,
      );
    }

    final validIndices = selectedIndices
        .where((i) => i >= 0 && i < queue.length)
        .toSet();

    if (validIndices.isEmpty) {
      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(queue),
        newSelectedIndices: const <int>{},
        newCurrentIndex: currentIndex,
        affectedTracks: const <Track>[],
        hasChanged: false,
      );
    }

    final updated = <Track>[];
    final removed = <Track>[];

    for (int i = 0; i < queue.length; i++) {
      if (validIndices.contains(i)) {
        removed.add(queue[i]);
      } else {
        updated.add(queue[i]);
      }
    }

    int? newCurrent;
    if (currentIndex != null && currentIndex >= 0 && currentIndex < queue.length) {
      if (validIndices.contains(currentIndex)) {
        // Current track was removed
        if (updated.isEmpty) {
          newCurrent = -1;
        } else {
          final removedBefore =
              validIndices.where((i) => i < currentIndex).length;
          final candidate = currentIndex - removedBefore;
          newCurrent = candidate.clamp(0, updated.length - 1);
        }
      } else {
        // Current track was preserved; adjust index for tracks removed ahead of it
        final removedBefore =
            validIndices.where((i) => i < currentIndex).length;
        newCurrent = currentIndex - removedBefore;
      }
    } else {
      newCurrent = currentIndex;
    }

    return QueueBatchActionResult(
      updatedQueue: List<Track>.unmodifiable(updated),
      newSelectedIndices: const <int>{},
      newCurrentIndex: newCurrent,
      affectedTracks: List<Track>.unmodifiable(removed),
      hasChanged: true,
    );
  }

  /// Moves all selected tracks to the top of the queue.
  ///
  /// If [preserveCurrentTrack] is true and [currentIndex] is valid, keeps the
  /// current track (and any preceding history) pinned and moves selected tracks
  /// to the immediate top of the upcoming queue (starting at `currentIndex + 1`).
  ///
  /// Otherwise, moves selected tracks to absolute index 0 of the entire queue.
  static QueueBatchActionResult moveSelectedToTop(
    List<Track> queue,
    Set<int> selectedIndices, {
    int? currentIndex,
    bool preserveCurrentTrack = false,
  }) {
    if (queue.isEmpty || selectedIndices.isEmpty) {
      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(queue),
        newSelectedIndices: Set<int>.unmodifiable(selectedIndices),
        newCurrentIndex: currentIndex,
        hasChanged: false,
      );
    }

    final validIndices = selectedIndices
        .where((i) => i >= 0 && i < queue.length)
        .toSet();

    if (validIndices.isEmpty || validIndices.length == queue.length) {
      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(queue),
        newSelectedIndices: Set<int>.unmodifiable(validIndices),
        newCurrentIndex: currentIndex,
        hasChanged: false,
      );
    }

    final canPreserve = preserveCurrentTrack &&
        currentIndex != null &&
        currentIndex >= 0 &&
        currentIndex < queue.length;

    if (canPreserve) {
      // Split into pinned head (0..currentIndex) and upcoming tail
      final head = queue.sublist(0, currentIndex + 1);
      final upcomingIndices =
          validIndices.where((i) => i > currentIndex).toList()..sort();

      if (upcomingIndices.isEmpty) {
        return QueueBatchActionResult(
          updatedQueue: List<Track>.unmodifiable(queue),
          newSelectedIndices: Set<int>.unmodifiable(validIndices),
          newCurrentIndex: currentIndex,
          hasChanged: false,
        );
      }

      // Check if already contiguous at upcoming head
      bool alreadyAtUpcomingTop = true;
      for (int i = 0; i < upcomingIndices.length; i++) {
        if (upcomingIndices[i] != (currentIndex + 1 + i)) {
          alreadyAtUpcomingTop = false;
          break;
        }
      }

      if (alreadyAtUpcomingTop) {
        return QueueBatchActionResult(
          updatedQueue: List<Track>.unmodifiable(queue),
          newSelectedIndices: Set<int>.unmodifiable(validIndices),
          newCurrentIndex: currentIndex,
          hasChanged: false,
        );
      }

      final upcomingSelected = <Track>[];
      final upcomingUnselected = <Track>[];

      for (int i = currentIndex + 1; i < queue.length; i++) {
        if (validIndices.contains(i)) {
          upcomingSelected.add(queue[i]);
        } else {
          upcomingUnselected.add(queue[i]);
        }
      }

      final updated = <Track>[
        ...head,
        ...upcomingSelected,
        ...upcomingUnselected,
      ];

      final newSelection = <int>{
        // Any selected items that were pinned in head
        for (final idx in validIndices.where((i) => i <= currentIndex)) idx,
        // Shifted upcoming selected items
        for (int i = 0; i < upcomingSelected.length; i++)
          currentIndex + 1 + i,
      };

      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(updated),
        newSelectedIndices: Set<int>.unmodifiable(newSelection),
        newCurrentIndex: currentIndex,
        affectedTracks: List<Track>.unmodifiable(upcomingSelected),
        hasChanged: true,
      );
    } else {
      // Absolute move to index 0
      final sortedValid = validIndices.toList()..sort();

      // Check if already contiguous at index 0
      bool alreadyAtTop = true;
      for (int i = 0; i < sortedValid.length; i++) {
        if (sortedValid[i] != i) {
          alreadyAtTop = false;
          break;
        }
      }

      if (alreadyAtTop) {
        return QueueBatchActionResult(
          updatedQueue: List<Track>.unmodifiable(queue),
          newSelectedIndices: Set<int>.unmodifiable(validIndices),
          newCurrentIndex: currentIndex,
          hasChanged: false,
        );
      }

      final selectedTracks = <Track>[];
      final unselectedTracks = <Track>[];

      for (int i = 0; i < queue.length; i++) {
        if (validIndices.contains(i)) {
          selectedTracks.add(queue[i]);
        } else {
          unselectedTracks.add(queue[i]);
        }
      }

      final updated = <Track>[
        ...selectedTracks,
        ...unselectedTracks,
      ];

      final newSelection = <int>{
        for (int i = 0; i < selectedTracks.length; i++) i,
      };

      int? newCurrent;
      if (currentIndex != null && currentIndex >= 0 && currentIndex < queue.length) {
        final currentTrack = queue[currentIndex];
        final found = updated.indexOf(currentTrack);
        newCurrent = found >= 0 ? found : currentIndex;
      }

      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(updated),
        newSelectedIndices: Set<int>.unmodifiable(newSelection),
        newCurrentIndex: newCurrent,
        affectedTracks: List<Track>.unmodifiable(selectedTracks),
        hasChanged: true,
      );
    }
  }

  /// Moves all selected tracks to the bottom of the queue while preserving
  /// their relative order.
  static QueueBatchActionResult moveSelectedToBottom(
    List<Track> queue,
    Set<int> selectedIndices, {
    int? currentIndex,
  }) {
    if (queue.isEmpty || selectedIndices.isEmpty) {
      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(queue),
        newSelectedIndices: Set<int>.unmodifiable(selectedIndices),
        newCurrentIndex: currentIndex,
        hasChanged: false,
      );
    }

    final validIndices = selectedIndices
        .where((i) => i >= 0 && i < queue.length)
        .toSet();

    if (validIndices.isEmpty || validIndices.length == queue.length) {
      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(queue),
        newSelectedIndices: Set<int>.unmodifiable(validIndices),
        newCurrentIndex: currentIndex,
        hasChanged: false,
      );
    }

    final sortedValid = validIndices.toList()..sort();
    final tailStart = queue.length - sortedValid.length;

    // Check if already contiguous at queue bottom
    bool alreadyAtBottom = true;
    for (int i = 0; i < sortedValid.length; i++) {
      if (sortedValid[i] != tailStart + i) {
        alreadyAtBottom = false;
        break;
      }
    }

    if (alreadyAtBottom) {
      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(queue),
        newSelectedIndices: Set<int>.unmodifiable(validIndices),
        newCurrentIndex: currentIndex,
        hasChanged: false,
      );
    }

    final selectedTracks = <Track>[];
    final unselectedTracks = <Track>[];

    for (int i = 0; i < queue.length; i++) {
      if (validIndices.contains(i)) {
        selectedTracks.add(queue[i]);
      } else {
        unselectedTracks.add(queue[i]);
      }
    }

    final updated = <Track>[
      ...unselectedTracks,
      ...selectedTracks,
    ];

    final newSelection = <int>{
      for (int i = 0; i < selectedTracks.length; i++) tailStart + i,
    };

    int? newCurrent;
    if (currentIndex != null && currentIndex >= 0 && currentIndex < queue.length) {
      final currentTrack = queue[currentIndex];
      final found = updated.indexOf(currentTrack);
      newCurrent = found >= 0 ? found : currentIndex;
    }

    return QueueBatchActionResult(
      updatedQueue: List<Track>.unmodifiable(updated),
      newSelectedIndices: Set<int>.unmodifiable(newSelection),
      newCurrentIndex: newCurrent,
      affectedTracks: List<Track>.unmodifiable(selectedTracks),
      hasChanged: true,
    );
  }

  /// Moves selected tracks up by 1 position as a contiguous or grouped block.
  static QueueBatchActionResult moveSelectedUp(
    List<Track> queue,
    Set<int> selectedIndices, {
    int? currentIndex,
    bool preserveCurrentTrack = false,
  }) {
    if (queue.isEmpty || selectedIndices.isEmpty) {
      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(queue),
        newSelectedIndices: Set<int>.unmodifiable(selectedIndices),
        newCurrentIndex: currentIndex,
        hasChanged: false,
      );
    }

    final valid = selectedIndices.where((i) => i >= 0 && i < queue.length).toSet();
    final minAllowed = (preserveCurrentTrack && currentIndex != null && currentIndex >= 0)
        ? currentIndex + 1
        : 0;

    final sorted = valid.toList()..sort();
    if (sorted.isEmpty || sorted.first <= minAllowed) {
      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(queue),
        newSelectedIndices: Set<int>.unmodifiable(valid),
        newCurrentIndex: currentIndex,
        hasChanged: false,
      );
    }

    final updated = List<Track>.from(queue);
    final newSelection = <int>{};

    for (final idx in sorted) {
      if (idx > minAllowed && !valid.contains(idx - 1)) {
        final temp = updated[idx];
        updated[idx] = updated[idx - 1];
        updated[idx - 1] = temp;
        newSelection.add(idx - 1);
      } else {
        newSelection.add(idx);
      }
    }

    return QueueBatchActionResult(
      updatedQueue: List<Track>.unmodifiable(updated),
      newSelectedIndices: Set<int>.unmodifiable(newSelection),
      newCurrentIndex: currentIndex,
      hasChanged: true,
    );
  }

  /// Moves selected tracks down by 1 position as a contiguous or grouped block.
  static QueueBatchActionResult moveSelectedDown(
    List<Track> queue,
    Set<int> selectedIndices, {
    int? currentIndex,
  }) {
    if (queue.isEmpty || selectedIndices.isEmpty) {
      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(queue),
        newSelectedIndices: Set<int>.unmodifiable(selectedIndices),
        newCurrentIndex: currentIndex,
        hasChanged: false,
      );
    }

    final valid = selectedIndices.where((i) => i >= 0 && i < queue.length).toSet();
    final maxAllowed = queue.length - 1;

    final sortedDesc = valid.toList()..sort((a, b) => b.compareTo(a));
    if (sortedDesc.isEmpty || sortedDesc.first >= maxAllowed) {
      return QueueBatchActionResult(
        updatedQueue: List<Track>.unmodifiable(queue),
        newSelectedIndices: Set<int>.unmodifiable(valid),
        newCurrentIndex: currentIndex,
        hasChanged: false,
      );
    }

    final updated = List<Track>.from(queue);
    final newSelection = <int>{};

    for (final idx in sortedDesc) {
      if (idx < maxAllowed && !valid.contains(idx + 1)) {
        final temp = updated[idx];
        updated[idx] = updated[idx + 1];
        updated[idx + 1] = temp;
        newSelection.add(idx + 1);
      } else {
        newSelection.add(idx);
      }
    }

    return QueueBatchActionResult(
      updatedQueue: List<Track>.unmodifiable(updated),
      newSelectedIndices: Set<int>.unmodifiable(newSelection),
      newCurrentIndex: currentIndex,
      hasChanged: true,
    );
  }
}

// ============================================================================
// StateNotifier: QueueMultiSelectNotifier
// ============================================================================

/// StateNotifier managing multi-track selection and batch queue actions.
class QueueMultiSelectNotifier extends StateNotifier<QueueMultiSelectState> {
  final Ref? _ref;
  final QueueBatchReorderPrefsStorage _storage;

  QueueMultiSelectNotifier({
    Ref? ref,
    QueueBatchReorderPrefsStorage? storage,
    QueueMultiSelectState? initialState,
  })  : _ref = ref,
        _storage = storage ?? QueueBatchReorderPrefsStorage(),
        super(initialState ?? const QueueMultiSelectState());

  /// Toggles selection of item at [index].
  ///
  /// If [isShiftPressed] is true and a previous [lastToggledIndex] exists, selects
  /// all items between [lastToggledIndex] and [index] inclusively.
  void toggleItem(int index, {bool isShiftPressed = false, int? totalCount}) {
    if (index < 0 || (totalCount != null && index >= totalCount)) return;

    if (isShiftPressed && state.lastToggledIndex != null) {
      final from = state.lastToggledIndex!;
      final to = index;
      final start = min(from, to);
      final end = max(from, to);
      final range = <int>{};
      for (int i = start; i <= end; i++) {
        if (totalCount == null || i < totalCount) {
          range.add(i);
        }
      }
      final newSelected = Set<int>.from(state.selectedIndices)..addAll(range);
      state = state.copyWith(
        selectedIndices: newSelected,
        lastToggledIndex: index,
        totalItems: totalCount,
      );
    } else {
      final newSelected = Set<int>.from(state.selectedIndices);
      if (newSelected.contains(index)) {
        newSelected.remove(index);
      } else {
        newSelected.add(index);
      }
      state = state.copyWith(
        selectedIndices: newSelected,
        lastToggledIndex: index,
        totalItems: totalCount,
      );
    }
  }

  /// Explicitly selects the item at [index].
  void selectItem(int index, {int? totalCount}) {
    if (index < 0 || (totalCount != null && index >= totalCount)) return;
    final newSelected = Set<int>.from(state.selectedIndices)..add(index);
    state = state.copyWith(
      selectedIndices: newSelected,
      lastToggledIndex: index,
      totalItems: totalCount,
    );
  }

  /// Explicitly deselects the item at [index].
  void deselectItem(int index) {
    if (!state.selectedIndices.contains(index)) return;
    final newSelected = Set<int>.from(state.selectedIndices)..remove(index);
    state = state.copyWith(
      selectedIndices: newSelected,
      lastToggledIndex: state.lastToggledIndex == index ? null : state.lastToggledIndex,
    );
  }

  /// Selects a contiguous range of indices from [fromIndex] to [toIndex].
  void selectRange(int fromIndex, int toIndex, {int? totalCount}) {
    final start = max(0, min(fromIndex, toIndex));
    var end = max(fromIndex, toIndex);
    if (totalCount != null && totalCount > 0) {
      end = min(end, totalCount - 1);
    }
    if (start > end) return;

    final range = <int>{};
    for (int i = start; i <= end; i++) {
      range.add(i);
    }

    final newSelected = Set<int>.from(state.selectedIndices)..addAll(range);
    state = state.copyWith(
      selectedIndices: newSelected,
      lastToggledIndex: toIndex,
      totalItems: totalCount,
    );
  }

  /// Selects all [totalItems] in the queue.
  void selectAll(int totalItems) {
    if (totalItems <= 0) {
      clearSelection();
      return;
    }
    final all = List<int>.generate(totalItems, (i) => i).toSet();
    state = state.copyWith(
      selectedIndices: all,
      lastToggledIndex: totalItems - 1,
      totalItems: totalItems,
    );
  }

  /// Inverts the current selection across [totalItems].
  void invertSelection(int totalItems) {
    if (totalItems <= 0) {
      clearSelection();
      return;
    }
    final inverted = <int>{};
    for (int i = 0; i < totalItems; i++) {
      if (!state.selectedIndices.contains(i)) {
        inverted.add(i);
      }
    }
    state = state.copyWith(
      selectedIndices: inverted,
      clearLastToggledIndex: true,
      totalItems: totalItems,
    );
  }

  /// Clears all active selections and resets the range pivot.
  void clearSelection() {
    if (state.selectedIndices.isEmpty && state.lastToggledIndex == null) return;
    state = state.copyWith(
      selectedIndices: const <int>{},
      clearLastToggledIndex: true,
    );
  }

  /// Prunes out-of-bounds indices if the queue length shrunk.
  void prune(int totalItems) {
    if (totalItems <= 0) {
      clearSelection();
      return;
    }
    final filtered =
        state.selectedIndices.where((i) => i >= 0 && i < totalItems).toSet();
    final lastIdx = (state.lastToggledIndex != null &&
            state.lastToggledIndex! < totalItems)
        ? state.lastToggledIndex
        : null;

    state = state.copyWith(
      selectedIndices: filtered,
      lastToggledIndex: lastIdx,
      clearLastToggledIndex: lastIdx == null,
      totalItems: totalItems,
    );
  }

  /// Removes all selected tracks from the audio handler queue and clears selection.
  Future<QueueBatchActionResult?> removeSelected({
    SoftifyAudioHandler? handler,
  }) async {
    if (state.selectedIndices.isEmpty) return null;

    final targetHandler = handler ?? _resolveAudioHandler();
    final queue = targetHandler?.currentQueue ?? const <Track>[];
    final currentIndex = targetHandler?.currentIndex ?? -1;

    final result = QueueBatchReorderHelper.removeSelected(
      queue,
      state.selectedIndices,
      currentIndex: currentIndex,
    );

    if (targetHandler != null && result.hasChanged) {
      // Remove in descending index order so earlier indices remain stable
      final descending = state.sortedIndices.reversed.toList();
      for (final idx in descending) {
        if (idx >= 0 && idx < targetHandler.currentQueue.length) {
          await targetHandler.removeQueueItemAt(idx);
        }
      }
    }

    clearSelection();
    return result;
  }

  /// Moves all selected tracks to the top of the queue or upcoming section.
  Future<QueueBatchActionResult?> moveSelectedToTop({
    SoftifyAudioHandler? handler,
    bool? preserveCurrentTrack,
  }) async {
    if (state.selectedIndices.isEmpty) return null;

    final targetHandler = handler ?? _resolveAudioHandler();
    final queue = targetHandler?.currentQueue ?? const <Track>[];
    final currentIndex = targetHandler?.currentIndex ?? -1;

    final preserve = preserveCurrentTrack ??
        (await _storage.getBool(kBatchReorderPreserveCurrentKey) ?? true);

    final result = QueueBatchReorderHelper.moveSelectedToTop(
      queue,
      state.selectedIndices,
      currentIndex: currentIndex,
      preserveCurrentTrack: preserve,
    );

    if (targetHandler != null && result.hasChanged) {
      await _applyReorderToHandler(targetHandler, result);
    }

    state = state.copyWith(selectedIndices: result.newSelectedIndices);
    return result;
  }

  /// Moves all selected tracks to the bottom of the queue.
  Future<QueueBatchActionResult?> moveSelectedToBottom({
    SoftifyAudioHandler? handler,
  }) async {
    if (state.selectedIndices.isEmpty) return null;

    final targetHandler = handler ?? _resolveAudioHandler();
    final queue = targetHandler?.currentQueue ?? const <Track>[];
    final currentIndex = targetHandler?.currentIndex ?? -1;

    final result = QueueBatchReorderHelper.moveSelectedToBottom(
      queue,
      state.selectedIndices,
      currentIndex: currentIndex,
    );

    if (targetHandler != null && result.hasChanged) {
      await _applyReorderToHandler(targetHandler, result);
    }

    state = state.copyWith(selectedIndices: result.newSelectedIndices);
    return result;
  }

  /// Resolves the global audio handler from Riverpod if available.
  SoftifyAudioHandler? _resolveAudioHandler() {
    if (_ref == null) return null;
    try {
      return _ref.read(audioHandlerProvider);
    } catch (_) {
      return null;
    }
  }

  /// Synchronizes a newly ordered queue with the audio handler using
  /// progressive [reorderQueue] calls without interrupting active audio.
  Future<void> _applyReorderToHandler(
    SoftifyAudioHandler handler,
    QueueBatchActionResult result,
  ) async {
    final targetQueue = result.updatedQueue;
    try {
      for (int i = 0; i < targetQueue.length; i++) {
        final target = targetQueue[i];
        final currentQueue = handler.currentQueue;
        final currentIdx =
            currentQueue.indexWhere((t) => t.id == target.id, i);
        if (currentIdx != -1 && currentIdx != i) {
          await handler.reorderQueue(currentIdx, i);
        }
      }
    } catch (_) {
      // Graceful fallback to setQueue if reorderQueue fails or handler is mocked
      await handler.setQueue(
        targetQueue,
        startIndex: result.newCurrentIndex ?? handler.currentIndex,
      );
    }
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Global StateNotifierProvider managing queue multi-track selection.
final queueMultiSelectProvider =
    StateNotifierProvider<QueueMultiSelectNotifier, QueueMultiSelectState>((ref) {
  return QueueMultiSelectNotifier(ref: ref);
});

/// Whether multi-track selection is currently active (selectionCount > 0).
final isQueueSelectionActiveProvider = Provider<bool>((ref) {
  return ref.watch(queueMultiSelectProvider).hasSelection;
});

/// Count of currently selected queue tracks.
final queueSelectedCountProvider = Provider<int>((ref) {
  return ref.watch(queueMultiSelectProvider).selectedCount;
});

/// Provider family checking whether a specific queue index is selected.
final isQueueIndexSelectedProvider =
    Provider.family<bool, int>((ref, index) {
  return ref.watch(queueMultiSelectProvider).isSelected(index);
});

// ============================================================================
// UI Widget: QueueBatchActionBar
// ============================================================================

/// Material 3 floating / docked batch action bar displayed whenever one or more
/// queue tracks are selected.
///
/// Provides quick action buttons for:
/// - Clearing selection
/// - Move Selected to Top
/// - Move Selected to Bottom
/// - Select All
/// - Invert Selection
/// - Remove Selected Tracks
class QueueBatchActionBar extends ConsumerWidget {
  /// Whether to render even when selection is 0 (useful for testing or fixed headers).
  final bool alwaysVisible;

  /// Optional total count of items in the queue. If omitted, resolved via Riverpod.
  final int? totalItemCount;

  /// Custom callbacks to override or test actions without relying on audio handler.
  final VoidCallback? onClearSelection;
  final VoidCallback? onMoveSelectedToTop;
  final VoidCallback? onMoveSelectedToBottom;
  final VoidCallback? onRemoveSelected;
  final VoidCallback? onSelectAll;
  final VoidCallback? onInvertSelection;

  /// Optional padding override.
  final EdgeInsetsGeometry? padding;

  /// Optional margin override.
  final EdgeInsetsGeometry? margin;

  const QueueBatchActionBar({
    super.key,
    this.alwaysVisible = false,
    this.totalItemCount,
    this.onClearSelection,
    this.onMoveSelectedToTop,
    this.onMoveSelectedToBottom,
    this.onRemoveSelected,
    this.onSelectAll,
    this.onInvertSelection,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final selectState = ref.watch(queueMultiSelectProvider);
    final isVisible = selectState.hasSelection || alwaysVisible;

    if (!isVisible) {
      return const SizedBox.shrink();
    }

    final total = totalItemCount ?? _resolveTotalQueueItems(ref);

    return AppSurface(
      key: const Key('queue_batch_action_bar'),
      withBlur: tokens.isGlass,
      color: tokens.isGlass
          ? tokens.glassSurface
          : tokens.surfaceElevated,
      borderRadius: BorderRadius.circular(tokens.radiusLg),
      border: Border.all(
        color: tokens.isGlass
            ? tokens.glassBorder
            : Colors.white.withValues(alpha: 0.12),
        width: 1.0,
      ),
      boxShadow: tokens.cardShadow,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close button to cancel/clear selection
          IconButton(
            key: const Key('queue_batch_clear_button'),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: tokens.textSecondary,
            tooltip: 'Clear selection',
            onPressed: () {
              if (onClearSelection != null) {
                onClearSelection!();
              } else {
                ref.read(queueMultiSelectProvider.notifier).clearSelection();
              }
            },
          ),
          const SizedBox(width: 4),

          // Count Badge Chip
          Container(
            key: const Key('queue_batch_count_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(tokens.radiusFull),
              border: Border.all(
                color: tokens.accent.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Text(
              '${selectState.selectedCount} selected',
              key: const Key('queue_batch_count_label'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tokens.accent,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Vertical Separator
          Container(
            height: 20,
            width: 1,
            color: Colors.white.withValues(alpha: 0.12),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),

          // Move to Top
          IconButton(
            key: const Key('queue_batch_move_top_button'),
            icon: const Icon(Icons.vertical_align_top_rounded, size: 20),
            color: tokens.textPrimary,
            tooltip: 'Move to Top',
            onPressed: () {
              if (onMoveSelectedToTop != null) {
                onMoveSelectedToTop!();
              } else {
                ref.read(queueMultiSelectProvider.notifier).moveSelectedToTop();
              }
            },
          ),

          // Move to Bottom
          IconButton(
            key: const Key('queue_batch_move_bottom_button'),
            icon: const Icon(Icons.vertical_align_bottom_rounded, size: 20),
            color: tokens.textPrimary,
            tooltip: 'Move to Bottom',
            onPressed: () {
              if (onMoveSelectedToBottom != null) {
                onMoveSelectedToBottom!();
              } else {
                ref.read(queueMultiSelectProvider.notifier).moveSelectedToBottom();
              }
            },
          ),

          // Select All
          IconButton(
            key: const Key('queue_batch_select_all_button'),
            icon: const Icon(Icons.select_all_rounded, size: 20),
            color: tokens.textPrimary,
            tooltip: 'Select All',
            onPressed: () {
              if (onSelectAll != null) {
                onSelectAll!();
              } else {
                ref.read(queueMultiSelectProvider.notifier).selectAll(total);
              }
            },
          ),

          // Invert Selection
          IconButton(
            key: const Key('queue_batch_invert_button'),
            icon: const Icon(Icons.swap_vert_rounded, size: 20),
            color: tokens.textPrimary,
            tooltip: 'Invert Selection',
            onPressed: () {
              if (onInvertSelection != null) {
                onInvertSelection!();
              } else {
                ref.read(queueMultiSelectProvider.notifier).invertSelection(total);
              }
            },
          ),

          // Remove Selected
          IconButton(
            key: const Key('queue_batch_remove_button'),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: tokens.error,
            ),
            tooltip: 'Remove Selected',
            onPressed: () {
              if (onRemoveSelected != null) {
                onRemoveSelected!();
              } else {
                ref.read(queueMultiSelectProvider.notifier).removeSelected();
              }
            },
          ),
        ],
      ),
    );
  }

  int _resolveTotalQueueItems(WidgetRef ref) {
    try {
      final queue = ref.read(queueProvider).value;
      if (queue != null && queue.isNotEmpty) return queue.length;
    } catch (_) {}
    try {
      final handler = ref.read(audioHandlerProvider);
      return handler.currentQueue.length;
    } catch (_) {}
    return 0;
  }
}

// ============================================================================
// UI Widget: QueueSelectableItem
// ============================================================================

/// Convenience widget wrapping a queue item row with multi-select support,
/// checkbox indicator, Shift-key range detection, and Material 3 highlight.
class QueueSelectableItem extends ConsumerWidget {
  final int index;
  final Track track;
  final int totalCount;
  final bool isCurrent;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const QueueSelectableItem({
    super.key,
    required this.index,
    required this.track,
    required this.totalCount,
    this.isCurrent = false,
    this.leading,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final isSelected = ref.watch(isQueueIndexSelectedProvider(index));

    final backgroundColor = isSelected
        ? tokens.accent.withValues(alpha: 0.16)
        : (isCurrent
            ? tokens.surfaceHighlight.withValues(alpha: 0.4)
            : Colors.transparent);

    return Material(
      key: Key('queue_selectable_item_$index'),
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          final isShift = HardwareKeyboard.instance.isShiftPressed;
          ref.read(queueMultiSelectProvider.notifier).toggleItem(
                index,
                isShiftPressed: isShift,
                totalCount: totalCount,
              );
          onTap?.call();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Selection Checkbox Indicator
              GestureDetector(
                key: Key('queue_item_checkbox_$index'),
                onTap: () {
                  final isShift = HardwareKeyboard.instance.isShiftPressed;
                  ref.read(queueMultiSelectProvider.notifier).toggleItem(
                        index,
                        isShiftPressed: isShift,
                        totalCount: totalCount,
                      );
                },
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? tokens.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(tokens.radiusSm / 2),
                    border: Border.all(
                      color: isSelected
                          ? tokens.accent
                          : tokens.textMuted.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),

              // Optional leading (e.g. artwork)
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],

              // Title and Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? tokens.accent
                            : (isCurrent ? tokens.accent : tokens.textPrimary),
                        fontWeight: isSelected || isCurrent
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Optional trailing (e.g. duration or reorder handle)
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
