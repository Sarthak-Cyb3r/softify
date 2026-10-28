import 'dart:async';
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

    test('parses multi-format timestamps, single-digit minutes, colon separators, and offset tag', () {
      const complexLrc = '''
[offset:500]
[1:05.20] Single digit minute
[02:10:40] Colon subsecond separator
[03:15.5] Single digit fraction
[04:20.125] Three digit millisecond
[00:10.00][00:25.00] Repeated chorus line
''';
      final lines = LrclibLyricsProvider.parseLrc(complexLrc);
      expect(lines.length, 6);
      // [00:10.00] + 500ms offset = 10500ms
      expect(lines[0].timestamp, const Duration(milliseconds: 10500));
      expect(lines[0].text, 'Repeated chorus line');

      // [00:25.00] + 500ms offset = 25500ms
      expect(lines[1].timestamp, const Duration(milliseconds: 25500));
      expect(lines[1].text, 'Repeated chorus line');

      // [1:05.20] (65200ms) + 500ms offset = 65700ms
      expect(lines[2].timestamp, const Duration(milliseconds: 65700));
      expect(lines[2].text, 'Single digit minute');

      // [02:10:40] (130400ms) + 500ms offset = 130900ms
      expect(lines[3].timestamp, const Duration(milliseconds: 130900));
      expect(lines[3].text, 'Colon subsecond separator');

      // [03:15.5] (195500ms) + 500ms offset = 196000ms
      expect(lines[4].timestamp, const Duration(milliseconds: 196000));
      expect(lines[4].text, 'Single digit fraction');

      // [04:20.125] (260125ms) + 500ms offset = 260625ms
      expect(lines[5].timestamp, const Duration(milliseconds: 260625));
      expect(lines[5].text, 'Three digit millisecond');
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
      expect(find.text('0ms'), findsNothing);
      expect(find.text('Self Aware • Qveen Herby'), findsOneWidget);
      expect(find.text('First line of the song'), findsOneWidget);
      expect(find.text('Second line of the song'), findsOneWidget);
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
      expect(find.text('Synced with audio'), findsOneWidget);
      expect(find.text('Continuous Track Sync'), findsOneWidget);
    });

    testWidgets('renders font size scaler and romanize transliteration toggles', (tester) async {
      final fakeLyrics = Future.value(
        const SyncedLyrics(
          trackId: 'track_1',
          lines: [
            LyricLine(
              timestamp: Duration(seconds: 2),
              text: 'तुम ही हो',
            ),
          ],
        ),
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

      // Font size badge exists (defaults to M)
      expect(find.text('M'), findsOneWidget);
      // Romanize toggle exists (defaults to ORIG)
      expect(find.text('ORIG'), findsOneWidget);

      // Tap font size badge -> cycles to L
      await tester.tap(find.text('M'));
      await tester.pump();
      expect(find.text('L'), findsOneWidget);

      // Tap romanize badge -> toggles to ROM
      await tester.tap(find.text('ORIG'));
      await tester.pump();
      expect(find.text('ROM'), findsOneWidget);
      // Verify transliterated line is rendered
      expect(find.text('tum hee ho'), findsOneWidget);
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

    testWidgets('wrapped lyric lines animate sequentially sub-line by sub-line', (tester) async {
      const longLineTrack = Track(
        id: 'track_wrapped',
        sourceId: 'src_wrapped',
        title: 'Wrapped Test',
        artist: 'Tester',
        duration: Duration(seconds: 20),
      );

      final positionController = StreamController<Duration>.broadcast();
      addTearDown(positionController.close);

      final longLyrics = SyncedLyrics(
        trackId: longLineTrack.id,
        lines: const [
          LyricLine(
            timestamp: Duration(seconds: 1),
            text: 'This is a very long line of lyrics that will wrap into multiple lines on device screen',
          ),
          LyricLine(
            timestamp: Duration(seconds: 10),
            text: 'Next line after long',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackLyricsProvider(longLineTrack).overrideWith((ref) => longLyrics),
            playbackStateStreamProvider.overrideWith((ref) => Stream.value(PlaybackState(playing: true))),
            positionStreamProvider.overrideWith((ref) => positionController.stream),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 600,
                child: LyricsView(
                  track: longLineTrack,
                  ambientColor: Color(0xFF1DB954),
                ),
              ),
            ),
          ),
        ),
      );

      // Early progress: line starts at 1s, duration is 9s (until 10s).
      // At 2s, progress is (2000 - 1000) / 9000 = ~11%.
      // Sub-line 1 is animating (ShaderMask exists). Sub-line 2 is not yet started (0%).
      positionController.add(const Duration(milliseconds: 1800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Exactly 1 ShaderMask should exist across the sublines because only sub-line 1 has started animating
      expect(find.byType(ShaderMask), findsOneWidget);

      // Mid-to-late progress: position at 6.5s -> progress ~61%.
      // Sub-line 1 is 100% finished (rendered as plain Text with activeStyle, no ShaderMask),
      // while subsequent sub-line is now actively animating (ShaderMask exists).
      positionController.add(const Duration(milliseconds: 6500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('word-to-word synchronization progressively illuminates active word', (tester) async {
      const wordTrack = Track(
        id: 'track_word_sync',
        sourceId: 'src_word_sync',
        title: 'Word Sync',
        artist: 'Tester',
        duration: Duration(seconds: 20),
      );

      final positionController = StreamController<Duration>.broadcast();
      addTearDown(positionController.close);

      final wordLyrics = SyncedLyrics(
        trackId: wordTrack.id,
        lines: const [
          LyricLine(
            timestamp: Duration(seconds: 1),
            text: 'One Two Three Four',
            words: [
              LyricWord(timestamp: Duration(milliseconds: 1000), text: 'One', duration: Duration(milliseconds: 1000)),
              LyricWord(timestamp: Duration(milliseconds: 2000), text: 'Two', duration: Duration(milliseconds: 1000)),
              LyricWord(timestamp: Duration(milliseconds: 3000), text: 'Three', duration: Duration(milliseconds: 1000)),
              LyricWord(timestamp: Duration(milliseconds: 4000), text: 'Four', duration: Duration(milliseconds: 1000)),
            ],
          ),
          LyricLine(
            timestamp: Duration(seconds: 6),
            text: 'Next line',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackLyricsProvider(wordTrack).overrideWith((ref) => wordLyrics),
            playbackStateStreamProvider.overrideWith((ref) => Stream.value(PlaybackState(playing: true))),
            positionStreamProvider.overrideWith((ref) => positionController.stream),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: LyricsView(
                  track: wordTrack,
                  ambientColor: Color(0xFF1DB954),
                ),
              ),
            ),
          ),
        ),
      );

      // At 1.5s, word "One" is actively being sung (50% progress) -> exactly 1 ShaderMask on "One"
      positionController.add(const Duration(milliseconds: 1500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShaderMask), findsOneWidget);

      // At 2.5s, word "One" is 100% complete (plain Text), word "Two" is actively being sung -> exactly 1 ShaderMask on "Two"
      positionController.add(const Duration(milliseconds: 2500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShaderMask), findsOneWidget);
    });

    test('CuratedLyricsProvider returns verified lyrics for Maine Khud Ko', () async {
      const maineTrack = Track(
        id: 'spotify_05REArTDZQd59A9Y4XC0Aq',
        sourceId: 'src_maine',
        title: 'Maine Khud Ko',
        artist: 'Mustafa Zahid',
        duration: Duration(seconds: 329),
      );

      final composite = CompositeLyricsProvider();
      final lyrics = await composite.getLyrics(maineTrack);

      expect(lyrics, isNotNull);
      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.any((l) => l.text.contains('Maine khud ko de diya hai tujhko')), isTrue);
      expect(lyrics.lines.any((l) => l.text.contains('Gunaah')), isFalse);
    });
  });
}

class _FakeLyricsProvider implements ILyricsProvider {
  final SyncedLyrics? _result;
  _FakeLyricsProvider(this._result);

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async => _result;
}

