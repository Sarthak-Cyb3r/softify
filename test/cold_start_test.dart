import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/recommendations/cold_start_seeder.dart';
import 'package:softify/data/recommendations/drift_taste_profile_repository.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  group('ColdStartSeeder Tests', () {
    late AppDatabase db;
    late DriftTasteProfileRepository tasteRepo;
    late ColdStartSeeder seeder;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      tasteRepo = DriftTasteProfileRepository(db);
      seeder = ColdStartSeeder(
        db: db,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('seedFromInitialArtists inserts taste profiles with strong affinity', () async {
      final initialArtists = ['Arijit Singh', 'The Weeknd', 'Taylor Swift'];

      await seeder.seedFromInitialArtists(initialArtists);

      // Verify that all seeded artists have records in tasteProfiles table
      final profiles = await db.select(db.tasteProfiles).get();
      expect(profiles.length, 3);

      for (final artist in initialArtists) {
        final profile = profiles.firstWhere((p) => p.entityId == artist);
        expect(profile.slowWeight, 1.0);
        expect(profile.fastWeight, 1.0);
      }

      // Verify taste similarity for a track by seeded artist
      const trackByArijit = Track(
        id: 'arijit_1',
        sourceId: 'src_1',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        duration: Duration(minutes: 4),
      );

      final similarity = await tasteRepo.computeTasteSimilarity(trackByArijit);
      expect(similarity, greaterThan(0.3));

      // Verify taste similarity for an unseeded artist
      const trackByUnknown = Track(
        id: 'unknown_1',
        sourceId: 'src_2',
        title: 'Random Song',
        artist: 'Unknown Artist XYZ',
        duration: Duration(minutes: 3),
      );

      final unknownSim = await tasteRepo.computeTasteSimilarity(trackByUnknown);
      expect(unknownSim, 0.0);
      expect(unknownSim, lessThan(similarity));
    });

    test('seedFromInitialArtists handles empty or whitespace input gracefully', () async {
      await seeder.seedFromInitialArtists(['', '   ']);
      final profiles = await db.select(db.tasteProfiles).get();
      expect(profiles.isEmpty, isTrue);
    });
  });
}
