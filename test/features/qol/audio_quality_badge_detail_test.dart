import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/audio_quality_preset.dart';
import 'package:softify/domain/entities/stream_info.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/audio_quality_badge_detail.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleTrack = Track(
    id: 'track-101',
    sourceId: 'src-101',
    title: 'Midnight City',
    artist: 'M83',
    duration: Duration(seconds: 243),
  );

  group('AudioStreamDiagnostics logic', () {
    test('Standard stream diagnostics', () {
      final diag = AudioStreamDiagnostics.from(
        track: sampleTrack,
        streamInfo: StreamInfo(
          url: Uri.parse('https://example.com/audio.m4a'),
          container: 'm4a',
          bitrate: 128000,
          codec: 'mp4a.40.2',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          providerName: 'saavn',
        ),
        qualityPreset: AudioQualityPreset.standard,
      );

      expect(diag.qualityLevel, contains('Standard'));
      expect(diag.qualityLevel, contains('128kbps'));
      expect(diag.badgeText, equals('STANDARD'));
      expect(diag.codec, equals('AAC'));
      expect(diag.container, equals('M4A'));
      expect(diag.sampleRate, equals('44.1 kHz'));
      expect(diag.sourceType, equals('Streamed'));
      expect(diag.channel, equals('Stereo 2.0'));
      expect(diag.isLossless, isFalse);
    });

    test('HQ 320kbps stream diagnostics', () {
      final diag = AudioStreamDiagnostics.from(
        track: sampleTrack,
        streamInfo: StreamInfo(
          url: Uri.parse('https://example.com/master.m4a'),
          container: 'm4a',
          bitrate: 320000,
          codec: 'mp4a.40.2',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          providerName: 'saavn',
        ),
        qualityPreset: AudioQualityPreset.high,
      );

      expect(diag.qualityLevel, contains('High'));
      expect(diag.qualityLevel, contains('320kbps'));
      expect(diag.badgeText, equals('HQ'));
      expect(diag.codec, equals('AAC'));
      expect(diag.isHiRes, isTrue);
      expect(diag.sourceType, equals('Streamed'));
    });

    test('Lossless FLAC stream diagnostics', () {
      final diag = AudioStreamDiagnostics.from(
        track: sampleTrack,
        streamInfo: StreamInfo(
          url: Uri.parse('https://example.com/lossless.flac'),
          container: 'flac',
          bitrate: 1411000,
          codec: 'flac',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          providerName: 'local_flac',
        ),
      );

      expect(diag.qualityLevel, contains('Lossless'));
      expect(diag.qualityLevel, contains('FLAC'));
      expect(diag.badgeText, equals('LOSSLESS'));
      expect(diag.codec, equals('FLAC'));
      expect(diag.isLossless, isTrue);
      expect(diag.sampleRate, equals('44.1 kHz'));
    });

    test('Opus stream diagnostics sample rate is 48 kHz', () {
      final diag = AudioStreamDiagnostics.from(
        track: sampleTrack,
        streamInfo: StreamInfo(
          url: Uri.parse('https://example.com/stream.webm'),
          container: 'webm',
          bitrate: 160000,
          codec: 'opus',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          providerName: 'youtube_explode',
        ),
      );

      expect(diag.codec, equals('Opus'));
      expect(diag.container, equals('WebM'));
      expect(diag.sampleRate, equals('48 kHz'));
    });

    test('Local file source detection', () {
      const localTrack = Track(
        id: 'local_track_99',
        sourceId: '/storage/music/song.mp3',
        title: 'Local Melody',
        artist: 'Home Artist',
        duration: Duration(seconds: 180),
      );

      final diag = AudioStreamDiagnostics.from(
        track: localTrack,
        streamInfo: StreamInfo(
          url: Uri.parse('file:///storage/music/song.mp3'),
          container: 'mp3',
          bitrate: 320000,
          codec: 'mp3',
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          providerName: 'local_audio',
        ),
      );

      expect(diag.sourceType, equals('Local File'));
      expect(diag.sourceDetail, contains('Device Storage'));
      expect(diag.codec, equals('MP3'));
    });

    test('Offline cached source detection', () {
      final diag = AudioStreamDiagnostics.from(
        track: sampleTrack,
        streamInfo: StreamInfo(
          url: Uri.parse('cache:///local_cache/track101.m4a'),
          container: 'm4a',
          bitrate: 320000,
          codec: 'aac',
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          providerName: 'offline_cached',
        ),
      );

      expect(diag.sourceType, equals('Cached'));
      expect(diag.sourceDetail, contains('Offline'));
    });
  });

  group('AudioQualityDetailDialog Widget Tests', () {
    testWidgets('Renders all required diagnostics fields in dialog',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final stream = StreamInfo(
        url: Uri.parse('https://example.com/high.m4a'),
        container: 'm4a',
        bitrate: 320000,
        codec: 'mp4a.40.2',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        providerName: 'saavn',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentTrackProvider.overrideWith((ref) => Stream.value(sampleTrack)),
            currentStreamInfoProvider.overrideWith((ref) => Stream.value(stream)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => AudioQualityDetailDialog.show(
                    context,
                    track: sampleTrack,
                    streamInfo: stream,
                  ),
                  child: const Text('Open Inspector'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open dialog
      await tester.tap(find.text('Open Inspector'));
      await tester.pumpAndSettle();

      // 1. Verify Dialog Header & Track Info
      expect(find.text('Stream Format Inspector'), findsOneWidget);
      expect(find.text('Midnight City'), findsOneWidget);
      expect(find.text('M83'), findsOneWidget);

      // 2. Verify Formatted stream info
      // - Audio Quality Level: High (320kbps)
      expect(find.text('Audio Quality Level'), findsOneWidget);
      expect(find.text('High (320kbps)'), findsOneWidget);

      // - Codec / Container: AAC / M4A
      expect(find.text('Codec / Container'), findsOneWidget);
      expect(find.text('AAC / M4A'), findsOneWidget);

      // - Estimated Sample Rate: 44.1 kHz / 48 kHz
      expect(find.text('Estimated Sample Rate'), findsOneWidget);
      expect(find.textContaining('44.1 kHz'), findsWidgets);

      // - Source Type: Streamed / Local File / Cached
      expect(find.text('Source Type'), findsOneWidget);
      expect(find.textContaining('Streamed'), findsWidgets);

      // - Audio Channel: Stereo 2.0
      expect(find.text('Audio Channel'), findsOneWidget);
      expect(find.text('Stereo 2.0'), findsOneWidget);

      // 3. Verify Audiophile Badges Explanation Guide
      expect(find.text('Audiophile Badges Explanation'), findsOneWidget);
      expect(find.text('LOSSLESS'), findsWidgets);
      expect(find.text('HQ'), findsWidgets);
      expect(find.text('STANDARD'), findsWidgets);
      expect(find.text('SAVER'), findsWidgets);

      // 4. Verify Audio Quality Settings Button
      expect(find.text('Audio Quality Settings'), findsOneWidget);

      // 5. Dismiss Dialog
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Stream Format Inspector'), findsNothing);
    });

    testWidgets('AudioQualityBadge renders and triggers dialog',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final flacStream = StreamInfo(
        url: Uri.parse('https://example.com/song.flac'),
        container: 'flac',
        bitrate: 1411000,
        codec: 'flac',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        providerName: 'saavn',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentTrackProvider.overrideWith((ref) => Stream.value(sampleTrack)),
            currentStreamInfoProvider.overrideWith((ref) => Stream.value(flacStream)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: AudioQualityBadge(
                  track: sampleTrack,
                  streamInfo: flacStream,
                ),
              ),
            ),
          ),
        ),
      );

      // Badge displays LOSSLESS
      expect(find.text('LOSSLESS'), findsOneWidget);

      // Tapping badge opens inspector dialog
      await tester.tap(find.text('LOSSLESS'));
      await tester.pumpAndSettle();

      expect(find.text('Stream Format Inspector'), findsOneWidget);
      expect(find.text('Lossless (FLAC)'), findsOneWidget);
    });
  });
}
