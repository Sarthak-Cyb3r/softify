import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/recommendations/explanation_generator.dart';
import 'package:softify/data/recommendations/mmr_diversity_ranker.dart';
import 'package:softify/data/search/multi_source_autocomplete.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  Track makeTrack(String id, String title, String artist) {
    return Track(
      id: id,
      sourceId: 'src_$id',
      title: title,
      artist: artist,
      duration: const Duration(minutes: 3),
    );
  }

  group('MmrDiversityRanker Tests', () {
    late AppDatabase db;
    late MmrDiversityRanker ranker;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      ranker = MmrDiversityRanker(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('applyMmr strictly enforces maxPerArtist cap invariant', () {
      // 5 tracks from Arijit Singh, 2 from The Weeknd, 2 from Taylor Swift
      final inputTracks = [
        makeTrack('1', 'Song 1', 'Arijit Singh'),
        makeTrack('2', 'Song 2', 'Arijit Singh'),
        makeTrack('3', 'Song 3', 'Arijit Singh'),
        makeTrack('4', 'Song 4', 'Arijit Singh'),
        makeTrack('5', 'Song 5', 'Arijit Singh'),
        makeTrack('6', 'Song 6', 'The Weeknd'),
        makeTrack('7', 'Song 7', 'The Weeknd'),
        makeTrack('8', 'Song 8', 'Taylor Swift'),
        makeTrack('9', 'Song 9', 'Taylor Swift'),
      ];

      final diversified = ranker.applyMmr(inputTracks, maxPerArtist: 2, lambda: 0.7);

      // Verify that no artist appears more than 2 times
      final artistCounts = <String, int>{};
      for (final t in diversified) {
        artistCounts[t.artist] = (artistCounts[t.artist] ?? 0) + 1;
      }

      for (final count in artistCounts.values) {
        expect(count, lessThanOrEqualTo(2));
      }

      expect(artistCounts['Arijit Singh'], 2);
      expect(artistCounts['The Weeknd'], 2);
      expect(artistCounts['Taylor Swift'], 2);
    });

    test('snoozeArtist persists 30-day snooze and isSnoozed returns true', () async {
      await ranker.snoozeArtist('Drake', const Duration(days: 30));

      expect(await ranker.isSnoozed('Drake'), isTrue);
      expect(await ranker.isSnoozed('drake'), isTrue); // Case-insensitive
      expect(await ranker.isSnoozed('Taylor Swift'), isFalse);

      final snoozed = await ranker.getSnoozedArtists();
      expect(snoozed.contains('drake'), isTrue);

      // Remove snooze
      await ranker.removeSnooze('Drake');
      expect(await ranker.isSnoozed('Drake'), isFalse);
    });

    test('learning paused toggle persists in database settings', () async {
      expect(await ranker.isLearningPaused(), isFalse);

      await ranker.setLearningPaused(true);
      expect(await ranker.isLearningPaused(), isTrue);

      await ranker.setLearningPaused(false);
      expect(await ranker.isLearningPaused(), isFalse);
    });

    test('resetAllLearning purges all on-device learning data', () async {
      // Seed some learning data
      await ranker.snoozeArtist('Coldplay', const Duration(days: 30));
      expect(await ranker.isSnoozed('Coldplay'), isTrue);

      await ranker.resetAllLearning();

      expect(await ranker.isSnoozed('Coldplay'), isFalse);
      final snoozed = await ranker.getSnoozedArtists();
      expect(snoozed.isEmpty, isTrue);
    });

    test('MultiSourceAutocomplete excludes snoozed artists from suggestions', () async {
      final autocomplete = MultiSourceAutocomplete(
        db: db,
        diversityController: ranker,
      );

      // Record successful queries for Drake and The Weeknd
      await autocomplete.recordSuccessfulQuery('Drake Hotline Bling');
      await autocomplete.recordSuccessfulQuery('The Weeknd Starboy');

      // Snooze Drake
      await ranker.snoozeArtist('Drake', const Duration(days: 30));

      final suggestions = await autocomplete.getSuggestions('D');
      // Drake suggestions must be completely excluded
      final hasDrake = suggestions.any((s) => s.toLowerCase().contains('drake'));
      expect(hasDrake, isFalse);
    });
  });

  group('ExplanationGenerator Tests', () {
    final generator = ExplanationGenerator();

    test('generates transparent 1-line reason for different contexts', () async {
      final track = makeTrack('t1', 'Tum Hi Ho', 'Arijit Singh');
      final seed = makeTrack('seed1', 'Channa Mereya', 'Arijit Singh');

      final seedReason = await generator.generateExplanation(track, seedTrack: seed);
      expect(seedReason, 'Because you listened to Channa Mereya');

      final rotationReason = await generator.generateExplanation(track, shelfId: 'jump_back_in');
      expect(rotationReason, 'From your recent rotation');

      final discoverReason = await generator.generateExplanation(track, shelfId: 'discover_weekly');
      expect(discoverReason, contains('Arijit Singh'));
    });
  });
}
