import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/resolvers/hybrid_stream_resolver.dart';
import 'package:softify/data/resolvers/saavn_stream_resolver.dart';
import 'package:softify/data/resolvers/youtube_stream_resolver.dart';
import 'package:softify/domain/entities/audio_quality_preset.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  HttpOverrides.global = null;

  group('JioSaavn Studio Stream Resolver', () {
    late SaavnStreamResolver saavnResolver;

    setUp(() {
      saavnResolver = SaavnStreamResolver();
    });

    test('Resolves "Pink Lips" to 320kbps pure studio audio without movie dialogue', () async {
      const track = Track(
        id: 'test_pink_lips',
        sourceId: 'itunes_907310557',
        title: 'Pink Lips',
        artist: 'Khushboo Grewal, Meet Bros Anjjan',
        album: 'Hate Story 2',
        duration: Duration(seconds: 255),
      );

      final streamInfo = await saavnResolver.resolve(
        track,
        quality: AudioQualityPreset.standard,
      );

      expect(streamInfo.container, 'm4a');
      expect(streamInfo.codec, 'aac');
      expect(streamInfo.bitrate, 320000);
      expect(streamInfo.url.toString(), contains('aac.saavncdn.com'));
      expect(streamInfo.url.toString(), contains('_320.mp4'));
      expect(streamInfo.providerName, contains('jiosaavn_studio (320kbps)'));
      expect(streamInfo.isExpired, isFalse);
    });

    test('Direct Saavn source ID resolution via pid', () async {
      const track = Track(
        id: 'test_direct_saavn',
        sourceId: 'saavn_mcbYa1Hg',
        title: 'Pink Lips',
        artist: 'Meet Bros Anjjan, Khushboo Grewal',
        album: 'Hate Story 2',
        duration: Duration(seconds: 255),
      );

      final streamInfo = await saavnResolver.resolve(
        track,
        quality: AudioQualityPreset.low,
      );

      expect(streamInfo.bitrate, 96000);
      expect(streamInfo.url.toString(), contains('_96.mp4'));
    });
  });

  group('Hybrid Stream Resolver', () {
    late HybridStreamResolver hybridResolver;

    setUp(() {
      hybridResolver = HybridStreamResolver();
    });

    tearDown(() {
      hybridResolver.close();
    });

    test('Prefers Saavn studio audio master over YouTube video for standard tracks', () async {
      const track = Track(
        id: 'test_sheila',
        sourceId: 'itunes_402123456',
        title: 'Sheila Ki Jawani',
        artist: 'Sunidhi Chauhan, Vishal Dadlani',
        duration: Duration(seconds: 281),
      );

      final stream = await hybridResolver.resolve(track);
      expect(stream.container, 'm4a');
      expect(stream.providerName, contains('jiosaavn_studio'));
      expect(stream.url.toString(), contains('aac.saavncdn.com'));
    });
  });

  group('YouTube Stream Resolver Logic Verification', () {
    test('YoutubeStreamResolver instance initializes cleanly', () {
      final ytResolver = YoutubeStreamResolver();
      expect(ytResolver, isNotNull);
      ytResolver.close();
    });
  });
}
