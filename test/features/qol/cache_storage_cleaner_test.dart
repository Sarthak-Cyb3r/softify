import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/cache_storage_cleaner.dart';

void main() {
  group('CacheCategoryStats', () {
    test('computes exact size in MB and formats correctly', () {
      const stats = CacheCategoryStats(
        category: CacheCategory.artwork,
        title: 'Album Artwork Cache',
        description: 'Test description',
        bytes: 10485760, // Exactly 10 MB (10 * 1024 * 1024)
        itemCount: 42,
        icon: Icons.photo_library_rounded,
        accentColor: Colors.red,
      );

      expect(stats.sizeMb, 10.0);
      expect(stats.formattedMb, '10.00 MB');
      expect(stats.itemCount, 42);
    });

    test('handles zero bytes gracefully', () {
      const stats = CacheCategoryStats(
        category: CacheCategory.streamChunks,
        title: 'Stream Chunk Cache',
        description: 'Test description',
        bytes: 0,
        itemCount: 0,
        icon: Icons.graphic_eq_rounded,
        accentColor: Colors.blue,
      );

      expect(stats.sizeMb, 0.0);
      expect(stats.formattedMb, '0.00 MB');
    });

    test('formats fractional MB values accurately', () {
      const stats = CacheCategoryStats(
        category: CacheCategory.lyrics,
        title: 'Synchronized Lyrics Cache',
        description: 'Test description',
        bytes: 2621440, // 2.5 MB (2.5 * 1024 * 1024)
        itemCount: 15,
        icon: Icons.lyrics_rounded,
        accentColor: Colors.purple,
      );

      expect(stats.sizeMb, 2.5);
      expect(stats.formattedMb, '2.50 MB');
    });
  });

  group('CacheBreakdownState', () {
    test('computes aggregated total bytes and total MB accurately', () {
      final initial = CacheBreakdownState.initial();
      expect(initial.totalBytes, 0);
      expect(initial.totalMb, 0.0);
      expect(initial.formattedTotalMb, '0.00 MB');

      final populated = initial.copyWith(
        artwork: initial.artwork.copyWith(bytes: 10 * 1024 * 1024), // 10 MB
        streamChunks: initial.streamChunks.copyWith(bytes: 20 * 1024 * 1024), // 20 MB
        lyrics: initial.lyrics.copyWith(bytes: 5 * 1024 * 1024), // 5 MB
      );

      expect(populated.totalBytes, 35 * 1024 * 1024);
      expect(populated.totalMb, 35.0);
      expect(populated.formattedTotalMb, '35.00 MB');
    });

    test('tracks individual clearing state and master clearing state', () {
      final state = CacheBreakdownState.initial();

      expect(state.isClearing(CacheCategory.artwork), false);
      expect(state.isClearing(CacheCategory.streamChunks), false);
      expect(state.isClearing(CacheCategory.lyrics), false);

      final clearingArt = state.copyWith(clearingCategory: CacheCategory.artwork);
      expect(clearingArt.isClearing(CacheCategory.artwork), true);
      expect(clearingArt.isClearing(CacheCategory.streamChunks), false);

      final clearingAll = state.copyWith(isClearingAll: true);
      expect(clearingAll.isClearing(CacheCategory.artwork), true);
      expect(clearingAll.isClearing(CacheCategory.streamChunks), true);
      expect(clearingAll.isClearing(CacheCategory.lyrics), true);
    });
  });
}
