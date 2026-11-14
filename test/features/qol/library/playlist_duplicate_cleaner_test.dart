// ============================================================================
// Softify Quality of Life (QoL) - Feature 24: Bulk Duplicate Cleaner Tests
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/playlist.dart';
import 'package:softify/domain/entities/playlist_entry.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_library_repository.dart';
import 'package:softify/features/qol/library/playlist_duplicate_cleaner.dart';
import 'package:softify/presentation/providers/player_providers.dart';

/// Fake repository recording track deletions and providing playlist track lookups.
class FakeLibraryRepo implements ILibraryRepository {
  final Map<String, PlaylistWithTracks> playlists = {};
  final List<({String playlistId, int position})> removedPositions = [];

  @override
  Future<PlaylistWithTracks?> getPlaylistWithTracks(String playlistId) async {
    return playlists[playlistId];
  }

  @override
  Future<void> removeTrackFromPlaylist(String playlistId, int position) async {
    removedPositions.add((playlistId: playlistId, position: position));
    final current = playlists[playlistId];
    if (current != null) {
      final updated = List<PlaylistEntry>.from(current.entries);
      if (position >= 0 && position < updated.length) {
        updated.removeAt(position);
        // Re-index subsequent positions to replicate DriftLibraryRepository behavior
        final reindexed = List<PlaylistEntry>.generate(
          updated.length,
          (i) => updated[i].copyWith(position: i),
        );
        playlists[playlistId] = PlaylistWithTracks(
          playlist: current.playlist.copyWith(trackCount: reindexed.length),
          entries: reindexed,
        );
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const trackA = Track(
    id: 'track-1',
    sourceId: 'src-1',
    title: 'Starboy',
    artist: 'The Weeknd',
    duration: Duration(seconds: 230),
  );

  const trackB = Track(
    id: 'track-2',
    sourceId: 'src-2',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    duration: Duration(seconds: 200),
  );

  const trackC = Track(
    id: 'track-3',
    sourceId: 'src-3',
    title: 'Save Your Tears',
    artist: 'The Weeknd',
    duration: Duration(seconds: 215),
  );

  group('PlaylistDuplicateCleanerService Text Normalization', () {
    test('normalizes empty or null strings to empty string', () {
      expect(PlaylistDuplicateCleanerService.normalizeText(null), '');
      expect(PlaylistDuplicateCleanerService.normalizeText(''), '');
      expect(PlaylistDuplicateCleanerService.normalizeText('   '), '');
    });

    test('lowercases and collapses multiple whitespaces', () {
      expect(
        PlaylistDuplicateCleanerService.normalizeText('  Starboy   The   Weeknd  '),
        'starboy the weeknd',
      );
    });

    test('normalizes curly quotes and hyphens', () {
      expect(
        PlaylistDuplicateCleanerService.normalizeText("Can’t Feel My Face – Remix"),
        "can't feel my face - remix",
      );
    });

    test('builds compound composite key', () {
      final key = PlaylistDuplicateCleanerService.makeTitleArtistKey(
        '  Starboy  ',
        ' The Weeknd ',
      );
      expect(key, 'starboy:::the weeknd');
    });
  });

  group('PlaylistDuplicateCleanerService Detection Logic', () {
    test('returns empty scan result for empty entries', () {
      final result = PlaylistDuplicateCleanerService.detectDuplicates(
        playlistId: 'pl-1',
        playlistName: 'Favorites',
        entries: [],
      );

      expect(result.totalTracks, 0);
      expect(result.duplicateCount, 0);
      expect(result.hasDuplicates, isFalse);
      expect(result.groups, isEmpty);
      expect(result.duplicatePositions, isEmpty);
      expect(result.cleanedEntries, isEmpty);
    });

    test('returns 0 duplicates when all tracks are distinct', () {
      final entries = [
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 0,
          track: trackA,
          originalTitle: 'Starboy',
          originalArtist: 'The Weeknd',
        ),
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 1,
          track: trackB,
          originalTitle: 'Blinding Lights',
          originalArtist: 'The Weeknd',
        ),
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 2,
          track: trackC,
          originalTitle: 'Save Your Tears',
          originalArtist: 'The Weeknd',
        ),
      ];

      final result = PlaylistDuplicateCleanerService.detectDuplicates(
        playlistId: 'pl-1',
        playlistName: 'Favorites',
        entries: entries,
      );

      expect(result.totalTracks, 3);
      expect(result.duplicateCount, 0);
      expect(result.hasDuplicates, isFalse);
      expect(result.groups, isEmpty);
      expect(result.cleanedEntries.length, 3);
    });

    test('detects duplicate by trackId and keeps first occurrence', () {
      final entries = [
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 0,
          trackId: 'track-1',
          track: trackA,
          originalTitle: 'Starboy',
          originalArtist: 'The Weeknd',
        ),
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 1,
          trackId: 'track-2',
          track: trackB,
          originalTitle: 'Blinding Lights',
          originalArtist: 'The Weeknd',
        ),
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 2,
          trackId: 'track-1', // Duplicate of pos 0
          originalTitle: 'Starboy (Copy)',
          originalArtist: 'The Weeknd',
        ),
      ];

      final result = PlaylistDuplicateCleanerService.detectDuplicates(
        playlistId: 'pl-1',
        playlistName: 'Favorites',
        entries: entries,
      );

      expect(result.totalTracks, 3);
      expect(result.duplicateCount, 1);
      expect(result.hasDuplicates, isTrue);
      expect(result.duplicatePositions, [2]);
      expect(result.groups.length, 1);

      final group = result.groups.first;
      expect(group.canonicalPosition, 0);
      expect(group.duplicates.first.position, 2);
      expect(group.matchReason, DuplicateMatchReason.trackId);
    });

    test('detects duplicate by audio sourceId', () {
      final entries = [
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 0,
          track: Track(
            id: 'id-alpha',
            sourceId: 'src-shared-123',
            title: 'Song Alpha',
            artist: 'Artist A',
            duration: Duration(seconds: 180),
          ),
          originalTitle: 'Song Alpha',
          originalArtist: 'Artist A',
        ),
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 1,
          track: Track(
            id: 'id-beta',
            sourceId: 'src-shared-123', // Same sourceId
            title: 'Song Different Title',
            artist: 'Artist Different',
            duration: Duration(seconds: 180),
          ),
          originalTitle: 'Song Different',
          originalArtist: 'Artist Different',
        ),
      ];

      final result = PlaylistDuplicateCleanerService.detectDuplicates(
        playlistId: 'pl-1',
        playlistName: 'Favorites',
        entries: entries,
      );

      expect(result.duplicateCount, 1);
      expect(result.duplicatePositions, [1]);
      expect(result.groups.first.matchReason, DuplicateMatchReason.sourceId);
    });

    test('detects duplicate by normalized title + artist with casing and whitespace variance', () {
      final entries = [
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 0,
          track: Track(
            id: 'id-1',
            sourceId: 'src-1',
            title: 'Starboy',
            artist: 'The Weeknd',
            duration: Duration(seconds: 230),
          ),
          originalTitle: 'Starboy',
          originalArtist: 'The Weeknd',
        ),
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 1,
          track: Track(
            id: 'id-2-different',
            sourceId: 'src-2-different',
            title: '  STARBOY  ',
            artist: ' THE WEEKND   ',
            duration: Duration(seconds: 230),
          ),
          originalTitle: 'STARBOY',
          originalArtist: 'THE WEEKND',
        ),
      ];

      final result = PlaylistDuplicateCleanerService.detectDuplicates(
        playlistId: 'pl-1',
        playlistName: 'Favorites',
        entries: entries,
      );

      expect(result.duplicateCount, 1);
      expect(result.duplicatePositions, [1]);
      expect(result.groups.first.canonicalPosition, 0);
      expect(
        result.groups.first.matchReason,
        DuplicateMatchReason.normalizedTitleArtist,
      );
    });

    test('handles multiple duplicates across multiple tracks', () {
      final entries = [
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 0,
          trackId: 'track-1',
          track: trackA,
          originalTitle: 'Starboy',
          originalArtist: 'The Weeknd',
        ),
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 1,
          trackId: 'track-2',
          track: trackB,
          originalTitle: 'Blinding Lights',
          originalArtist: 'The Weeknd',
        ),
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 2,
          trackId: 'track-1', // Dup of 0
          track: trackA,
          originalTitle: 'Starboy',
          originalArtist: 'The Weeknd',
        ),
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 3,
          trackId: 'track-2', // Dup of 1
          track: trackB,
          originalTitle: 'Blinding Lights',
          originalArtist: 'The Weeknd',
        ),
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 4,
          trackId: 'track-1', // Another dup of 0
          track: trackA,
          originalTitle: 'Starboy',
          originalArtist: 'The Weeknd',
        ),
      ];

      final result = PlaylistDuplicateCleanerService.detectDuplicates(
        playlistId: 'pl-1',
        playlistName: 'Favorites',
        entries: entries,
      );

      expect(result.totalTracks, 5);
      expect(result.duplicateCount, 3);
      expect(result.uniqueTracksCount, 2);
      expect(result.duplicatePositions, [4, 3, 2]); // Descending order
      expect(result.groups.length, 2);
    });
  });

  group('PlaylistDuplicateCleanerService In-Memory Pruning', () {
    test('pruneDuplicateEntries returns distinct entries with contiguous positions', () {
      final entries = [
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 0,
          trackId: 'track-1',
          track: trackA,
          originalTitle: 'Starboy',
          originalArtist: 'The Weeknd',
        ),
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 1,
          trackId: 'track-1', // dup
          track: trackA,
          originalTitle: 'Starboy',
          originalArtist: 'The Weeknd',
        ),
        const PlaylistEntry(
          playlistId: 'pl-1',
          position: 2,
          trackId: 'track-2',
          track: trackB,
          originalTitle: 'Blinding Lights',
          originalArtist: 'The Weeknd',
        ),
      ];

      final pruned = PlaylistDuplicateCleanerService.pruneDuplicateEntries(entries);
      expect(pruned.length, 2);
      expect(pruned[0].trackId, 'track-1');
      expect(pruned[0].position, 0);
      expect(pruned[1].trackId, 'track-2');
      expect(pruned[1].position, 1);
    });
  });

  group('PlaylistDuplicateCleanerService Repository Execution', () {
    late FakeLibraryRepo fakeRepo;

    setUp(() {
      fakeRepo = FakeLibraryRepo();
    });

    test('deletes duplicate entries in descending order of position', () async {
      fakeRepo.playlists['pl-1'] = PlaylistWithTracks(
        playlist: Playlist(
          id: 'pl-1',
          name: 'My Mix',
          trackCount: 4,
          createdAt: DateTime(2025, 1, 1),
        ),
        entries: const [
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 0,
            trackId: 'track-1',
            track: trackA,
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
          ),
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 1,
            trackId: 'track-2',
            track: trackB,
            originalTitle: 'Blinding Lights',
            originalArtist: 'The Weeknd',
          ),
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 2,
            trackId: 'track-1', // dup
            track: trackA,
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
          ),
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 3,
            trackId: 'track-2', // dup
            track: trackB,
            originalTitle: 'Blinding Lights',
            originalArtist: 'The Weeknd',
          ),
        ],
      );

      final service = PlaylistDuplicateCleanerService(fakeRepo);
      final summary = await service.cleanDuplicates(playlistId: 'pl-1');

      expect(summary.success, isTrue);
      expect(summary.removedCount, 2);
      expect(summary.remainingCount, 2);

      // Verify descending deletion order: position 3 deleted first, then position 2
      expect(fakeRepo.removedPositions.length, 2);
      expect(fakeRepo.removedPositions[0].position, 3);
      expect(fakeRepo.removedPositions[1].position, 2);

      // Verify final playlist contents
      final finalPlaylist = await fakeRepo.getPlaylistWithTracks('pl-1');
      expect(finalPlaylist?.entries.length, 2);
      expect(finalPlaylist?.entries[0].trackId, 'track-1');
      expect(finalPlaylist?.entries[1].trackId, 'track-2');
    });

    test('returns 0 removed when playlist has no duplicates', () async {
      fakeRepo.playlists['pl-1'] = PlaylistWithTracks(
        playlist: Playlist(
          id: 'pl-1',
          name: 'Clean Playlist',
          trackCount: 2,
          createdAt: DateTime(2025, 1, 1),
        ),
        entries: const [
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 0,
            trackId: 'track-1',
            track: trackA,
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
          ),
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 1,
            trackId: 'track-2',
            track: trackB,
            originalTitle: 'Blinding Lights',
            originalArtist: 'The Weeknd',
          ),
        ],
      );

      final service = PlaylistDuplicateCleanerService(fakeRepo);
      final summary = await service.cleanDuplicates(playlistId: 'pl-1');

      expect(summary.success, isTrue);
      expect(summary.removedCount, 0);
      expect(summary.remainingCount, 2);
      expect(fakeRepo.removedPositions, isEmpty);
    });
  });

  group('Riverpod Notifier Tests', () {
    late FakeLibraryRepo fakeRepo;

    setUp(() {
      fakeRepo = FakeLibraryRepo();
      fakeRepo.playlists['pl-1'] = PlaylistWithTracks(
        playlist: Playlist(
          id: 'pl-1',
          name: 'Weekend Jams',
          trackCount: 3,
          createdAt: DateTime(2025, 1, 1),
        ),
        entries: const [
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 0,
            trackId: 'track-1',
            track: trackA,
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
          ),
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 1,
            trackId: 'track-1', // dup
            track: trackA,
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
          ),
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 2,
            trackId: 'track-2',
            track: trackB,
            originalTitle: 'Blinding Lights',
            originalArtist: 'The Weeknd',
          ),
        ],
      );
    });

    test('Notifier scans and executes cleanup correctly', () async {
      final container = ProviderContainer(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(playlistDuplicateCleanerProvider.notifier);

      // 1. Initial State
      expect(container.read(playlistDuplicateCleanerProvider).isScanning, isFalse);
      expect(container.read(playlistDuplicateCleanerProvider).scanResult, isNull);

      // 2. Scan
      final scanResult = await notifier.scan('pl-1');
      expect(scanResult, isNotNull);
      expect(scanResult!.duplicateCount, 1);
      expect(
        container.read(playlistDuplicateCleanerProvider).scanResult?.duplicateCount,
        1,
      );

      // 3. Execute Clean
      final summary = await notifier.executeClean('pl-1');
      expect(summary, isNotNull);
      expect(summary!.success, isTrue);
      expect(summary.removedCount, 1);
      expect(summary.remainingCount, 2);

      // 4. Verify state after clean
      final state = container.read(playlistDuplicateCleanerProvider);
      expect(state.isCleaning, isFalse);
      expect(state.lastSummary?.removedCount, 1);
      expect(state.scanResult?.hasDuplicates, isFalse);
    });
  });

  group('DuplicateCleanerDialog Widget Tests', () {
    late FakeLibraryRepo fakeRepo;

    setUp(() {
      fakeRepo = FakeLibraryRepo();
    });

    testWidgets('displays "No Duplicates Found" when playlist is clean', (tester) async {
      fakeRepo.playlists['pl-1'] = PlaylistWithTracks(
        playlist: Playlist(
          id: 'pl-1',
          name: 'Clean Playlist',
          trackCount: 1,
          createdAt: DateTime(2025, 1, 1),
        ),
        entries: const [
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 0,
            trackId: 'track-1',
            track: trackA,
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DuplicateCleanerDialog(
                playlistId: 'pl-1',
                playlistName: 'Clean Playlist',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Clean Duplicate Tracks'), findsOneWidget);
      expect(find.text('No Duplicates Found'), findsOneWidget);
      expect(find.text('All tracks in this playlist are unique.'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.textContaining('duplicate entry'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Clean'), findsNothing);
    });

    testWidgets('displays duplicate count, entries, and clean button when duplicates exist',
        (tester) async {
      fakeRepo.playlists['pl-1'] = PlaylistWithTracks(
        playlist: Playlist(
          id: 'pl-1',
          name: 'Party Playlist',
          trackCount: 2,
          createdAt: DateTime(2025, 1, 1),
        ),
        entries: const [
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 0,
            trackId: 'track-1',
            track: trackA,
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
          ),
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 1,
            trackId: 'track-1',
            track: trackA,
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
          ),
        ],
      );

      DuplicateCleanSummary? cleanResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      cleanResult = await DuplicateCleanerDialog.show(
                        context,
                        playlistId: 'pl-1',
                        playlistName: 'Party Playlist',
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog header and count
      expect(find.text('Clean Duplicate Tracks'), findsOneWidget);
      expect(find.text('Party Playlist'), findsOneWidget);
      expect(find.textContaining('Found 1 duplicate entry'), findsOneWidget);
      expect(find.text('Keep # 1'), findsOneWidget);
      expect(find.text('Remove # 2'), findsOneWidget);

      // Verify Clean Button exists
      final cleanButton = find.widgetWithText(ElevatedButton, 'Clean 1 Duplicate');
      expect(cleanButton, findsOneWidget);

      // Tap Clean button
      await tester.tap(cleanButton);
      await tester.pumpAndSettle();

      // Dialog should be dismissed with result
      expect(find.byType(DuplicateCleanerDialog), findsNothing);
      expect(cleanResult, isNotNull);
      expect(cleanResult!.success, isTrue);
      expect(cleanResult!.removedCount, 1);
    });

    testWidgets('dismisses dialog without cleaning when Cancel is tapped', (tester) async {
      fakeRepo.playlists['pl-1'] = PlaylistWithTracks(
        playlist: Playlist(
          id: 'pl-1',
          name: 'Party Playlist',
          trackCount: 2,
          createdAt: DateTime(2025, 1, 1),
        ),
        entries: const [
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 0,
            trackId: 'track-1',
            track: trackA,
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
          ),
          PlaylistEntry(
            playlistId: 'pl-1',
            position: 1,
            trackId: 'track-1',
            track: trackA,
            originalTitle: 'Starboy',
            originalArtist: 'The Weeknd',
          ),
        ],
      );

      DuplicateCleanSummary? cleanResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      cleanResult = await DuplicateCleanerDialog.show(
                        context,
                        playlistId: 'pl-1',
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(DuplicateCleanerDialog), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(DuplicateCleanerDialog), findsNothing);
      expect(cleanResult, isNull);
      expect(fakeRepo.removedPositions, isEmpty);
    });
  });
}
