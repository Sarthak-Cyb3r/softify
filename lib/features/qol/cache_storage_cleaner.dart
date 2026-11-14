import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../presentation/providers/player_providers.dart';
import '../../presentation/providers/settings_providers.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/shared/app_dialog.dart';
import '../../presentation/widgets/shared/app_pill_button.dart';
import '../../presentation/widgets/shared/app_toast.dart';
import '../../services/animated_artwork_service.dart';
import '../../services/canvas_engine_service.dart';
import '../../services/chunk_cache_service.dart';

/// Categories of caches managed by Softify.
enum CacheCategory {
  artwork,
  streamChunks,
  lyrics,
}

/// Statistics and metadata for a single cache category.
class CacheCategoryStats {
  final CacheCategory category;
  final String title;
  final String description;
  final int bytes;
  final int itemCount;
  final IconData icon;
  final Color accentColor;

  const CacheCategoryStats({
    required this.category,
    required this.title,
    required this.description,
    required this.bytes,
    this.itemCount = 0,
    required this.icon,
    required this.accentColor,
  });

  /// Size in Megabytes (MB).
  double get sizeMb => bytes / (1024.0 * 1024.0);

  /// Formatted storage string strictly in MB.
  String get formattedMb => '${sizeMb.toStringAsFixed(2)} MB';

  CacheCategoryStats copyWith({
    int? bytes,
    int? itemCount,
  }) {
    return CacheCategoryStats(
      category: category,
      title: title,
      description: description,
      bytes: bytes ?? this.bytes,
      itemCount: itemCount ?? this.itemCount,
      icon: icon,
      accentColor: accentColor,
    );
  }
}

/// State representation for the granular cache breakdown.
class CacheBreakdownState {
  final CacheCategoryStats artwork;
  final CacheCategoryStats streamChunks;
  final CacheCategoryStats lyrics;
  final bool isLoading;
  final CacheCategory? clearingCategory;
  final bool isClearingAll;

  const CacheBreakdownState({
    required this.artwork,
    required this.streamChunks,
    required this.lyrics,
    this.isLoading = false,
    this.clearingCategory,
    this.isClearingAll = false,
  });

  /// Total storage occupied across all three categories in bytes.
  int get totalBytes => artwork.bytes + streamChunks.bytes + lyrics.bytes;

  /// Total storage in Megabytes (MB).
  double get totalMb => totalBytes / (1024.0 * 1024.0);

  /// Formatted total string in MB.
  String get formattedTotalMb => '${totalMb.toStringAsFixed(2)} MB';

  bool isClearing(CacheCategory cat) => clearingCategory == cat || isClearingAll;

  static CacheBreakdownState initial() {
    return const CacheBreakdownState(
      artwork: CacheCategoryStats(
        category: CacheCategory.artwork,
        title: 'Album Artwork Cache',
        description: 'Covers, animated motion artwork & visual canvas loops',
        bytes: 0,
        itemCount: 0,
        icon: Icons.photo_library_rounded,
        accentColor: Color(0xFFED5564), // Coral Red
      ),
      streamChunks: CacheCategoryStats(
        category: CacheCategory.streamChunks,
        title: 'Stream Chunk Cache',
        description: '320 kbps sparse streaming buffers & playback chunks',
        bytes: 0,
        itemCount: 0,
        icon: Icons.graphic_eq_rounded,
        accentColor: Color(0xFF38BDF8), // Sky Blue
      ),
      lyrics: CacheCategoryStats(
        category: CacheCategory.lyrics,
        title: 'Synchronized Lyrics Cache',
        description: 'Time-coded LRC & syllable karaoke database entries',
        bytes: 0,
        itemCount: 0,
        icon: Icons.lyrics_rounded,
        accentColor: Color(0xFFA855F7), // Purple
      ),
      isLoading: true,
    );
  }

  CacheBreakdownState copyWith({
    CacheCategoryStats? artwork,
    CacheCategoryStats? streamChunks,
    CacheCategoryStats? lyrics,
    bool? isLoading,
    CacheCategory? clearingCategory,
    bool clearClearingCategory = false,
    bool? isClearingAll,
  }) {
    return CacheBreakdownState(
      artwork: artwork ?? this.artwork,
      streamChunks: streamChunks ?? this.streamChunks,
      lyrics: lyrics ?? this.lyrics,
      isLoading: isLoading ?? this.isLoading,
      clearingCategory: clearClearingCategory
          ? null
          : (clearingCategory ?? this.clearingCategory),
      isClearingAll: isClearingAll ?? this.isClearingAll,
    );
  }
}

/// State notifier managing scanning and clearing of granular cache categories.
class CacheStorageCleanerNotifier extends StateNotifier<CacheBreakdownState> {
  final Ref _ref;

  CacheStorageCleanerNotifier(this._ref) : super(CacheBreakdownState.initial()) {
    refreshBreakdown();
  }

  /// Scans file systems and SQLite tables to calculate exact MB usage per category.
  Future<void> refreshBreakdown() async {
    state = state.copyWith(isLoading: true);

    try {
      final db = _ref.read(databaseProvider);

      // 1. Calculate Album Artwork Cache (In-memory + Disk)
      int artworkBytes = 0;
      int artworkFiles = 0;
      try {
        artworkBytes += PaintingBinding.instance.imageCache.currentSizeBytes;
      } catch (_) {}

      try {
        final tempDir = await getTemporaryDirectory();
        final dirs = [
          Directory(p.join(tempDir.path, 'softify_animated_artwork')),
          Directory(p.join(tempDir.path, 'softify_canvas')),
          Directory(p.join(tempDir.path, 'softify_artwork')),
        ];
        for (final dir in dirs) {
          if (await dir.exists()) {
            final entities = dir.listSync(recursive: true, followLinks: false);
            for (final entity in entities) {
              if (entity is File) {
                artworkBytes += entity.lengthSync();
                artworkFiles++;
              }
            }
          }
        }

        // Image files stored directly in temporary directory
        final imageExtensions = {
          '.jpg',
          '.jpeg',
          '.png',
          '.webp',
          '.gif',
          '.bmp',
          '.ico'
        };
        final tempEntries =
            tempDir.listSync(recursive: false, followLinks: false);
        for (final entity in tempEntries) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (imageExtensions.contains(ext)) {
              artworkBytes += entity.lengthSync();
              artworkFiles++;
            }
          }
        }
      } catch (_) {}

      // 2. Calculate Stream Chunk Cache (Host storage + temp chunk directory)
      int streamChunkBytes = 0;
      int streamChunkFiles = 0;
      try {
        final List<Directory> chunkDirs = [];
        if (Platform.isLinux) {
          final home = Platform.environment['HOME'] ?? '';
          if (home.isNotEmpty) {
            chunkDirs.add(
                Directory(p.join(home, '.cache', 'softify', 'Storage', 'chunks')));
          }
        }
        final tempDir = await getTemporaryDirectory();
        chunkDirs.add(Directory(p.join(tempDir.path, 'chunks')));

        for (final dir in chunkDirs) {
          if (await dir.exists()) {
            final entities = dir.listSync(recursive: true, followLinks: false);
            for (final entity in entities) {
              if (entity is File) {
                streamChunkBytes += entity.lengthSync();
                streamChunkFiles++;
              }
            }
          }
        }

        // Buffer files in temporary directory
        final streamExts = {'.chunk', '.bin', '.part', '.m4s'};
        final tempEntries =
            tempDir.listSync(recursive: false, followLinks: false);
        for (final entity in tempEntries) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (streamExts.contains(ext) ||
                p.basename(entity.path).startsWith('chunk_')) {
              streamChunkBytes += entity.lengthSync();
              streamChunkFiles++;
            }
          }
        }
      } catch (_) {}

      // 3. Calculate Synchronized Lyrics Cache (SQLite database + temp files)
      int lyricsBytes = 0;
      int lyricsCount = 0;
      try {
        final rows = await db.select(db.cachedLyrics).get();
        lyricsCount = rows.length;
        for (final row in rows) {
          final id = row.trackId;
          final synced = row.syncedLrc;
          final plain = row.plainText;
          lyricsBytes += utf8.encode(id).length;
          if (synced != null) lyricsBytes += utf8.encode(synced).length;
          if (plain != null) lyricsBytes += utf8.encode(plain).length;
          // SQLite B-tree & record header indexing overhead (~128 bytes per row)
          lyricsBytes += 128;
        }
      } catch (_) {}

      try {
        final tempDir = await getTemporaryDirectory();
        final lyricsDir = Directory(p.join(tempDir.path, 'lyrics'));
        if (await lyricsDir.exists()) {
          final entities =
              lyricsDir.listSync(recursive: true, followLinks: false);
          for (final entity in entities) {
            if (entity is File) {
              lyricsBytes += entity.lengthSync();
              lyricsCount++;
            }
          }
        }
      } catch (_) {}

      state = state.copyWith(
        artwork: state.artwork
            .copyWith(bytes: artworkBytes, itemCount: artworkFiles),
        streamChunks: state.streamChunks
            .copyWith(bytes: streamChunkBytes, itemCount: streamChunkFiles),
        lyrics: state.lyrics
            .copyWith(bytes: lyricsBytes, itemCount: lyricsCount),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Clears only Album Artwork cache.
  Future<int> clearArtworkCache() async {
    state = state.copyWith(clearingCategory: CacheCategory.artwork);
    final prevBytes = state.artwork.bytes;

    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    try {
      await AnimatedArtworkService.instance.clearCache();
    } catch (_) {}

    try {
      await CanvasEngineService.instance.clearCache();
    } catch (_) {}

    try {
      final tempDir = await getTemporaryDirectory();
      final dirs = [
        Directory(p.join(tempDir.path, 'softify_animated_artwork')),
        Directory(p.join(tempDir.path, 'softify_canvas')),
        Directory(p.join(tempDir.path, 'softify_artwork')),
      ];
      for (final dir in dirs) {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }

      final imageExtensions = {
        '.jpg',
        '.jpeg',
        '.png',
        '.webp',
        '.gif',
        '.bmp',
        '.ico'
      };
      final tempEntries =
          tempDir.listSync(recursive: false, followLinks: false);
      for (final entity in tempEntries) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (imageExtensions.contains(ext)) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    _ref.invalidate(storageBreakdownProvider);
    await refreshBreakdown();
    state = state.copyWith(clearClearingCategory: true);
    return prevBytes;
  }

  /// Clears only Stream Chunk cache.
  Future<int> clearStreamChunkCache() async {
    state = state.copyWith(clearingCategory: CacheCategory.streamChunks);
    final prevBytes = state.streamChunks.bytes;

    try {
      await ChunkCacheService.instance.clearAll();
    } catch (_) {}

    try {
      final List<Directory> chunkDirs = [];
      if (Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '';
        if (home.isNotEmpty) {
          chunkDirs.add(
              Directory(p.join(home, '.cache', 'softify', 'Storage', 'chunks')));
        }
      }
      final tempDir = await getTemporaryDirectory();
      chunkDirs.add(Directory(p.join(tempDir.path, 'chunks')));

      for (final dir in chunkDirs) {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          await dir.create(recursive: true);
        }
      }

      final streamExts = {'.chunk', '.bin', '.part', '.m4s'};
      final tempEntries =
          tempDir.listSync(recursive: false, followLinks: false);
      for (final entity in tempEntries) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (streamExts.contains(ext) ||
              p.basename(entity.path).startsWith('chunk_')) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    _ref.invalidate(storageBreakdownProvider);
    await refreshBreakdown();
    state = state.copyWith(clearClearingCategory: true);
    return prevBytes;
  }

  /// Clears only Synchronized Lyrics cache.
  Future<int> clearLyricsCache() async {
    state = state.copyWith(clearingCategory: CacheCategory.lyrics);
    final prevBytes = state.lyrics.bytes;

    try {
      final db = _ref.read(databaseProvider);
      await db.delete(db.cachedLyrics).go();
    } catch (_) {}

    try {
      _ref.read(lyricsProviderRegistryProvider).clearCache();
    } catch (_) {}

    try {
      final tempDir = await getTemporaryDirectory();
      final lyricsDir = Directory(p.join(tempDir.path, 'lyrics'));
      if (await lyricsDir.exists()) {
        await lyricsDir.delete(recursive: true);
      }
    } catch (_) {}

    _ref.invalidate(storageBreakdownProvider);
    await refreshBreakdown();
    state = state.copyWith(clearClearingCategory: true);
    return prevBytes;
  }

  /// Master clear: purges all three cache categories simultaneously.
  Future<int> clearAllCaches() async {
    state = state.copyWith(isClearingAll: true);
    final initialTotal = state.totalBytes;

    await clearArtworkCache();
    await clearStreamChunkCache();
    await clearLyricsCache();

    state = state.copyWith(isClearingAll: false);
    return initialTotal;
  }
}

/// Provider for the Granular Cache & Storage Breakdown cleaner state.
final cacheStorageCleanerProvider = StateNotifierProvider.autoDispose<
    CacheStorageCleanerNotifier, CacheBreakdownState>(
  (ref) => CacheStorageCleanerNotifier(ref),
);

/// Interactive bottom sheet modal providing granular inspection and independent
/// cleaning controls for Album Artwork, Stream Chunks, and Synchronized Lyrics.
class CacheStorageCleanerSheet extends ConsumerWidget {
  const CacheStorageCleanerSheet({super.key});

  /// Presents the bottom sheet modal.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const CacheStorageCleanerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cacheStorageCleanerProvider);
    final notifier = ref.read(cacheStorageCleanerProvider.notifier);
    final tokens = context.tokens;
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.90;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: maxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.isGlass
                ? const Color(0xE8121614)
                : tokens.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: tokens.isGlass
                  ? tokens.glassBorder
                  : tokens.divider,
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 28,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 2. Header Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.cleaning_services_rounded,
                          size: 20,
                          color: tokens.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cache & Storage Breakdown',
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Granular per-category disk footprint cleaner',
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh Breakdown',
                        onPressed: state.isLoading
                            ? null
                            : () => notifier.refreshBreakdown(),
                        icon: state.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white70),
                                ),
                              )
                            : Icon(Icons.refresh_rounded,
                                color: tokens.textSecondary),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded,
                            color: tokens.textSecondary),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white12, height: 1),

                // 3. Scrollable Breakdown Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Master Footprint Card
                        _buildStorageFootprintCard(context, state, tokens),

                        const SizedBox(height: 20),

                        // Section Heading
                        Row(
                          children: [
                            Text(
                              'CACHE CATEGORIES',
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: tokens.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            if (state.isLoading)
                              Text(
                                'Scanning disks...',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontUi,
                                  fontSize: 11,
                                  color: tokens.accent,
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Category 1: Album Artwork Cache
                        _buildCategoryCard(
                          context: context,
                          stats: state.artwork,
                          isClearing: state.isClearing(CacheCategory.artwork),
                          tokens: tokens,
                          onClear: () => _handleClearCategory(
                            context: context,
                            category: CacheCategory.artwork,
                            stats: state.artwork,
                            clearAction: notifier.clearArtworkCache,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Category 2: Stream Chunk Cache
                        _buildCategoryCard(
                          context: context,
                          stats: state.streamChunks,
                          isClearing:
                              state.isClearing(CacheCategory.streamChunks),
                          tokens: tokens,
                          onClear: () => _handleClearCategory(
                            context: context,
                            category: CacheCategory.streamChunks,
                            stats: state.streamChunks,
                            clearAction: notifier.clearStreamChunkCache,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Category 3: Synchronized Lyrics Cache
                        _buildCategoryCard(
                          context: context,
                          stats: state.lyrics,
                          isClearing: state.isClearing(CacheCategory.lyrics),
                          tokens: tokens,
                          onClear: () => _handleClearCategory(
                            context: context,
                            category: CacheCategory.lyrics,
                            stats: state.lyrics,
                            clearAction: notifier.clearLyricsCache,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Master "Clear All Caches" Action Button
                        _buildMasterClearAllButton(
                          context: context,
                          state: state,
                          notifier: notifier,
                          tokens: tokens,
                        ),

                        const SizedBox(height: 16),

                        // Safe Offline Downloads Guarantee Notice
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tokens.card.withValues(alpha: 0.5),
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 18,
                                color: tokens.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Offline downloads, saved playlists, and liked tracks are stored separately and are never deleted by cache cleaning.',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontUi,
                                    fontSize: 11.5,
                                    color: tokens.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Master visual storage footprint overview card.
  Widget _buildStorageFootprintCard(
    BuildContext context,
    CacheBreakdownState state,
    AppTokens tokens,
  ) {
    final total = state.totalBytes > 0 ? state.totalBytes : 1;
    final artRatio = (state.artwork.bytes / total).clamp(0.0, 1.0);
    final chunkRatio = (state.streamChunks.bytes / total).clamp(0.0, 1.0);
    final lyricsRatio = (state.lyrics.bytes / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(
          color: tokens.isGlass
              ? tokens.glassBorder
              : tokens.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Total Temporary Cache',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              Text(
                state.formattedTotalMb,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: state.totalBytes > 0 ? tokens.accent : Colors.white60,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Proportional Multi-Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusFull),
            child: Container(
              height: 10,
              color: Colors.white.withValues(alpha: 0.08),
              child: state.totalBytes == 0
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        if (artRatio > 0.005)
                          Flexible(
                            flex: (artRatio * 1000).toInt(),
                            child: Container(color: state.artwork.accentColor),
                          ),
                        if (chunkRatio > 0.005)
                          Flexible(
                            flex: (chunkRatio * 1000).toInt(),
                            child: Container(
                                color: state.streamChunks.accentColor),
                          ),
                        if (lyricsRatio > 0.005)
                          Flexible(
                            flex: (lyricsRatio * 1000).toInt(),
                            child: Container(color: state.lyrics.accentColor),
                          ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // Legend chips
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendChip(
                color: state.artwork.accentColor,
                label: 'Artwork (${state.artwork.formattedMb})',
                tokens: tokens,
              ),
              _buildLegendChip(
                color: state.streamChunks.accentColor,
                label: 'Audio Stream (${state.streamChunks.formattedMb})',
                tokens: tokens,
              ),
              _buildLegendChip(
                color: state.lyrics.accentColor,
                label: 'Lyrics (${state.lyrics.formattedMb})',
                tokens: tokens,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendChip({
    required Color color,
    required String label,
    required AppTokens tokens,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontUi,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Individual cache category card with exact MB storage readout and independent "Clear" button.
  Widget _buildCategoryCard({
    required BuildContext context,
    required CacheCategoryStats stats,
    required bool isClearing,
    required AppTokens tokens,
    required VoidCallback onClear,
  }) {
    final bool isEmpty = stats.bytes <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(
          color: tokens.isGlass ? tokens.glassBorder : tokens.divider,
        ),
      ),
      child: Row(
        children: [
          // Category Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: stats.accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
            child: Icon(
              stats.icon,
              size: 22,
              color: stats.accentColor,
            ),
          ),
          const SizedBox(width: 14),

          // Title, Description & Item count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stats.description,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 11.5,
                    color: tokens.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Exact MB Display & Independent Clear Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Exact MB Storage Display
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stats.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(tokens.radiusFull),
                  border: Border.all(
                    color: stats.accentColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  stats.formattedMb,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: stats.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Independent Clear Button
              SizedBox(
                height: 28,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isClearing
                        ? Colors.white12
                        : (isEmpty
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.redAccent.withValues(alpha: 0.12)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusFull),
                    ),
                  ),
                  onPressed: (isClearing || isEmpty) ? null : onClear,
                  child: isClearing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        )
                      : Text(
                          'Clear',
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isEmpty
                                ? tokens.textMuted
                                : const Color(0xFFFF5252),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Master button providing one-tap clearing of all caches with confirmation dialog & toast.
  Widget _buildMasterClearAllButton({
    required BuildContext context,
    required CacheBreakdownState state,
    required CacheStorageCleanerNotifier notifier,
    required AppTokens tokens,
  }) {
    final bool isEmpty = state.totalBytes <= 0;
    final bool isBusy = state.isClearingAll || state.clearingCategory != null;

    return SizedBox(
      width: double.infinity,
      child: AppPillButton(
        label: state.isClearingAll ? 'Clearing All Caches...' : 'Clear All Caches',
        icon: const Icon(Icons.delete_sweep_rounded),
        variant: AppPillButtonVariant.destructive,
        isLoading: state.isClearingAll,
        onPressed: (isEmpty || isBusy)
            ? null
            : () => _handleClearAll(
                  context: context,
                  state: state,
                  notifier: notifier,
                ),
      ),
    );
  }

  /// Handles clearing an individual cache category and triggers an immediate toast.
  Future<void> _handleClearCategory({
    required BuildContext context,
    required CacheCategory category,
    required CacheCategoryStats stats,
    required Future<int> Function() clearAction,
  }) async {
    final freedMb = stats.formattedMb;
    final categoryTitle = stats.title;

    final bytesFreed = await clearAction();

    if (context.mounted) {
      if (bytesFreed > 0) {
        AppToast.showSuccess(
          context,
          message: '$categoryTitle cleared (freed $freedMb)',
        );
      } else {
        AppToast.show(
          context,
          message: '$categoryTitle is already clean',
        );
      }
    }
  }

  /// Handles master Clear All Caches flow with confirmation dialog and toast.
  Future<void> _handleClearAll({
    required BuildContext context,
    required CacheBreakdownState state,
    required CacheStorageCleanerNotifier notifier,
  }) async {
    final totalMb = state.formattedTotalMb;

    final bool? confirmed = await AppDialog.confirm(
      context,
      title: 'Clear All Caches?',
      message:
          'This will purge all album artwork ($totalMb total) including cover images, audio stream chunks, and cached lyrics.\n\nOffline downloads and user playlists will not be touched.',
      confirmText: 'Clear All',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      final clearedBytes = await notifier.clearAllCaches();
      if (context.mounted) {
        final freedMb = (clearedBytes / (1024.0 * 1024.0)).toStringAsFixed(2);
        AppToast.showSuccess(
          context,
          message: 'All caches cleared successfully (freed $freedMb MB)',
        );
      }
    }
  }
}
