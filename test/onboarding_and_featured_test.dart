import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/repositories/drift_library_repository.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_catalog_repository.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/providers/settings_providers.dart';

class MockCatalogRepository implements ICatalogRepository {
  Track? lastRelatedSeed;

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async => [];

  @override
  Future<List<Track>> getTrendingTracks({int limit = 30}) async => [
        const Track(
          id: 'trend-1',
          sourceId: 'src-trend-1',
          title: 'Trending Song 1',
          artist: 'Trending Artist',
          album: 'Hits',
          duration: Duration(seconds: 180),
        ),
      ];

  @override
  Future<List<String>> getSearchSuggestions(String query) async => [];

  @override
  Future<List<Track>> getArtistTracks(String artist, {int limit = 25}) async => [];

  @override
  Future<List<Track>> getAlbumTracks(String album, String artist, {int limit = 25}) async => [];

  @override
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) async {
    lastRelatedSeed = track;
    return [
      Track(
        id: 'rec-${track.id}',
        sourceId: 'src-${track.sourceId}',
        title: 'Similar to ${track.title}',
        artist: track.artist,
        album: track.album,
        duration: const Duration(seconds: 200),
      ),
    ];
  }
}

void main() {
  late AppDatabase db;
  late DriftLibraryRepository libraryRepo;
  late MockCatalogRepository mockCatalog;

  const testTrack = Track(
    id: 'track-pink-lips',
    sourceId: 'saavn_pink_lips',
    title: 'Pink Lips',
    artist: 'Meet Bros Anjjan',
    album: 'Hate Story 2',
    duration: Duration(seconds: 220),
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    libraryRepo = DriftLibraryRepository(db);
    mockCatalog = MockCatalogRepository();
  });

  tearDown(() async {
    await db.close();
  });

  group('Onboarding & User Name Storage', () {
    test('UserNameNotifier stores name in Drift Settings table and updates state', () async {
      final notifier = UserNameNotifier(db);

      // Initially null
      expect(notifier.state, isNull);

      // Set user name
      await notifier.setUserName('Sarthak');
      expect(notifier.state, 'Sarthak');

      // Verify row in database
      final row = await (db.select(db.settings)..where((t) => t.key.equals('user_name'))).getSingleOrNull();
      expect(row, isNotNull);
      expect(row!.value, 'Sarthak');

      // Verify prompt marked completed
      final promptRow = await (db.select(db.settings)..where((t) => t.key.equals('has_completed_name_prompt'))).getSingleOrNull();
      expect(promptRow?.value, 'true');
    });

    test('Greeting formatting includes user name when available', () {
      String getGreeting(String? name, int hour) {
        final timeGreeting = hour < 12
            ? 'Good morning'
            : (hour < 18 ? 'Good afternoon' : 'Good evening');
        if (name != null && name.trim().isNotEmpty) {
          return '$timeGreeting, ${name.trim()}';
        }
        return timeGreeting;
      }

      expect(getGreeting('Sarthak', 9), 'Good morning, Sarthak');
      expect(getGreeting('Sarthak', 14), 'Good afternoon, Sarthak');
      expect(getGreeting('Sarthak', 20), 'Good evening, Sarthak');
      expect(getGreeting(null, 9), 'Good morning');
      expect(getGreeting('', 9), 'Good morning');
    });
  });

  group('Taste-Based Featured Music Provider', () {
    test('Returns trending hits when listening history and liked tracks are empty', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          libraryRepositoryProvider.overrideWithValue(libraryRepo),
          catalogRepositoryProvider.overrideWithValue(mockCatalog),
        ],
      );

      final featured = await container.read(featuredMusicProvider.future);
      expect(featured.subtitle, 'Trending Hits');
      expect(featured.tracks.length, 1);
      expect(featured.tracks.first.title, 'Trending Song 1');

      container.dispose();
    });

    test('Recommends music based on recently played seed track when history exists', () async {
      // Record Pink Lips in play history
      await libraryRepo.recordPlayHistory(testTrack, 0.5);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          libraryRepositoryProvider.overrideWithValue(libraryRepo),
          catalogRepositoryProvider.overrideWithValue(mockCatalog),
        ],
      );

      // Await play history stream emission
      await container.read(playHistoryStreamProvider.future);

      final featured = await container.read(featuredMusicProvider.future);
      expect(featured.subtitle, 'Based on "Pink Lips"');
      expect(featured.tracks.first.title, 'Similar to Pink Lips');
      expect(mockCatalog.lastRelatedSeed?.id, testTrack.id);

      container.dispose();
    });
  });
}
