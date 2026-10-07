import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/search/drift_fts_repository.dart';
import 'package:softify/domain/entities/track.dart';

Track _makeTrack(String id, String title, String artist, {String? album}) {
  return Track(
    id: id,
    sourceId: 'src_$id',
    title: title,
    artist: artist,
    album: album,
    duration: const Duration(seconds: 210),
  );
}

void main() {
  late AppDatabase db;
  late DriftFtsRepository ftsRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    ftsRepo = DriftFtsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('S2: DriftFtsRepository Tests', () {
    test('Indexes and retrieves tracks using FTS5 prefix match', () async {
      final t1 = _makeTrack('t1', 'Tum Hi Ho', 'Arijit Singh', album: 'Aashiqui 2');
      final t2 = _makeTrack('t2', 'Channa Mereya', 'Arijit Singh', album: 'Ae Dil Hai Mushkil');
      final t3 = _makeTrack('t3', 'Starboy', 'The Weeknd', album: 'Starboy');

      await ftsRepo.indexTrack(t1);
      await ftsRepo.indexTrack(t2);
      await ftsRepo.indexTrack(t3);

      // Query "arijit" should match t1 and t2
      final resultsArijit = await ftsRepo.queryFts('arijit');
      expect(resultsArijit, containsAll(['t1', 't2']));
      expect(resultsArijit, isNot(contains('t3')));

      // Query prefix "star" should match t3
      final resultsStar = await ftsRepo.queryFts('star');
      expect(resultsStar, contains('t3'));

      // Query album token "aashiqui" should match t1
      final resultsAlbum = await ftsRepo.queryFts('aashiqui');
      expect(resultsAlbum, contains('t1'));
    });

    test('Removing track purges it from FTS index', () async {
      final track = _makeTrack('t1', 'Kesariya', 'Arijit Singh');
      await ftsRepo.indexTrack(track);

      var results = await ftsRepo.queryFts('kesariya');
      expect(results, contains('t1'));

      await ftsRepo.removeTrack('t1');
      results = await ftsRepo.queryFts('kesariya');
      expect(results, isEmpty);
    });

    test('rebuildFullIndex populates FTS from existing tracks table', () async {
      final t1 = _makeTrack('t1', 'Dil Diyan Gallan', 'Atif Aslam');
      // Insert directly into tracks table in DB
      await db.into(db.tracks).insert(TracksCompanion.insert(
            id: t1.id,
            sourceId: t1.sourceId,
            title: t1.title,
            artist: t1.artist,
            durationMs: t1.duration.inMilliseconds,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ));

      await ftsRepo.rebuildFullIndex();

      final results = await ftsRepo.queryFts('atif');
      expect(results, contains('t1'));
    });
  });
}
