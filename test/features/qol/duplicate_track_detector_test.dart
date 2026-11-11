import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/playlist.dart';
import 'package:softify/domain/entities/playlist_entry.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_library_repository.dart';
import 'package:softify/features/qol/duplicate_track_detector.dart';
import 'package:softify/presentation/providers/player_providers.dart';

class MockLibraryRepo implements ILibraryRepository {
  final Map<String, PlaylistWithTracks> playlists = {};

  @override
  Future<PlaylistWithTracks?> getPlaylistWithTracks(String playlistId) async {
    return playlists[playlistId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleTrack = Track(
    id: 'track-1',
    sourceId: 'source-1',
    title: 'Starboy',
    artist: 'The Weeknd',
    duration: Duration(seconds: 230),
  );

  group('DuplicateTrackDetector isDuplicate logic', () {
    test('returns false for empty entries', () {
      final isDup = DuplicateTrackDetector.isDuplicate(
        entries: [],
        track: sampleTrack,
      );
      expect(isDup, false);
    });

    test('detects duplicate by trackId', () {
      final entries = [
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 0,
          trackId: 'track-1',
          originalTitle: 'Different Title',
          originalArtist: 'Different Artist',
        ),
      ];

      expect(
        DuplicateTrackDetector.isDuplicate(entries: entries, track: sampleTrack),
        true,
      );
    });

    test('detects duplicate by resolved track ID', () {
      const entries = [
        PlaylistEntry(
          playlistId: 'pl-1',
          position: 0,
          track: Track(
            id: 'track-1',
            sourceId: 'other-source',
            title: 'Other Title',
            artist: 'Other Artist',
            duration: Duration(seconds: 120),
          ),
          originalTitle: 'Other',
          originalArtist: 'Other',
        ),
      ];

      expect(
        DuplicateTrackDetector.isDuplicate(entries: entries, track: sampleTrack),
        true,
      );
    });

    test('detects duplicate by track sourceId', () {
      const entries = [
        PlaylistEntry(
          playlistId: 'pl-1',
          position: 0,
          track: Track(
            id: 'different-id',
            sourceId: 'source-1',
            title: 'Other Title',
            artist: 'Other Artist',
            duration: Duration(seconds: 120),
          ),
          originalTitle: 'Other',
          originalArtist: 'Other',
        ),
      ];

      expect(
        DuplicateTrackDetector.isDuplicate(entries: entries, track: sampleTrack),
        true,
      );
    });

    test('detects duplicate by exact title and artist on resolved track (case-insensitive)', () {
      const entries = [
        PlaylistEntry(
          playlistId: 'pl-1',
          position: 0,
          track: Track(
            id: 'unrelated-id',
            sourceId: 'unrelated-src',
            title: '  starboy  ',
            artist: '  THE WEEKND  ',
            duration: Duration(seconds: 200),
          ),
          originalTitle: 'Unknown',
          originalArtist: 'Unknown',
        ),
      ];

      expect(
        DuplicateTrackDetector.isDuplicate(entries: entries, track: sampleTrack),
        true,
      );
    });

    test('detects duplicate by originalTitle and originalArtist metadata', () {
      const entries = [
        PlaylistEntry(
          playlistId: 'pl-1',
          position: 0,
          originalTitle: 'starboy',
          originalArtist: 'the weeknd',
        ),
      ];

      expect(
        DuplicateTrackDetector.isDuplicate(entries: entries, track: sampleTrack),
        true,
      );
    });

    test('returns false when no duplicate criteria match', () {
      const entries = [
        PlaylistEntry(
          playlistId: 'pl-1',
          position: 0,
          trackId: 'track-999',
          track: Track(
            id: 'track-999',
            sourceId: 'source-999',
            title: 'Blinding Lights',
            artist: 'The Weeknd',
            duration: Duration(seconds: 200),
          ),
          originalTitle: 'Blinding Lights',
          originalArtist: 'The Weeknd',
        ),
      ];

      expect(
        DuplicateTrackDetector.isDuplicate(entries: entries, track: sampleTrack),
        false,
      );
    });
  });

  group('DuplicateTrackDetector checkAndConfirmAdd Widget Tests', () {
    late MockLibraryRepo mockRepo;

    setUp(() {
      mockRepo = MockLibraryRepo();
    });

    testWidgets('returns true immediately if playlist has no duplicate', (tester) async {
      mockRepo.playlists['pl-1'] = PlaylistWithTracks(
        playlist: Playlist(
          id: 'pl-1',
          name: 'My Playlist',
          trackCount: 0,
          createdAt: DateTime(2025, 1, 1),
        ),
        entries: const [],
      );

      bool? result;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await DuplicateTrackDetector.checkAndConfirmAdd(
                      context,
                      ref,
                      playlistId: 'pl-1',
                      track: sampleTrack,
                    );
                  },
                  child: const Text('Add Track'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Track'));
      await tester.pumpAndSettle();

      expect(result, true);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('shows alert dialog and returns false when user cancels', (tester) async {
      mockRepo.playlists['pl-1'] = PlaylistWithTracks(
        playlist: Playlist(
          id: 'pl-1',
          name: 'My Playlist',
          trackCount: 1,
          createdAt: DateTime(2025, 1, 1),
        ),
        entries: [
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 0,
            trackId: 'track-1',
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
          ),
        ],
      );

      bool? result;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await DuplicateTrackDetector.checkAndConfirmAdd(
                      context,
                      ref,
                      playlistId: 'pl-1',
                      track: sampleTrack,
                    );
                  },
                  child: const Text('Add Track'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Track'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Track Already in Playlist'), findsOneWidget);
      expect(
        find.text("'Starboy' is already in this playlist. Do you want to add it anyway?"),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add Anyway'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, false);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('shows alert dialog and returns true when user selects Add Anyway', (tester) async {
      mockRepo.playlists['pl-1'] = PlaylistWithTracks(
        playlist: Playlist(
          id: 'pl-1',
          name: 'My Playlist',
          trackCount: 1,
          createdAt: DateTime(2025, 1, 1),
        ),
        entries: [
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 0,
            trackId: 'track-1',
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
          ),
        ],
      );

      bool? result;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await const DuplicateTrackDetector().checkAndConfirmAdd(
                      context,
                      ref,
                      playlistId: 'pl-1',
                      track: sampleTrack,
                    );
                  },
                  child: const Text('Add Track'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Track'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Add Anyway'));
      await tester.pumpAndSettle();

      expect(result, true);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
