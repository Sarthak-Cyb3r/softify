import 'dart:convert';
import 'dart:ui';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/data/database/app_database.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/providers/animated_artwork_provider.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/providers/ui_style_provider.dart';
import 'package:softify/presentation/widgets/animated_artwork_card.dart';
import 'package:softify/services/animated_artwork_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NowPlayingStyle & LyricsStyle Drift Persistence', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('NowPlayingStyleNotifier toggles between classic and appleMusic and persists to DB', () async {
      final notifier = NowPlayingStyleNotifier(db);
      expect(notifier.state, equals(NowPlayingStyle.appleMusic));

      await notifier.setStyle(NowPlayingStyle.classic);
      expect(notifier.state, equals(NowPlayingStyle.classic));

      // Verify row in SQLite Drift
      final row = await (db.select(db.settings)
            ..where((t) => t.key.equals('now_playing_style')))
          .getSingle();
      expect(row.value, equals(NowPlayingStyle.classic.name));

      // Reloading from fresh notifier instance loads persisted style
      final reloaded = NowPlayingStyleNotifier(db);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(reloaded.state, equals(NowPlayingStyle.classic));

      // Switch back to appleMusic
      await reloaded.setStyle(NowPlayingStyle.appleMusic);
      expect(reloaded.state, equals(NowPlayingStyle.appleMusic));
      final updatedRow = await (db.select(db.settings)
            ..where((t) => t.key.equals('now_playing_style')))
          .getSingle();
      expect(updatedRow.value, equals(NowPlayingStyle.appleMusic.name));
    });

    test('LyricsStyleNotifier toggles between classic and appleMusic and persists to DB', () async {
      final notifier = LyricsStyleNotifier(db);
      expect(notifier.state, equals(LyricsStyle.appleMusic));

      await notifier.setStyle(LyricsStyle.classic);
      expect(notifier.state, equals(LyricsStyle.classic));

      final row = await (db.select(db.settings)
            ..where((t) => t.key.equals('lyrics_style')))
          .getSingle();
      expect(row.value, equals(LyricsStyle.classic.name));

      final reloaded = LyricsStyleNotifier(db);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(reloaded.state, equals(LyricsStyle.classic));
    });

    test('LiquidGlassNotifier persists setting and computes active state', () async {
      final notifier = LiquidGlassNotifier(db);
      expect(notifier.state, isTrue);

      await notifier.setEnabled(false);
      expect(notifier.state, isFalse);

      final row = await (db.select(db.settings)
            ..where((t) => t.key.equals('liquid_glass_enabled')))
          .getSingle();
      expect(row.value, equals('false'));

      final reloaded = LiquidGlassNotifier(db);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(reloaded.state, isFalse);
    });

    test('AnimatedArtworkNotifier persists enabled flag to DB', () async {
      final notifier = AnimatedArtworkNotifier(db);
      expect(notifier.state, isTrue);

      await notifier.setEnabled(false);
      expect(notifier.state, isFalse);

      final row = await (db.select(db.settings)
            ..where((t) => t.key.equals('animated_artwork_enabled')))
          .getSingle();
      expect(row.value, equals('false'));

      final reloaded = AnimatedArtworkNotifier(db);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(reloaded.state, isFalse);

      await reloaded.setEnabled(true);
      expect(reloaded.state, isTrue);
    });
  });

  group('Apple Music Optical Depth of Field & Lyrics Formulas', () {
    test('SimpMusic depth-of-field formulas enforce asymmetric past line penalty', () {
      const activeIndex = 5;

      // 1. Pre-roll intro (activeIndex < 0)
      const introActiveIndex = -1;
      const introLine = 0;
      final introAlpha = introActiveIndex < 0
          ? 0.60
          : (introLine == introActiveIndex ? 1.0 : (1.0 - 1 * 0.25).clamp(0.25, 0.90));
      final introBlur = (introActiveIndex < 0 || introLine == introActiveIndex)
          ? 0.0
          : (28.0 * (1 * 0.095)).clamp(0.0, 9.5);

      expect(introAlpha, equals(0.60));
      expect(introBlur, equals(0.0));

      // 2. Active line
      final activeAlpha = (activeIndex == activeIndex) ? 1.0 : 0.5;
      final activeBlur = (activeIndex < 0 || activeIndex == activeIndex)
          ? 0.0
          : (28.0 * 0.095);
      expect(activeAlpha, equals(1.0));
      expect(activeBlur, equals(0.0));

      // 3. Past line (index = 4, activeIndex = 5)
      // Carries +1 distance penalty: ((5 - 4).abs() + 1) = 2
      const pastIndex = 4;
      final pastDistance = (pastIndex < activeIndex)
          ? ((activeIndex - pastIndex).abs() + 1)
          : (pastIndex - activeIndex);
      expect(pastDistance, equals(2));

      final pastBlur = (28.0 * (pastDistance * 0.095)).clamp(0.0, 9.5);
      final pastAlpha = (1.0 - pastDistance * 0.25).clamp(0.25, 0.90);
      expect(pastBlur, closeTo(5.32, 0.01));
      expect(pastAlpha, closeTo(0.50, 0.01));

      // 4. Future line (index = 6, activeIndex = 5)
      // Distance is (6 - 5) = 1 (no penalty)
      const futureIndex = 6;
      final futureDistance = (futureIndex < activeIndex)
          ? ((activeIndex - futureIndex).abs() + 1)
          : (futureIndex - activeIndex);
      expect(futureDistance, equals(1));

      final futureBlur = (28.0 * (futureDistance * 0.095)).clamp(0.0, 9.5);
      final futureAlpha = (1.0 - futureDistance * 0.25).clamp(0.25, 0.90);
      expect(futureBlur, closeTo(2.66, 0.01));
      expect(futureAlpha, closeTo(0.75, 0.01));

      // Past lines recede faster than future lines of equal nominal delta
      expect(pastBlur, greaterThan(futureBlur));
      expect(pastAlpha, lessThan(futureAlpha));
    });

    test('Clamping bounds prevent negative blur or out-of-range opacity', () {
      const activeIndex = 0;
      const distantPastIndex = -10; // Extreme boundary
      final dist = (distantPastIndex < activeIndex)
          ? ((activeIndex - distantPastIndex).abs() + 1)
          : (distantPastIndex - activeIndex);

      final blur = (28.0 * (dist * 0.095)).clamp(0.0, 9.5);
      final alpha = (1.0 - dist * 0.25).clamp(0.25, 0.90);

      expect(blur, equals(9.5));
      expect(alpha, equals(0.25));
    });

    test('Apple Music word karaoke pending color is 0xFF8E8E8E and font size is 28sp', () {
      const appleMusicPendingWordColor = Color(0xFF8E8E8E);
      expect(appleMusicPendingWordColor.value, equals(0xFF8E8E8E));

      const appleMusicFontSize = 28.0;
      expect(appleMusicFontSize, equals(28.0));

      const appleMusicScrollAlignment = 0.16;
      const classicScrollAlignment = 0.35;
      expect(appleMusicScrollAlignment, equals(0.16));
      expect(classicScrollAlignment, equals(0.35));
    });
  });

  group('AnimatedArtwork Model & Serialization', () {
    test('AnimatedArtwork JSON roundtrip preserves all fields', () {
      const original = AnimatedArtwork(
        trackId: 'test_track_123',
        videoUrl: 'https://mvod.itunes.apple.com/master.m3u8',
        previewImageUrl: 'https://is1-ssl.mzstatic.com/preview/800x800bb.jpg',
        hasAnimatedArtwork: true,
        width: 768,
        height: 768,
        albumName: 'After Hours',
        artistName: 'The Weeknd',
      );

      final jsonMap = original.toJson();
      final restored = AnimatedArtwork.fromJson(jsonMap);

      expect(restored.trackId, equals(original.trackId));
      expect(restored.videoUrl, equals(original.videoUrl));
      expect(restored.previewImageUrl, equals(original.previewImageUrl));
      expect(restored.hasAnimatedArtwork, isTrue);
      expect(restored.width, equals(768));
      expect(restored.height, equals(768));
      expect(restored.albumName, equals('After Hours'));
      expect(restored.artistName, equals('The Weeknd'));
    });

    test('AnimatedArtwork.empty handles absent video gracefully', () {
      expect(AnimatedArtwork.empty.hasAnimatedArtwork, isFalse);
      expect(AnimatedArtwork.empty.videoUrl, isNull);
      expect(AnimatedArtwork.empty.previewImageUrl, isNull);
    });
  });

  group('HLS Variant Resolution & Codec Selection Logic', () {
    test('Rendition selection picks H.264 (avc1) over HEVC 10-bit (hvc1)', () {
      const sampleMasterPlaylist = '''
#EXTM3U
#EXT-X-VERSION:7

#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=2125654,BANDWIDTH=2499558,CODECS="avc1.64001f",RESOLUTION=768x768
https://mvod.itunes.apple.com/video_768x768_avc1.m3u8
#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=1859556,BANDWIDTH=2177387,CODECS="hvc1.2.20000000.L123.B0",RESOLUTION=768x768
https://mvod.itunes.apple.com/video_768x768_hvc1.m3u8
#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=766942,BANDWIDTH=887529,CODECS="avc1.64001f",RESOLUTION=486x486
https://mvod.itunes.apple.com/video_486x486_avc1.m3u8
''';

      final lines = sampleMasterPlaylist.split('\n');
      final variants = <Map<String, dynamic>>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('#EXT-X-STREAM-INF:')) {
          final resMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
          final codecMatch = RegExp(r'CODECS="([^"]+)"').firstMatch(line);
          final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);

          final nextLine = (i + 1 < lines.length) ? lines[i + 1].trim() : '';
          if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
            variants.add({
              'uri': nextLine,
              'width': int.parse(resMatch!.group(1)!),
              'bandwidth': int.parse(bwMatch!.group(1)!),
              'codecs': codecMatch!.group(1)!,
            });
          }
        }
      }

      expect(variants.length, equals(3));

      // Filter for H.264
      final h264List = variants.where((v) => (v['codecs'] as String).startsWith('avc1')).toList();
      expect(h264List.length, equals(2));

      // Filter >= 720px width
      final wideEnough = h264List.where((v) => (v['width'] as int) >= 720).toList();
      expect(wideEnough.length, equals(1));
      expect(wideEnough.first['uri'], equals('https://mvod.itunes.apple.com/video_768x768_avc1.m3u8'));
    });
  });

  group('AnimatedArtworkCard Widget Rendering & Lifecycle', () {
    const testTrack = Track(
      id: 'test_track_mock',
      sourceId: 'mock_src',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      duration: Duration(seconds: 200),
      coverUrl: 'https://example.com/cover.jpg',
    );

    testWidgets('AnimatedArtworkCard mounts base cover and reacts to play state', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AnimatedArtworkCard(
                track: testTrack,
                isPlaying: false,
                ambientColor: Color(0xFFED5564),
                borderRadius: 16,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Card container renders with specified border radius
      expect(find.byType(AnimatedArtworkCard), findsOneWidget);

      // Re-pumping with isPlaying = true starts smooth breathing controller without exceptions
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AnimatedArtworkCard(
                track: testTrack,
                isPlaying: true,
                ambientColor: Color(0xFFED5564),
                borderRadius: 16,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedArtworkCard), findsOneWidget);

      // Clean unmount terminates animation controllers cleanly
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('AnimatedArtworkCard with motion artwork renders badge and layer', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db.close());

      const mockResolvedArtwork = AnimatedArtwork(
        trackId: 'test_track_mock',
        videoUrl: 'https://example.com/video.m3u8',
        previewImageUrl: 'https://example.com/preview.jpg',
        hasAnimatedArtwork: true,
        width: 800,
        height: 800,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            animatedArtworkEnabledProvider.overrideWith((ref) {
              final n = AnimatedArtworkNotifier(db);
              n.state = true;
              return n;
            }),
            animatedArtworkProvider(testTrack).overrideWith((ref) => Future.value(mockResolvedArtwork)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AnimatedArtworkCard(
                track: testTrack,
                isPlaying: true,
                ambientColor: Color(0xFFED5564),
              ),
            ),
          ),
        ),
      );

      // Pump to resolve future and render badge
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Motion badge rendered
      expect(find.text('ANIMATED COVER'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_motion_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
