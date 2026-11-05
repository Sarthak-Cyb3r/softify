import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/audio_quality_preset.dart';
import 'package:softify/domain/entities/stream_info.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_download_repository.dart';
import 'package:softify/domain/ports/i_library_repository.dart';
import 'package:softify/domain/ports/i_stream_resolver.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/providers/settings_providers.dart';

class MockStreamResolver implements IStreamResolver {
  AudioQualityPreset? lastResolvedQuality;
  int resolveCount = 0;

  @override
  Future<StreamInfo> resolve(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
    bool forceFresh = false,
  }) async {
    lastResolvedQuality = quality;
    resolveCount++;
    final bitrate = quality == AudioQualityPreset.high
        ? 320000
        : (quality == AudioQualityPreset.standard ? 160000 : 96000);
    return StreamInfo(
      url: Uri.parse('https://example.com/audio_${quality.name}.m4a'),
      container: 'm4a',
      bitrate: bitrate,
      codec: 'aac',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      providerName: 'mock_resolver',
    );
  }

  @override
  Future<void> prefetch(Track track, {AudioQualityPreset quality = AudioQualityPreset.standard}) async {
    lastResolvedQuality = quality;
  }
}

class MockLibraryRepository implements ILibraryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDownloadRepository implements IDownloadRepository {
  @override
  Future<String?> getDownloadedFilePath(String trackId) async => null;

  @override
  Future<bool> isDownloaded(String trackId) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Audio Quality Changer Integration Tests', () {
    late AppDatabase db;
    late MockStreamResolver streamResolver;
    late SoftifyAudioHandler audioHandler;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      streamResolver = MockStreamResolver();
      audioHandler = SoftifyAudioHandler(
        streamResolver: streamResolver,
        libraryRepo: MockLibraryRepository(),
        downloadRepo: MockDownloadRepository(),
        qualityPreset: AudioQualityPreset.standard,
        enableAudioSession: false,
        autoRestoreState: false,
      );
    });

    tearDown(() async {
      await audioHandler.stop();
      await db.close();
    });

    test('SoftifyAudioHandler initializes with specified quality and dynamically updates', () async {
      expect(audioHandler.qualityPreset, equals(AudioQualityPreset.standard));

      await audioHandler.setQualityPreset(AudioQualityPreset.high, reloadCurrent: false);
      expect(audioHandler.qualityPreset, equals(AudioQualityPreset.high));

      await audioHandler.setQualityPreset(AudioQualityPreset.low, reloadCurrent: false);
      expect(audioHandler.qualityPreset, equals(AudioQualityPreset.low));
    });

    test('AudioQualityNotifier propagates quality changes to database and AudioHandler', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          audioHandlerProvider.overrideWithValue(audioHandler),
        ],
      );

      final notifier = container.read(audioQualityPresetProvider.notifier);
      expect(notifier.state, equals(AudioQualityPreset.standard));
      expect(audioHandler.qualityPreset, equals(AudioQualityPreset.standard));

      // 1. Switch to High Quality
      await notifier.setQuality(AudioQualityPreset.high);
      expect(notifier.state, equals(AudioQualityPreset.high));
      expect(audioHandler.qualityPreset, equals(AudioQualityPreset.high));

      // Verify persistence in DB
      final rowHigh = await (db.select(db.settings)
            ..where((t) => t.key.equals('audio_quality')))
          .getSingle();
      expect(rowHigh.value, equals('high'));

      // 2. Switch to Data Saver (Low)
      await notifier.setQuality(AudioQualityPreset.low);
      expect(notifier.state, equals(AudioQualityPreset.low));
      expect(audioHandler.qualityPreset, equals(AudioQualityPreset.low));

      final rowLow = await (db.select(db.settings)
            ..where((t) => t.key.equals('audio_quality')))
          .getSingle();
      expect(rowLow.value, equals('low'));

      container.dispose();
    });

    test('Updating quality re-resolves stream using the new quality preset', () async {
      const track = Track(
        id: 'test-track-1',
        sourceId: 'src-1',
        title: 'Test Song',
        artist: 'Test Artist',
        duration: Duration(seconds: 180),
      );

      // Play track with initial Standard quality
      await audioHandler.playTrack(track);
      expect(streamResolver.lastResolvedQuality, equals(AudioQualityPreset.standard));
      expect(audioHandler.currentStreamInfo?.bitrate, equals(160000));

      // Change quality to High with reloadCurrent: true
      await audioHandler.setQualityPreset(AudioQualityPreset.high, reloadCurrent: true);
      expect(audioHandler.qualityPreset, equals(AudioQualityPreset.high));
      expect(streamResolver.lastResolvedQuality, equals(AudioQualityPreset.high));
      expect(audioHandler.currentStreamInfo?.bitrate, equals(320000));

      // Change quality to Low with reloadCurrent: true
      await audioHandler.setQualityPreset(AudioQualityPreset.low, reloadCurrent: true);
      expect(audioHandler.qualityPreset, equals(AudioQualityPreset.low));
      expect(streamResolver.lastResolvedQuality, equals(AudioQualityPreset.low));
      expect(audioHandler.currentStreamInfo?.bitrate, equals(96000));
    });
  });
}
