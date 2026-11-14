import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/playlist_search_filter.dart';
import 'package:softify/presentation/theme/app_theme.dart';

void main() {
  group('PlaylistSearchFilterHelper', () {
    final sampleTracks = [
      const Track(
        id: '1',
        sourceId: 's1',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        duration: Duration(minutes: 6),
      ),
      const Track(
        id: '2',
        sourceId: 's2',
        title: 'Radio Ga Ga',
        artist: 'Queen',
        album: 'The Works',
        duration: Duration(minutes: 5, seconds: 48),
      ),
      const Track(
        id: '3',
        sourceId: 's3',
        title: 'Hotel California',
        artist: 'Eagles',
        album: 'Hotel California',
        duration: Duration(minutes: 6, seconds: 30),
      ),
      const Track(
        id: '4',
        sourceId: 's4',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: null,
        duration: Duration(minutes: 3, seconds: 50),
      ),
    ];

    test('returns all tracks when query is empty or whitespace', () {
      expect(
        PlaylistSearchFilterHelper.filterTracks(
          tracks: sampleTracks,
          query: '',
        ),
        sampleTracks,
      );

      expect(
        PlaylistSearchFilterHelper.filterTracks(
          tracks: sampleTracks,
          query: '   ',
        ),
        sampleTracks,
      );
    });

    test('filters case-insensitively by title', () {
      final results = PlaylistSearchFilterHelper.filterTracks(
        tracks: sampleTracks,
        query: 'rhapsody',
      );
      expect(results.length, 1);
      expect(results.first.title, 'Bohemian Rhapsody');

      final upperResults = PlaylistSearchFilterHelper.filterTracks(
        tracks: sampleTracks,
        query: 'RHAPSODY',
      );
      expect(upperResults.length, 1);
      expect(upperResults.first.id, '1');
    });

    test('filters case-insensitively by artist', () {
      final results = PlaylistSearchFilterHelper.filterTracks(
        tracks: sampleTracks,
        query: 'queen',
      );
      expect(results.length, 2);
      expect(results.map((t) => t.id).toSet(), {'1', '2'});
    });

    test('filters case-insensitively by album', () {
      final results = PlaylistSearchFilterHelper.filterTracks(
        tracks: sampleTracks,
        query: 'opera',
      );
      expect(results.length, 1);
      expect(results.first.album, 'A Night at the Opera');
    });

    test('supports multi-token matching across title and artist', () {
      final results = PlaylistSearchFilterHelper.filterTracks(
        tracks: sampleTracks,
        query: 'queen bohemian',
      );
      expect(results.length, 1);
      expect(results.first.title, 'Bohemian Rhapsody');
    });

    test('handles tracks with null album gracefully', () {
      final results = PlaylistSearchFilterHelper.filterTracks(
        tracks: sampleTracks,
        query: 'weeknd',
      );
      expect(results.length, 1);
      expect(results.first.title, 'Starboy');
    });

    test('respects search scope filters', () {
      // "Hotel California" is both title and album
      final titleOnly = PlaylistSearchFilterHelper.filterTracks(
        tracks: sampleTracks,
        query: 'California',
        scope: PlaylistSearchScope.title,
      );
      expect(titleOnly.length, 1);

      final artistOnly = PlaylistSearchFilterHelper.filterTracks(
        tracks: sampleTracks,
        query: 'California',
        scope: PlaylistSearchScope.artist,
      );
      expect(artistOnly.isEmpty, true);

      final albumOnly = PlaylistSearchFilterHelper.filterTracks(
        tracks: sampleTracks,
        query: 'California',
        scope: PlaylistSearchScope.album,
      );
      expect(albumOnly.length, 1);
    });
  });

  group('PlaylistSearchFilterController', () {
    test('initializes with default values and manages state', () {
      final controller = PlaylistSearchFilterController();
      expect(controller.query, '');
      expect(controller.isExpanded, false);
      expect(controller.hasActiveFilter, false);
      expect(controller.scope, PlaylistSearchScope.all);

      controller.setQuery('Beatles');
      expect(controller.query, 'Beatles');
      expect(controller.hasActiveFilter, true);

      controller.setScope(PlaylistSearchScope.artist);
      expect(controller.scope, PlaylistSearchScope.artist);

      controller.expand(requestFocus: false);
      expect(controller.isExpanded, true);

      controller.collapse();
      expect(controller.isExpanded, false);
      expect(controller.query, '');
      expect(controller.hasActiveFilter, false);

      controller.dispose();
    });

    test('toggle alternates expansion state', () {
      final controller = PlaylistSearchFilterController();
      expect(controller.isExpanded, false);
      controller.toggle();
      expect(controller.isExpanded, true);
      controller.toggle();
      expect(controller.isExpanded, false);
      controller.dispose();
    });
  });

  group('PlaylistSearchFilterBar Widget', () {
    testWidgets('renders collapsed trigger and expands smoothly on tap',
        (tester) async {
      final controller = PlaylistSearchFilterController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppTokens.standardTokens],
          ),
          home: Scaffold(
            body: PlaylistSearchFilterBar(
              controller: controller,
              totalTrackCount: 50,
              filteredTrackCount: 50,
            ),
          ),
        ),
      );

      // Collapsed state initially
      expect(find.text('Find in playlist...'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('Find in playlist...'));
      await tester.pumpAndSettle();

      expect(controller.isExpanded, true);
      expect(find.byType(TextField), findsOneWidget);

      controller.dispose();
    });

    testWidgets('shows match count indicator and clear button when active',
        (tester) async {
      final controller = PlaylistSearchFilterController(
        initiallyExpanded: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppTokens.standardTokens],
          ),
          home: Scaffold(
            body: PlaylistSearchFilterBar(
              controller: controller,
              totalTrackCount: 120,
              filteredTrackCount: 14,
            ),
          ),
        ),
      );

      // Enter search query
      controller.setQuery('Radio');
      await tester.pumpAndSettle();

      expect(find.text('Showing 14 of 120 tracks'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();

      expect(controller.query, '');
      expect(find.text('120 tracks in playlist'), findsOneWidget);

      controller.dispose();
    });
  });
}
