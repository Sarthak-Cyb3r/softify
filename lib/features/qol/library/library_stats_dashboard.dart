import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// 1. SharedPreferences Persistence Layer (Zero-Dependency & Self-Contained)
// ============================================================================

/// Storage keys for library statistics user preferences.
const String kLibraryStatsSortMetricPrefKey = 'library_stats_sort_metric';
const String kLibraryStatsFilterScopePrefKey = 'library_stats_filter_scope';

/// Self-contained, durable SharedPreferences engine matching the standard API.
/// Persists preferences across sessions without external plugin dependencies.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _preferenceStore;
  final File? _storageFile;

  SharedPreferences._(this._preferenceStore, this._storageFile);

  /// Injects initial values for test suites and harnesses.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Asynchronously loads or initializes the shared preferences storage.
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
      // In-memory fallback if file system access fails
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
        return File('${dir.path}/shared_preferences.json');
      }
      return File('.softify_shared_preferences.json');
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

  bool? getBool(String key) {
    final val = _preferenceStore[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
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
}

// ============================================================================
// 2. Data Models & Statistics Domain Entities
// ============================================================================

/// Sorting criteria for the Top Artists breakdown.
enum ArtistSortMetric {
  trackCount('By Tracks', Icons.queue_music_rounded),
  playtime('By Playtime', Icons.schedule_rounded);

  final String label;
  final IconData icon;
  const ArtistSortMetric(this.label, this.icon);
}

/// Filter scope for calculating library statistics.
enum LibraryFilterScope {
  all('All Songs', Icons.library_music_rounded),
  likedOnly('Favorites Only', Icons.favorite_rounded);

  final String label;
  final IconData icon;
  const LibraryFilterScope(this.label, this.icon);
}

/// Breakdown statistics for an individual artist in the user's library.
@immutable
class ArtistStat {
  final String artist;
  final int trackCount;
  final Duration totalDuration;
  final double percentage; // 0.0 to 100.0 relative to total library

  const ArtistStat({
    required this.artist,
    required this.trackCount,
    required this.totalDuration,
    required this.percentage,
  });

  /// Formatted duration in hours & minutes, or minutes & seconds.
  String get formattedPlaytime {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;
    final seconds = totalDuration.inSeconds % 60;

    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    } else if (minutes > 0) {
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    } else {
      return '${seconds}s';
    }
  }

  /// Total playtime represented in fractional hours.
  double get playtimeHours => totalDuration.inSeconds / 3600.0;

  /// Formatted percentage string (e.g. "24.5%").
  String get formattedPercentage => '${percentage.toStringAsFixed(1)}%';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtistStat &&
          runtimeType == other.runtimeType &&
          artist == other.artist &&
          trackCount == other.trackCount &&
          totalDuration == other.totalDuration &&
          (percentage - other.percentage).abs() < 0.001;

  @override
  int get hashCode => Object.hash(artist, trackCount, totalDuration, percentage.round());

  @override
  String toString() =>
      'ArtistStat(artist: $artist, tracks: $trackCount, playtime: $formattedPlaytime, share: $formattedPercentage)';
}

/// Breakdown between audiophile lossless formats and lossy compressed formats.
@immutable
class AudioQualityBreakdown {
  final int losslessCount;
  final int compressedCount;

  const AudioQualityBreakdown({
    required this.losslessCount,
    required this.compressedCount,
  });

  static const empty = AudioQualityBreakdown(losslessCount: 0, compressedCount: 0);

  int get totalCount => losslessCount + compressedCount;

  double get losslessRatio => totalCount > 0 ? losslessCount / totalCount : 0.0;
  double get compressedRatio => totalCount > 0 ? compressedCount / totalCount : 0.0;

  double get losslessPercentage => losslessRatio * 100.0;
  double get compressedPercentage => compressedRatio * 100.0;

  String get formattedLosslessPercentage => '${losslessPercentage.toStringAsFixed(1)}%';
  String get formattedCompressedPercentage => '${compressedPercentage.toStringAsFixed(1)}%';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioQualityBreakdown &&
          runtimeType == other.runtimeType &&
          losslessCount == other.losslessCount &&
          compressedCount == other.compressedCount;

  @override
  int get hashCode => Object.hash(losslessCount, compressedCount);

  @override
  String toString() =>
      'AudioQualityBreakdown(lossless: $losslessCount ($formattedLosslessPercentage), compressed: $compressedCount ($formattedCompressedPercentage))';
}

/// Comprehensive aggregated metrics for a music library collection.
@immutable
class LibraryStats {
  final int totalTracks;
  final Duration totalPlaytime;
  final List<ArtistStat> topArtists; // Capped to top 5 (or configured limit)
  final AudioQualityBreakdown qualityBreakdown;
  final int uniqueArtistCount;
  final int uniqueAlbumCount;
  final Duration averageTrackDuration;

  const LibraryStats({
    required this.totalTracks,
    required this.totalPlaytime,
    required this.topArtists,
    required this.qualityBreakdown,
    required this.uniqueArtistCount,
    required this.uniqueAlbumCount,
    required this.averageTrackDuration,
  });

  /// Canonical empty library stats state.
  static const empty = LibraryStats(
    totalTracks: 0,
    totalPlaytime: Duration.zero,
    topArtists: [],
    qualityBreakdown: AudioQualityBreakdown.empty,
    uniqueArtistCount: 0,
    uniqueAlbumCount: 0,
    averageTrackDuration: Duration.zero,
  );

  bool get isEmpty => totalTracks == 0;
  bool get isNotEmpty => totalTracks > 0;

  /// Shorthand accessors for audio quality counts.
  int get losslessCount => qualityBreakdown.losslessCount;
  int get compressedCount => qualityBreakdown.compressedCount;

  /// Total playtime represented in fractional hours.
  double get totalPlaytimeHours => totalPlaytime.inSeconds / 3600.0;

  /// Formatted playtime string (e.g. "42.5 hrs").
  String get formattedPlaytimeHours => '${totalPlaytimeHours.toStringAsFixed(1)} hrs';

  /// Verbose human-readable total playtime (e.g., "3d 4h 12m" or "14h 32m").
  String get formattedTotalPlaytime {
    final days = totalPlaytime.inDays;
    final hours = totalPlaytime.inHours % 24;
    final minutes = totalPlaytime.inMinutes % 60;
    final seconds = totalPlaytime.inSeconds % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (totalPlaytime.inHours > 0) {
      return '${totalPlaytime.inHours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Formatted average track length (e.g. "3m 45s").
  String get formattedAverageDuration {
    final minutes = averageTrackDuration.inMinutes;
    final seconds = averageTrackDuration.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryStats &&
          runtimeType == other.runtimeType &&
          totalTracks == other.totalTracks &&
          totalPlaytime == other.totalPlaytime &&
          qualityBreakdown == other.qualityBreakdown &&
          uniqueArtistCount == other.uniqueArtistCount &&
          uniqueAlbumCount == other.uniqueAlbumCount &&
          averageTrackDuration == other.averageTrackDuration;

  @override
  int get hashCode => Object.hash(
        totalTracks,
        totalPlaytime,
        qualityBreakdown,
        uniqueArtistCount,
        uniqueAlbumCount,
        averageTrackDuration,
      );

  @override
  String toString() =>
      'LibraryStats(tracks: $totalTracks, hours: $formattedPlaytimeHours, lossless: $losslessCount, compressed: $compressedCount, topArtists: ${topArtists.length})';
}

// ============================================================================
// 3. Library Statistics Aggregator (Pure Business Logic)
// ============================================================================

/// High-performance, pure Dart aggregator that processes track collections
/// and calculates comprehensive playback, artist, and audio quality analytics.
class LibraryStatsAggregator {
  const LibraryStatsAggregator._();

  /// Known file extensions, codecs, and tags that designate audiophile lossless quality.
  static const Set<String> _losslessSignatures = {
    '.flac',
    '.wav',
    '.alac',
    '.aiff',
    '.aif',
    '.dsd',
    '.dff',
    '.dsf',
    '.pcm',
    '.wv',
    '.ape',
  };

  /// Explicit lossy/compressed file extensions.
  static const Set<String> _compressedSignatures = {
    '.mp3',
    '.m4a',
    '.aac',
    '.ogg',
    '.opus',
    '.webm',
    '.wma',
    '.mp4',
  };

  /// Determines whether a given audio path, URI, or format identifier represents lossless audio.
  static bool isLosslessFormat(String identifierOrPath) {
    final lower = identifierOrPath.trim().toLowerCase();
    if (lower.isEmpty) return false;

    // Check file extensions
    for (final sig in _losslessSignatures) {
      if (lower.endsWith(sig) || lower.contains(sig + '?') || lower.contains('$sig#')) {
        return true;
      }
    }

    // Check audiophile metadata keywords
    if (lower.contains('[flac]') ||
        lower.contains('(flac)') ||
        lower.contains('lossless') ||
        lower.contains('hi-res') ||
        lower.contains('studio master') ||
        lower == 'flac' ||
        lower == 'alac' ||
        lower == 'wav') {
      return true;
    }

    return false;
  }

  /// Determines if an individual [Track] has lossless audio quality.
  static bool isTrackLossless(
    Track track, {
    bool Function(Track track)? customResolver,
  }) {
    if (customResolver != null) {
      return customResolver(track);
    }

    // 1. Check sourceId and track ID for file extensions or lossless markers
    if (isLosslessFormat(track.sourceId)) return true;
    if (isLosslessFormat(track.id)) return true;

    // 2. Check title and album for audiophile indicators
    if (isLosslessFormat(track.title)) return true;
    if (track.album != null && isLosslessFormat(track.album!)) return true;

    // Default to compressed (e.g. streaming sources Opus/AAC)
    return false;
  }

  /// Computes a [LibraryStats] snapshot from the provided [tracks].
  ///
  /// - [sortMetric]: whether to rank top artists by track count or duration.
  /// - [topArtistLimit]: number of top artists to extract (defaults to 5).
  /// - [isLosslessResolver]: optional custom predicate for format categorization.
  static LibraryStats aggregate({
    required Iterable<Track> tracks,
    ArtistSortMetric sortMetric = ArtistSortMetric.trackCount,
    int topArtistLimit = 5,
    bool Function(Track track)? isLosslessResolver,
  }) {
    final trackList = tracks.toList(growable: false);
    if (trackList.isEmpty) {
      return LibraryStats.empty;
    }

    final totalTracks = trackList.length;
    int totalMilliseconds = 0;
    int losslessCount = 0;
    int compressedCount = 0;

    final Map<String, int> artistTrackCounts = {};
    final Map<String, int> artistDurations = {};
    final Set<String> uniqueAlbums = {};

    for (final track in trackList) {
      // 1. Playtime aggregation
      final durationMs = max(0, track.duration.inMilliseconds);
      totalMilliseconds += durationMs;

      // 2. Artist grouping
      final rawArtist = track.artist.trim();
      final artist = rawArtist.isEmpty ? 'Unknown Artist' : rawArtist;
      artistTrackCounts[artist] = (artistTrackCounts[artist] ?? 0) + 1;
      artistDurations[artist] = (artistDurations[artist] ?? 0) + durationMs;

      // 3. Album tracking
      final album = track.album?.trim();
      if (album != null && album.isNotEmpty) {
        uniqueAlbums.add(album);
      }

      // 4. Quality classification
      if (isTrackLossless(track, customResolver: isLosslessResolver)) {
        losslessCount++;
      } else {
        compressedCount++;
      }
    }

    final totalPlaytime = Duration(milliseconds: totalMilliseconds);
    final averageTrackDuration = totalTracks > 0
        ? Duration(milliseconds: totalMilliseconds ~/ totalTracks)
        : Duration.zero;

    // 5. Sort & Rank Artists
    final allArtists = artistTrackCounts.keys.toList();
    allArtists.sort((a, b) {
      if (sortMetric == ArtistSortMetric.trackCount) {
        final countCompare = artistTrackCounts[b]!.compareTo(artistTrackCounts[a]!);
        if (countCompare != 0) return countCompare;
        final durationCompare = artistDurations[b]!.compareTo(artistDurations[a]!);
        if (durationCompare != 0) return durationCompare;
        return a.compareTo(b);
      } else {
        final durationCompare = artistDurations[b]!.compareTo(artistDurations[a]!);
        if (durationCompare != 0) return durationCompare;
        final countCompare = artistTrackCounts[b]!.compareTo(artistTrackCounts[a]!);
        if (countCompare != 0) return countCompare;
        return a.compareTo(b);
      }
    });

    final topArtistsSubset = allArtists.take(topArtistLimit);
    final List<ArtistStat> topArtistStats = [];

    for (final artist in topArtistsSubset) {
      final count = artistTrackCounts[artist]!;
      final duration = Duration(milliseconds: artistDurations[artist]!);

      final double percentage;
      if (sortMetric == ArtistSortMetric.trackCount) {
        percentage = totalTracks > 0 ? (count / totalTracks) * 100.0 : 0.0;
      } else {
        percentage = totalMilliseconds > 0 ? (duration.inMilliseconds / totalMilliseconds) * 100.0 : 0.0;
      }

      topArtistStats.add(ArtistStat(
        artist: artist,
        trackCount: count,
        totalDuration: duration,
        percentage: percentage,
      ));
    }

    return LibraryStats(
      totalTracks: totalTracks,
      totalPlaytime: totalPlaytime,
      topArtists: List.unmodifiable(topArtistStats),
      qualityBreakdown: AudioQualityBreakdown(
        losslessCount: losslessCount,
        compressedCount: compressedCount,
      ),
      uniqueArtistCount: artistTrackCounts.length,
      uniqueAlbumCount: uniqueAlbums.length,
      averageTrackDuration: averageTrackDuration,
    );
  }
}

// ============================================================================
// 4. Riverpod State Providers & Notifiers
// ============================================================================

/// Notifier managing persistence of the Top Artists sort metric.
class LibraryStatsSortNotifier extends StateNotifier<ArtistSortMetric> {
  SharedPreferences? _prefs;

  LibraryStatsSortNotifier({SharedPreferences? prefs})
      : _prefs = prefs,
        super(ArtistSortMetric.trackCount) {
    _init();
  }

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final saved = _prefs?.getString(kLibraryStatsSortMetricPrefKey);
    if (saved != null) {
      if (saved == ArtistSortMetric.playtime.name) {
        state = ArtistSortMetric.playtime;
      } else {
        state = ArtistSortMetric.trackCount;
      }
    }
  }

  void setMetric(ArtistSortMetric metric) {
    if (state != metric) {
      state = metric;
      _prefs?.setString(kLibraryStatsSortMetricPrefKey, metric.name);
    }
  }

  void toggle() {
    final next = state == ArtistSortMetric.trackCount
        ? ArtistSortMetric.playtime
        : ArtistSortMetric.trackCount;
    setMetric(next);
  }
}

/// Provider for the Top Artists sorting criteria.
final libraryStatsSortMetricProvider =
    StateNotifierProvider<LibraryStatsSortNotifier, ArtistSortMetric>((ref) {
  return LibraryStatsSortNotifier();
});

/// Notifier managing persistence of the library statistics filter scope.
class LibraryStatsFilterNotifier extends StateNotifier<LibraryFilterScope> {
  SharedPreferences? _prefs;

  LibraryStatsFilterNotifier({SharedPreferences? prefs})
      : _prefs = prefs,
        super(LibraryFilterScope.all) {
    _init();
  }

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final saved = _prefs?.getString(kLibraryStatsFilterScopePrefKey);
    if (saved != null) {
      if (saved == LibraryFilterScope.likedOnly.name) {
        state = LibraryFilterScope.likedOnly;
      } else {
        state = LibraryFilterScope.all;
      }
    }
  }

  void setScope(LibraryFilterScope scope) {
    if (state != scope) {
      state = scope;
      _prefs?.setString(kLibraryStatsFilterScopePrefKey, scope.name);
    }
  }
}

/// Provider for the library filter scope (all vs liked-only).
final libraryStatsFilterScopeProvider =
    StateNotifierProvider<LibraryStatsFilterNotifier, LibraryFilterScope>((ref) {
  return LibraryStatsFilterNotifier();
});

/// Injected custom tracks provider (primarily for tests and controlled scopes).
final libraryStatsCustomTracksProvider = StateProvider<List<Track>?>((ref) => null);

/// Computed Riverpod provider yielding real-time [LibraryStats].
final libraryStatsProvider = Provider<LibraryStats>((ref) {
  final customTracks = ref.watch(libraryStatsCustomTracksProvider);
  final sortMetric = ref.watch(libraryStatsSortMetricProvider);

  List<Track> effectiveTracks = [];
  if (customTracks != null) {
    effectiveTracks = customTracks;
  } else {
    // Watch liked tracks as canonical library source
    final likedAsync = ref.watch(likedTracksStreamProvider);
    effectiveTracks = likedAsync.valueOrNull ?? [];
  }

  return LibraryStatsAggregator.aggregate(
    tracks: effectiveTracks,
    sortMetric: sortMetric,
    topArtistLimit: 5,
  );
});

// ============================================================================
// 5. Presentation Widgets: Material 3 Dashboard & Visual Breakdown Bars
// ============================================================================

/// Modern Material 3 dashboard widget displaying comprehensive library statistics,
/// total playtime, top 5 artists, and audio quality breakdown bars.
class LibraryStatsDashboardWidget extends ConsumerWidget {
  /// Optional standalone tracks list override.
  final List<Track>? tracks;

  /// Whether to display the top header banner.
  final bool showHeader;

  /// Whether the view is dismissible (e.g. inside a modal bottom sheet).
  final bool isDismissible;

  /// Outer padding for the dashboard container.
  final EdgeInsetsGeometry padding;

  const LibraryStatsDashboardWidget({
    super.key,
    this.tracks,
    this.showHeader = true,
    this.isDismissible = false,
    this.padding = const EdgeInsets.all(20),
  });

  /// Displays the library statistics dashboard in a modal bottom sheet.
  static Future<void> showBottomSheet(
    BuildContext context, {
    List<Track>? tracks,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Material(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Grab handle
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: LibraryStatsDashboardWidget(
                    tracks: tracks,
                    showHeader: true,
                    isDismissible: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Displays the dashboard inside a centered dialog.
  static Future<void> showAsDialog(
    BuildContext context, {
    List<Track>? tracks,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
          child: SingleChildScrollView(
            child: LibraryStatsDashboardWidget(
              tracks: tracks,
              showHeader: true,
              isDismissible: true,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final sortMetric = ref.watch(libraryStatsSortMetricProvider);

    // Compute stats from passed tracks or from provider
    final LibraryStats stats;
    if (tracks != null) {
      stats = LibraryStatsAggregator.aggregate(
        tracks: tracks!,
        sortMetric: sortMetric,
        topArtistLimit: 5,
      );
    } else {
      stats = ref.watch(libraryStatsProvider);
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header Section
          if (showHeader) ...[
            _DashboardHeader(
              isDismissible: isDismissible,
              sortMetric: sortMetric,
              onToggleSort: () => ref.read(libraryStatsSortMetricProvider.notifier).toggle(),
            ),
            const SizedBox(height: 20),
          ],

          // 2. Main Content or Empty State
          if (stats.isEmpty) ...[
            _EmptyLibraryCard(tokens: tokens),
          ] else ...[
            // Stat Cards Grid
            _StatCardsGrid(stats: stats, tokens: tokens),
            const SizedBox(height: 24),

            // Audio Quality Breakdown Bar
            _AudioQualityCard(breakdown: stats.qualityBreakdown, tokens: tokens),
            const SizedBox(height: 24),

            // Top 5 Artists & Playtime Charts
            _TopArtistsSection(
              stats: stats,
              sortMetric: sortMetric,
              tokens: tokens,
              onSelectMetric: (metric) =>
                  ref.read(libraryStatsSortMetricProvider.notifier).setMetric(metric),
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Internal Sub-widgets & Material 3 Building Blocks
// ----------------------------------------------------------------------------

class _DashboardHeader extends StatelessWidget {
  final bool isDismissible;
  final ArtistSortMetric sortMetric;
  final VoidCallback onToggleSort;

  const _DashboardHeader({
    required this.isDismissible,
    required this.sortMetric,
    required this.onToggleSort,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tokens.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(tokens.radiusCard),
            border: Border.all(
              color: tokens.accent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.analytics_rounded,
            color: tokens.accent,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Library Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Playtime insights & format breakdown',
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (isDismissible)
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: tokens.textSecondary,
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
      ],
    );
  }
}

class _EmptyLibraryCard extends StatelessWidget {
  final AppTokens tokens;

  const _EmptyLibraryCard({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 56,
            color: tokens.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'No Tracks in Library',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add songs to your favorites or scan local folders to view playtime charts and audio quality statistics.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: tokens.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardsGrid extends StatelessWidget {
  final LibraryStats stats;
  final AppTokens tokens;

  const _StatCardsGrid({required this.stats, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;

        final cardTotalTracks = _StatCard(
          title: 'Total Tracks',
          value: stats.totalTracks.toString(),
          subtitle: '${stats.uniqueAlbumCount} albums',
          icon: Icons.library_music_rounded,
          iconColor: tokens.accentCyan,
          tokens: tokens,
        );

        final cardTotalPlaytime = _StatCard(
          title: 'Total Playtime',
          value: stats.formattedPlaytimeHours,
          subtitle: stats.formattedTotalPlaytime,
          icon: Icons.access_time_filled_rounded,
          iconColor: tokens.accent,
          tokens: tokens,
        );

        final cardAvgDuration = _StatCard(
          title: 'Avg Track Length',
          value: stats.formattedAverageDuration,
          subtitle: 'per song',
          icon: Icons.timer_outlined,
          iconColor: tokens.accentViolet,
          tokens: tokens,
        );

        final cardArtists = _StatCard(
          title: 'Artists',
          value: stats.uniqueArtistCount.toString(),
          subtitle: 'unique performers',
          icon: Icons.people_alt_rounded,
          iconColor: const Color(0xFFD4AF37), // Gold
          tokens: tokens,
        );

        if (isNarrow) {
          return Column(
            children: [
              cardTotalTracks,
              const SizedBox(height: 10),
              cardTotalPlaytime,
              const SizedBox(height: 10),
              cardAvgDuration,
              const SizedBox(height: 10),
              cardArtists,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cardTotalTracks),
            const SizedBox(width: 12),
            Expanded(child: cardTotalPlaytime),
            const SizedBox(width: 12),
            Expanded(child: cardAvgDuration),
            const SizedBox(width: 12),
            Expanded(child: cardArtists),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final AppTokens tokens;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: tokens.textMuted,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual breakdown card showcasing Lossless vs Compressed audio quality.
class _AudioQualityCard extends StatelessWidget {
  final AudioQualityBreakdown breakdown;
  final AppTokens tokens;

  const _AudioQualityCard({required this.breakdown, required this.tokens});

  @override
  Widget build(BuildContext context) {
    const losslessColor = Color(0xFFD4AF37); // Audiophile Studio Gold
    final compressedColor = tokens.accentCyan; // Metrolist Cyan

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.high_quality_rounded, size: 20, color: tokens.textPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Audio Quality Breakdown',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Text(
                '${breakdown.totalCount} tracks evaluated',
                style: TextStyle(fontSize: 12, color: tokens.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Segmented Breakdown Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (breakdown.losslessCount > 0)
                    Expanded(
                      flex: max(1, (breakdown.losslessRatio * 1000).round()),
                      child: Container(
                        color: losslessColor,
                      ),
                    ),
                  if (breakdown.losslessCount > 0 && breakdown.compressedCount > 0)
                    const SizedBox(width: 2),
                  if (breakdown.compressedCount > 0)
                    Expanded(
                      flex: max(1, (breakdown.compressedRatio * 1000).round()),
                      child: Container(
                        color: compressedColor,
                      ),
                    ),
                  if (breakdown.totalCount == 0)
                    Expanded(
                      child: Container(color: tokens.divider),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Legend & Counts
          Row(
            children: [
              // Lossless legend
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: losslessColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lossless (FLAC / Hi-Res)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                          Text(
                            '${breakdown.losslessCount} tracks (${breakdown.formattedLosslessPercentage})',
                            style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Compressed legend
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: compressedColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compressed (AAC / MP3)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                          Text(
                            '${breakdown.compressedCount} tracks (${breakdown.formattedCompressedPercentage})',
                            style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Top 5 Artists list with playtime breakdown progress bars.
class _TopArtistsSection extends StatelessWidget {
  final LibraryStats stats;
  final ArtistSortMetric sortMetric;
  final AppTokens tokens;
  final ValueChanged<ArtistSortMetric> onSelectMetric;

  const _TopArtistsSection({
    required this.stats,
    required this.sortMetric,
    required this.tokens,
    required this.onSelectMetric,
  });

  @override
  Widget build(BuildContext context) {
    final topArtists = stats.topArtists;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.leaderboard_rounded, size: 20, color: tokens.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Top 5 Artists',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              // Segmented metric toggle
              Container(
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  border: Border.all(color: tokens.divider),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MetricChip(
                      label: 'Tracks',
                      icon: Icons.music_note_rounded,
                      isSelected: sortMetric == ArtistSortMetric.trackCount,
                      tokens: tokens,
                      onTap: () => onSelectMetric(ArtistSortMetric.trackCount),
                    ),
                    _MetricChip(
                      label: 'Playtime',
                      icon: Icons.schedule_rounded,
                      isSelected: sortMetric == ArtistSortMetric.playtime,
                      tokens: tokens,
                      onTap: () => onSelectMetric(ArtistSortMetric.playtime),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (topArtists.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No artist statistics available',
                  style: TextStyle(fontSize: 13, color: tokens.textMuted),
                ),
              ),
            )
          else ...[
            for (int i = 0; i < topArtists.length; i++) ...[
              _TopArtistTile(
                rank: i + 1,
                stat: topArtists[i],
                sortMetric: sortMetric,
                tokens: tokens,
              ),
              if (i < topArtists.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final AppTokens tokens;
  final VoidCallback onTap;

  const _MetricChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? tokens.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : tokens.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopArtistTile extends StatelessWidget {
  final int rank;
  final ArtistStat stat;
  final ArtistSortMetric sortMetric;
  final AppTokens tokens;

  const _TopArtistTile({
    required this.rank,
    required this.stat,
    required this.sortMetric,
    required this.tokens,
  });

  Color _rankColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFD4AF37); // Gold
      case 2:
        return const Color(0xFFA0AEC0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return tokens.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankColor = _rankColor();
    final primaryValue = sortMetric == ArtistSortMetric.trackCount
        ? '${stat.trackCount} ${stat.trackCount == 1 ? "track" : "tracks"}'
        : stat.formattedPlaytime;
    final secondaryValue = sortMetric == ArtistSortMetric.trackCount
        ? stat.formattedPlaytime
        : '${stat.trackCount} ${stat.trackCount == 1 ? "track" : "tracks"}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Rank Badge
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: rankColor.withValues(alpha: 0.4), width: 1),
              ),
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: rankColor,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Artist Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Text(
                    '$primaryValue • $secondaryValue',
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Share percentage pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tokens.surfaceElevated,
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                border: Border.all(color: tokens.divider),
              ),
              child: Text(
                stat.formattedPercentage,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Relative share breakdown bar
        ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          child: LinearProgressIndicator(
            value: (stat.percentage / 100.0).clamp(0.0, 1.0),
            backgroundColor: tokens.surfaceHighlight.withValues(alpha: 0.5),
            valueColor: AlwaysStoppedAnimation<Color>(
              rank == 1 ? tokens.accent : tokens.accentCyan,
            ),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
