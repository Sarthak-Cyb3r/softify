import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/search/rule_intent_router.dart';
import 'package:softify/domain/entities/search_intent.dart';

void main() {
  group('RuleIntentRouter Table-Driven Tests (>=30 queries)', () {
    final router = RuleIntentRouter();

    final testCases = <Map<String, dynamic>>[
      // 1-5: SimilarToIntent
      {
        'query': 'songs like tum hi ho',
        'type': SimilarToIntent,
        'check': (SearchIntent i) =>
            (i as SimilarToIntent).seedTrackTitle.toLowerCase() == 'tum hi ho',
      },
      {
        'query': 'similar to blinding lights',
        'type': SimilarToIntent,
        'check': (SearchIntent i) =>
            (i as SimilarToIntent).seedTrackTitle.toLowerCase() ==
            'blinding lights',
      },
      {
        'query': 'like the weeknd',
        'type': SimilarToIntent,
        'check': (SearchIntent i) =>
            (i as SimilarToIntent).seedTrackTitle.toLowerCase() == 'the weeknd',
      },
      {
        'query': 'music like starboy',
        'type': SimilarToIntent,
        'check': (SearchIntent i) =>
            (i as SimilarToIntent).seedTrackTitle.toLowerCase() == 'starboy',
      },
      {
        'query': 'tracks like shape of you',
        'type': SimilarToIntent,
        'check': (SearchIntent i) =>
            (i as SimilarToIntent).seedTrackTitle.toLowerCase() ==
            'shape of you',
      },

      // 6-17: ArtistIntent (Known Artists & 'by [Artist]' patterns)
      {
        'query': 'arijit singh',
        'type': ArtistIntent,
        'check': (SearchIntent i) =>
            (i as ArtistIntent).artistName.toLowerCase() == 'arijit singh',
      },
      {
        'query': 'the weeknd',
        'type': ArtistIntent,
        'check': (SearchIntent i) =>
            (i as ArtistIntent).artistName.toLowerCase() == 'the weeknd',
      },
      {
        'query': 'taylor swift',
        'type': ArtistIntent,
        'check': (SearchIntent i) =>
            (i as ArtistIntent).artistName.toLowerCase() == 'taylor swift',
      },
      {
        'query': 'coldplay',
        'type': ArtistIntent,
        'check': (SearchIntent i) =>
            (i as ArtistIntent).artistName.toLowerCase() == 'coldplay',
      },
      {
        'query': 'ed sheeran',
        'type': ArtistIntent,
        'check': (SearchIntent i) =>
            (i as ArtistIntent).artistName.toLowerCase() == 'ed sheeran',
      },
      {
        'query': 'diljit dosanjh',
        'type': ArtistIntent,
        'check': (SearchIntent i) =>
            (i as ArtistIntent).artistName.toLowerCase() == 'diljit dosanjh',
      },
      {
        'query': 'badshah',
        'type': ArtistIntent,
        'check': (SearchIntent i) =>
            (i as ArtistIntent).artistName.toLowerCase() == 'badshah',
      },
      {
        'query': 'songs by taylor swift',
        'type': ArtistIntent,
        'check': (SearchIntent i) =>
            (i as ArtistIntent).artistName.toLowerCase() == 'taylor swift',
      },
      {
        'query': 'music by arijit singh',
        'type': ArtistIntent,
        'check': (SearchIntent i) =>
            (i as ArtistIntent).artistName.toLowerCase() == 'arijit singh',
      },
      {
        'query': 'by drake',
        'type': ArtistIntent,
        'check': (SearchIntent i) =>
            (i as ArtistIntent).artistName.toLowerCase() == 'drake',
      },
      {
        'query': 'tracks by coldplay',
        'type': ArtistIntent,
        'check': (SearchIntent i) =>
            (i as ArtistIntent).artistName.toLowerCase() == 'coldplay',
      },
      {
        'query': 'arijit singh songs',
        'type': ArtistIntent,
        'check': (SearchIntent i) =>
            (i as ArtistIntent).artistName.toLowerCase() == 'arijit singh',
      },

      // 18-32: MoodOrGenreIntent (Tag based)
      {
        'query': 'sad hindi songs',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) {
          final tags = (i as MoodOrGenreIntent).tags;
          return tags.contains('sad') && tags.contains('hindi');
        },
      },
      {
        'query': 'party music',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('party'),
      },
      {
        'query': 'workout mix',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('workout'),
      },
      {
        'query': 'chill vibes',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('chill'),
      },
      {
        'query': 'lofi chill beats',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('chill'),
      },
      {
        'query': 'romantic songs',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('romantic'),
      },
      {
        'query': 'rock music',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('rock'),
      },
      {
        'query': 'punjabi songs',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('punjabi'),
      },
      {
        'query': 'gym music',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('gym'),
      },
      {
        'query': 'sleep music',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('sleep'),
      },
      {
        'query': 'study beats',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('study'),
      },
      {
        'query': 'bollywood dance songs',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) {
          final tags = (i as MoodOrGenreIntent).tags;
          return tags.contains('bollywood') && tags.contains('dance');
        },
      },
      {
        'query': 'acoustic tracks',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('acoustic'),
      },
      {
        'query': 'edm tracks',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('edm'),
      },
      {
        'query': 'jazz playlist',
        'type': MoodOrGenreIntent,
        'check': (SearchIntent i) =>
            (i as MoodOrGenreIntent).tags.contains('jazz'),
      },

      // 33-34: ExactTrackIntent
      {
        'query': 'softify:track:track_id_99',
        'type': ExactTrackIntent,
        'check': (SearchIntent i) =>
            (i as ExactTrackIntent).trackId == 'track_id_99',
      },
      {
        'query': 't_test_exact_123',
        'type': ExactTrackIntent,
        'check': (SearchIntent i) =>
            (i as ExactTrackIntent).trackId == 't_test_exact_123',
      },

      // 35-37: GenericSearchIntent
      {
        'query': 'random unstructured keywords xyz',
        'type': GenericSearchIntent,
        'check': (SearchIntent i) =>
            (i as GenericSearchIntent).rawQuery ==
            'random unstructured keywords xyz',
      },
      {
        'query': 'episode 42 interview podcast',
        'type': GenericSearchIntent,
        'check': (SearchIntent i) =>
            (i as GenericSearchIntent).rawQuery ==
            'episode 42 interview podcast',
      },
      {
        'query': 'some non matching text',
        'type': GenericSearchIntent,
        'check': (SearchIntent i) =>
            (i as GenericSearchIntent).rawQuery ==
            'some non matching text',
      },
    ];

    test('verifies table-driven test suite has >= 30 test cases', () {
      expect(testCases.length, greaterThanOrEqualTo(30));
    });

    for (int idx = 0; idx < testCases.length; idx++) {
      final tc = testCases[idx];
      final query = tc['query'] as String;
      final expectedType = tc['type'] as Type;
      final checkFn = tc['check'] as bool Function(SearchIntent);

      test('#${idx + 1}: "$query" resolves to $expectedType', () {
        final result = router.resolve(query);
        expect(result.runtimeType, expectedType);
        expect(checkFn(result), isTrue);
      });
    }
  });
}
