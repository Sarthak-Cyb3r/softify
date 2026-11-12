import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player/softify_audio_handler.dart';
import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/animated_music_wave_indicator.dart';
import '../../../presentation/widgets/shared/app_network_image.dart';

// ============================================================================
// Constants & Preference Keys
// ============================================================================

const String kPriorityPlayNextStackKey = 'softify_priority_play_next_stack_v1';
const String kPriorityPlaylistQueueKey = 'softify_priority_playlist_queue_v1';
const String kPriorityLifoModeKey = 'softify_priority_lifo_mode_v1';

// ============================================================================
// Enums & Models
// ============================================================================

/// Origin / categorization of a track in the playback queue.
enum QueueTrackOrigin {
  /// Currently active and playing track.
  nowPlaying,

  /// User-directed priority track scheduled via "Play Next" (LIFO priority stack).
  priorityPlayNext,

  /// Standard sequential track from album/playlist or added via "Add to End" (FIFO queue).
  playlistFifo,
}

/// Immutable state snapshot of the dual priority queue system.
@immutable
class PriorityQueueState {
  /// The currently playing track, or null if player is stopped/idle.
  final Track? currentTrack;

  /// User-directed LIFO "Play Next" priority stack.
  /// Index 0 is the immediate next track to be played.
  final List<Track> priorityStack;

  /// FIFO sequential playlist or "Add to End" queue.
  /// Index 0 is played after all [priorityStack] tracks are consumed.
  final List<Track> playlistQueue;

  /// History of recently played tracks in reverse chronological order.
  final List<Track> history;

  /// Whether new "Play Next" tracks are pushed in LIFO order (top of stack)
  /// or FIFO order (tail of priority stack). Defaults to true (LIFO stack).
  final bool isLifoMode;

  /// Timestamp when the queue state was last mutated.
  final DateTime lastModified;

  PriorityQueueState({
    this.currentTrack,
    List<Track>? priorityStack,
    List<Track>? playlistQueue,
    List<Track>? history,
    this.isLifoMode = true,
    DateTime? lastModified,
  })  : priorityStack = List.unmodifiable(priorityStack ?? const <Track>[]),
        playlistQueue = List.unmodifiable(playlistQueue ?? const <Track>[]),
        history = List.unmodifiable(history ?? const <Track>[]),
        lastModified = lastModified ?? DateTime.now();

  /// Total count of user priority tracks.
  int get priorityCount => priorityStack.length;

  /// Total count of upcoming playlist tracks.
  int get playlistCount => playlistQueue.length;

  /// Total count of all upcoming tracks (priority + playlist).
  int get totalUpcomingCount => priorityCount + playlistCount;

  /// Whether any user priority tracks are queued.
  bool get hasPriorityTracks => priorityStack.isNotEmpty;

  /// Whether any playlist tracks are queued.
  bool get hasPlaylistTracks => playlistQueue.isNotEmpty;

  /// Whether any upcoming tracks exist in either queue.
  bool get hasUpcoming => totalUpcomingCount > 0;

  /// Returns the next track scheduled to play, checking the priority stack first,
  /// then the playlist queue.
  Track? get nextUpTrack {
    if (priorityStack.isNotEmpty) return priorityStack.first;
    if (playlistQueue.isNotEmpty) return playlistQueue.first;
    return null;
  }

  /// Combined upcoming tracks in resolved playback order:
  /// [all priority tracks in LIFO order] followed by [all playlist tracks in FIFO order].
  List<Track> get unifiedUpcomingQueue => [
        ...priorityStack,
        ...playlistQueue,
      ];

  /// The complete queue representation including the currently playing track.
  List<Track> get fullQueue => [
        if (currentTrack != null) currentTrack!,
        ...priorityStack,
        ...playlistQueue,
      ];

  /// Whether all queues and current track are completely empty.
  bool get isEmpty =>
      currentTrack == null && priorityStack.isEmpty && playlistQueue.isEmpty;

  PriorityQueueState copyWith({
    Track? currentTrack,
    bool clearCurrentTrack = false,
    List<Track>? priorityStack,
    List<Track>? playlistQueue,
    List<Track>? history,
    bool? isLifoMode,
    DateTime? lastModified,
  }) {
    return PriorityQueueState(
      currentTrack:
          clearCurrentTrack ? null : (currentTrack ?? this.currentTrack),
      priorityStack: priorityStack ?? this.priorityStack,
      playlistQueue: playlistQueue ?? this.playlistQueue,
      history: history ?? this.history,
      isLifoMode: isLifoMode ?? this.isLifoMode,
      lastModified: lastModified ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentTrack': currentTrack?.toMap(),
      'priorityStack': priorityStack.map((t) => t.toMap()).toList(),
      'playlistQueue': playlistQueue.map((t) => t.toMap()).toList(),
      'history': history.map((t) => t.toMap()).toList(),
      'isLifoMode': isLifoMode,
      'lastModified': lastModified.millisecondsSinceEpoch,
    };
  }

  factory PriorityQueueState.fromMap(Map<String, dynamic> map) {
    Track? parseTrack(dynamic item) {
      if (item is Map<String, dynamic>) {
        return Track(
          id: item['id'] as String? ?? '',
          sourceId: item['sourceId'] as String? ?? '',
          title: item['title'] as String? ?? 'Unknown Title',
          artist: item['artist'] as String? ?? 'Unknown Artist',
          album: item['album'] as String?,
          duration: Duration(milliseconds: item['durationMs'] as int? ?? 0),
          coverUrl: item['coverUrl'] as String?,
          isLiked: item['isLiked'] as bool? ?? false,
          isUnavailable: item['isUnavailable'] as bool? ?? false,
        );
      }
      return null;
    }

    final cur = parseTrack(map['currentTrack']);
    final prio = <Track>[];
    if (map['priorityStack'] is List) {
      for (final e in map['priorityStack'] as List) {
        final t = parseTrack(e);
        if (t != null) prio.add(t);
      }
    }

    final pl = <Track>[];
    if (map['playlistQueue'] is List) {
      for (final e in map['playlistQueue'] as List) {
        final t = parseTrack(e);
        if (t != null) pl.add(t);
      }
    }

    final hist = <Track>[];
    if (map['history'] is List) {
      for (final e in map['history'] as List) {
        final t = parseTrack(e);
        if (t != null) hist.add(t);
      }
    }

    return PriorityQueueState(
      currentTrack: cur,
      priorityStack: prio,
      playlistQueue: pl,
      history: hist,
      isLifoMode: map['isLifoMode'] as bool? ?? true,
      lastModified: map['lastModified'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastModified'] as int)
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PriorityQueueState.fromJson(String source) =>
      PriorityQueueState.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PriorityQueueState) return false;
    if (currentTrack != other.currentTrack) return false;
    if (isLifoMode != other.isLifoMode) return false;
    if (priorityStack.length != other.priorityStack.length) return false;
    for (int i = 0; i < priorityStack.length; i++) {
      if (priorityStack[i].id != other.priorityStack[i].id) return false;
    }
    if (playlistQueue.length != other.playlistQueue.length) return false;
    for (int i = 0; i < playlistQueue.length; i++) {
      if (playlistQueue[i].id != other.playlistQueue[i].id) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        currentTrack,
        isLifoMode,
        Object.hashAll(priorityStack.map((t) => t.id)),
        Object.hashAll(playlistQueue.map((t) => t.id)),
      );
}

// ============================================================================
// Priority Queue Manager (Core Logic & State Management)
// ============================================================================

/// Priority Queue Manager separating user-directed LIFO "Play Next" queue from
/// the FIFO sequential playlist queue.
///
/// Features:
/// - LIFO "Play Next" priority stack: newly added Play Next tracks sit at index 0
///   of the priority stack, ensuring the most recently prioritized track plays first.
/// - FIFO playlist queue: sequentially consumes album or playlist tracks.
/// - Automatic priority resolution: [advanceNext] exhausts the priority stack
///   before drawing tracks from the upcoming playlist queue.
/// - Full reordering, promotion, demotion, clearing, and persistence capabilities.
class PriorityQueueManager extends ChangeNotifier {
  PriorityQueueState _state;
  final SoftifyAudioHandler? _audioHandler;
  final PriorityQueuePreferences? _preferences;

  PriorityQueueManager({
    PriorityQueueState? initialState,
    SoftifyAudioHandler? audioHandler,
    PriorityQueuePreferences? preferences,
  })  : _state = initialState ?? PriorityQueueState(),
        _audioHandler = audioHandler,
        _preferences = preferences;

  /// Current immutable state.
  PriorityQueueState get state => _state;

  /// Active playing track.
  Track? get currentTrack => _state.currentTrack;

  /// User-directed LIFO "Play Next" priority stack.
  List<Track> get priorityStack => _state.priorityStack;

  /// FIFO sequential playlist queue.
  List<Track> get playlistQueue => _state.playlistQueue;

  /// Recent playback history.
  List<Track> get history => _state.history;

  /// Whether LIFO mode is active for "Play Next" actions.
  bool get isLifoMode => _state.isLifoMode;

  // --------------------------------------------------------------------------
  // Core Queue Operations
  // --------------------------------------------------------------------------

  /// Adds [track] to the user priority queue.
  ///
  /// In default LIFO mode, [track] is inserted at index 0 (top of stack) so it
  /// becomes the immediate next track to be played.
  /// If [playImmediatelyIfIdle] is true and no track is currently playing,
  /// [track] is set as [currentTrack] immediately.
  void playNext(Track track, {bool playImmediatelyIfIdle = false}) {
    if (playImmediatelyIfIdle &&
        _state.currentTrack == null &&
        _state.priorityStack.isEmpty &&
        _state.playlistQueue.isEmpty) {
      _state = _state.copyWith(currentTrack: track);
      notifyListeners();
      _syncToAudioHandlerIfNeeded();
      return;
    }

    final updated = List<Track>.from(_state.priorityStack);
    if (_state.isLifoMode) {
      updated.insert(0, track);
    } else {
      updated.add(track);
    }

    _state = _state.copyWith(priorityStack: updated);
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
  }

  /// Adds a list of [tracks] to the priority stack.
  ///
  /// If [preserveOrder] is true, [tracks] will appear in their given order
  /// at the top of the priority stack (i.e. `tracks[0]` is played first).
  void playNextBatch(List<Track> tracks, {bool preserveOrder = true}) {
    if (tracks.isEmpty) return;

    final updated = List<Track>.from(_state.priorityStack);
    if (preserveOrder) {
      updated.insertAll(0, tracks);
    } else {
      // Push each one onto the stack individually
      for (final track in tracks) {
        updated.insert(0, track);
      }
    }

    _state = _state.copyWith(priorityStack: updated);
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
  }

  /// Appends [track] to the end of the FIFO playlist queue ("Add to End").
  void addToEnd(Track track) {
    final updated = List<Track>.from(_state.playlistQueue)..add(track);
    _state = _state.copyWith(playlistQueue: updated);
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
  }

  /// Appends [tracks] to the end of the FIFO playlist queue.
  void addToEndBatch(List<Track> tracks) {
    if (tracks.isEmpty) return;
    final updated = List<Track>.from(_state.playlistQueue)..addAll(tracks);
    _state = _state.copyWith(playlistQueue: updated);
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
  }

  /// Replaces the entire FIFO playlist queue with [tracks] (e.g. when loading
  /// a new playlist or album), preserving any existing user priority stack.
  void setPlaylistQueue(List<Track> tracks) {
    _state = _state.copyWith(playlistQueue: List<Track>.from(tracks));
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
  }

  /// Directly sets the currently playing [track].
  void setCurrentTrack(Track? track, {bool recordInHistory = true}) {
    List<Track> updatedHistory = _state.history;
    if (recordInHistory && _state.currentTrack != null) {
      updatedHistory = [_state.currentTrack!, ..._state.history];
    }

    _state = _state.copyWith(
      currentTrack: track,
      clearCurrentTrack: track == null,
      history: updatedHistory,
    );
    notifyListeners();
  }

  /// Advances playback to the next upcoming track based on priority resolution:
  /// 1. Pops the top track from [priorityStack] (LIFO priority stack).
  /// 2. If [priorityStack] is empty, dequeues the first track from [playlistQueue] (FIFO).
  /// 3. Returns null if both queues are exhausted.
  ///
  /// The popped track becomes the new [currentTrack], and the prior active track
  /// is archived into [history].
  Track? advanceNext() {
    Track? nextTrack;
    List<Track> updatedPriority = List<Track>.from(_state.priorityStack);
    List<Track> updatedPlaylist = List<Track>.from(_state.playlistQueue);

    if (updatedPriority.isNotEmpty) {
      nextTrack = updatedPriority.removeAt(0);
    } else if (updatedPlaylist.isNotEmpty) {
      nextTrack = updatedPlaylist.removeAt(0);
    }

    if (nextTrack == null) return null;

    final updatedHistory = _state.currentTrack != null
        ? [_state.currentTrack!, ..._state.history]
        : _state.history;

    _state = _state.copyWith(
      currentTrack: nextTrack,
      priorityStack: updatedPriority,
      playlistQueue: updatedPlaylist,
      history: updatedHistory,
    );

    notifyListeners();
    _syncToAudioHandlerIfNeeded();
    return nextTrack;
  }

  /// Reverts to the previous track from [history] if available.
  /// If a track is currently playing, it is pushed back to the top of the priority stack.
  Track? skipPrevious() {
    if (_state.history.isEmpty) return null;

    final updatedHistory = List<Track>.from(_state.history);
    final previousTrack = updatedHistory.removeAt(0);

    final updatedPriority = List<Track>.from(_state.priorityStack);
    if (_state.currentTrack != null) {
      updatedPriority.insert(0, _state.currentTrack!);
    }

    _state = _state.copyWith(
      currentTrack: previousTrack,
      priorityStack: updatedPriority,
      history: updatedHistory,
    );

    notifyListeners();
    _syncToAudioHandlerIfNeeded();
    return previousTrack;
  }

  // --------------------------------------------------------------------------
  // Granular Item Manipulation & Promotion / Demotion
  // --------------------------------------------------------------------------

  /// Promotes a track from the FIFO [playlistQueue] at [playlistIndex] to the
  /// user [priorityStack] at [targetIndex] (defaults to 0: top of priority stack).
  bool promoteToPriority(int playlistIndex, {int targetIndex = 0}) {
    if (playlistIndex < 0 || playlistIndex >= _state.playlistQueue.length) {
      return false;
    }

    final updatedPlaylist = List<Track>.from(_state.playlistQueue);
    final track = updatedPlaylist.removeAt(playlistIndex);

    final updatedPriority = List<Track>.from(_state.priorityStack);
    final clampedTarget = targetIndex.clamp(0, updatedPriority.length);
    updatedPriority.insert(clampedTarget, track);

    _state = _state.copyWith(
      priorityStack: updatedPriority,
      playlistQueue: updatedPlaylist,
    );

    notifyListeners();
    _syncToAudioHandlerIfNeeded();
    return true;
  }

  /// Demotes a track from the user [priorityStack] at [priorityIndex] to the
  /// FIFO [playlistQueue] at [targetIndex] (defaults to tail of playlist queue).
  bool demoteToPlaylist(int priorityIndex, {int? targetIndex}) {
    if (priorityIndex < 0 || priorityIndex >= _state.priorityStack.length) {
      return false;
    }

    final updatedPriority = List<Track>.from(_state.priorityStack);
    final track = updatedPriority.removeAt(priorityIndex);

    final updatedPlaylist = List<Track>.from(_state.playlistQueue);
    final target = targetIndex ?? updatedPlaylist.length;
    final clampedTarget = target.clamp(0, updatedPlaylist.length);
    updatedPlaylist.insert(clampedTarget, track);

    _state = _state.copyWith(
      priorityStack: updatedPriority,
      playlistQueue: updatedPlaylist,
    );

    notifyListeners();
    _syncToAudioHandlerIfNeeded();
    return true;
  }

  /// Removes the track at [index] from the user priority stack.
  bool removePriorityTrackAt(int index) {
    if (index < 0 || index >= _state.priorityStack.length) return false;

    final updated = List<Track>.from(_state.priorityStack)..removeAt(index);
    _state = _state.copyWith(priorityStack: updated);
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
    return true;
  }

  /// Removes the track at [index] from the FIFO playlist queue.
  bool removePlaylistTrackAt(int index) {
    if (index < 0 || index >= _state.playlistQueue.length) return false;

    final updated = List<Track>.from(_state.playlistQueue)..removeAt(index);
    _state = _state.copyWith(playlistQueue: updated);
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
    return true;
  }

  /// Removes all occurrences of [trackId] from priority and/or playlist queues.
  int removeTrackById(
    String trackId, {
    bool priorityOnly = false,
    bool playlistOnly = false,
  }) {
    int removedCount = 0;

    List<Track> updatedPriority = List<Track>.from(_state.priorityStack);
    List<Track> updatedPlaylist = List<Track>.from(_state.playlistQueue);

    if (!playlistOnly) {
      final initialLength = updatedPriority.length;
      updatedPriority.removeWhere((t) => t.id == trackId);
      removedCount += (initialLength - updatedPriority.length);
    }

    if (!priorityOnly) {
      final initialLength = updatedPlaylist.length;
      updatedPlaylist.removeWhere((t) => t.id == trackId);
      removedCount += (initialLength - updatedPlaylist.length);
    }

    if (removedCount > 0) {
      _state = _state.copyWith(
        priorityStack: updatedPriority,
        playlistQueue: updatedPlaylist,
      );
      notifyListeners();
      _syncToAudioHandlerIfNeeded();
    }

    return removedCount;
  }

  /// Reorders items within the user priority stack with standard Flutter
  /// reordering index adjustment.
  bool reorderPriorityQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _state.priorityStack.length) return false;

    final updated = List<Track>.from(_state.priorityStack);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (newIndex < 0 || newIndex >= updated.length) return false;

    final track = updated.removeAt(oldIndex);
    updated.insert(newIndex, track);

    _state = _state.copyWith(priorityStack: updated);
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
    return true;
  }

  /// Reorders items within the upcoming playlist queue.
  bool reorderPlaylistQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _state.playlistQueue.length) return false;

    final updated = List<Track>.from(_state.playlistQueue);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (newIndex < 0 || newIndex >= updated.length) return false;

    final track = updated.removeAt(oldIndex);
    updated.insert(newIndex, track);

    _state = _state.copyWith(playlistQueue: updated);
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
    return true;
  }

  // --------------------------------------------------------------------------
  // Bulk Queue Operations
  // --------------------------------------------------------------------------

  /// Clears only the user priority stack, keeping current track and playlist intact.
  void clearPriorityQueue() {
    if (_state.priorityStack.isEmpty) return;
    _state = _state.copyWith(priorityStack: const <Track>[]);
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
  }

  /// Clears only upcoming playlist tracks, keeping priority stack intact.
  void clearPlaylistQueue() {
    if (_state.playlistQueue.isEmpty) return;
    _state = _state.copyWith(playlistQueue: const <Track>[]);
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
  }

  /// Clears both user priority stack and upcoming playlist tracks.
  void clearAllUpcoming() {
    if (_state.priorityStack.isEmpty && _state.playlistQueue.isEmpty) return;
    _state = _state.copyWith(
      priorityStack: const <Track>[],
      playlistQueue: const <Track>[],
    );
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
  }

  /// Clears playback history.
  void clearHistory() {
    if (_state.history.isEmpty) return;
    _state = _state.copyWith(history: const <Track>[]);
    notifyListeners();
  }

  /// Shuffles the upcoming playlist queue only.
  /// User priority tracks and current track are completely preserved.
  void shufflePlaylistQueue({Random? random}) {
    if (_state.playlistQueue.length <= 1) return;

    final updated = List<Track>.from(_state.playlistQueue);
    updated.shuffle(random ?? Random());

    _state = _state.copyWith(playlistQueue: updated);
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
  }

  /// Inverts the priority stack order.
  void reversePriorityQueue() {
    if (_state.priorityStack.length <= 1) return;

    final updated = List<Track>.from(_state.priorityStack.reversed);
    _state = _state.copyWith(priorityStack: updated);
    notifyListeners();
    _syncToAudioHandlerIfNeeded();
  }

  /// Configures whether "Play Next" uses LIFO (top of stack) or FIFO order.
  void setLifoMode(bool enableLifo) {
    if (_state.isLifoMode == enableLifo) return;
    _state = _state.copyWith(isLifoMode: enableLifo);
    notifyListeners();
    _saveLifoPreference();
  }

  /// Toggles LIFO mode.
  void toggleLifoMode() => setLifoMode(!_state.isLifoMode);

  // --------------------------------------------------------------------------
  // AudioHandler & Preferences Synchronization
  // --------------------------------------------------------------------------

  void _syncToAudioHandlerIfNeeded() {
    if (_audioHandler == null) return;
    final unified = _state.fullQueue;
    if (unified.isNotEmpty) {
      _audioHandler.setQueue(unified, startIndex: 0);
    }
  }

  /// Syncs internal state from an active [SoftifyAudioHandler].
  void syncFromAudioHandler(SoftifyAudioHandler handler) {
    final curTrack = handler.currentTrack;
    if (curTrack != null && curTrack != _state.currentTrack) {
      _state = _state.copyWith(currentTrack: curTrack);
      notifyListeners();
    }
  }

  Future<void> _saveLifoPreference() async {
    final prefs = _preferences ?? await PriorityQueuePreferences.getInstance();
    await prefs.setBool(kPriorityLifoModeKey, _state.isLifoMode);
  }

  /// Persists current priority stack and settings to key-value storage.
  Future<void> saveToPreferences([PriorityQueuePreferences? prefs]) async {
    final store =
        prefs ?? _preferences ?? await PriorityQueuePreferences.getInstance();
    final serialized = jsonEncode(
      _state.priorityStack.map((t) => t.toMap()).toList(),
    );
    await store.setString(kPriorityPlayNextStackKey, serialized);
    await store.setBool(kPriorityLifoModeKey, _state.isLifoMode);
  }

  /// Restores priority stack and settings from key-value storage.
  Future<bool> loadFromPreferences([PriorityQueuePreferences? prefs]) async {
    final store =
        prefs ?? _preferences ?? await PriorityQueuePreferences.getInstance();
    final lifo = store.getBool(kPriorityLifoModeKey) ?? true;
    final jsonStr = store.getString(kPriorityPlayNextStackKey);

    if (jsonStr == null || jsonStr.isEmpty) {
      _state = _state.copyWith(isLifoMode: lifo);
      notifyListeners();
      return false;
    }

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        final loadedTracks = decoded
            .map((item) {
              if (item is Map<String, dynamic>) {
                return Track(
                  id: item['id'] as String? ?? '',
                  sourceId: item['sourceId'] as String? ?? '',
                  title: item['title'] as String? ?? 'Unknown',
                  artist: item['artist'] as String? ?? 'Unknown',
                  album: item['album'] as String?,
                  duration: Duration(
                    milliseconds: item['durationMs'] as int? ?? 0,
                  ),
                  coverUrl: item['coverUrl'] as String?,
                  isLiked: item['isLiked'] as bool? ?? false,
                  isUnavailable: item['isUnavailable'] as bool? ?? false,
                );
              }
              return null;
            })
            .whereType<Track>()
            .toList();

        _state = _state.copyWith(
          priorityStack: loadedTracks,
          isLifoMode: lifo,
        );
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Fallback on corrupt payload
    }
    return false;
  }
}

// ============================================================================
// SharedPreferences Persistence Engine (Self-contained & Test-Safe)
// ============================================================================

/// In-memory and file-backed key-value persistence store matching SharedPreferences API.
class PriorityQueuePreferences {
  static PriorityQueuePreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _file;

  PriorityQueuePreferences._(this._store, this._file);

  /// Synchronously accessible singleton instance if resolved.
  static PriorityQueuePreferences? get instance => _instance;

  /// Injects mock values for testing harnesses.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance =
        PriorityQueuePreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Resolves the singleton instance.
  static Future<PriorityQueuePreferences> getInstance() async {
    if (_instance != null) return _instance!;

    if (_mockInitialValues != null) {
      _instance = PriorityQueuePreferences._(
        Map<String, Object>.from(_mockInitialValues!),
        null,
      );
      return _instance!;
    }

    try {
      final homeDir = Platform.environment['HOME'] ?? '';
      if (homeDir.isNotEmpty) {
        final dir = Directory('$homeDir/.softify');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final file = File('${dir.path}/priority_queue_prefs.json');
        Map<String, Object> data = {};
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          if (content.isNotEmpty) {
            final decoded = jsonDecode(content);
            if (decoded is Map<String, dynamic>) {
              data = Map<String, Object>.from(decoded);
            }
          }
        }
        _instance = PriorityQueuePreferences._(data, file);
        return _instance!;
      }
    } catch (_) {}

    _instance = PriorityQueuePreferences._({}, null);
    return _instance!;
  }

  String? getString(String key) => _store[key] as String?;
  bool? getBool(String key) => _store[key] as bool?;
  int? getInt(String key) => _store[key] as int?;

  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    _flush();
    return true;
  }

  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    _flush();
    return true;
  }

  Future<bool> setInt(String key, int value) async {
    _store[key] = value;
    _flush();
    return true;
  }

  Future<bool> remove(String key) async {
    _store.remove(key);
    _flush();
    return true;
  }

  Future<bool> clear() async {
    _store.clear();
    _flush();
    return true;
  }

  void _flush() {
    try {
      if (_file != null) {
        _file.writeAsStringSync(jsonEncode(_store));
      }
    } catch (_) {}
  }
}

// ============================================================================
// UI Widget: QueueSectionDivider
// ============================================================================

/// Visual divider separating sections in the playback queue:
/// - Distinguishes user-directed "Play Next" priority stack from upcoming playlist tracks.
/// - Material 3 styled with pill badges, track count chips, action buttons, and accent indicators.
class QueueSectionDivider extends StatelessWidget {
  /// Section title (e.g. 'Play Next Stack', 'Upcoming from Playlist', 'Now Playing').
  final String title;

  /// Optional subtitle or operational description.
  final String? subtitle;

  /// Number of tracks in this section.
  final int? count;

  /// Leading icon.
  final IconData? icon;

  /// Custom icon color override.
  final Color? iconColor;

  /// Accent highlight color for this section.
  final Color? accentColor;

  /// High-visibility pill badge (e.g. 'PRIORITY', 'LIFO', 'PLAYLIST').
  final String? badgeText;

  /// Whether this divider marks the user-directed priority section.
  /// When true, renders an expressive glowing pill and colored accent border.
  final bool isPriority;

  /// Optional custom trailing widget.
  final Widget? trailing;

  /// Callback when tapping the section clear action.
  final VoidCallback? onClear;

  /// Tooltip for the clear action.
  final String clearTooltip;

  /// Secondary action callback (e.g. shuffle playlist).
  final VoidCallback? onAction;

  /// Secondary action icon.
  final IconData? actionIcon;

  /// Secondary action tooltip.
  final String? actionTooltip;

  /// Whether to render a horizontal divider line beneath or around the header.
  final bool showDividerLine;

  /// Padding around the section header.
  final EdgeInsetsGeometry padding;

  const QueueSectionDivider({
    super.key,
    required this.title,
    this.subtitle,
    this.count,
    this.icon,
    this.iconColor,
    this.accentColor,
    this.badgeText,
    this.isPriority = false,
    this.trailing,
    this.onClear,
    this.clearTooltip = 'Clear Section',
    this.onAction,
    this.actionIcon,
    this.actionTooltip,
    this.showDividerLine = true,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  /// Factory constructor configured for the User Priority "Play Next" section.
  factory QueueSectionDivider.priority({
    Key? key,
    int? count,
    VoidCallback? onClear,
    VoidCallback? onReverse,
    Widget? trailing,
    String? subtitle,
    bool isLifo = true,
  }) {
    return QueueSectionDivider(
      key: key,
      title: 'Play Next Stack',
      subtitle: subtitle ??
          (isLifo
              ? 'User priority stack • LIFO (latest plays first)'
              : 'User priority queue • FIFO'),
      count: count,
      icon: Icons.bolt_rounded,
      badgeText: isLifo ? 'LIFO STACK' : 'PRIORITY',
      isPriority: true,
      onClear: onClear,
      clearTooltip: 'Clear Priority Queue',
      onAction: onReverse,
      actionIcon: Icons.swap_vert_rounded,
      actionTooltip: 'Reverse Priority Order',
      trailing: trailing,
    );
  }

  /// Factory constructor configured for the Upcoming Playlist / Album section.
  factory QueueSectionDivider.playlist({
    Key? key,
    int? count,
    String? playlistTitle,
    VoidCallback? onShuffle,
    VoidCallback? onClear,
    Widget? trailing,
  }) {
    final sub = playlistTitle != null && playlistTitle.isNotEmpty
        ? 'From: $playlistTitle'
        : 'Sequential queue (FIFO order)';
    return QueueSectionDivider(
      key: key,
      title: 'Upcoming from Playlist',
      subtitle: sub,
      count: count,
      icon: Icons.playlist_play_rounded,
      badgeText: 'PLAYLIST',
      isPriority: false,
      onClear: onClear,
      clearTooltip: 'Clear Playlist Queue',
      onAction: onShuffle,
      actionIcon: Icons.shuffle_rounded,
      actionTooltip: 'Shuffle Upcoming Playlist',
      trailing: trailing,
    );
  }

  /// Factory constructor configured for the Currently Playing track section.
  factory QueueSectionDivider.nowPlaying({
    Key? key,
    Widget? trailing,
  }) {
    return QueueSectionDivider(
      key: key,
      title: 'Now Playing',
      icon: Icons.play_circle_fill_rounded,
      badgeText: 'CURRENT',
      isPriority: false,
      showDividerLine: true,
      trailing: trailing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final effectiveAccent = accentColor ?? tokens.accent;
    final effectiveIconColor = iconColor ?? (isPriority ? effectiveAccent : tokens.textSecondary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDividerLine)
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 4),
            color: isPriority
                ? effectiveAccent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.06),
          ),
        Padding(
          padding: padding,
          child: Row(
            children: [
              // Visual Indicator Pill or Icon
              if (icon != null) ...[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isPriority
                        ? effectiveAccent.withValues(alpha: 0.16)
                        : tokens.surfaceHighlight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(
                      color: isPriority
                          ? effectiveAccent.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: effectiveIconColor,
                  ),
                ),
                const SizedBox(width: 10),
              ] else if (isPriority) ...[
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: effectiveAccent,
                    borderRadius: BorderRadius.circular(tokens.radiusFull),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Section Titles & Subtitles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: isPriority
                                  ? tokens.textPrimary
                                  : tokens.textSecondary,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isPriority
                                  ? effectiveAccent.withValues(alpha: 0.18)
                                  : tokens.surfaceHighlight,
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusFull),
                              border: Border.all(
                                color: isPriority
                                    ? effectiveAccent.withValues(alpha: 0.35)
                                    : Colors.white.withValues(alpha: 0.06),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: isPriority
                                    ? effectiveAccent
                                    : tokens.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Track Count Chip
              if (count != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: tokens.surfaceHighlight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(tokens.radiusFull),
                  ),
                  child: Text(
                    '$count ${count == 1 ? "track" : "tracks"}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              ],

              // Secondary Action (e.g. Shuffle or Reverse)
              if (onAction != null && actionIcon != null) ...[
                Tooltip(
                  message: actionTooltip ?? 'Action',
                  child: IconButton(
                    icon: Icon(actionIcon, size: 17),
                    color: tokens.textSecondary,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    splashRadius: 18,
                    onPressed: onAction,
                  ),
                ),
              ],

              // Clear Button Action
              if (onClear != null) ...[
                Tooltip(
                  message: clearTooltip,
                  child: TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(40, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isPriority ? effectiveAccent : tokens.textMuted,
                      ),
                    ),
                  ),
                ),
              ],

              // Custom Trailing
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// UI Widget: PriorityQueueView
// ============================================================================

/// Full-featured interactive queue list widget showcasing:
/// 1. Currently active Now Playing card
/// 2. User-directed LIFO Priority "Play Next" section with [QueueSectionDivider.priority]
/// 3. Upcoming playlist tracks with [QueueSectionDivider.playlist] and quick "Play Next" promote action.
class PriorityQueueView extends ConsumerStatefulWidget {
  /// Optional injected manager. If null, reads from [priorityQueueManagerProvider].
  final PriorityQueueManager? manager;

  /// Custom playlist header name.
  final String? playlistTitle;

  /// Callback when a track is tapped to play immediately.
  final ValueChanged<Track>? onTrackTap;

  /// Custom padding.
  final EdgeInsetsGeometry padding;

  const PriorityQueueView({
    super.key,
    this.manager,
    this.playlistTitle,
    this.onTrackTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  ConsumerState<PriorityQueueView> createState() => _PriorityQueueViewState();
}

class _PriorityQueueViewState extends ConsumerState<PriorityQueueView> {
  PriorityQueueManager get _effectiveManager =>
      widget.manager ?? ref.watch(priorityQueueManagerProvider);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final manager = _effectiveManager;
    final state = manager.state;

    final currentTrack = state.currentTrack;
    final priorityTracks = state.priorityStack;
    final playlistTracks = state.playlistQueue;

    if (state.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.queue_music_rounded,
                size: 48,
                color: tokens.textMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Playback Queue is Empty',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Play a song or select "Play Next" on any track to start listening.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: widget.padding,
      children: [
        // --------------------------------------------------------------------
        // 1. Now Playing Section
        // --------------------------------------------------------------------
        if (currentTrack != null) ...[
          QueueSectionDivider.nowPlaying(),
          _NowPlayingTile(
            track: currentTrack,
            onTap: () => widget.onTrackTap?.call(currentTrack),
          ),
          const SizedBox(height: 10),
        ],

        // --------------------------------------------------------------------
        // 2. User Priority "Play Next" Stack
        // --------------------------------------------------------------------
        QueueSectionDivider.priority(
          count: priorityTracks.length,
          isLifo: state.isLifoMode,
          onClear: priorityTracks.isNotEmpty
              ? () => manager.clearPriorityQueue()
              : null,
          onReverse: priorityTracks.length > 1
              ? () => manager.reversePriorityQueue()
              : null,
        ),
        if (priorityTracks.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surfaceHighlight.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.04),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No priority tracks queued. Tap "Play Next" on any song to place it in this priority stack.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: tokens.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: priorityTracks.length,
            onReorder: (oldIdx, newIdx) =>
                manager.reorderPriorityQueue(oldIdx, newIdx),
            itemBuilder: (context, index) {
              final track = priorityTracks[index];
              return _PriorityTrackTile(
                key: ValueKey('prio_${track.id}_$index'),
                track: track,
                rankIndex: index + 1,
                onTap: () => widget.onTrackTap?.call(track),
                onDemote: () => manager.demoteToPlaylist(index),
                onRemove: () => manager.removePriorityTrackAt(index),
              );
            },
          ),

        const SizedBox(height: 16),

        // --------------------------------------------------------------------
        // 3. Upcoming Playlist / Add-to-End Queue (FIFO)
        // --------------------------------------------------------------------
        QueueSectionDivider.playlist(
          count: playlistTracks.length,
          playlistTitle: widget.playlistTitle,
          onShuffle: playlistTracks.length > 1
              ? () => manager.shufflePlaylistQueue()
              : null,
          onClear: playlistTracks.isNotEmpty
              ? () => manager.clearPlaylistQueue()
              : null,
        ),
        if (playlistTracks.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surfaceHighlight.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
            child: Text(
              'No upcoming playlist tracks remaining.',
              style: TextStyle(
                fontSize: 11.5,
                color: tokens.textMuted,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: playlistTracks.length,
            onReorder: (oldIdx, newIdx) =>
                manager.reorderPlaylistQueue(oldIdx, newIdx),
            itemBuilder: (context, index) {
              final track = playlistTracks[index];
              return _PlaylistTrackTile(
                key: ValueKey('playlist_${track.id}_$index'),
                track: track,
                queuePosition: index + 1,
                onTap: () => widget.onTrackTap?.call(track),
                onPlayNext: () => manager.promoteToPriority(index),
                onRemove: () => manager.removePlaylistTrackAt(index),
              );
            },
          ),
      ],
    );
  }
}

// ============================================================================
// Internal Tile Widgets
// ============================================================================

class _NowPlayingTile extends ConsumerWidget {
  final Track track;
  final VoidCallback? onTap;

  const _NowPlayingTile({required this.track, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final isPlaying = ref.watch(isPlayingProvider);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(
          color: tokens.accent.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: AppNetworkImage(
            imageUrl: track.coverUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            placeholderIcon: Icons.music_note_rounded,
          ),
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.accent,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
        subtitle: Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 11.5,
          ),
        ),
        trailing: AnimatedMusicWaveIndicator(
          isPlaying: isPlaying,
          color: tokens.accent,
          size: 20,
          barCount: 4,
        ),
      ),
    );
  }
}

class _PriorityTrackTile extends StatelessWidget {
  final Track track;
  final int rankIndex;
  final VoidCallback? onTap;
  final VoidCallback? onDemote;
  final VoidCallback? onRemove;

  const _PriorityTrackTile({
    super.key,
    required this.track,
    required this.rankIndex,
    this.onTap,
    this.onDemote,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: tokens.surfaceHighlight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: tokens.accent.withValues(alpha: 0.16),
          width: 0.8,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Priority Stack Rank Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
              child: Text(
                '#$rankIndex',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: tokens.accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              child: AppNetworkImage(
                imageUrl: track.coverUrl,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                placeholderIcon: Icons.music_note_rounded,
              ),
            ),
          ],
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        subtitle: Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: tokens.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDemote != null)
              Tooltip(
                message: 'Demote to playlist queue',
                child: IconButton(
                  icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                  color: tokens.textMuted,
                  onPressed: onDemote,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
              ),
            if (onRemove != null)
              Tooltip(
                message: 'Remove from priority queue',
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: tokens.textMuted,
                  onPressed: onRemove,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
              ),
            const Icon(
              Icons.drag_handle_rounded,
              size: 18,
              color: Colors.white24,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistTrackTile extends StatelessWidget {
  final Track track;
  final int queuePosition;
  final VoidCallback? onTap;
  final VoidCallback? onPlayNext;
  final VoidCallback? onRemove;

  const _PlaylistTrackTile({
    super.key,
    required this.track,
    required this.queuePosition,
    this.onTap,
    this.onPlayNext,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: tokens.surfaceHighlight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$queuePosition',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              child: AppNetworkImage(
                imageUrl: track.coverUrl,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                placeholderIcon: Icons.music_note_rounded,
              ),
            ),
          ],
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: tokens.textPrimary,
          ),
        ),
        subtitle: Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: tokens.textMuted,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick "Play Next" promote button
            if (onPlayNext != null)
              Tooltip(
                message: 'Promote to Play Next priority stack',
                child: IconButton(
                  icon: Icon(
                    Icons.bolt_rounded,
                    size: 17,
                    color: tokens.accent.withValues(alpha: 0.8),
                  ),
                  onPressed: onPlayNext,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
              ),
            if (onRemove != null)
              Tooltip(
                message: 'Remove from playlist queue',
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: tokens.textMuted,
                  onPressed: onRemove,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
              ),
            const Icon(
              Icons.drag_handle_rounded,
              size: 18,
              color: Colors.white24,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Quick Action Button Widgets
// ============================================================================

/// Quick button to insert [track] into the user priority stack ("Play Next").
class PlayNextActionButton extends ConsumerWidget {
  final Track track;
  final Widget? child;
  final VoidCallback? onComplete;

  const PlayNextActionButton({
    super.key,
    required this.track,
    this.child,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final manager = ref.read(priorityQueueManagerProvider);

    return child ??
        IconButton(
          tooltip: 'Play Next (Priority)',
          icon: Icon(
            Icons.bolt_rounded,
            color: tokens.accent,
            size: 20,
          ),
          onPressed: () {
            manager.playNext(track);
            HapticFeedback.lightImpact();
            onComplete?.call();
          },
        );
  }
}

/// Quick button to append [track] to the end of the FIFO queue ("Add to End").
class AddToEndActionButton extends ConsumerWidget {
  final Track track;
  final Widget? child;
  final VoidCallback? onComplete;

  const AddToEndActionButton({
    super.key,
    required this.track,
    this.child,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final manager = ref.read(priorityQueueManagerProvider);

    return child ??
        IconButton(
          tooltip: 'Add to End of Queue',
          icon: Icon(
            Icons.playlist_add_rounded,
            color: tokens.textSecondary,
            size: 20,
          ),
          onPressed: () {
            manager.addToEnd(track);
            HapticFeedback.lightImpact();
            onComplete?.call();
          },
        );
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Primary Riverpod ChangeNotifier provider for the Priority Queue Manager.
final priorityQueueManagerProvider =
    ChangeNotifierProvider<PriorityQueueManager>((ref) {
  SoftifyAudioHandler? audioHandler;
  try {
    audioHandler = ref.watch(audioHandlerProvider);
  } catch (_) {
    // Allows headless or mock operation in test environments
  }

  final manager = PriorityQueueManager(audioHandler: audioHandler);

  // Sync current track from audio handler if initialized
  if (audioHandler != null) {
    manager.syncFromAudioHandler(audioHandler);
  }

  return manager;
});

/// Reactive provider exposing current [PriorityQueueState].
final priorityQueueStateProvider = Provider<PriorityQueueState>((ref) {
  return ref.watch(priorityQueueManagerProvider).state;
});

/// Reactive provider exposing only the user-directed priority stack.
final priorityStackProvider = Provider<List<Track>>((ref) {
  return ref.watch(priorityQueueManagerProvider).priorityStack;
});

/// Reactive provider exposing only the upcoming FIFO playlist queue.
final playlistQueueProvider = Provider<List<Track>>((ref) {
  return ref.watch(priorityQueueManagerProvider).playlistQueue;
});

/// Reactive provider exposing the resolved next upcoming track.
final nextUpTrackProvider = Provider<Track?>((ref) {
  return ref.watch(priorityQueueManagerProvider).state.nextUpTrack;
});
