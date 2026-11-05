import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/services/music_language_service.dart';

void main() {
  group('MusicLanguageService', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('detects Hindi from Devanagari script and Bollywood artists', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Seed Hindi tracks in history
      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 'track_hindi_1',
              sourceId: 'src_h1',
              title: 'Kesariya',
              artist: 'Arijit Singh, Pritam',
              durationMs: 240000,
              createdAt: now,
            ),
          );
      await db.into(db.playHistories).insert(
            PlayHistoriesCompanion.insert(
              trackId: 'track_hindi_1',
              playedAt: now,
              completedRatio: 1.0,
            ),
          );

      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 'track_hindi_2',
              sourceId: 'src_h2',
              title: 'तुम ही हो',
              artist: 'Arijit Singh',
              durationMs: 260000,
              createdAt: now - 1000,
            ),
          );
      await db.into(db.playHistories).insert(
            PlayHistoriesCompanion.insert(
              trackId: 'track_hindi_2',
              playedAt: now - 1000,
              completedRatio: 1.0,
            ),
          );

      final result = await MusicLanguageService.detectUserLanguages(db);
      expect(result.primary, MusicLanguage.hindi);
      expect(result.isAutoDetected, isTrue);

      final relaxQuery = MusicLanguageService.getMoodQuery('Relax', result.primary);
      expect(relaxQuery.contains('hindi') || relaxQuery.contains('bollywood'), isTrue);

      final romanceQuery = MusicLanguageService.getMoodQuery('Romance', result.primary);
      expect(romanceQuery.contains('hindi') || romanceQuery.contains('bollywood'), isTrue);
    });

    test('detects Punjabi from Gurmukhi script and Punjabi artists', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 'track_punjabi_1',
              sourceId: 'src_p1',
              title: 'Born to Shine',
              artist: 'Diljit Dosanjh',
              durationMs: 210000,
              createdAt: now,
            ),
          );
      await db.into(db.playHistories).insert(
            PlayHistoriesCompanion.insert(
              trackId: 'track_punjabi_1',
              playedAt: now,
              completedRatio: 1.0,
            ),
          );

      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 'track_punjabi_2',
              sourceId: 'src_p2',
              title: '295',
              artist: 'Sidhu Moose Wala',
              durationMs: 250000,
              createdAt: now - 1000,
            ),
          );
      await db.into(db.playHistories).insert(
            PlayHistoriesCompanion.insert(
              trackId: 'track_punjabi_2',
              playedAt: now - 1000,
              completedRatio: 1.0,
            ),
          );

      final result = await MusicLanguageService.detectUserLanguages(db);
      expect(result.primary, MusicLanguage.punjabi);

      final partyQuery = MusicLanguageService.getMoodQuery('Party', result.primary);
      expect(partyQuery.contains('punjabi'), isTrue);
      expect(partyQuery.contains('bangers') || partyQuery.contains('dhol'), isTrue);
    });

    test('detects Tamil from Tamil artists and keywords', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 'track_tamil_1',
              sourceId: 'src_t1',
              title: 'Hukum - Thalaivar Alappara',
              artist: 'Anirudh Ravichander',
              durationMs: 200000,
              createdAt: now,
            ),
          );
      await db.into(db.playHistories).insert(
            PlayHistoriesCompanion.insert(
              trackId: 'track_tamil_1',
              playedAt: now,
              completedRatio: 1.0,
            ),
          );

      final result = await MusicLanguageService.detectUserLanguages(db);
      expect(result.primary, MusicLanguage.tamil);

      final energizeQuery = MusicLanguageService.getMoodQuery('Energize', result.primary);
      expect(energizeQuery.contains('tamil'), isTrue);
    });

    test('detects Spanish from Latin artists and reggaeton keywords', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 'track_sp_1',
              sourceId: 'src_s1',
              title: 'Tití Me Preguntó',
              artist: 'Bad Bunny',
              durationMs: 240000,
              createdAt: now,
            ),
          );
      await db.into(db.playHistories).insert(
            PlayHistoriesCompanion.insert(
              trackId: 'track_sp_1',
              playedAt: now,
              completedRatio: 1.0,
            ),
          );

      final result = await MusicLanguageService.detectUserLanguages(db);
      expect(result.primary, MusicLanguage.spanish);

      final partyQuery = MusicLanguageService.getMoodQuery('Party', result.primary);
      expect(partyQuery.contains('reggaeton') || partyQuery.contains('latina'), isTrue);
    });

    test('detects Korean from Hangul and K-Pop artists', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 'track_ko_1',
              sourceId: 'src_k1',
              title: 'Super Shy',
              artist: 'NewJeans',
              durationMs: 160000,
              createdAt: now,
            ),
          );
      await db.into(db.playHistories).insert(
            PlayHistoriesCompanion.insert(
              trackId: 'track_ko_1',
              playedAt: now,
              completedRatio: 1.0,
            ),
          );

      final result = await MusicLanguageService.detectUserLanguages(db);
      expect(result.primary, MusicLanguage.korean);

      final workoutQuery = MusicLanguageService.getMoodQuery('Workout', result.primary);
      expect(workoutQuery.contains('k-pop'), isTrue);
    });

    test('detects English when user exclusively listens to Western pop', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 'track_en_1',
              sourceId: 'src_e1',
              title: 'Cruel Summer',
              artist: 'Taylor Swift',
              durationMs: 180000,
              createdAt: now,
            ),
          );
      await db.into(db.playHistories).insert(
            PlayHistoriesCompanion.insert(
              trackId: 'track_en_1',
              playedAt: now,
              completedRatio: 1.0,
            ),
          );

      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 'track_en_2',
              sourceId: 'src_e2',
              title: 'Starboy',
              artist: 'The Weeknd',
              durationMs: 230000,
              createdAt: now - 500,
            ),
          );
      await db.into(db.playHistories).insert(
            PlayHistoriesCompanion.insert(
              trackId: 'track_en_2',
              playedAt: now - 500,
              completedRatio: 1.0,
            ),
          );

      final result = await MusicLanguageService.detectUserLanguages(db);
      expect(result.primary, MusicLanguage.english);

      final chillQuery = MusicLanguageService.getMoodQuery('Relax', result.primary);
      expect(chillQuery, 'chill relaxing acoustic songs peaceful calm');
    });

    test('respects manual language preference override', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Seed history with English songs
      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: 'track_en_3',
              sourceId: 'src_e3',
              title: 'Levitating',
              artist: 'Dua Lipa',
              durationMs: 200000,
              createdAt: now,
            ),
          );
      await db.into(db.playHistories).insert(
            PlayHistoriesCompanion.insert(
              trackId: 'track_en_3',
              playedAt: now,
              completedRatio: 1.0,
            ),
          );

      // Force preference override to Punjabi
      await MusicLanguageService.setPreferredLanguageOverride(db, 'punjabi');

      final result = await MusicLanguageService.detectUserLanguages(db);
      expect(result.primary, MusicLanguage.punjabi);
      expect(result.isAutoDetected, isFalse);

      final settingValue = await MusicLanguageService.getPreferredLanguageOverride(db);
      expect(settingValue, 'punjabi');
    });

    test('detects dual languages when user listens to multiple regional genres', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Seed Hindi
      for (int i = 1; i <= 3; i++) {
        await db.into(db.tracks).insert(
              TracksCompanion.insert(
                id: 'hindi_$i',
                sourceId: 'src_h_$i',
                title: 'Song Hindi $i',
                artist: 'Arijit Singh',
                durationMs: 200000,
                createdAt: now - i * 100,
              ),
            );
        await db.into(db.playHistories).insert(
              PlayHistoriesCompanion.insert(
                trackId: 'hindi_$i',
                playedAt: now - i * 100,
                completedRatio: 1.0,
              ),
            );
      }

      // Seed Punjabi
      for (int i = 1; i <= 2; i++) {
        await db.into(db.tracks).insert(
              TracksCompanion.insert(
                id: 'punjabi_$i',
                sourceId: 'src_p_$i',
                title: 'Song Punjabi $i',
                artist: 'Diljit Dosanjh',
                durationMs: 200000,
                createdAt: now - i * 200,
              ),
            );
        await db.into(db.playHistories).insert(
              PlayHistoriesCompanion.insert(
                trackId: 'punjabi_$i',
                playedAt: now - i * 200,
                completedRatio: 1.0,
              ),
            );
      }

      final result = await MusicLanguageService.detectUserLanguages(db);
      expect(result.primary, MusicLanguage.hindi);
      expect(result.secondary, MusicLanguage.punjabi);
    });
  });
}
