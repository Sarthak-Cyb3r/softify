import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_fts_repository.dart';
import 'package:softify/features/qol/track_tag_editor.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/theme/app_theme.dart';
import 'package:softify/presentation/widgets/shared/app_filter_chip.dart';

class FakeFtsRepository implements IFtsRepository {
  final List<Track> indexedTracks = [];

  @override
  Future<void> indexTrack(Track track) async {
    indexedTracks.add(track);
  }

  @override
  Future<void> removeTrack(String trackId) async {
    indexedTracks.removeWhere((t) => t.id == trackId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAudioHandler {
  Track? lastUpdatedTrack;

  void updateTrackMetadata(Track track) {
    lastUpdatedTrack = track;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeFtsRepository fts;
  late FakeAudioHandler fakeAudioHandler;
  late Track sampleTrack;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fts = FakeFtsRepository();
    fakeAudioHandler = FakeAudioHandler();

    sampleTrack = const Track(
      id: 'local_12345',
      sourceId: '/storage/music/sample_song.mp3',
      title: 'Original Song',
      artist: 'Original Artist',
      album: 'Original Album',
      duration: Duration(minutes: 3, seconds: 45),
      matchConfidence: 1.0,
      isLiked: true,
    );

    // Seed track in database
    await db.into(db.tracks).insert(
      TracksCompanion(
        id: Value(sampleTrack.id),
        sourceId: Value(sampleTrack.sourceId),
        title: Value(sampleTrack.title),
        artist: Value(sampleTrack.artist),
        album: Value(sampleTrack.album),
        durationMs: Value(sampleTrack.duration.inMilliseconds),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        isLiked: const Value(true),
        isUnavailable: const Value(false),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TrackTagEditorService Tests', () {
    test('updates track metadata in local Drift database via insertOnConflictUpdate', () async {
      final service = TrackTagEditorService(
        db: db,
        audioHandler: fakeAudioHandler,
        ftsRepository: fts,
      );

      final updated = await service.updateTrackMetadata(
        track: sampleTrack,
        title: 'New Title',
        artist: 'New Artist',
        album: 'New Album',
        genre: 'Electronic',
      );

      expect(updated.title, 'New Title');
      expect(updated.artist, 'New Artist');
      expect(updated.album, 'New Album');

      // Verify row in database
      final row = await (db.select(db.tracks)..where((t) => t.id.equals(sampleTrack.id))).getSingle();
      expect(row.title, 'New Title');
      expect(row.artist, 'New Artist');
      expect(row.album, 'New Album');
      expect(row.isLiked, true); // preserved
      expect(row.durationMs, sampleTrack.duration.inMilliseconds); // preserved

      // Verify genre saved in settings
      final genre = await service.getTrackGenre(sampleTrack.id);
      expect(genre, 'Electronic');

      // Verify taste profile entry created
      final taste = await (db.select(db.tasteProfiles)
            ..where((p) => p.entityType.equals('genre') & p.entityId.equals('electronic')))
          .getSingleOrNull();
      expect(taste, isNotNull);

      // Verify FTS repository indexed
      expect(fts.indexedTracks.any((t) => t.id == sampleTrack.id && t.title == 'New Title'), isTrue);

      // Verify audio handler queue synchronized
      expect(fakeAudioHandler.lastUpdatedTrack?.title, 'New Title');
    });

    test('clearing genre removes it from Settings table', () async {
      final service = TrackTagEditorService(
        db: db,
        audioHandler: fakeAudioHandler,
        ftsRepository: fts,
      );

      // Set genre first
      await service.updateTrackMetadata(
        track: sampleTrack,
        title: 'Song',
        artist: 'Artist',
        genre: 'Rock',
      );
      expect(await service.getTrackGenre(sampleTrack.id), 'Rock');

      // Now clear genre
      await service.updateTrackMetadata(
        track: sampleTrack,
        title: 'Song',
        artist: 'Artist',
        genre: '',
      );
      expect(await service.getTrackGenre(sampleTrack.id), isNull);
    });
  });

  group('TrackTagEditorDialog Widget Tests', () {
    testWidgets('renders all fields and quick tag chips correctly', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          ftsRepositoryProvider.overrideWithValue(fts),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: TrackTagEditorDialog(track: sampleTrack),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check fields rendered
      expect(find.text('Edit Track Tags'), findsOneWidget);
      expect(find.text('Original Song'), findsOneWidget);
      expect(find.text('Original Artist'), findsOneWidget);
      expect(find.text('Original Album'), findsOneWidget);

      // Check Quick Tags header and chips
      expect(find.text('Quick Tags'), findsOneWidget);
      expect(find.text('Pop'), findsOneWidget);
      expect(find.text('Rock'), findsOneWidget);
      expect(find.text('Hip-Hop'), findsOneWidget);
      expect(find.text('Lo-Fi'), findsOneWidget);

      // Tap on a quick tag chip (e.g. "Rock")
      await tester.tap(find.widgetWithText(AppFilterChip, 'Rock'));
      await tester.pumpAndSettle();

      // Check genre text field now contains 'Rock'
      expect(find.text('Rock'), findsWidgets);
    });

    testWidgets('shows validation error if title is empty', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          ftsRepositoryProvider.overrideWithValue(fts),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: TrackTagEditorDialog(track: sampleTrack),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clear title field
      await tester.enterText(find.widgetWithText(TextFormField, 'Original Song'), '');
      await tester.pumpAndSettle();

      // Tap Save Tags button
      await tester.tap(find.text('Save Tags'));
      await tester.pumpAndSettle();

      // Validation error should appear
      expect(find.text('Track title cannot be empty'), findsOneWidget);
    });

    testWidgets('saving valid form updates database and dismisses dialog', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          ftsRepositoryProvider.overrideWithValue(fts),
        ],
      );
      addTearDown(container.dispose);

      Track? returnedTrack;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    returnedTrack = await TrackTagEditorDialog.show(ctx, track: sampleTrack);
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Track Tags'), findsOneWidget);

      // Edit title and artist
      await tester.enterText(find.widgetWithText(TextFormField, 'Original Song'), 'Renamed Song');
      await tester.enterText(find.widgetWithText(TextFormField, 'Original Artist'), 'Renamed Artist');
      await tester.tap(find.widgetWithText(AppFilterChip, 'Pop'));
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Save Tags'));
      await tester.pumpAndSettle();

      // Dialog dismissed
      expect(find.text('Edit Track Tags'), findsNothing);
      expect(returnedTrack, isNotNull);
      expect(returnedTrack?.title, 'Renamed Song');
      expect(returnedTrack?.artist, 'Renamed Artist');

      // Verify persisted in DB
      final row = await (db.select(db.tracks)..where((t) => t.id.equals(sampleTrack.id))).getSingle();
      expect(row.title, 'Renamed Song');
      expect(row.artist, 'Renamed Artist');
    });
  });
}
