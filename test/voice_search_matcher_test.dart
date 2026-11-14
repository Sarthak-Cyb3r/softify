import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/services/voice/voice_search_matcher.dart';

void main() {
  Track makeTrack({
    required String title,
    required String artist,
    String? album,
  }) {
    return Track(
      id: title.replaceAll(' ', '_').toLowerCase(),
      sourceId: 'src_${title.replaceAll(' ', '_').toLowerCase()}',
      title: title,
      artist: artist,
      album: album,
      duration: const Duration(seconds: 210),
    );
  }

  group('Jaro-Winkler Algorithm', () {
    test('exact match returns 1.0', () {
      expect(VoiceSearchMatcher.jaroWinkler('hello', 'hello'), equals(1.0));
      expect(VoiceSearchMatcher.jaroWinkler('Starboy', 'Starboy'), equals(1.0));
      expect(VoiceSearchMatcher.jaroWinkler('a', 'a'), equals(1.0));
    });

    test('empty strings handling', () {
      expect(VoiceSearchMatcher.jaroWinkler('', 'hello'), equals(0.0));
      expect(VoiceSearchMatcher.jaroWinkler('hello', ''), equals(0.0));
      expect(VoiceSearchMatcher.jaroWinkler('', ''), equals(1.0));
    });

    test('completely different strings return 0.0', () {
      expect(VoiceSearchMatcher.jaroWinkler('abc', 'xyz'), equals(0.0));
      expect(VoiceSearchMatcher.jaroWinkler('123', '456'), equals(0.0));
    });

    test('transpositions and similar strings', () {
      final score = VoiceSearchMatcher.jaroWinkler('martha', 'marhta');
      expect(score, greaterThan(0.9));
      expect(score, closeTo(0.961, 0.005));
    });

    test('prefix boost applies when jaro > 0.7', () {
      final scoreWithPrefix = VoiceSearchMatcher.jaroWinkler('DIXON', 'DICKSONX');
      expect(scoreWithPrefix, greaterThan(0.75));
    });

    test('prefix boost is blocked when jaro <= 0.7', () {
      expect(
        VoiceSearchMatcher.jaroWinkler('MARGHERITA', 'MARMMELLATA'),
        lessThan(0.7),
      );
    });

    test('fuzzy match between typos', () {
      // Starboi vs Starboy
      final typoScore = VoiceSearchMatcher.jaroWinkler('starboi', 'starboy');
      expect(typoScore, greaterThan(0.85));
    });
  });

  group('Tokenizer', () {
    test('strips punctuation and converts to lowercase', () {
      final tokens = VoiceSearchMatcher.tokenize("Don't Stop Me Now!");
      expect(tokens, equals({'don', 't', 'stop', 'me', 'now'}));
    });

    test('handles special characters and excessive whitespace', () {
      final tokens = VoiceSearchMatcher.tokenize('  Hello,   ---world!  @#\$%^&*()  ');
      expect(tokens, equals({'hello', 'world'}));
    });

    test('supports unicode characters and accents', () {
      final tokens = VoiceSearchMatcher.tokenize('Äpfel, Über, Ça plane pour moi 123');
      expect(tokens, equals({'äpfel', 'über', 'ça', 'plane', 'pour', 'moi', '123'}));
    });

    test('empty or whitespace-only strings produce empty set', () {
      expect(VoiceSearchMatcher.tokenize(''), isEmpty);
      expect(VoiceSearchMatcher.tokenize('   \t\n  '), isEmpty);
      expect(VoiceSearchMatcher.tokenize('!@#\$%^&*()_+'), isEmpty);
    });
  });

  group('Artist Stripping', () {
    test('"Starboy by The Weeknd" strips "The Weeknd" leaving "Starboy"', () {
      final queryTokens = VoiceSearchMatcher.tokenize('Starboy by The Weeknd');
      final track = makeTrack(title: 'Starboy', artist: 'The Weeknd');

      final remaining = VoiceSearchMatcher.stripArtistTokens(queryTokens, track);
      expect(remaining, equals({'starboy'}));
    });

    test('strips artist tokens directly from artist string', () {
      final remaining = VoiceSearchMatcher.stripArtistTokens(
        'Starboy by The Weeknd',
        'The Weeknd',
      );
      expect(remaining, equals({'starboy'}));
    });

    test('strips multi-artist tokens from query', () {
      final queryTokens = VoiceSearchMatcher.tokenize('Queen David Bowie Under Pressure');
      final track = makeTrack(title: 'Under Pressure', artist: 'Queen, David Bowie');

      final remaining = VoiceSearchMatcher.stripArtistTokens(queryTokens, track);
      expect(remaining, equals({'under', 'pressure'}));
    });

    test('exact match required for short artist tokens (< 4 chars)', () {
      final queryTokens = {'a', 'song', 'title'};
      final remaining = VoiceSearchMatcher.stripArtistTokens(queryTokens, 'A');
      expect(remaining, equals({'song', 'title'}));
    });

    test('fuzzy match for longer artist tokens (>= 4 chars)', () {
      // Query has typo "weeknd" or "weeknds"
      final queryTokens = {'starboy', 'weeknd'};
      final remaining = VoiceSearchMatcher.stripArtistTokens(queryTokens, 'The Weeknd');
      expect(remaining, equals({'starboy'}));
    });
  });

  group('Fuzzy Matching & Scoring', () {
    test('exact match scores 1.0 and is word-order independent', () {
      final candidates = [
        makeTrack(title: 'Bohemian Rhapsody', artist: 'Queen'),
        makeTrack(title: 'Bohemian Like You', artist: 'Dandy Warhols'),
      ];

      final ranked = VoiceSearchMatcher.rankAll('Bohemian Rhapsody', candidates);
      expect(ranked.first.track.title, equals('Bohemian Rhapsody'));
      expect(ranked.first.score, equals(1.0));

      final reversed = VoiceSearchMatcher.rankAll(
        'Pressure Under',
        [makeTrack(title: 'Under Pressure', artist: 'Queen')],
      );
      expect(reversed.first.score, equals(1.0));
    });

    test('artist tokens are stripped giving 0.95 confidence for exact title', () {
      final candidates = [
        makeTrack(title: 'Blinding Lights', artist: 'The Weeknd'),
        makeTrack(title: 'Lights', artist: 'Ellie Goulding'),
      ];

      final ranked = VoiceSearchMatcher.rankAll(
        'The Weeknd Blinding Lights',
        candidates,
      );
      expect(ranked.first.track.title, equals('Blinding Lights'));
      expect(ranked.first.score, closeTo(0.95, 0.001));
    });

    test('pure artist query returns moderate confidence 0.5', () {
      final candidates = [
        makeTrack(title: 'Song A', artist: 'Queen'),
        makeTrack(title: 'Song B', artist: 'Beatles'),
      ];

      final ranked = VoiceSearchMatcher.rankAll('Queen', candidates);
      expect(ranked.first.track.title, equals('Song A'));
      expect(ranked.first.score, closeTo(0.5, 0.001));
    });

    test('generic query guard blocks short fuzzy matches while allowing exact', () {
      final fuzzyBlocked = VoiceSearchMatcher.rankAll(
        'Go',
        [makeTrack(title: 'Go Away', artist: 'Artist A')],
      );
      expect(fuzzyBlocked.first.score, equals(0.0));

      final exactAllowed = VoiceSearchMatcher.rankAll(
        'Go',
        [makeTrack(title: 'Go', artist: 'Artist A')],
      );
      expect(exactAllowed.first.score, equals(1.0));
    });

    test('fuzzy matching with typos: "Starboi Weeknd" matches "Starboy" by "The Weeknd"', () {
      final candidates = [
        makeTrack(title: 'Starboy', artist: 'The Weeknd'),
        makeTrack(title: 'Stay', artist: 'The Kid LAROI'),
        makeTrack(title: 'Starman', artist: 'David Bowie'),
      ];

      final ranked = VoiceSearchMatcher.rankAll('Starboi Weeknd', candidates);
      expect(ranked.first.track.title, equals('Starboy'));
      expect(ranked.first.score, greaterThanOrEqualTo(VoiceSearchMatcher.strongMatchThreshold));

      final best = VoiceSearchMatcher.findBest('Starboi Weeknd', candidates);
      expect(best?.title, equals('Starboy'));
    });

    test('fuzzy typo in title: "Bohemian Rapsody" matches "Bohemian Rhapsody"', () {
      final ranked = VoiceSearchMatcher.rankAll(
        'Bohemian Rapsody',
        [makeTrack(title: 'Bohemian Rhapsody', artist: 'Queen')],
      );
      expect(ranked.first.score, greaterThanOrEqualTo(VoiceSearchMatcher.strongMatchThreshold));
    });

    test('punctuation tolerance: "Dont Stop Me Now" matches "Don\'t Stop Me Now!"', () {
      final ranked = VoiceSearchMatcher.rankAll(
        'Dont Stop Me Now',
        [makeTrack(title: "Don't Stop Me Now!", artist: 'Queen')],
      );
      expect(ranked.first.score, greaterThanOrEqualTo(VoiceSearchMatcher.strongMatchThreshold));
    });
  });

  group('findBest and rankAll', () {
    test('returns null when no candidate meets strongMatchThreshold', () {
      final best = VoiceSearchMatcher.findBest(
        'Bohemian Rhapsody',
        [makeTrack(title: 'Completely Different Song', artist: 'Nobody')],
      );
      expect(best, isNull);
    });

    test('returns empty list for blank query or empty candidates', () {
      expect(VoiceSearchMatcher.rankAll('Hello', <Track>[]), isEmpty);
      expect(
        VoiceSearchMatcher.rankAll('', [makeTrack(title: 'S', artist: 'A')]),
        isEmpty,
      );
      expect(
        VoiceSearchMatcher.rankAll('   ', [makeTrack(title: 'S', artist: 'A')]),
        isEmpty,
      );
    });

    test('findBest returns winner even when not first in list', () {
      final candidates = [
        makeTrack(title: 'Unrelated Song', artist: 'Nobody'),
        makeTrack(title: 'Bohemian Rhapsody', artist: 'Queen'),
        makeTrack(title: 'Another Song', artist: 'Someone'),
      ];

      final best = VoiceSearchMatcher.findBest('Bohemian Rhapsody', candidates);
      expect(best?.title, equals('Bohemian Rhapsody'));
    });

    test('rankAll handles generic objects with custom extractors', () {
      final rawCandidates = [
        {'name': 'Blinding Lights', 'by': 'The Weeknd'},
        {'name': 'Shape of You', 'by': 'Ed Sheeran'},
      ];

      final ranked = VoiceSearchMatcher.rankAll<Map<String, String>>(
        'Blinding Lights',
        rawCandidates,
        getTitle: (m) => m['name'] ?? '',
        getArtists: (m) => [m['by'] ?? ''],
      );

      expect(ranked.first.candidate['name'], equals('Blinding Lights'));
      expect(ranked.first.score, equals(1.0));
    });
  });

  group('Voice Intent Parsing', () {
    test('parses "play [song] by [artist]"', () {
      final intent = VoiceSearchMatcher.parseIntent('play Starboy by The Weeknd');
      expect(intent.type, equals(VoiceIntentType.playTrack));
      expect(intent.trackTitle, equals('Starboy'));
      expect(intent.artistName, equals('The Weeknd'));
      expect(intent.isShuffle, isFalse);
    });

    test('parses "[song] by [artist]" without leading play', () {
      final intent = VoiceSearchMatcher.parseIntent('Starboy by The Weeknd');
      expect(intent.type, equals(VoiceIntentType.playTrack));
      expect(intent.trackTitle, equals('Starboy'));
      expect(intent.artistName, equals('The Weeknd'));
    });

    test('parses "shuffle [artist]"', () {
      final intent1 = VoiceSearchMatcher.parseIntent('shuffle Queen');
      expect(intent1.type, equals(VoiceIntentType.shuffleArtist));
      expect(intent1.artistName, equals('Queen'));
      expect(intent1.isShuffle, isTrue);

      final intent2 = VoiceSearchMatcher.parseIntent('shuffle songs by The Weeknd');
      expect(intent2.type, equals(VoiceIntentType.shuffleArtist));
      expect(intent2.artistName, equals('The Weeknd'));
      expect(intent2.isShuffle, isTrue);
    });

    test('parses "play album [album]" and "play album [album] by [artist]"', () {
      final intent1 = VoiceSearchMatcher.parseIntent('play album After Hours');
      expect(intent1.type, equals(VoiceIntentType.playAlbum));
      expect(intent1.albumName, equals('After Hours'));

      final intent2 = VoiceSearchMatcher.parseIntent('play album After Hours by The Weeknd');
      expect(intent2.type, equals(VoiceIntentType.playAlbum));
      expect(intent2.albumName, equals('After Hours'));
      expect(intent2.artistName, equals('The Weeknd'));
    });

    test('parses voice query with leading "play"', () {
      final intent = VoiceSearchMatcher.parseIntent('play Blinding Lights');
      expect(intent.type, equals(VoiceIntentType.playTrack));
      expect(intent.trackTitle, equals('Blinding Lights'));
    });

    test('parses generic queries', () {
      final intent = VoiceSearchMatcher.parseIntent('The Weeknd Starboy');
      expect(intent.type, equals(VoiceIntentType.generic));
      expect(intent.rawQuery, equals('The Weeknd Starboy'));
    });
  });
}
