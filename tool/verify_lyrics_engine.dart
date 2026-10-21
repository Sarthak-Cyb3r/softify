import 'package:softify/data/lyrics/composite_lyrics_provider.dart';
import 'package:softify/data/lyrics/spotify_lyrics_provider.dart';
import 'package:softify/data/lyrics/spotify_lyrics_synchronizer.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_lyrics_provider.dart';

void expect(dynamic actual, dynamic expected, [String? message]) {
  if (actual != expected) {
    throw Exception('Assertion failed: Expected $expected, got $actual. $message');
  }
}

void expectTrue(bool condition, [String? message]) {
  if (!condition) {
    throw Exception('Assertion failed: Condition is false. $message');
  }
}

Future<void> main() async {
  print('=== [1] Verifying Spotify Color-Lyrics v2 JSON Parsing ===');
  const sampleJson = '''
{
  "lyrics": {
    "syncType": "SYLLABLE_SYNCED",
    "lines": [
      {
        "startTimeMs": "12500",
        "words": "First line",
        "syllables": []
      },
      {
        "startTimeMs": "18200",
        "words": "Second syllable line",
        "syllables": [
          {"startTimeMs": "18200", "text": "Second"},
          {"startTimeMs": "18600", "text": "syllable"},
          {"startTimeMs": "19400", "text": "line"}
        ]
      }
    ],
    "provider": "Musixmatch",
    "isTimeSynced": true
  },
  "colors": {
    "background": -16777216,
    "text": -1,
    "highlightText": -14761005
  }
}
''';

  final lyrics = SpotifyLyricsProvider.parseSpotifyLyricsJson(sampleJson, 'test_track');
  expectTrue(lyrics != null, 'Lyrics should not be null');
  expect(lyrics!.trackId, 'test_track');
  expect(lyrics.lines.length, 2);
  expect(lyrics.syncType, 'SYLLABLE_SYNCED');
  expectTrue(lyrics.isSyllableSynced, 'Should be syllable synced');
  expect(lyrics.colors?.background, -16777216);
  expect(lyrics.colors?.highlightText, -14761005);
  expect(lyrics.lines[1].words?.length, 3);
  expect(lyrics.lines[1].words?[0].duration?.inMilliseconds, 400); // 18600 - 18200
  print('✓ Spotify Color-Lyrics v2 JSON parser passed.');

  print('=== [2] Verifying Dead-Reckoning Extrapolation (Module 29735) ===');
  final refTime = DateTime(2026, 1, 1, 12, 0, 0);
  final now = DateTime(2026, 1, 1, 12, 0, 2); // 2000ms later
  final refPos = const Duration(seconds: 10);

  final activeExtrapolated = SpotifyLyricsSynchronizer.extrapolatePosition(
    referencePosition: refPos,
    referenceTimestamp: refTime,
    now: now,
    speed: 1.0,
    isPaused: false,
    isBuffering: false,
    latencyCompensationMs: 280,
  );
  // 10000 + 2000 + 280 = 12280
  expect(activeExtrapolated.inMilliseconds, 12280);

  final pausedExtrapolated = SpotifyLyricsSynchronizer.extrapolatePosition(
    referencePosition: refPos,
    referenceTimestamp: refTime,
    now: now,
    isPaused: true,
  );
  expect(pausedExtrapolated.inMilliseconds, 10000);
  print('✓ Dead-reckoning extrapolation passed.');

  print('=== [3] Verifying Binary Search Line & Syllable Matching (Module 52427) ===');
  final testLines = [
    const LyricLine(timestamp: Duration(milliseconds: 2000), text: 'L0'),
    const LyricLine(timestamp: Duration(milliseconds: 5000), text: 'L1'),
    const LyricLine(timestamp: Duration(milliseconds: 8000), text: 'L2'),
  ];
  expect(SpotifyLyricsSynchronizer.findActiveLineIndex(testLines, const Duration(milliseconds: 1000)), -1);
  expect(SpotifyLyricsSynchronizer.findActiveLineIndex(testLines, const Duration(milliseconds: 2000)), 0);
  expect(SpotifyLyricsSynchronizer.findActiveLineIndex(testLines, const Duration(milliseconds: 4000)), 0);
  expect(SpotifyLyricsSynchronizer.findActiveLineIndex(testLines, const Duration(milliseconds: 5000)), 1);
  expect(SpotifyLyricsSynchronizer.findActiveLineIndex(testLines, const Duration(milliseconds: 10000)), 2);

  final testWords = [
    const LyricWord(timestamp: Duration(milliseconds: 5000), text: 'One'),
    const LyricWord(timestamp: Duration(milliseconds: 5500), text: 'Two'),
  ];
  expect(SpotifyLyricsSynchronizer.findActiveWordIndex(testWords, const Duration(milliseconds: 4900)), -1);
  expect(SpotifyLyricsSynchronizer.findActiveWordIndex(testWords, const Duration(milliseconds: 5200)), 0);
  expect(SpotifyLyricsSynchronizer.findActiveWordIndex(testWords, const Duration(milliseconds: 5600)), 1);
  print('✓ Binary search line & syllable matching passed.');

  print('=== [4] Verifying Viewport Safe Deadzone Calculation (Module 52427) ===');
  expectTrue(
    SpotifyLyricsSynchronizer.isInAutoScrollZone(
      lineTop: 280.0,
      lineHeight: 30.0,
      viewTop: 0.0,
      viewHeight: 600.0,
    ),
    'Line in center of deadzone should be in zone',
  );
  expectTrue(
    !SpotifyLyricsSynchronizer.isInAutoScrollZone(
      lineTop: -100.0,
      lineHeight: 30.0,
      viewTop: 0.0,
      viewHeight: 600.0,
    ),
    'Line outside deadzone should trigger scroll',
  );
  print('✓ Safe auto-scroll deadzone calculation passed.');

  print('=== [5] Verifying AppSec SSRF & Endpoint Sanitization ===');
  expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('http://localhost:8080'), null);
  expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('http://127.0.0.1/admin'), null);
  expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('http://10.0.0.1/meta'), null);
  expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('http://192.168.0.1/'), null);
  expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('http://172.20.0.1/'), null);
  expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('http://169.254.169.254/'), null);
  expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('file:///etc/passwd'), null);
  expect(SpotifyLyricsSynchronizer.sanitizeEndpoint('javascript:void(0)'), null);
  expectTrue(
    SpotifyLyricsSynchronizer.sanitizeEndpoint('https://lyrics.example.com/api') != null,
    'Valid HTTPS endpoint should be accepted',
  );
  print('✓ AppSec SSRF & URL sanitization passed.');

  print('=== [6] Verifying CompositeLyricsProvider Priority (Spotify as Primary) ===');
  const dummy = Track(
    id: 'spotify_4cOdK2wGLETKBW3PvgPWqT',
    sourceId: 'spotify_4cOdK2wGLETKBW3PvgPWqT',
    title: 'Never Gonna Give You Up',
    artist: 'Rick Astley',
    duration: Duration(seconds: 213),
  );

  final spotifyLrc = SyncedLyrics(
    trackId: dummy.id,
    lines: [const LyricLine(timestamp: Duration(seconds: 1), text: 'Spotify Primary Line')],
    providerName: 'Spotify',
  );
  final lrclibLrc = SyncedLyrics(
    trackId: dummy.id,
    lines: [const LyricLine(timestamp: Duration(seconds: 2), text: 'LRCLIB Line')],
    providerName: 'LRCLIB',
  );

  final composite = CompositeLyricsProvider(
    spotify: _TestProvider(spotifyLrc),
    primary: _TestProvider(lrclibLrc),
  );

  final res = await composite.getLyrics(dummy);
  expect(res?.lines.first.text, 'Spotify Primary Line');
  expect(res?.providerName, 'Spotify');
  print('✓ Spotify primary priority in CompositeLyricsProvider passed.');

  print('\n🎯 ALL LYRICS ENGINE VERIFICATION GATES GREEN!');
}

class _TestProvider implements ILyricsProvider {
  final SyncedLyrics? _lyrics;
  _TestProvider(this._lyrics);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async => _lyrics;
}
