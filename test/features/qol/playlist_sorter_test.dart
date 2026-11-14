import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/playlist_sorter.dart';
import 'package:softify/presentation/theme/app_theme.dart';

void main() {
  group('PlaylistSortCriteria Enum', () {
    test('defines all 7 required criteria', () {
      expect(PlaylistSortCriteria.values, containsAll([
        PlaylistSortCriteria.customOrder,
        PlaylistSortCriteria.titleAsc,
        PlaylistSortCriteria.titleDesc,
        PlaylistSortCriteria.artistAsc,
        PlaylistSortCriteria.durationAsc,
        PlaylistSortCriteria.durationDesc,
        PlaylistSortCriteria.dateAdded,
      ]));
      expect(PlaylistSortCriteria.values.length, equals(7));
    });

    test('verifies label, description, and icons exist for each criteria', () {
      for (final criteria in PlaylistSortCriteria.values) {
        expect(criteria.label.isNotEmpty, isTrue);
        expect(criteria.description.isNotEmpty, isTrue);
        expect(criteria.icon, isNotNull);
      }
    });

    test('fromString parses correctly and defaults to customOrder on unknown', () {
      expect(PlaylistSortCriteria.fromString('titleAsc'), equals(PlaylistSortCriteria.titleAsc));
      expect(PlaylistSortCriteria.fromString('durationDesc'), equals(PlaylistSortCriteria.durationDesc));
      expect(PlaylistSortCriteria.fromString('unknown_criteria'), equals(PlaylistSortCriteria.customOrder));
      expect(PlaylistSortCriteria.fromString(null), equals(PlaylistSortCriteria.customOrder));
    });
  });

  group('sortPlaylistTracks Function', () {
    const track1 = Track(
      id: '1',
      sourceId: 's1',
      title: 'Counting Stars',
      artist: 'OneRepublic',
      duration: Duration(seconds: 257),
    );

    const track2 = Track(
      id: '2',
      sourceId: 's2',
      title: 'Animals',
      artist: 'Martin Garrix',
      duration: Duration(seconds: 176),
    );

    const track3 = Track(
      id: '3',
      sourceId: 's3',
      title: 'Believer',
      artist: 'Imagine Dragons',
      duration: Duration(seconds: 204),
    );

    const track4 = Track(
      id: '4',
      sourceId: 's4',
      title: 'bad guy',
      artist: 'Billie Eilish',
      duration: Duration(seconds: 194),
    );

    final sampleTracks = [track1, track2, track3, track4];

    test('customOrder preserves original sequence without mutating input', () {
      final input = List<Track>.from(sampleTracks);
      final sorted = sortPlaylistTracks(
        input,
        PlaylistSortCriteria.customOrder,
        trackExtractor: (t) => t,
      );

      expect(sorted.map((t) => t.title).toList(), equals([
        'Counting Stars',
        'Animals',
        'Believer',
        'bad guy',
      ]));
      expect(identical(sorted, input), isFalse);
    });

    test('titleAsc sorts alphabetically case-insensitively', () {
      final sorted = sortPlaylistTracks(
        sampleTracks,
        PlaylistSortCriteria.titleAsc,
        trackExtractor: (t) => t,
      );

      expect(sorted.map((t) => t.title).toList(), equals([
        'Animals',
        'bad guy',
        'Believer',
        'Counting Stars',
      ]));
    });

    test('titleDesc sorts reverse alphabetically case-insensitively', () {
      final sorted = sortPlaylistTracks(
        sampleTracks,
        PlaylistSortCriteria.titleDesc,
        trackExtractor: (t) => t,
      );

      expect(sorted.map((t) => t.title).toList(), equals([
        'Counting Stars',
        'Believer',
        'bad guy',
        'Animals',
      ]));
    });

    test('artistAsc sorts by artist case-insensitively with title tie-breaker', () {
      const extraBillie = Track(
        id: '5',
        sourceId: 's5',
        title: 'all the good girls go to hell',
        artist: 'Billie Eilish',
        duration: Duration(seconds: 168),
      );

      final listWithTies = [...sampleTracks, extraBillie];
      final sorted = sortPlaylistTracks(
        listWithTies,
        PlaylistSortCriteria.artistAsc,
        trackExtractor: (t) => t,
      );

      expect(sorted.map((t) => '${t.artist} - ${t.title}').toList(), equals([
        'Billie Eilish - all the good girls go to hell',
        'Billie Eilish - bad guy',
        'Imagine Dragons - Believer',
        'Martin Garrix - Animals',
        'OneRepublic - Counting Stars',
      ]));
    });

    test('durationAsc sorts shortest to longest duration', () {
      final sorted = sortPlaylistTracks(
        sampleTracks,
        PlaylistSortCriteria.durationAsc,
        trackExtractor: (t) => t,
      );

      expect(sorted.map((t) => t.title).toList(), equals([
        'Animals', // 176s
        'bad guy', // 194s
        'Believer', // 204s
        'Counting Stars', // 257s
      ]));
    });

    test('durationDesc sorts longest to shortest duration', () {
      final sorted = sortPlaylistTracks(
        sampleTracks,
        PlaylistSortCriteria.durationDesc,
        trackExtractor: (t) => t,
      );

      expect(sorted.map((t) => t.title).toList(), equals([
        'Counting Stars', // 257s
        'Believer', // 204s
        'bad guy', // 194s
        'Animals', // 176s
      ]));
    });

    test('dateAdded reverses list order by default (latest added first)', () {
      final sorted = sortPlaylistTracks(
        sampleTracks,
        PlaylistSortCriteria.dateAdded,
        trackExtractor: (t) => t,
      );

      expect(sorted.map((t) => t.title).toList(), equals([
        'bad guy',
        'Believer',
        'Animals',
        'Counting Stars',
      ]));
    });

    test('dateAdded sorts by custom dateExtractor when provided', () {
      final now = DateTime.now();
      final dates = {
        '1': now.subtract(const Duration(days: 10)),
        '2': now.subtract(const Duration(days: 1)), // most recent
        '3': now.subtract(const Duration(days: 5)),
        '4': now.subtract(const Duration(days: 20)),
      };

      final sorted = sortPlaylistTracks(
        sampleTracks,
        PlaylistSortCriteria.dateAdded,
        trackExtractor: (t) => t,
        dateExtractor: (t) => dates[t.id],
      );

      expect(sorted.map((t) => t.title).toList(), equals([
        'Animals', // 1 day ago
        'Believer', // 5 days ago
        'Counting Stars', // 10 days ago
        'bad guy', // 20 days ago
      ]));
    });

    test('handles empty list and single-item list gracefully', () {
      final empty = sortPlaylistTracks<Track>(
        [],
        PlaylistSortCriteria.titleAsc,
        trackExtractor: (t) => t,
      );
      expect(empty, isEmpty);

      final single = sortPlaylistTracks<Track>(
        [track1],
        PlaylistSortCriteria.durationDesc,
        trackExtractor: (t) => t,
      );
      expect(single.length, equals(1));
      expect(single.first.title, equals('Counting Stars'));
    });

    test('works with custom non-Track item wrapper types', () {
      final wrappers = [
        _TrackWrapper(id: 'w1', track: track1, customRating: 5),
        _TrackWrapper(id: 'w2', track: track2, customRating: 3),
      ];

      final sorted = sortPlaylistTracks<_TrackWrapper>(
        wrappers,
        PlaylistSortCriteria.titleAsc,
        trackExtractor: (w) => w.track,
      );

      expect(sorted.first.track.title, equals('Animals'));
      expect(sorted.last.track.title, equals('Counting Stars'));
    });

    test('extension sortedBy works seamlessly', () {
      final sorted = sampleTracks.sortedBy(
        PlaylistSortCriteria.titleAsc,
        trackExtractor: (t) => t,
      );
      expect(sorted.first.title, equals('Animals'));
    });
  });

  group('PlaylistSortNotifier and Local State Persistence', () {
    test('initializes with customOrder and updates local state correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testPlaylistId = 'playlist_test_123';
      final notifier = container.read(playlistSortProvider(testPlaylistId).notifier);

      expect(container.read(playlistSortProvider(testPlaylistId)), equals(PlaylistSortCriteria.customOrder));

      await notifier.setCriteria(PlaylistSortCriteria.durationAsc);
      expect(container.read(playlistSortProvider(testPlaylistId)), equals(PlaylistSortCriteria.durationAsc));

      // Separate container reading same playlist should read from memory store
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      expect(container2.read(playlistSortProvider(testPlaylistId)), equals(PlaylistSortCriteria.durationAsc));

      await notifier.reset();
      expect(container.read(playlistSortProvider(testPlaylistId)), equals(PlaylistSortCriteria.customOrder));
    });
  });

  group('PlaylistSortSheet Widget', () {
    testWidgets('renders all sort options and triggers callback on tap', (tester) async {
      PlaylistSortCriteria? selected;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.unifiedDarkTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    PlaylistSortSheet.show(
                      context,
                      currentCriteria: PlaylistSortCriteria.customOrder,
                      onSelected: (criteria) {
                        selected = criteria;
                      },
                    );
                  },
                  child: const Text('Open Sorter'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Sorter'));
      await tester.pumpAndSettle();

      // Verify sheet title and options
      expect(find.text('Sort Playlist'), findsOneWidget);
      expect(find.text('Custom Order'), findsOneWidget);
      expect(find.text('Title (A-Z)'), findsOneWidget);
      expect(find.text('Title (Z-A)'), findsOneWidget);
      expect(find.text('Artist (A-Z)'), findsOneWidget);
      expect(find.text('Duration (Shortest)'), findsOneWidget);
      expect(find.text('Duration (Longest)'), findsOneWidget);
      expect(find.text('Recently Added'), findsOneWidget);

      // Tap Title (A-Z)
      await tester.tap(find.text('Title (A-Z)'));
      await tester.pumpAndSettle();

      expect(selected, equals(PlaylistSortCriteria.titleAsc));
    });
  });
}

class _TrackWrapper {
  final String id;
  final Track track;
  final int customRating;

  _TrackWrapper({
    required this.id,
    required this.track,
    required this.customRating,
  });
}
