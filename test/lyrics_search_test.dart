import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/search_candidate.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/data/search/text_normalizer.dart';
import 'package:softify/data/search/linear_search_reranker.dart';
import 'package:softify/presentation/widgets/shared/track_row.dart';
import 'package:softify/presentation/theme/app_theme.dart';

void main() {
  group('Lyrics Search Engine Tests', () {
    test('Track entity serializes and deserializes isLyricsMatch correctly', () {
      const track = Track(
        id: 'spotify_bohemian_rhapsody',
        sourceId: 'spotify_bohemian_rhapsody',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night At The Opera',
        duration: Duration(seconds: 355),
        isLyricsMatch: true,
        matchedLyricSnippet: 'Is this the real life? Is this just fantasy?',
      );

      final map = track.toMap();
      expect(map['is_lyrics_match'], isTrue);
      expect(map['matched_lyric_snippet'], 'Is this the real life? Is this just fantasy?');

      final reconstructed = Track.fromMap(map);
      expect(reconstructed.isLyricsMatch, isTrue);
      expect(reconstructed.matchedLyricSnippet, 'Is this the real life? Is this just fantasy?');
    });

    test('scoreTrackOriginality grants priority bonus to indexed lyrics matches', () {
      const normalTrack = Track(
        id: 'spotify_random_track',
        sourceId: 'spotify_random_track',
        title: 'Is This The Real Life',
        artist: 'Unknown Artist',
        duration: Duration(seconds: 180),
        isLyricsMatch: false,
      );

      const lyricsMatchedCanonical = Track(
        id: 'spotify_bohemian_rhapsody',
        sourceId: 'spotify_bohemian_rhapsody',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night At The Opera',
        duration: Duration(seconds: 355),
        isLyricsMatch: true,
      );

      const query = 'is this the real life is this just fantasy';
      final scoreCanonical = TextNormalizer.scoreTrackOriginality(lyricsMatchedCanonical, query: query);
      final scoreNormal = TextNormalizer.scoreTrackOriginality(normalTrack, query: query);

      // Canonical lyrics match gets lyrics bonus and catalog/album bonus
      expect(scoreCanonical, greaterThan(scoreNormal));
    });

    test('LinearSearchReranker promotes lyrics-matched tracks to top result without edit penalty', () {
      final reranker = LinearSearchReranker();

      final candidateQueen = SearchCandidate(
        track: const Track(
          id: 'spotify_queen_bohemian',
          sourceId: 'spotify_queen_bohemian',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          duration: Duration(seconds: 355),
          isLyricsMatch: true,
        ),
        source: 'network',
        features: {},
      );

      final candidateFuzzyClone = SearchCandidate(
        track: const Track(
          id: 'spotify_fuzzy_title_clone',
          sourceId: 'spotify_fuzzy_title_clone',
          title: 'Is This Real Life (Cover)',
          artist: 'Random Band',
          duration: Duration(seconds: 120),
          isLyricsMatch: false,
        ),
        source: 'network',
        features: {},
      );

      final reranked = reranker.rerank(
        query: 'is this the real life is this just fantasy',
        candidates: [candidateFuzzyClone, candidateQueen],
      );

      expect(reranked.first.track.id, 'spotify_queen_bohemian');
      expect(reranked.first.track.isLyricsMatch, isTrue);
      expect(reranked.first.features['edit_distance_penalty'], 0.0);
      expect(reranked.first.features['lyrics_match'], 1.0);
    });

    testWidgets('TrackRow renders Lyrics match pill when track has isLyricsMatch == true', (tester) async {
      const trackWithLyrics = Track(
        id: 'spotify_1',
        sourceId: 'spotify_1',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        duration: Duration(seconds: 355),
        isLyricsMatch: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: TrackRow(
              track: trackWithLyrics,
              showArtwork: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lyrics match'), findsOneWidget);
      expect(find.byIcon(Icons.lyrics_outlined), findsOneWidget);
      expect(find.text('Bohemian Rhapsody'), findsOneWidget);
      expect(find.text('Queen'), findsOneWidget);
    });

    testWidgets('TrackRow does not render Lyrics match pill when isLyricsMatch == false', (tester) async {
      const trackWithoutLyrics = Track(
        id: 'spotify_2',
        sourceId: 'spotify_2',
        title: 'Radio Ga Ga',
        artist: 'Queen',
        duration: Duration(seconds: 340),
        isLyricsMatch: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: TrackRow(
              track: trackWithoutLyrics,
              showArtwork: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lyrics match'), findsNothing);
      expect(find.text('Radio Ga Ga'), findsOneWidget);
      expect(find.text('Queen'), findsOneWidget);
    });
  });
}
