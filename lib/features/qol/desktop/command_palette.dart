// ============================================================================
// Softify Quality of Life (QoL) - Feature 30: Universal Command Palette (Ctrl+K)
// ============================================================================
//
// A desktop HUD command palette providing instant keyboard-driven search and
// execution across navigation destinations, playback controls, themes, and
// utility tools.
//
// Features:
// - Keyboard-driven Command Palette Dialog invoked via Ctrl+K / Cmd+K.
// - Pure Dart fuzzy search engine with substring, prefix, acronym, keyword,
//   and subsequence scoring with matched character highlight offsets.
// - Full arrow key (Up/Down) navigation, Enter to execute, Escape to dismiss.
// - Recent commands tracking with SharedPreferences persistence.
// - Category filtering (All, Recent, Navigation, Playback, Theme, Tools).
// - Material 3 desktop HUD layout with glowing borders and frosted backdrop.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/audio_repeat_mode.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/providers/ui_style_provider.dart';
import '../../../presentation/theme/app_theme.dart';

// ============================================================================
// Lightweight SharedPreferences Persistence Engine
// ============================================================================

/// Self-contained SharedPreferences persistence store for desktop platforms.
///
/// Mirrors the standard `package:shared_preferences` interface to safely
/// persist recent commands across sessions and support unit test mocks.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _preferenceStore;
  final File? _storageFile;

  SharedPreferences._(this._preferenceStore, this._storageFile);

  /// Injects initial mock values for testing.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Retrieves or initializes the shared preferences store.
  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

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
      file = _resolveStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              if (value != null) {
                store[key.toString()] = value as Object;
              }
            });
          }
        }
      }
    } catch (_) {
      // In-memory fallback if disk access is prohibited
    }

    _instance = SharedPreferences._(store, file);
    return _instance!;
  }

  static File? _resolveStorageFile() {
    try {
      final userHome = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['LOCALAPPDATA'];
      if (userHome != null && userHome.isNotEmpty) {
        final dir = Directory('$userHome/.softify');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('${dir.path}/command_palette_prefs.json');
      }
      return File('.command_palette_prefs.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist() async {
    final file = _storageFile;
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(_preferenceStore);
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  List<String>? getStringList(String key) {
    final val = _preferenceStore[key];
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return null;
  }

  Future<bool> setStringList(String key, List<String> value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  String? getString(String key) {
    final val = _preferenceStore[key];
    return val?.toString();
  }

  Future<bool> setString(String key, String value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  bool? getBool(String key) {
    final val = _preferenceStore[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  int? getInt(String key) {
    final val = _preferenceStore[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  Future<bool> setInt(String key, int value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  Future<bool> remove(String key) async {
    _preferenceStore.remove(key);
    await _persist();
    return true;
  }

  Future<bool> clear() async {
    _preferenceStore.clear();
    await _persist();
    return true;
  }
}

// ============================================================================
// Enums & Models
// ============================================================================

/// Categories dividing commands in the palette for navigation and filtering.
enum CommandCategory {
  navigation('Navigation', Icons.explore_rounded),
  playback('Playback', Icons.play_circle_fill_rounded),
  theme('Theme & Appearance', Icons.palette_rounded),
  tools('Tools & Utilities', Icons.handyman_rounded),
  recent('Recent', Icons.history_rounded);

  final String label;
  final IconData icon;
  const CommandCategory(this.label, this.icon);

  Color getAccentColor(AppTokens tokens) {
    switch (this) {
      case CommandCategory.navigation:
        return tokens.accentCyan;
      case CommandCategory.playback:
        return const Color(0xFF4ADE80); // Vibrant Emerald Green
      case CommandCategory.theme:
        return tokens.accentViolet;
      case CommandCategory.tools:
        return const Color(0xFFFBBF24); // Warm Amber
      case CommandCategory.recent:
        return tokens.accent;
    }
  }
}

/// Represents a single executable action inside the Universal Command Palette.
@immutable
class CommandPaletteAction {
  final String id;
  final String title;
  final String? subtitle;
  final CommandCategory category;
  final IconData icon;
  final List<String> shortcutKeys;
  final List<String> keywords;
  final String? badge;
  final bool closeOnExecute;
  final FutureOr<void> Function(BuildContext context, WidgetRef ref)? onExecute;

  const CommandPaletteAction({
    required this.id,
    required this.title,
    this.subtitle,
    required this.category,
    required this.icon,
    this.shortcutKeys = const [],
    this.keywords = const [],
    this.badge,
    this.closeOnExecute = true,
    this.onExecute,
  });

  CommandPaletteAction copyWith({
    String? id,
    String? title,
    String? subtitle,
    CommandCategory? category,
    IconData? icon,
    List<String>? shortcutKeys,
    List<String>? keywords,
    String? badge,
    bool? closeOnExecute,
    FutureOr<void> Function(BuildContext context, WidgetRef ref)? onExecute,
  }) {
    return CommandPaletteAction(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      shortcutKeys: shortcutKeys ?? this.shortcutKeys,
      keywords: keywords ?? this.keywords,
      badge: badge ?? this.badge,
      closeOnExecute: closeOnExecute ?? this.closeOnExecute,
      onExecute: onExecute ?? this.onExecute,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommandPaletteAction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CommandPaletteAction($id: $title)';
}

/// Match result produced by the fuzzy search engine for ranking and highlighting.
@immutable
class FuzzyMatchResult {
  final CommandPaletteAction action;
  final double score;
  final List<int> matchedTitleIndices;
  final String matchedField;

  const FuzzyMatchResult({
    required this.action,
    required this.score,
    required this.matchedTitleIndices,
    this.matchedField = 'title',
  });

  @override
  String toString() =>
      'FuzzyMatchResult(${action.id}, score: $score, field: $matchedField, indices: $matchedTitleIndices)';
}

// ============================================================================
// Pure Dart Fuzzy Search Engine
// ============================================================================

/// High-performance fuzzy matching and ranking engine for command palette items.
class CommandPaletteSearchEngine {
  /// Filters and ranks [actions] based on [query], optional [categoryFilter],
  /// and user's [recentActionIds].
  static List<FuzzyMatchResult> search({
    required List<CommandPaletteAction> actions,
    required String query,
    CommandCategory? categoryFilter,
    List<String>? recentActionIds,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final recentList = recentActionIds ?? const <String>[];

    // Filter by category if specified
    Iterable<CommandPaletteAction> candidates = actions;
    if (categoryFilter != null) {
      if (categoryFilter == CommandCategory.recent) {
        final recentSet = recentList.toSet();
        candidates = candidates.where((a) => recentSet.contains(a.id));
      } else {
        candidates = candidates.where((a) => a.category == categoryFilter);
      }
    }

    // 1. Empty Query: Return candidates ordered by recency then default order
    if (cleanQuery.isEmpty) {
      final List<FuzzyMatchResult> results = [];
      final Set<String> processedIds = {};

      // If no category filter is applied and recent items exist, place recents first
      if (categoryFilter == null && recentList.isNotEmpty) {
        final actionMap = {for (final a in candidates) a.id: a};
        for (int i = 0; i < recentList.length; i++) {
          final id = recentList[i];
          final action = actionMap[id];
          if (action != null && !processedIds.contains(id)) {
            processedIds.add(id);
            results.add(
              FuzzyMatchResult(
                action: action,
                score: 200.0 - (i * 5.0),
                matchedTitleIndices: const [],
                matchedField: 'recent',
              ),
            );
          }
        }
      }

      // Add remaining actions
      for (final action in candidates) {
        if (!processedIds.contains(action.id)) {
          processedIds.add(action.id);
          results.add(
            FuzzyMatchResult(
              action: action,
              score: 50.0 - action.category.index,
              matchedTitleIndices: const [],
              matchedField: 'default',
            ),
          );
        }
      }

      return results;
    }

    // 2. Non-empty Query: Run fuzzy search across title, subtitle, keywords, and shortcuts
    final List<FuzzyMatchResult> matches = [];

    for (final action in candidates) {
      final recentRank = recentList.indexOf(action.id);
      final match = matchAction(
        action: action,
        query: cleanQuery,
        recentRank: recentRank,
      );
      if (match != null && match.score > 0) {
        matches.add(match);
      }
    }

    // Sort descending by score; if tied, sort alphabetically by title
    matches.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.action.title.compareTo(b.action.title);
    });

    return matches;
  }

  /// Calculates a match score and highlighted character offsets for an action.
  static FuzzyMatchResult? matchAction({
    required CommandPaletteAction action,
    required String query,
    int recentRank = -1,
  }) {
    double totalScore = 0.0;
    List<int> titleMatchedIndices = const [];
    String matchedField = 'title';

    // 1. Title Matching
    final (titleScore, indices) = scoreText(query: query, text: action.title);
    if (titleScore > 0) {
      totalScore += titleScore;
      titleMatchedIndices = indices;
      matchedField = 'title';
    }

    // 2. Subtitle Matching
    if (action.subtitle != null) {
      final sub = action.subtitle!.toLowerCase();
      if (sub.contains(query)) {
        totalScore += 75.0;
        if (totalScore <= 75.0) matchedField = 'subtitle';
      }
    }

    // 3. Keyword Matching
    for (final kw in action.keywords) {
      final kwLower = kw.toLowerCase();
      if (kwLower == query) {
        totalScore += 160.0;
        if (titleMatchedIndices.isEmpty) matchedField = 'keyword';
      } else if (kwLower.startsWith(query)) {
        totalScore += 90.0;
        if (titleMatchedIndices.isEmpty) matchedField = 'keyword';
      } else if (kwLower.contains(query)) {
        totalScore += 45.0;
        if (titleMatchedIndices.isEmpty) matchedField = 'keyword';
      }
    }

    // 4. Shortcut Keys Matching
    for (final key in action.shortcutKeys) {
      final keyLower = key.toLowerCase();
      if (keyLower.contains(query)) {
        totalScore += 80.0;
        if (titleMatchedIndices.isEmpty) matchedField = 'shortcut';
      }
    }

    // 5. Category Label Matching
    if (action.category.label.toLowerCase().contains(query)) {
      totalScore += 40.0;
      if (titleMatchedIndices.isEmpty) matchedField = 'category';
    }

    // If no match across any fields, return null
    if (totalScore <= 0) {
      return null;
    }

    // Recency Boost: Boost items the user recently executed
    if (recentRank >= 0) {
      final boost = (10 - recentRank).clamp(1, 10) * 12.0;
      totalScore += boost;
    }

    return FuzzyMatchResult(
      action: action,
      score: totalScore,
      matchedTitleIndices: titleMatchedIndices,
      matchedField: matchedField,
    );
  }

  /// Evaluates fuzzy matching score between [query] and [text].
  /// Returns a tuple of `(score, matchedIndices)`.
  static (double, List<int>) scoreText({
    required String query,
    required String text,
  }) {
    if (query.isEmpty || text.isEmpty) {
      return (0.0, const <int>[]);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    // Exact Match
    if (lowerText == lowerQuery) {
      return (1000.0, List<int>.generate(text.length, (i) => i));
    }

    // Prefix Match
    if (lowerText.startsWith(lowerQuery)) {
      return (500.0, List<int>.generate(lowerQuery.length, (i) => i));
    }

    // Substring Match
    final subIndex = lowerText.indexOf(lowerQuery);
    if (subIndex >= 0) {
      final score = 350.0 - (subIndex * 2.5);
      final indices = List<int>.generate(
        lowerQuery.length,
        (i) => subIndex + i,
      );
      return (score.clamp(100.0, 500.0), indices);
    }

    // Word Boundary / Acronym Match
    // e.g. "eq" matching "Open Equalizer", "cp" matching "Command Palette"
    final words = lowerText.split(RegExp(r'[\s\-_/]+'));
    final acronym = words
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .join();

    if (acronym == lowerQuery) {
      // Find character indices for each word's initial
      final List<int> acrIndices = [];
      int searchPos = 0;
      for (final word in words) {
        if (word.isEmpty) continue;
        final idx = lowerText.indexOf(word, searchPos);
        if (idx >= 0) {
          acrIndices.add(idx);
          searchPos = idx + word.length;
        }
      }
      return (300.0, acrIndices);
    }

    // Check if any word starts with query
    int wordOffset = 0;
    for (final word in words) {
      if (word.startsWith(lowerQuery)) {
        final idx = lowerText.indexOf(word, wordOffset);
        final indices = List<int>.generate(
          lowerQuery.length,
          (i) => idx + i,
        );
        return (280.0, indices);
      }
      wordOffset += word.length + 1;
    }

    // Subsequence Match with proximity bonuses and gap penalties
    int textIdx = 0;
    int queryIdx = 0;
    final List<int> matchedIndices = [];
    int consecutive = 0;
    double seqScore = 100.0;
    int lastMatchedIndex = -1;

    while (textIdx < lowerText.length && queryIdx < lowerQuery.length) {
      if (lowerText[textIdx] == lowerQuery[queryIdx]) {
        matchedIndices.add(textIdx);

        // Consecutive character bonus
        if (lastMatchedIndex != -1 && textIdx == lastMatchedIndex + 1) {
          consecutive++;
          seqScore += 15.0 * consecutive;
        } else {
          consecutive = 0;
          if (lastMatchedIndex != -1) {
            // Gap penalty
            seqScore -= (textIdx - lastMatchedIndex - 1) * 2.0;
          }
        }

        // Word start bonus
        if (textIdx == 0 ||
            lowerText[textIdx - 1] == ' ' ||
            lowerText[textIdx - 1] == '-' ||
            lowerText[textIdx - 1] == '_') {
          seqScore += 30.0;
        }

        lastMatchedIndex = textIdx;
        queryIdx++;
      }
      textIdx++;
    }

    // All characters of query were found in sequence
    if (queryIdx == lowerQuery.length) {
      return (seqScore.clamp(20.0, 250.0), matchedIndices);
    }

    return (0.0, const <int>[]);
  }
}

// ============================================================================
// Built-in Default Command Palette Actions Registry
// ============================================================================

/// Canonical list of built-in actions covering navigation, playback, themes, and tools.
final List<CommandPaletteAction> defaultCommandPaletteActions = [
  // --------------------------------------------------------------------------
  // Navigation Destinations
  // --------------------------------------------------------------------------
  CommandPaletteAction(
    id: 'nav_home',
    title: 'Go to Home',
    subtitle: 'Browse trending music, shelves & recommendations',
    category: CommandCategory.navigation,
    icon: Icons.home_rounded,
    shortcutKeys: const ['Ctrl', 'H'],
    keywords: const ['home', 'start', 'discover', 'browse', 'feed'],
    onExecute: (context, ref) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    },
  ),
  CommandPaletteAction(
    id: 'nav_search',
    title: 'Go to Search',
    subtitle: 'Find songs, artists, playlists, and albums',
    category: CommandCategory.navigation,
    icon: Icons.search_rounded,
    shortcutKeys: const ['Ctrl', 'F'],
    keywords: const ['search', 'find', 'explore', 'lookup', 'tracks', 'artists'],
    onExecute: (context, ref) {
      // Handled by shell scaffold or route push
    },
  ),
  CommandPaletteAction(
    id: 'nav_library',
    title: 'Go to Library',
    subtitle: 'Your playlists, liked songs & offline downloads',
    category: CommandCategory.navigation,
    icon: Icons.library_music_rounded,
    shortcutKeys: const ['Ctrl', 'L'],
    keywords: const ['library', 'collection', 'favorites', 'saved', 'playlists'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'nav_youtube',
    title: 'Go to YouTube Music',
    subtitle: 'Stream YouTube music videos and audio tracks',
    category: CommandCategory.navigation,
    icon: Icons.smart_display_rounded,
    shortcutKeys: const ['Ctrl', 'Y'],
    keywords: const ['youtube', 'video', 'streams', 'yt', 'ytm'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'nav_podcasts',
    title: 'Go to Podcasts',
    subtitle: 'Explore subscribed shows and podcast episodes',
    category: CommandCategory.navigation,
    icon: Icons.podcasts_rounded,
    shortcutKeys: const ['Ctrl', 'P'],
    keywords: const ['podcasts', 'episodes', 'shows', 'rss', 'talk'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'nav_settings',
    title: 'Open Settings',
    subtitle: 'Preferences, audio quality, cache & appearance',
    category: CommandCategory.navigation,
    icon: Icons.settings_rounded,
    shortcutKeys: const ['Ctrl', ','],
    keywords: const ['settings', 'preferences', 'config', 'options', 'setup'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'nav_equalizer',
    title: 'Open Equalizer',
    subtitle: 'Adjust 10-band audio frequency equalizer and presets',
    category: CommandCategory.navigation,
    icon: Icons.equalizer_rounded,
    shortcutKeys: const ['E'],
    keywords: const ['equalizer', 'eq', 'bass', 'treble', 'dsp', 'audio', 'sound'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'nav_lyrics',
    title: 'Toggle Lyrics View',
    subtitle: 'Synchronized real-time and karaoke lyrics display',
    category: CommandCategory.navigation,
    icon: Icons.lyrics_rounded,
    shortcutKeys: const ['L'],
    keywords: const ['lyrics', 'karaoke', 'text', 'words', 'sing', 'synced'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'nav_queue',
    title: 'Open Playback Queue',
    subtitle: 'View, reorder, and manage upcoming queue tracks',
    category: CommandCategory.navigation,
    icon: Icons.queue_music_rounded,
    shortcutKeys: const ['Q'],
    keywords: const ['queue', 'upcoming', 'next', 'playlist', 'history'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'nav_screensaver',
    title: 'Ambient Music Screensaver',
    subtitle: 'Full-screen visualizer and album artwork display',
    category: CommandCategory.navigation,
    icon: Icons.tv_rounded,
    shortcutKeys: const ['F11'],
    keywords: const ['screensaver', 'ambient', 'fullscreen', 'display', 'visualizer'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'nav_spotify_import',
    title: 'Import Spotify Playlists',
    subtitle: 'Migrate playlists and saved tracks from Spotify',
    category: CommandCategory.navigation,
    icon: Icons.sync_alt_rounded,
    keywords: const ['spotify', 'import', 'sync', 'transfer', 'migrate'],
    onExecute: (context, ref) {},
  ),

  // --------------------------------------------------------------------------
  // Playback Controls
  // --------------------------------------------------------------------------
  CommandPaletteAction(
    id: 'playback_play_pause',
    title: 'Toggle Play / Pause',
    subtitle: 'Start or pause current music playback',
    category: CommandCategory.playback,
    icon: Icons.play_circle_outline_rounded,
    shortcutKeys: const ['Space'],
    keywords: const ['play', 'pause', 'toggle', 'resume', 'stop'],
    onExecute: (context, ref) {
      try {
        final pb = ref.read(playbackStateStreamProvider).value;
        final isPlaying = pb?.playing ?? false;
        final audioHandler = ref.read(audioHandlerProvider);
        if (isPlaying) {
          audioHandler.pause();
        } else {
          audioHandler.play();
        }
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'playback_next',
    title: 'Next Track',
    subtitle: 'Skip forward to the next queued song',
    category: CommandCategory.playback,
    icon: Icons.skip_next_rounded,
    shortcutKeys: const ['Ctrl', '→'],
    keywords: const ['next', 'skip', 'forward', 'track'],
    onExecute: (context, ref) {
      try {
        ref.read(audioHandlerProvider).skipToNext();
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'playback_previous',
    title: 'Previous Track',
    subtitle: 'Return to previous track or start of current song',
    category: CommandCategory.playback,
    icon: Icons.skip_previous_rounded,
    shortcutKeys: const ['Ctrl', '←'],
    keywords: const ['previous', 'back', 'replay', 'prev'],
    onExecute: (context, ref) {
      try {
        ref.read(audioHandlerProvider).skipToPrevious();
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'playback_forward_15',
    title: 'Fast Forward (15s)',
    subtitle: 'Jump playback forward by 15 seconds',
    category: CommandCategory.playback,
    icon: Icons.fast_forward_rounded,
    shortcutKeys: const ['Shift', '→'],
    keywords: const ['seek', 'fast forward', 'jump', 'forward', '15s'],
    onExecute: (context, ref) {
      try {
        final handler = ref.read(audioHandlerProvider);
        final pos = handler.position;
        handler.seek(pos + const Duration(seconds: 15));
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'playback_rewind_15',
    title: 'Rewind (15s)',
    subtitle: 'Jump playback backward by 15 seconds',
    category: CommandCategory.playback,
    icon: Icons.fast_rewind_rounded,
    shortcutKeys: const ['Shift', '←'],
    keywords: const ['seek', 'rewind', 'backward', '15s'],
    onExecute: (context, ref) {
      try {
        final handler = ref.read(audioHandlerProvider);
        final pos = handler.position;
        final target = pos - const Duration(seconds: 15);
        handler.seek(target < Duration.zero ? Duration.zero : target);
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'playback_shuffle',
    title: 'Toggle Shuffle Mode',
    subtitle: 'Randomize queue playback order',
    category: CommandCategory.playback,
    icon: Icons.shuffle_rounded,
    shortcutKeys: const ['S'],
    keywords: const ['shuffle', 'random', 'mix'],
    onExecute: (context, ref) {
      try {
        final current = ref.read(shuffleModeStreamProvider).value ?? false;
        ref.read(audioHandlerProvider).setShuffleMode(
              !current
                  ? AudioServiceShuffleMode.all
                  : AudioServiceShuffleMode.none,
            );
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'playback_repeat',
    title: 'Cycle Repeat Mode',
    subtitle: 'Switch between repeat off, repeat all, and repeat one',
    category: CommandCategory.playback,
    icon: Icons.repeat_rounded,
    shortcutKeys: const ['R'],
    keywords: const ['repeat', 'loop', 'cycle'],
    onExecute: (context, ref) {
      try {
        final current =
            ref.read(repeatModeStreamProvider).value ?? AudioRepeatMode.off;
        final next = switch (current) {
          AudioRepeatMode.off => AudioServiceRepeatMode.all,
          AudioRepeatMode.playlist => AudioServiceRepeatMode.one,
          AudioRepeatMode.one => AudioServiceRepeatMode.none,
        };
        ref.read(audioHandlerProvider).setRepeatMode(next);
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'playback_volume_up',
    title: 'Increase Volume (+10%)',
    subtitle: 'Turn output listening volume up',
    category: CommandCategory.playback,
    icon: Icons.volume_up_rounded,
    shortcutKeys: const ['Ctrl', '↑'],
    keywords: const ['volume', 'louder', 'up', 'sound', 'audio'],
    onExecute: (context, ref) {
      try {
        final vol = ref.read(volumeStreamProvider).value ?? 1.0;
        ref.read(audioHandlerProvider).setVolume((vol + 0.1).clamp(0.0, 1.0));
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'playback_volume_down',
    title: 'Decrease Volume (-10%)',
    subtitle: 'Turn output listening volume down',
    category: CommandCategory.playback,
    icon: Icons.volume_down_rounded,
    shortcutKeys: const ['Ctrl', '↓'],
    keywords: const ['volume', 'quieter', 'down', 'sound', 'audio'],
    onExecute: (context, ref) {
      try {
        final vol = ref.read(volumeStreamProvider).value ?? 1.0;
        ref.read(audioHandlerProvider).setVolume((vol - 0.1).clamp(0.0, 1.0));
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'playback_mute',
    title: 'Toggle Mute',
    subtitle: 'Instantly silence or restore volume',
    category: CommandCategory.playback,
    icon: Icons.volume_off_rounded,
    shortcutKeys: const ['M'],
    keywords: const ['mute', 'silence', 'unmute', 'quiet'],
    onExecute: (context, ref) {
      try {
        final vol = ref.read(volumeStreamProvider).value ?? 1.0;
        if (vol > 0.0) {
          ref.read(audioHandlerProvider).setVolume(0.0);
        } else {
          ref.read(audioHandlerProvider).setVolume(0.5);
        }
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'playback_speed_10',
    title: 'Set Normal Speed (1.0x)',
    subtitle: 'Reset playback pitch and speed to 1.0x',
    category: CommandCategory.playback,
    icon: Icons.speed_rounded,
    keywords: const ['speed', 'playback speed', 'normal', '1.0x', 'tempo'],
    onExecute: (context, ref) {
      try {
        ref.read(audioHandlerProvider).setSpeed(1.0);
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'playback_speed_15',
    title: 'Set Faster Speed (1.5x)',
    subtitle: 'Accelerate playback speed to 1.5x',
    category: CommandCategory.playback,
    icon: Icons.speed_rounded,
    keywords: const ['speed', 'faster', '1.5x', 'fast', 'tempo'],
    onExecute: (context, ref) {
      try {
        ref.read(audioHandlerProvider).setSpeed(1.5);
      } catch (_) {}
    },
  ),

  // --------------------------------------------------------------------------
  // Appearance & Theme Switches
  // --------------------------------------------------------------------------
  CommandPaletteAction(
    id: 'theme_aurora',
    title: 'Switch to Aurora Glass Theme',
    subtitle: 'Vibrant frosted-glass blur & dynamic gradients',
    category: CommandCategory.theme,
    icon: Icons.blur_on_rounded,
    keywords: const ['theme', 'aurora', 'glass', 'blur', 'style', 'appearance', 'gradient'],
    onExecute: (context, ref) {
      try {
        ref.read(uiStyleProvider.notifier).setStyle(UiStyle.auroraGlass);
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'theme_classic',
    title: 'Switch to Classic Dark Theme',
    subtitle: 'Minimalist high-contrast dark theme',
    category: CommandCategory.theme,
    icon: Icons.dark_mode_rounded,
    keywords: const ['theme', 'classic', 'dark', 'black', 'metrolist', 'style'],
    onExecute: (context, ref) {
      try {
        ref.read(uiStyleProvider.notifier).setStyle(UiStyle.classic);
      } catch (_) {}
    },
  ),
  CommandPaletteAction(
    id: 'theme_oled',
    title: 'Toggle OLED Pure Black Mode',
    subtitle: 'True #000000 blacks for OLED / AMOLED displays',
    category: CommandCategory.theme,
    icon: Icons.brightness_2_rounded,
    keywords: const ['oled', 'amoled', 'black', 'pitch', 'battery', 'theme'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'theme_contrast',
    title: 'Toggle High Contrast Mode',
    subtitle: 'Enhanced text and border contrast',
    category: CommandCategory.theme,
    icon: Icons.contrast_rounded,
    keywords: const ['contrast', 'accessibility', 'bright', 'borders'],
    onExecute: (context, ref) {},
  ),

  // --------------------------------------------------------------------------
  // Tools & Utilities
  // --------------------------------------------------------------------------
  CommandPaletteAction(
    id: 'tool_shortcuts',
    title: 'Keyboard Shortcuts Cheat Sheet',
    subtitle: 'View all desktop keyboard hotkeys and controls',
    category: CommandCategory.tools,
    icon: Icons.keyboard_rounded,
    shortcutKeys: const ['?'],
    keywords: const ['shortcuts', 'hotkeys', 'cheat sheet', 'keys', 'help', 'f1'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'tool_clear_cache',
    title: 'Clear Temporary Audio Cache',
    subtitle: 'Free up disk space from cached audio streams',
    category: CommandCategory.tools,
    icon: Icons.cleaning_services_rounded,
    keywords: const ['cache', 'clear', 'clean', 'storage', 'disk', 'delete', 'free'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'tool_export_m3u',
    title: 'Export Current Playlist as M3U',
    subtitle: 'Save active playlist metadata to an M3U file',
    category: CommandCategory.tools,
    icon: Icons.file_download_rounded,
    keywords: const ['export', 'm3u', 'playlist', 'save', 'file'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'tool_import_m3u',
    title: 'Import M3U Playlist',
    subtitle: 'Load external playlist file into your library',
    category: CommandCategory.tools,
    icon: Icons.file_upload_rounded,
    keywords: const ['import', 'm3u', 'playlist', 'load', 'file'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'tool_audio_sink',
    title: 'Select Linux Audio Output Sink',
    subtitle: 'Switch PipeWire / PulseAudio / ALSA audio device',
    category: CommandCategory.tools,
    icon: Icons.speaker_group_rounded,
    keywords: const ['sink', 'device', 'audio', 'output', 'pipewire', 'pulseaudio', 'alsa', 'speakers', 'headphones'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'tool_sleep_timer',
    title: 'Set Sleep Timer to End of Track',
    subtitle: 'Automatically stop music playback when song finishes',
    category: CommandCategory.tools,
    icon: Icons.bedtime_rounded,
    keywords: const ['sleep', 'timer', 'bedtime', 'stop', 'off'],
    onExecute: (context, ref) {},
  ),
  CommandPaletteAction(
    id: 'tool_share',
    title: 'Share Current Track',
    subtitle: 'Copy song share link or metadata to clipboard',
    category: CommandCategory.tools,
    icon: Icons.share_rounded,
    keywords: const ['share', 'copy', 'link', 'url', 'clipboard'],
    onExecute: (context, ref) {},
  ),
];

// ============================================================================
// Riverpod State Providers
// ============================================================================

/// Recent commands state notifier managing executed action history.
class CommandPaletteRecentNotifier extends StateNotifier<List<String>> {
  static const String prefKey = 'command_palette_recent_actions';
  static const int maxRecent = 10;

  CommandPaletteRecentNotifier([List<String>? initial])
      : super(initial ?? const []) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(prefKey);
      if (list != null && list.isNotEmpty) {
        state = list.take(maxRecent).toList();
      }
    } catch (_) {}
  }

  Future<void> recordAction(String actionId) async {
    if (actionId.trim().isEmpty) return;
    final updated = [
      actionId,
      ...state.where((id) => id != actionId),
    ].take(maxRecent).toList();
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefKey, updated);
    } catch (_) {}
  }

  Future<void> clearRecent() async {
    state = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefKey);
    } catch (_) {}
  }
}

/// Provider managing the list of recent action IDs.
final commandPaletteRecentActionsProvider =
    StateNotifierProvider<CommandPaletteRecentNotifier, List<String>>((ref) {
  return CommandPaletteRecentNotifier();
});

/// Provider for custom user-registered actions.
final commandPaletteCustomActionsProvider =
    StateProvider<List<CommandPaletteAction>>((ref) => const []);

/// Provider aggregating built-in actions and custom user actions.
final commandPaletteAllActionsProvider =
    Provider<List<CommandPaletteAction>>((ref) {
  final custom = ref.watch(commandPaletteCustomActionsProvider);
  return [
    ...defaultCommandPaletteActions,
    ...custom,
  ];
});

/// Provider managing active search query in the command palette.
final commandPaletteQueryProvider = StateProvider<String>((ref) => '');

/// Provider managing active category filter tab in the command palette.
final commandPaletteCategoryFilterProvider =
    StateProvider<CommandCategory?>((ref) => null);

/// Provider computing filtered and ranked fuzzy search results.
final commandPaletteSearchResultsProvider =
    Provider<List<FuzzyMatchResult>>((ref) {
  final actions = ref.watch(commandPaletteAllActionsProvider);
  final query = ref.watch(commandPaletteQueryProvider);
  final category = ref.watch(commandPaletteCategoryFilterProvider);
  final recentIds = ref.watch(commandPaletteRecentActionsProvider);

  return CommandPaletteSearchEngine.search(
    actions: actions,
    query: query,
    categoryFilter: category,
    recentActionIds: recentIds,
  );
});

// ============================================================================
// Widgets: Keycaps & Tile Components
// ============================================================================

/// Single visual keycap rendering with dark elevated surface and border highlights.
class CommandKeycap extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isSmall;

  const CommandKeycap({
    super.key,
    required this.label,
    this.isSelected = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: isSmall ? 20 : 26,
        minHeight: isSmall ? 20 : 26,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 5 : 7,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2C2F38) : const Color(0xFF1E2026),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isSelected ? const Color(0x66ED5564) : const Color(0x38FFFFFF),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x60000000),
            offset: Offset(0, 1.5),
            blurRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontUi,
          fontSize: isSmall ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: isSelected ? const Color(0xFFFF8592) : const Color(0xFFE6E1E5),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Renders a list of keycaps separated by small gaps.
class CommandKeycapGroup extends StatelessWidget {
  final List<String> keys;
  final bool isSelected;

  const CommandKeycapGroup({
    super.key,
    required this.keys,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    if (keys.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          CommandKeycap(
            label: keys[i],
            isSelected: isSelected,
          ),
        ],
      ],
    );
  }
}

/// Individual item tile representing an action in the command palette list.
class CommandPaletteItemTile extends StatelessWidget {
  final FuzzyMatchResult matchResult;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onHover;

  const CommandPaletteItemTile({
    super.key,
    required this.matchResult,
    required this.isSelected,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final action = matchResult.action;
    final categoryColor = action.category.getAccentColor(tokens);

    return MouseRegion(
      onEnter: (_) => onHover(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (tokens.isGlass
                    ? tokens.glassBorder.withOpacity(0.25)
                    : tokens.surfaceHighlight)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? tokens.accent.withOpacity(0.55)
                  : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              // Left Accent Selection Bar
              Container(
                width: 3.5,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected ? tokens.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),

              // Category Icon Container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(isSelected ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  action.icon,
                  size: 20,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 12),

              // Title & Subtitle Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHighlightedTitle(action.title, matchResult.matchedTitleIndices, tokens),
                    if (action.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        action.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Trailing Shortcuts or Enter Keycap
              if (isSelected)
                const CommandKeycap(label: '↵ Enter', isSelected: true)
              else if (action.shortcutKeys.isNotEmpty)
                CommandKeycapGroup(keys: action.shortcutKeys)
              else if (action.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    action.badge!,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: tokens.primaryLight,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a rich text title with highlighted matching characters.
  Widget _buildHighlightedTitle(
    String title,
    List<int> matchedIndices,
    AppTokens tokens,
  ) {
    if (matchedIndices.isEmpty) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppTheme.fontUi,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: tokens.textPrimary,
        ),
      );
    }

    final matchSet = matchedIndices.toSet();
    final List<TextSpan> spans = [];
    StringBuffer currentBuffer = StringBuffer();
    bool currentIsMatched = false;

    for (int i = 0; i < title.length; i++) {
      final isCharMatched = matchSet.contains(i);
      if (i == 0) {
        currentIsMatched = isCharMatched;
        currentBuffer.write(title[i]);
      } else if (isCharMatched == currentIsMatched) {
        currentBuffer.write(title[i]);
      } else {
        spans.add(
          TextSpan(
            text: currentBuffer.toString(),
            style: currentIsMatched
                ? TextStyle(
                    color: tokens.accent,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: tokens.accent.withOpacity(0.6),
                  )
                : TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
          ),
        );
        currentBuffer = StringBuffer()..write(title[i]);
        currentIsMatched = isCharMatched;
      }
    }

    if (currentBuffer.isNotEmpty) {
      spans.add(
        TextSpan(
          text: currentBuffer.toString(),
          style: currentIsMatched
              ? TextStyle(
                  color: tokens.accent,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: tokens.accent.withOpacity(0.6),
                )
              : TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
        ),
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontFamily: AppTheme.fontUi,
          fontSize: 14,
        ),
        children: spans,
      ),
    );
  }
}

// ============================================================================
// Main Command Palette Dialog Widget
// ============================================================================

/// Desktop HUD Command Palette modal dialog with keyboard navigation.
class CommandPaletteDialog extends ConsumerStatefulWidget {
  final List<CommandPaletteAction>? customActions;
  final String? initialQuery;
  final CommandCategory? initialCategory;
  final void Function(CommandPaletteAction action)? onActionExecuted;

  const CommandPaletteDialog({
    super.key,
    this.customActions,
    this.initialQuery,
    this.initialCategory,
    this.onActionExecuted,
  });

  /// Displays the Command Palette dialog centered with a backdrop blur scrim.
  static Future<void> show(
    BuildContext context, {
    List<CommandPaletteAction>? customActions,
    String? initialQuery,
    CommandCategory? initialCategory,
    void Function(CommandPaletteAction action)? onActionExecuted,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: CommandPaletteDialog(
          customActions: customActions,
          initialQuery: initialQuery,
          initialCategory: initialCategory,
          onActionExecuted: onActionExecuted,
        ),
      ),
    );
  }

  @override
  ConsumerState<CommandPaletteDialog> createState() =>
      _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends ConsumerState<CommandPaletteDialog> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final ScrollController _scrollController;
  int _selectedIndex = 0;
  CommandCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _searchFocusNode = FocusNode(
      debugLabel: 'CommandPaletteSearchFocus',
      onKeyEvent: _handleKeyEvent,
    );
    _scrollController = ScrollController();
    _selectedCategory = widget.initialCategory;

    // Listen to query changes to reset index and scroll position
    _searchController.addListener(_onSearchQueryChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchQueryChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged() {
    setState(() {
      _selectedIndex = 0;
    });
    _scrollToIndex(0);
  }

  /// Handles keyboard navigation events (Up/Down/Enter/Escape).
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final results = _getEffectiveResults();
    if (results.isEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % results.length;
      });
      _scrollToIndex(_selectedIndex);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + results.length) % results.length;
      });
      _scrollToIndex(_selectedIndex);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_selectedIndex >= 0 && _selectedIndex < results.length) {
        _executeAction(results[_selectedIndex].action);
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  List<FuzzyMatchResult> _getEffectiveResults() {
    final baseActions = ref.watch(commandPaletteAllActionsProvider);
    final allActions = widget.customActions != null && widget.customActions!.isNotEmpty
        ? [...widget.customActions!, ...baseActions]
        : baseActions;
    final recentIds = ref.watch(commandPaletteRecentActionsProvider);

    return CommandPaletteSearchEngine.search(
      actions: allActions,
      query: _searchController.text,
      categoryFilter: _selectedCategory,
      recentActionIds: recentIds,
    );
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 60.0;
    final targetOffset = (index * itemHeight) - 100.0;
    final clamped = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 70),
      curve: Curves.easeOut,
    );
  }

  void _executeAction(CommandPaletteAction action) {
    ref.read(commandPaletteRecentActionsProvider.notifier).recordAction(action.id);
    if (widget.onActionExecuted != null) {
      widget.onActionExecuted!(action);
    }
    if (action.closeOnExecute) {
      Navigator.of(context).maybePop();
    }
    if (action.onExecute != null) {
      action.onExecute!(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final results = _getEffectiveResults();
    final recentIds = ref.watch(commandPaletteRecentActionsProvider);

    // Clamp selected index if query reduced results count
    if (_selectedIndex >= results.length && results.isNotEmpty) {
      _selectedIndex = results.length - 1;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop();
        },
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 660,
            maxHeight: 560,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: tokens.isGlass
                    ? tokens.glassBorder
                    : tokens.accent.withOpacity(0.28),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.65),
                  offset: const Offset(0, 18),
                  blurRadius: 36,
                ),
                BoxShadow(
                  color: tokens.accent.withOpacity(0.12),
                  offset: const Offset(0, 0),
                  blurRadius: 24,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Search Bar Header
                    _buildSearchBar(tokens),

                    // 2. Category Filter Pills
                    _buildCategoryFilterBar(tokens, recentIds.isNotEmpty),

                    const Divider(height: 1, color: Colors.white12),

                    // 3. Scrollable Results List
                    Flexible(
                      child: results.isEmpty
                          ? _buildEmptyState(tokens)
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                return CommandPaletteItemTile(
                                  matchResult: results[index],
                                  isSelected: index == _selectedIndex,
                                  onTap: () => _executeAction(results[index].action),
                                  onHover: () {
                                    setState(() {
                                      _selectedIndex = index;
                                    });
                                  },
                                );
                              },
                            ),
                    ),

                    const Divider(height: 1, color: Colors.white12),

                    // 4. Desktop HUD Footer
                    _buildFooter(tokens, results.length),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the top search input bar with search icon and clear button.
  Widget _buildSearchBar(AppTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surface.withOpacity(0.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: tokens.accent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: tokens.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Type a command, tool, or shortcut...',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 15,
                  color: tokens.textMuted,
                ),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: tokens.textSecondary,
              splashRadius: 16,
              onPressed: () {
                _searchController.clear();
              },
            ),
            const SizedBox(width: 6),
          ],
          const CommandKeycap(label: 'ESC', isSmall: true),
        ],
      ),
    );
  }

  /// Builds the horizontal category filtering chip bar.
  Widget _buildCategoryFilterBar(AppTokens tokens, bool hasRecent) {
    final categories = <CommandCategory?>[
      null, // "All"
      if (hasRecent) CommandCategory.recent,
      CommandCategory.navigation,
      CommandCategory.playback,
      CommandCategory.theme,
      CommandCategory.tools,
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: tokens.surfaceElevated.withOpacity(0.6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          final label = cat == null ? 'All' : cat.label;
          final icon = cat == null ? Icons.apps_rounded : cat.icon;

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                _selectedCategory = cat;
                _selectedIndex = 0;
              });
              _scrollToIndex(0);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? tokens.accent.withOpacity(0.2)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? tokens.accent
                      : Colors.white.withOpacity(0.08),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? tokens.accent : tokens.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? tokens.accent : tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Empty state displayed when no commands match the query.
  Widget _buildEmptyState(AppTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 48,
              color: tokens.textMuted.withOpacity(0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'No matching commands found',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try searching for playback, themes, settings, or tools',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 12,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedCategory = null;
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Search & Filters'),
              style: TextButton.styleFrom(
                foregroundColor: tokens.accent,
                textStyle: const TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Desktop HUD footer showing keyboard shortcuts navigation tips and match counter.
  Widget _buildFooter(AppTokens tokens, int resultCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black.withOpacity(0.25),
      child: Row(
        children: [
          // Navigation tips
          Row(
            children: [
              const CommandKeycap(label: '↑', isSmall: true),
              const SizedBox(width: 2),
              const CommandKeycap(label: '↓', isSmall: true),
              const SizedBox(width: 6),
              Text(
                'Navigate',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              const CommandKeycap(label: '↵', isSmall: true),
              const SizedBox(width: 6),
              Text(
                'Execute',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              const CommandKeycap(label: 'ESC', isSmall: true),
              const SizedBox(width: 6),
              Text(
                'Dismiss',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Results counter
          Text(
            '$resultCount command${resultCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Global Shortcut Wrapper: Ctrl+K / Cmd+K Listener
// ============================================================================

/// Global desktop shortcut wrapper listening for Ctrl+K, Cmd+K, and F2
/// to present the Universal Command Palette.
class CommandPaletteShortcutListener extends StatelessWidget {
  final Widget child;
  final List<CommandPaletteAction>? customActions;
  final bool enabled;

  const CommandPaletteShortcutListener({
    super.key,
    required this.child,
    this.customActions,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          CommandPaletteDialog.show(context, customActions: customActions);
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          CommandPaletteDialog.show(context, customActions: customActions);
        },
        const SingleActivator(LogicalKeyboardKey.f2): () {
          CommandPaletteDialog.show(context, customActions: customActions);
        },
      },
      child: child,
    );
  }
}
