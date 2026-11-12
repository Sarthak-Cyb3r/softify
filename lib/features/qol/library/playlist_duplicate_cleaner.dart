// ============================================================================
// Softify Quality of Life (QoL) - Feature 24: Bulk Duplicate Cleaner for Playlists
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/playlist_entry.dart';
import '../../../domain/entities/track.dart';
import '../../../domain/ports/i_library_repository.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Enums & Models
// ============================================================================

/// The primary matching criteria by which a track was recognized as duplicate.
enum DuplicateMatchReason {
  trackId('Track ID'),
  sourceId('Source ID'),
  normalizedTitleArtist('Title & Artist');

  final String label;
  const DuplicateMatchReason(this.label);
}

/// Details of a single redundant playlist entry scheduled for removal.
@immutable
class DuplicateTrackEntry {
  final int position;
  final PlaylistEntry entry;
  final DuplicateMatchReason matchReason;
  final int canonicalPosition;

  const DuplicateTrackEntry({
    required this.position,
    required this.entry,
    required this.matchReason,
    required this.canonicalPosition,
  });

  String get title =>
      entry.track?.title ??
      (entry.originalTitle.isNotEmpty ? entry.originalTitle : 'Unknown Title');

  String get artist =>
      entry.track?.artist ??
      (entry.originalArtist.isNotEmpty ? entry.originalArtist : 'Unknown Artist');

  String? get trackId => entry.trackId ?? entry.track?.id;
  String? get sourceId => entry.track?.sourceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DuplicateTrackEntry &&
          runtimeType == other.runtimeType &&
          position == other.position &&
          canonicalPosition == other.canonicalPosition &&
          matchReason == other.matchReason;

  @override
  int get hashCode => Object.hash(position, canonicalPosition, matchReason);
}

/// A grouped cluster of duplicates sharing the same canonical (first) occurrence.
@immutable
class DuplicateTrackGroup {
  final PlaylistEntry canonicalEntry;
  final int canonicalPosition;
  final List<DuplicateTrackEntry> duplicates;
  final DuplicateMatchReason matchReason;

  const DuplicateTrackGroup({
    required this.canonicalEntry,
    required this.canonicalPosition,
    required this.duplicates,
    required this.matchReason,
  });

  String get title =>
      canonicalEntry.track?.title ??
      (canonicalEntry.originalTitle.isNotEmpty
          ? canonicalEntry.originalTitle
          : 'Unknown Title');

  String get artist =>
      canonicalEntry.track?.artist ??
      (canonicalEntry.originalArtist.isNotEmpty
          ? canonicalEntry.originalArtist
          : 'Unknown Artist');

  int get duplicateCount => duplicates.length;

  List<int> get duplicatePositions =>
      duplicates.map((d) => d.position).toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DuplicateTrackGroup &&
          runtimeType == other.runtimeType &&
          canonicalPosition == other.canonicalPosition &&
          matchReason == other.matchReason;

  @override
  int get hashCode => Object.hash(canonicalPosition, matchReason);
}

/// Result of scanning a playlist for duplicate tracks.
@immutable
class PlaylistDuplicateScanResult {
  final String playlistId;
  final String playlistName;
  final int totalTracks;
  final List<DuplicateTrackGroup> groups;
  final List<int> duplicatePositions;
  final List<PlaylistEntry> duplicatesToRemove;
  final List<PlaylistEntry> cleanedEntries;

  const PlaylistDuplicateScanResult({
    required this.playlistId,
    required this.playlistName,
    required this.totalTracks,
    required this.groups,
    required this.duplicatePositions,
    required this.duplicatesToRemove,
    required this.cleanedEntries,
  });

  int get duplicateCount => duplicatePositions.length;
  int get uniqueTracksCount => totalTracks - duplicateCount;
  bool get hasDuplicates => duplicateCount > 0;

  static const PlaylistDuplicateScanResult empty = PlaylistDuplicateScanResult(
    playlistId: '',
    playlistName: '',
    totalTracks: 0,
    groups: [],
    duplicatePositions: [],
    duplicatesToRemove: [],
    cleanedEntries: [],
  );
}

/// Outcome summary after executing the bulk duplicate cleanup operation.
@immutable
class DuplicateCleanSummary {
  final String playlistId;
  final int removedCount;
  final int remainingCount;
  final bool success;
  final String? errorMessage;

  const DuplicateCleanSummary({
    required this.playlistId,
    required this.removedCount,
    required this.remainingCount,
    this.success = true,
    this.errorMessage,
  });

  @override
  String toString() =>
      'DuplicateCleanSummary(playlistId: $playlistId, removed: $removedCount, remaining: $remainingCount, success: $success)';
}

// ============================================================================
// Service: Detection & Removal Engine
// ============================================================================

/// Pure Dart service detecting duplicated tracks and orchestrating safe bulk removal.
class PlaylistDuplicateCleanerService {
  final ILibraryRepository? _libraryRepo;

  const PlaylistDuplicateCleanerService([this._libraryRepo]);

  /// Normalizes track title or artist strings for robust fuzzy comparison.
  /// Converts to lowercase, strips common curly quotes and em-dashes,
  /// and condenses multiple whitespace characters into a single space.
  static String normalizeText(String? input) {
    if (input == null) return '';
    var text = input.trim().toLowerCase();
    if (text.isEmpty) return '';

    // Standardize quotes and hyphens
    text = text
        .replaceAll(RegExp(r'[\u2018\u2019]'), "'")
        .replaceAll(RegExp(r'[\u201C\u201D]'), '"')
        .replaceAll(RegExp(r'[\u2013\u2014]'), '-');

    // Condense whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }

  /// Builds a composite key from normalized title and artist.
  static String makeTitleArtistKey(String? title, String? artist) {
    final normTitle = normalizeText(title);
    final normArtist = normalizeText(artist);
    if (normTitle.isEmpty && normArtist.isEmpty) return '';
    return '$normTitle:::$normArtist';
  }

  /// Pure Dart detection scanning a list of [PlaylistEntry] items.
  /// Identifies duplicates by:
  /// 1. Exact Track ID match
  /// 2. Audio sourceId match
  /// 3. Normalized Title + Artist match
  ///
  /// Always treats the FIRST occurrence (lowest position) as canonical and
  /// flags subsequent occurrences as duplicates to prune.
  static PlaylistDuplicateScanResult detectDuplicates({
    required String playlistId,
    required String playlistName,
    required List<PlaylistEntry> entries,
  }) {
    if (entries.isEmpty) {
      return PlaylistDuplicateScanResult(
        playlistId: playlistId,
        playlistName: playlistName,
        totalTracks: 0,
        groups: const [],
        duplicatePositions: const [],
        duplicatesToRemove: const [],
        cleanedEntries: const [],
      );
    }

    // Sort ascending by position to guarantee deterministic first-occurrence ordering
    final sortedEntries = List<PlaylistEntry>.from(entries)
      ..sort((a, b) => a.position.compareTo(b.position));

    final Map<String, int> seenTrackIds = {};
    final Map<String, int> seenSourceIds = {};
    final Map<String, int> seenTitleArtistKeys = {};

    final Map<int, List<DuplicateTrackEntry>> duplicatesByCanonicalPos = {};
    final Map<int, PlaylistEntry> canonicalEntriesByPos = {};
    final Map<int, DuplicateMatchReason> groupReasonsByPos = {};

    final List<int> duplicatePositions = [];
    final List<PlaylistEntry> duplicatesToRemove = [];
    final List<PlaylistEntry> keptEntries = [];

    for (final entry in sortedEntries) {
      final trackId = (entry.trackId?.trim().isNotEmpty == true)
          ? entry.trackId!.trim()
          : (entry.track?.id.trim().isNotEmpty == true
              ? entry.track!.id.trim()
              : null);

      final sourceId = (entry.track?.sourceId.trim().isNotEmpty == true)
          ? entry.track!.sourceId.trim()
          : null;

      final title = entry.track?.title ?? entry.originalTitle;
      final artist = entry.track?.artist ?? entry.originalArtist;
      final titleArtistKey = makeTitleArtistKey(title, artist);

      int? canonicalPos;
      DuplicateMatchReason? matchReason;

      // 1. Check exact Track ID match
      if (trackId != null && seenTrackIds.containsKey(trackId)) {
        canonicalPos = seenTrackIds[trackId];
        matchReason = DuplicateMatchReason.trackId;
      }
      // 2. Check sourceId match
      else if (sourceId != null && seenSourceIds.containsKey(sourceId)) {
        canonicalPos = seenSourceIds[sourceId];
        matchReason = DuplicateMatchReason.sourceId;
      }
      // 3. Check normalized title + artist match
      else if (titleArtistKey.isNotEmpty &&
          seenTitleArtistKeys.containsKey(titleArtistKey)) {
        canonicalPos = seenTitleArtistKeys[titleArtistKey];
        matchReason = DuplicateMatchReason.normalizedTitleArtist;
      }

      if (canonicalPos != null && matchReason != null) {
        // Redundant entry detected
        final dup = DuplicateTrackEntry(
          position: entry.position,
          entry: entry,
          matchReason: matchReason,
          canonicalPosition: canonicalPos,
        );

        duplicatesByCanonicalPos.putIfAbsent(canonicalPos, () => []).add(dup);
        groupReasonsByPos.putIfAbsent(canonicalPos, () => matchReason!);
        duplicatePositions.add(entry.position);
        duplicatesToRemove.add(entry);
      } else {
        // First occurrence: mark as canonical
        canonicalEntriesByPos[entry.position] = entry;
        keptEntries.add(entry);

        if (trackId != null) seenTrackIds[trackId] = entry.position;
        if (sourceId != null) seenSourceIds[sourceId] = entry.position;
        if (titleArtistKey.isNotEmpty) {
          seenTitleArtistKeys[titleArtistKey] = entry.position;
        }
      }
    }

    // Build structured duplicate groups
    final groups = <DuplicateTrackGroup>[];
    for (final entry in canonicalEntriesByPos.entries) {
      final pos = entry.key;
      final dups = duplicatesByCanonicalPos[pos];
      if (dups != null && dups.isNotEmpty) {
        groups.add(
          DuplicateTrackGroup(
            canonicalEntry: entry.value,
            canonicalPosition: pos,
            duplicates: dups,
            matchReason: groupReasonsByPos[pos] ?? DuplicateMatchReason.trackId,
          ),
        );
      }
    }

    // Re-index remaining entries with contiguous 0..N-1 positions
    final cleanedEntries = List<PlaylistEntry>.generate(
      keptEntries.length,
      (i) => keptEntries[i].copyWith(position: i),
    );

    // Positions sorted in descending order for safe consecutive deletions
    final sortedDuplicatePositionsDesc = List<int>.from(duplicatePositions)
      ..sort((a, b) => b.compareTo(a));

    return PlaylistDuplicateScanResult(
      playlistId: playlistId,
      playlistName: playlistName,
      totalTracks: sortedEntries.length,
      groups: groups,
      duplicatePositions: sortedDuplicatePositionsDesc,
      duplicatesToRemove: duplicatesToRemove,
      cleanedEntries: cleanedEntries,
    );
  }

  /// Pure Dart in-memory pruning helper. Returns a fresh list of entries
  /// keeping only the first occurrence of each track and re-indexing positions.
  static List<PlaylistEntry> pruneDuplicateEntries(List<PlaylistEntry> entries) {
    final result = detectDuplicates(
      playlistId: 'mem',
      playlistName: 'Memory',
      entries: entries,
    );
    return result.cleanedEntries;
  }

  /// Scans the repository for duplicate tracks in [playlistId].
  Future<PlaylistDuplicateScanResult> scanPlaylist(String playlistId) async {
    final repo = _libraryRepo;
    if (repo == null) {
      throw StateError('ILibraryRepository is required for scanPlaylist');
    }

    final data = await repo.getPlaylistWithTracks(playlistId);
    if (data == null) {
      return PlaylistDuplicateScanResult.empty;
    }

    return detectDuplicates(
      playlistId: playlistId,
      playlistName: data.playlist.name,
      entries: data.entries,
    );
  }

  /// Executes bulk deletion of duplicate entries from the playlist.
  ///
  /// IMPORTANT: Deletions are applied in DESCENDING position order.
  /// Because removing an item shifts higher positions down by 1, removing from
  /// highest to lowest position prevents shifting lower indices, preserving
  /// exact index stability across all removals.
  Future<DuplicateCleanSummary> cleanDuplicates({
    required String playlistId,
    ILibraryRepository? libraryRepo,
    List<int>? targetPositions,
  }) async {
    final repo = libraryRepo ?? _libraryRepo;
    if (repo == null) {
      throw StateError('ILibraryRepository is required for cleanDuplicates');
    }

    try {
      List<int> positionsToRemove;
      int originalTotal = 0;

      if (targetPositions != null) {
        positionsToRemove = List<int>.from(targetPositions)
          ..sort((a, b) => b.compareTo(a));
        final data = await repo.getPlaylistWithTracks(playlistId);
        originalTotal = data?.entries.length ?? positionsToRemove.length;
      } else {
        final scan = await scanPlaylist(playlistId);
        positionsToRemove = scan.duplicatePositions;
        originalTotal = scan.totalTracks;
      }

      if (positionsToRemove.isEmpty) {
        return DuplicateCleanSummary(
          playlistId: playlistId,
          removedCount: 0,
          remainingCount: originalTotal,
          success: true,
        );
      }

      // Execute descending deletions
      for (final position in positionsToRemove) {
        await repo.removeTrackFromPlaylist(playlistId, position);
      }

      final removedCount = positionsToRemove.length;
      final remainingCount = (originalTotal - removedCount).clamp(0, originalTotal);

      return DuplicateCleanSummary(
        playlistId: playlistId,
        removedCount: removedCount,
        remainingCount: remainingCount,
        success: true,
      );
    } catch (e) {
      return DuplicateCleanSummary(
        playlistId: playlistId,
        removedCount: 0,
        remainingCount: 0,
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
}

// ============================================================================
// Riverpod State Management
// ============================================================================

/// Service provider.
final playlistDuplicateCleanerServiceProvider =
    Provider<PlaylistDuplicateCleanerService>((ref) {
  final repo = ref.read(libraryRepositoryProvider);
  return PlaylistDuplicateCleanerService(repo);
});

/// State for the Duplicate Cleaner notifier.
@immutable
class PlaylistDuplicateCleanerState {
  final bool isScanning;
  final bool isCleaning;
  final PlaylistDuplicateScanResult? scanResult;
  final DuplicateCleanSummary? lastSummary;
  final String? errorMessage;

  const PlaylistDuplicateCleanerState({
    this.isScanning = false,
    this.isCleaning = false,
    this.scanResult,
    this.lastSummary,
    this.errorMessage,
  });

  PlaylistDuplicateCleanerState copyWith({
    bool? isScanning,
    bool? isCleaning,
    PlaylistDuplicateScanResult? scanResult,
    DuplicateCleanSummary? lastSummary,
    String? errorMessage,
  }) {
    return PlaylistDuplicateCleanerState(
      isScanning: isScanning ?? this.isScanning,
      isCleaning: isCleaning ?? this.isCleaning,
      scanResult: scanResult ?? this.scanResult,
      lastSummary: lastSummary ?? this.lastSummary,
      errorMessage: errorMessage,
    );
  }
}

/// StateNotifier managing scan and cleanup workflow for a playlist.
class PlaylistDuplicateCleanerNotifier
    extends StateNotifier<PlaylistDuplicateCleanerState> {
  final Ref _ref;

  PlaylistDuplicateCleanerNotifier(this._ref)
      : super(const PlaylistDuplicateCleanerState());

  /// Triggers a scan on [playlistId].
  Future<PlaylistDuplicateScanResult?> scan(String playlistId) async {
    state = state.copyWith(isScanning: true, errorMessage: null);
    try {
      final service = _ref.read(playlistDuplicateCleanerServiceProvider);
      final result = await service.scanPlaylist(playlistId);
      if (mounted) {
        state = state.copyWith(isScanning: false, scanResult: result);
      }
      return result;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isScanning: false,
          errorMessage: 'Failed to scan playlist: $e',
        );
      }
      return null;
    }
  }

  /// Sets an explicit scan result (useful for tests or pre-computed state).
  void setScanResult(PlaylistDuplicateScanResult result) {
    state = state.copyWith(scanResult: result);
  }

  /// Executes cleaning on [playlistId].
  Future<DuplicateCleanSummary?> executeClean(String playlistId) async {
    state = state.copyWith(isCleaning: true, errorMessage: null);
    try {
      final service = _ref.read(playlistDuplicateCleanerServiceProvider);
      final summary = await service.cleanDuplicates(
        playlistId: playlistId,
        targetPositions: state.scanResult?.duplicatePositions,
      );

      if (mounted) {
        state = state.copyWith(
          isCleaning: false,
          lastSummary: summary,
          scanResult: summary.success
              ? PlaylistDuplicateScanResult(
                  playlistId: playlistId,
                  playlistName: state.scanResult?.playlistName ?? '',
                  totalTracks: summary.remainingCount,
                  groups: const [],
                  duplicatePositions: const [],
                  duplicatesToRemove: const [],
                  cleanedEntries: state.scanResult?.cleanedEntries ?? const [],
                )
              : state.scanResult,
        );
      }
      return summary;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isCleaning: false,
          errorMessage: 'Failed to clean duplicates: $e',
        );
      }
      return null;
    }
  }

  /// Resets state.
  void reset() {
    state = const PlaylistDuplicateCleanerState();
  }
}

/// AutoDispose StateNotifierProvider for duplicate cleaner.
final playlistDuplicateCleanerProvider = StateNotifierProvider.autoDispose<
    PlaylistDuplicateCleanerNotifier, PlaylistDuplicateCleanerState>((ref) {
  return PlaylistDuplicateCleanerNotifier(ref);
});

// ============================================================================
// UI Component: DuplicateCleanerDialog
// ============================================================================

/// Content-first Material 3 dialog displaying the count of redundant duplicate tracks
/// in a playlist and offering a 1-tap bulk cleanup action.
class DuplicateCleanerDialog extends ConsumerStatefulWidget {
  final String playlistId;
  final String? playlistName;
  final PlaylistDuplicateScanResult? initialScanResult;

  const DuplicateCleanerDialog({
    super.key,
    required this.playlistId,
    this.playlistName,
    this.initialScanResult,
  });

  /// Displays the DuplicateCleanerDialog modal. Returns [DuplicateCleanSummary]
  /// if cleanup was executed, or `null` if cancelled/dismissed.
  static Future<DuplicateCleanSummary?> show(
    BuildContext context, {
    required String playlistId,
    String? playlistName,
    PlaylistDuplicateScanResult? initialScanResult,
  }) {
    return showDialog<DuplicateCleanSummary>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DuplicateCleanerDialog(
        playlistId: playlistId,
        playlistName: playlistName,
        initialScanResult: initialScanResult,
      ),
    );
  }

  @override
  ConsumerState<DuplicateCleanerDialog> createState() =>
      _DuplicateCleanerDialogState();
}

class _DuplicateCleanerDialogState
    extends ConsumerState<DuplicateCleanerDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialScanResult != null) {
        ref
            .read(playlistDuplicateCleanerProvider.notifier)
            .setScanResult(widget.initialScanResult!);
      } else {
        ref
            .read(playlistDuplicateCleanerProvider.notifier)
            .scan(widget.playlistId);
      }
    });
  }

  Future<void> _handleClean() async {
    final notifier = ref.read(playlistDuplicateCleanerProvider.notifier);
    final summary = await notifier.executeClean(widget.playlistId);
    if (!mounted) return;

    if (summary != null && summary.success) {
      Navigator.of(context).pop(summary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playlistDuplicateCleanerProvider);
    final tokens = context.tokens;
    final theme = Theme.of(context);

    final titleName = widget.playlistName ??
        state.scanResult?.playlistName ??
        'Playlist';

    return Dialog(
      backgroundColor: tokens.surfaceElevated,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        side: BorderSide(color: tokens.divider, width: 1.0),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 540,
          maxHeight: 620,
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tokens.primaryContainer,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    child: Icon(
                      Icons.cleaning_services_rounded,
                      color: tokens.accent,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: tokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clean Duplicate Tracks',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: AppTheme.fontPageTitle,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          titleName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: AppTheme.fontUi,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
                    onPressed: state.isCleaning
                        ? null
                        : () => Navigator.of(context).pop(null),
                    tooltip: 'Close',
                  ),
                ],
              ),
              SizedBox(height: tokens.spaceMd),
              const Divider(height: 1),
              SizedBox(height: tokens.spaceMd),

              // Body Content
              Expanded(
                child: _buildBody(context, state, tokens, theme),
              ),

              SizedBox(height: tokens.spaceMd),
              const Divider(height: 1),
              SizedBox(height: tokens.spaceMd),

              // Action Buttons Row
              _buildActions(context, state, tokens),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PlaylistDuplicateCleanerState state,
    AppTokens tokens,
    ThemeData theme,
  ) {
    if (state.isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
              strokeWidth: 2.5,
            ),
            SizedBox(height: tokens.spaceMd),
            Text(
              'Scanning playlist for duplicates...',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                color: tokens.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: tokens.error, size: 36),
            SizedBox(height: tokens.spaceSm),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                color: tokens.error,
                fontSize: 13,
              ),
            ),
            SizedBox(height: tokens.spaceMd),
            TextButton.icon(
              onPressed: () => ref
                  .read(playlistDuplicateCleanerProvider.notifier)
                  .scan(widget.playlistId),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final scan = state.scanResult;
    if (scan == null || !scan.hasDuplicates) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.accentCyan.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: tokens.accentCyan,
                size: 38,
              ),
            ),
            SizedBox(height: tokens.spaceMd),
            Text(
              'No Duplicates Found',
              style: TextStyle(
                fontFamily: AppTheme.fontPageTitle,
                fontWeight: FontWeight.bold,
                color: tokens.textPrimary,
                fontSize: 16,
              ),
            ),
            SizedBox(height: tokens.spaceXs),
            Text(
              'All tracks in this playlist are unique.',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                color: tokens.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // List of duplicate items and groups
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Banner
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spaceMd,
            vertical: tokens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: tokens.primaryContainer.withOpacity(0.6),
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(
              color: tokens.accent.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: tokens.accent, size: 20),
              SizedBox(width: tokens.spaceSm),
              Expanded(
                child: Text(
                  'Found ${scan.duplicateCount} duplicate ${scan.duplicateCount == 1 ? "entry" : "entries"}. First occurrence will be kept.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    color: tokens.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spaceSm),

        // Scrollable duplicates preview
        Expanded(
          child: ListView.separated(
            itemCount: scan.groups.length,
            separatorBuilder: (_, __) => SizedBox(height: tokens.spaceSm),
            itemBuilder: (context, index) {
              final group = scan.groups[index];
              return _buildDuplicateGroupCard(context, group, tokens);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicateGroupCard(
    BuildContext context,
    DuplicateTrackGroup group,
    AppTokens tokens,
  ) {
    return Container(
      padding: EdgeInsets.all(tokens.spaceSm + 2),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.divider, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Track Info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.surfaceHighlight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  group.matchReason.label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 10.5,
                    color: tokens.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceSm),

          // Occurrence chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              // Canonical badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.accentCyan.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: tokens.accentCyan.withOpacity(0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: tokens.accentCyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Keep # ${group.canonicalPosition + 1}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tokens.accentCyan,
                      ),
                    ),
                  ],
                ),
              ),

              // Duplicates to remove
              ...group.duplicates.map(
                (dup) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: tokens.error.withOpacity(0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.remove_circle_outline_rounded,
                        size: 13,
                        color: tokens.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Remove # ${dup.position + 1}',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tokens.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    PlaylistDuplicateCleanerState state,
    AppTokens tokens,
  ) {
    final hasDuplicates = state.scanResult?.hasDuplicates ?? false;
    final dupCount = state.scanResult?.duplicateCount ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: state.isCleaning
              ? null
              : () => Navigator.of(context).pop(null),
          style: TextButton.styleFrom(
            foregroundColor: tokens.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            hasDuplicates ? 'Cancel' : 'Close',
            style: const TextStyle(fontFamily: AppTheme.fontUi),
          ),
        ),
        if (hasDuplicates) ...[
          SizedBox(width: tokens.spaceSm),
          ElevatedButton.icon(
            onPressed: state.isCleaning ? null : _handleClean,
            icon: state.isCleaning
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.cleaning_services_rounded, size: 16),
            label: Text(
              state.isCleaning
                  ? 'Cleaning...'
                  : 'Clean $dupCount ${dupCount == 1 ? "Duplicate" : "Duplicates"}',
              style: const TextStyle(
                fontFamily: AppTheme.fontUi,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
