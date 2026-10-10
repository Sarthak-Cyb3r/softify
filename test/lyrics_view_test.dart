import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/data/lyrics/composite_lyrics_provider.dart';
import 'package:softify/data/lyrics/lrclib_lyrics_provider.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_lyrics_provider.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/widgets/lyrics_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTrack = Track(
    id: 'track_1',
    sourceId: 'src_1',
    title: 'Self Aware',
    artist: 'Qveen Herby',
    duration: Duration(seconds: 180),
  );

  group('LRC Parsing & Word Synchronization Tests', () {
    test('parses standard line-level LRC timestamps correctly', () {
      const lrc = '''
[00:10.50] Line one of lyrics
[00:15.00] Line two of lyrics
[00:20.75] ♪
''';
      final lines = LrclibLyricsProvider.parseLrc(lrc);
      expect(lines.length, 3);
      expect(lines[0].timestamp, const Duration(seconds: 10, milliseconds: 500));
      expect(lines[0].text, 'Line one of lyrics');
      expect(lines[0].words, isNull);

      expect(lines[1].timestamp, const Duration(seconds: 15));
      expect(lines[1].text, 'Line two of lyrics');

      expect(lines[2].timestamp, const Duration(seconds: 20, milliseconds: 750));
      expect(lines[2].text, '♪');
    });

    test('parses enhanced word-level LRC tags (<mm:ss.xx>) into LyricWord items', () {
      const enhancedLrc = '''
[00:05.00]<00:05.00>I <00:05.50>want <00:06.00>you
[00:10.00]Regular line
''';
      final lines = LrclibLyricsProvider.parseLrc(enhancedLrc);
      expect(lines.length, 2);
      expect(lines[0].words, isNotNull);
      expect(lines[0].words!.length, 3);
      expect(lines[0].words![0].text, 'I');
      expect(lines[0].words![0].timestamp, const Duration(seconds: 5));
      expect(lines[0].words![1].text, 'want');
      expect(lines[0].words![1].timestamp, const Duration(seconds: 5, milliseconds: 500));
      expect(lines[0].words![2].text, 'you');
      expect(lines[0].words![2].timestamp, const Duration(seconds: 6));
      expect(lines[0].text, 'I want you');

      expect(lines[1].words, isNull);
      expect(lines[1].text, 'Regular line');
    });
  });

  group('LyricsView Widget UI/UX Tests', () {
    testWidgets('renders synced karaoke lyrics without throwing', (tester) async {
      final fakeLyrics = SyncedLyrics(
        trackId: testTrack.id,
        lines: [
          const LyricLine(
            timestamp: Duration(seconds: 2),
            text: 'First line of the song',
          ),
          const LyricLine(
            timestamp: Duration(seconds: 6),
            text: 'Second line of the song',
          ),
          const LyricLine(
            timestamp: Duration(seconds: 12),
            text: 'Third line of the song',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackLyricsProvider(testTrack).overrideWith((ref) => fakeLyrics),
            playbackStateStreamProvider.overrideWith((ref) => Stream.value(PlaybackState(playing: false))),
            positionStreamProvider.overrideWith((ref) => Stream.value(const Duration(seconds: 3))),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 700,
                child: LyricsView(
                  track: testTrack,
                  ambientColor: Color(0xFF1DB954),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('LYRICS'), findsOneWidget);
      expect(find.text('0ms'), findsOneWidget);
      expect(find.text('Self Aware • Qveen Herby'), findsOneWidget);
      expect(find.text('First line of the song'), findsNothing); // Active line is split into words
      expect(find.text('First'), findsOneWidget); // Active word
      expect(find.text('Second line of the song'), findsOneWidget); // Inactive line
    });

    testWidgets('renders plain unsynced lyrics sheet when synced lyrics are missing', (tester) async {
      final plainLyrics = SyncedLyrics(
        trackId: testTrack.id,
        lines: const [],
        plainLyrics: 'Just plain text lyrics without timestamps.\nSecond verse here.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackLyricsProvider(testTrack).overrideWith((ref) => plainLyrics),
            playbackStateStreamProvider.overrideWith((ref) => Stream.value(PlaybackState(playing: false))),
            positionStreamProvider.overrideWith((ref) => Stream.value(Duration.zero)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 700,
                child: LyricsView(
                  track: testTrack,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Just plain text lyrics without timestamps'), findsOneWidget);
    });

    testWidgets('renders empty state gracefully when no lyrics exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackLyricsProvider(testTrack).overrideWith((ref) => null),
            playbackStateStreamProvider.overrideWith((ref) => Stream.value(PlaybackState(playing: false))),
            positionStreamProvider.overrideWith((ref) => Stream.value(Duration.zero)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 700,
                child: LyricsView(
                  track: testTrack,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No lyrics available for this track'), findsOneWidget);
    });

    testWidgets('renders desktop 2-column Sing Along layout with sidebar telemetry', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeLyrics = SyncedLyrics(
        trackId: testTrack.id,
        lines: [
          const LyricLine(
            timestamp: Duration(seconds: 2),
            text: 'First line of the song',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackLyricsProvider(testTrack).overrideWith((ref) => fakeLyrics),
            playbackStateStreamProvider.overrideWith((ref) => Stream.value(PlaybackState(playing: false))),
            positionStreamProvider.overrideWith((ref) => Stream.value(const Duration(seconds: 2))),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 900,
                height: 700,
                child: LyricsView(
                  track: testTrack,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sync Live'), findsOneWidget);
      expect(find.text('Stereo Hi-Fi'), findsOneWidget);
      expect(find.text('171 BPM'), findsOneWidget);
      expect(find.text('VOCAL VOLUME MODE'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Karaoke'), findsOneWidget);
      expect(find.text('VOCALS 92%'), findsOneWidget);
    });

    test('CompositeLyricsProvider seamlessly falls back when primary is empty', () async {
      final primary = _FakeLyricsProvider(null);
      final secondary = _FakeLyricsProvider(
        const SyncedLyrics(
          trackId: 'track_1',
          lines: [
            LyricLine(timestamp: Duration(seconds: 1), text: 'Fallback line'),
          ],
        ),
      );

      final composite = CompositeLyricsProvider(
        primary: primary,
        secondary: secondary,
      );

      final result = await composite.getLyrics(testTrack);
      expect(result, isNotNull);
      expect(result!.lines.first.text, 'Fallback line');
    });
  });
}

class _FakeLyricsProvider implements ILyricsProvider {
  final SyncedLyrics? _result;
  _FakeLyricsProvider(this._result);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async => _result;
}

