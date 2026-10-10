import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/lyrics/composite_lyrics_provider.dart';
import 'package:softify/data/lyrics/spotify_lyrics_provider.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_lyrics_provider.dart';

void main() {
  group('SpotifyLyricsProvider & JSON Parser', () {
    const sampleSpotifyColorLyricsJson = '''
{
  "lyrics": {
    "syncType": "LINE_SYNCED",
    "lines": [
      {
        "startTimeMs": "12500",
        "words": "First line of the song",
        "syllables": []
      },
      {
        "startTimeMs": "18200",
        "words": "Second line with syllable sync",
        "syllables": [
          {"startTimeMs": "18200", "text": "Second"},
          {"startTimeMs": "18600", "text": "line"},
          {"startTimeMs": "19000", "text": "with"},
          {"startTimeMs": "19400", "text": "syllable"},
          {"startTimeMs": "20000", "text": "sync"}
        ]
      }
    ]
  }
}
''';

    test('parses Spotify color-lyrics JSON into SyncedLyrics with lines and syllables', () {
      final lyrics = SpotifyLyricsProvider.parseSpotifyLyricsJson(
        sampleSpotifyColorLyricsJson,
        'track-123',
      );

      expect(lyrics, isNotNull);
      expect(lyrics!.trackId, equals('track-123'));
      expect(lyrics.lines.length, equals(2));

      // Line 1
      expect(lyrics.lines[0].timestamp, equals(const Duration(milliseconds: 12500)));
      expect(lyrics.lines[0].text, equals('First line of the song'));
      expect(lyrics.lines[0].words, isNull);

      // Line 2
      expect(lyrics.lines[1].timestamp, equals(const Duration(milliseconds: 18200)));
      expect(lyrics.lines[1].text, equals('Second line with syllable sync'));
      expect(lyrics.lines[1].words, isNotNull);
      expect(lyrics.lines[1].words!.length, equals(5));
      expect(lyrics.lines[1].words![0].text, equals('Second'));
      expect(lyrics.lines[1].words![0].timestamp, equals(const Duration(milliseconds: 18200)));
      expect(lyrics.lines[1].words![4].text, equals('sync'));
      expect(lyrics.lines[1].words![4].timestamp, equals(const Duration(milliseconds: 20000)));

      // LRC export format verification
      expect(lyrics.rawLrc, contains('[00:12.50] First line of the song'));
      expect(lyrics.rawLrc, contains('[00:18.20] Second line with syllable sync'));
    });

    test('returns null gracefully on invalid or empty JSON', () {
      expect(SpotifyLyricsProvider.parseSpotifyLyricsJson('', 't1'), isNull);
      expect(SpotifyLyricsProvider.parseSpotifyLyricsJson('{}', 't1'), isNull);
      expect(
        SpotifyLyricsProvider.parseSpotifyLyricsJson('{"lyrics":{"lines":[]}}', 't1'),
        isNull,
      );
    });
  });

  group('CompositeLyricsProvider Multi-tier Fallback', () {
    const dummyTrack = Track(
      id: 'spotify_0s8fGVzyn6URNrUVwCE3dV',
      sourceId: 'spotify_0s8fGVzyn6URNrUVwCE3dV',
      title: 'Tum Hi Ho',
      artist: 'Arijit Singh',
      duration: Duration(seconds: 262),
    );

    test('prioritizes Tier 0 Spotify when available and configured', () async {
      final spotifyLyrics = SyncedLyrics(
        trackId: dummyTrack.id,
        lines: [
          const LyricLine(timestamp: Duration(seconds: 5), text: 'Spotify Line 1'),
        ],
        plainLyrics: 'Spotify Line 1',
      );

      final lrclibLyrics = SyncedLyrics(
        trackId: dummyTrack.id,
        lines: [
          const LyricLine(timestamp: Duration(seconds: 6), text: 'LRCLIB Line 1'),
        ],
        plainLyrics: 'LRCLIB Line 1',
      );

      final composite = CompositeLyricsProvider(
        spotify: _MockLyricsProvider(spotifyLyrics),
        primary: _MockLyricsProvider(lrclibLyrics),
        secondary: _MockLyricsProvider(null),
      );

      final result = await composite.getLyrics(dummyTrack);
      expect(result, isNotNull);
      expect(result!.lines.first.text, equals('Spotify Line 1'));
    });

    test('falls back to Tier 1 LRCLIB when Spotify returns null', () async {
      final lrclibLyrics = SyncedLyrics(
        trackId: dummyTrack.id,
        lines: [
          const LyricLine(timestamp: Duration(seconds: 6), text: 'LRCLIB Line 1'),
        ],
        plainLyrics: 'LRCLIB Line 1',
      );

      final composite = CompositeLyricsProvider(
        spotify: _MockLyricsProvider(null),
        primary: _MockLyricsProvider(lrclibLyrics),
        secondary: _MockLyricsProvider(null),
      );

      final result = await composite.getLyrics(dummyTrack);
      expect(result, isNotNull);
      expect(result!.lines.first.text, equals('LRCLIB Line 1'));
    });

    test('falls back to Tier 2 Kugou when both Spotify and LRCLIB return null', () async {
      final kugouLyrics = SyncedLyrics(
        trackId: dummyTrack.id,
        lines: [
          const LyricLine(timestamp: Duration(seconds: 7), text: 'Kugou Line 1'),
        ],
        plainLyrics: 'Kugou Line 1',
      );

      final composite = CompositeLyricsProvider(
        spotify: _MockLyricsProvider(null),
        primary: _MockLyricsProvider(null),
        secondary: _MockLyricsProvider(kugouLyrics),
      );

      final result = await composite.getLyrics(dummyTrack);
      expect(result, isNotNull);
      expect(result!.lines.first.text, equals('Kugou Line 1'));
    });
  });
}

class _MockLyricsProvider implements ILyricsProvider {
  final SyncedLyrics? _lyrics;
  _MockLyricsProvider(this._lyrics);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async => _lyrics;
}
