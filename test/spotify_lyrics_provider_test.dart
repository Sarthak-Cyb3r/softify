import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/lyrics/composite_lyrics_provider.dart';
import 'package:softify/data/lyrics/spotify_lyrics_provider.dart';
import 'package:softify/data/lyrics/spotify_lyrics_synchronizer.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_lyrics_provider.dart';

void main() {
  group('SpotifyLyricsProvider & JSON Parser (Module 88971 / 52388)', () {
    const sampleSpotifyColorLyricsJson = '''
{
  "lyrics": {
    "syncType": "SYLLABLE_SYNCED",
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
    ],
    "provider": "Musixmatch",
    "providerDisplayName": "Musixmatch",
    "isTimeSynced": true
  },
  "colors": {
    "background": -16777216,
    "text": -1,
    "highlightText": -14761005
  },
  "hasLyrics": true
}
''';

    test('parses Spotify color-lyrics JSON into SyncedLyrics with lines, syllables, and colors', () {
      final lyrics = SpotifyLyricsProvider.parseSpotifyLyricsJson(
        sampleSpotifyColorLyricsJson,
        'track-123',
      );

      expect(lyrics, isNotNull);
      expect(lyrics!.trackId, equals('track-123'));
      expect(lyrics.lines.length, equals(2));
      expect(lyrics.syncType, equals('SYLLABLE_SYNCED'));
      expect(lyrics.isSyllableSynced, isTrue);
      expect(lyrics.providerName, equals('Musixmatch'));

      // Dynamic colors
      expect(lyrics.colors, isNotNull);
      expect(lyrics.colors!.background, equals(-16777216));
      expect(lyrics.colors!.text, equals(-1));
      expect(lyrics.colors!.highlightText, equals(-14761005));

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
      expect(lyrics.lines[1].words![0].duration, equals(const Duration(milliseconds: 400))); // 18600 - 18200
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

  group('SpotifyLyricsSynchronizer Mathematical Model (Module 29735 & 52427)', () {
    test('dead-reckoning extrapolation matches kernel audio clock when playing', () {
      final refTime = DateTime(2026, 1, 1, 12, 0, 0);
      final now = DateTime(2026, 1, 1, 12, 0, 1); // 1000ms elapsed
      const refPos = Duration(seconds: 10); // 10000ms

      final extrapolated = SpotifyLyricsSynchronizer.extrapolatePosition(
        referencePosition: refPos,
        referenceTimestamp: refTime,
        now: now,
        speed: 1.0,
        isPaused: false,
        isBuffering: false,
        latencyCompensationMs: 280,
      );

      // Expected: 10000ms + 1000ms + 280ms = 11280ms
      expect(extrapolated, equals(const Duration(milliseconds: 11280)));
    });

    test('freezes position when paused or buffering (Module 29735 invariant)', () {
      final refTime = DateTime(2026, 1, 1, 12, 0, 0);
      final now = DateTime(2026, 1, 1, 12, 0, 5); // 5000ms later
      const refPos = Duration(seconds: 15);

      final pausedExtrapolated = SpotifyLyricsSynchronizer.extrapolatePosition(
        referencePosition: refPos,
        referenceTimestamp: refTime,
        now: now,
        isPaused: true,
      );
      expect(pausedExtrapolated, equals(refPos));

      final bufferingExtrapolated = SpotifyLyricsSynchronizer.extrapolatePosition(
        referencePosition: refPos,
        referenceTimestamp: refTime,
        now: now,
        isBuffering: true,
      );
      expect(bufferingExtrapolated, equals(refPos));
    });

    test('clamps position to track duration', () {
      final refTime = DateTime(2026, 1, 1, 12, 0, 0);
      final now = DateTime(2026, 1, 1, 12, 0, 10);
      const trackDuration = Duration(seconds: 12);

      final extrapolated = SpotifyLyricsSynchronizer.extrapolatePosition(
        referencePosition: const Duration(seconds: 11),
        referenceTimestamp: refTime,
        now: now,
        duration: trackDuration,
      );

      expect(extrapolated, equals(trackDuration));
    });

    test('binary search interval matching locates active line (Module 52427)', () {
      final lines = [
        const LyricLine(timestamp: Duration(milliseconds: 3000), text: 'Line 0'),
        const LyricLine(timestamp: Duration(milliseconds: 6000), text: 'Line 1'),
        const LyricLine(timestamp: Duration(milliseconds: 9000), text: 'Line 2'),
        const LyricLine(timestamp: Duration(milliseconds: 12000), text: 'Line 3'),
      ];

      // Before first line begins
      expect(SpotifyLyricsSynchronizer.findActiveLineIndex(lines, const Duration(milliseconds: 1000)), equals(-1));
      // Exactly at first line
      expect(SpotifyLyricsSynchronizer.findActiveLineIndex(lines, const Duration(milliseconds: 3000)), equals(0));
      // Between line 0 and line 1
      expect(SpotifyLyricsSynchronizer.findActiveLineIndex(lines, const Duration(milliseconds: 4500)), equals(0));
      // Exactly at line 2
      expect(SpotifyLyricsSynchronizer.findActiveLineIndex(lines, const Duration(milliseconds: 9000)), equals(2));
      // Beyond last line
      expect(SpotifyLyricsSynchronizer.findActiveLineIndex(lines, const Duration(milliseconds: 15000)), equals(3));
    });

    test('syllable active word index and progress calculations', () {
      final words = [
        const LyricWord(timestamp: Duration(milliseconds: 1000), text: 'Hel'),
        const LyricWord(timestamp: Duration(milliseconds: 1500), text: 'lo'),
        const LyricWord(timestamp: Duration(milliseconds: 2000), text: 'world'),
      ];

      expect(SpotifyLyricsSynchronizer.findActiveWordIndex(words, const Duration(milliseconds: 500)), equals(-1));
      expect(SpotifyLyricsSynchronizer.findActiveWordIndex(words, const Duration(milliseconds: 1200)), equals(0));
      expect(SpotifyLyricsSynchronizer.findActiveWordIndex(words, const Duration(milliseconds: 1600)), equals(1));
      expect(SpotifyLyricsSynchronizer.findActiveWordIndex(words, const Duration(milliseconds: 2100)), equals(2));

      // Progress ratio
      final progress = SpotifyLyricsSynchronizer.calculateWordProgress(
        wordStart: const Duration(milliseconds: 1000),
        nextWordStart: const Duration(milliseconds: 1500),
        currentPosition: const Duration(milliseconds: 1250),
      );
      expect(progress, closeTo(0.5, 0.01));
    });

    test('safe auto-scroll deadzone prevents jitter (Module 52427)', () {
      // In center of safe zone
      final inZone = SpotifyLyricsSynchronizer.isInAutoScrollZone(
        lineTop: 300.0,
        lineHeight: 30.0,
        viewTop: 0.0,
        viewHeight: 600.0,
      );
      expect(inZone, isTrue);

      // Way above viewport (departed safe zone)
      final outZone = SpotifyLyricsSynchronizer.isInAutoScrollZone(
        lineTop: -50.0,
        lineHeight: 30.0,
        viewTop: 0.0,
        viewHeight: 600.0,
      );
      expect(outZone, isFalse);
    });
  });

  group('AppSec Security Hardening (SSRF & Input Sanitization)', () {
    test('blocks SSRF loopback, localhost, and private RFC-1918 subnets', () {
      expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('http://localhost:8080'), isNull);
      expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('http://127.0.0.1:3000'), isNull);
      expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('http://169.254.169.254/latest/meta-data/'), isNull);
      expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('http://10.0.0.5/api'), isNull);
      expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('http://192.168.1.100/lyrics'), isNull);
      expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('http://172.16.0.1/proxy'), isNull);
      expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('file:///etc/passwd'), isNull);
      expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('javascript:alert(1)'), isNull);
    });

    test('allows legitimate public HTTPS lyrics endpoints', () {
      final valid = SpotifyLyricsSynchronizer.sanitizeEndpoint('https://lyrics.spotify-mirror.org/api');
      expect(valid, isNotNull);
      expect(valid!.host, equals('lyrics.spotify-mirror.org'));
      expect(valid.scheme, equals('https'));
    });
  });

  group('CompositeLyricsProvider Multi-tier Fallback (Spotify as Primary)', () {
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
        providerName: 'Spotify',
      );

      final lrclibLyrics = SyncedLyrics(
        trackId: dummyTrack.id,
        lines: [
          const LyricLine(timestamp: Duration(seconds: 6), text: 'LRCLIB Line 1'),
        ],
        plainLyrics: 'LRCLIB Line 1',
        providerName: 'LRCLIB',
      );

      final composite = CompositeLyricsProvider(
        spotify: _MockLyricsProvider(spotifyLyrics),
        primary: _MockLyricsProvider(lrclibLyrics),
        secondary: _MockLyricsProvider(null),
      );

      final result = await composite.getLyrics(dummyTrack);
      expect(result, isNotNull);
      expect(result!.lines.first.text, equals('Spotify Line 1'));
      expect(result.providerName, equals('Spotify'));
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
