import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:drift/native.dart';
import 'package:rxdart/rxdart.dart';

import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/data/player/softify_audio_player.dart';
import 'package:softify/data/recommendations/drift_taste_profile_repository.dart';
import 'package:softify/data/repositories/drift_event_logger.dart';
import 'package:softify/data/repositories/drift_library_repository.dart';
import 'package:softify/domain/entities/audio_quality_preset.dart';
import 'package:softify/domain/entities/download_item.dart';
import 'package:softify/domain/entities/stream_info.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_download_repository.dart';
import 'package:softify/domain/ports/i_stream_resolver.dart';

class SlowMockStreamResolver implements IStreamResolver {
  int resolveCallCount = 0;

  @override
  Future<StreamInfo> resolve(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
    bool forceFresh = false,
  }) async {
    resolveCallCount++;
    // Simulate realistic async network stream resolution latency
    await Future.delayed(const Duration(milliseconds: 50));
    return StreamInfo(
      url: Uri.parse('https://stream.softify.test/${track.id}.m4a'),
      container: 'm4a',
      bitrate: 320000,
      codec: 'aac',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      providerName: 'mock_resolver',
    );
  }

  @override
  Future<void> prefetch(Track track, {AudioQualityPreset quality = AudioQualityPreset.standard}) async {}
}

class TestMockPlayer implements ISoftifyAudioPlayer {
  String? activeUrl;
  bool isPlaying = false;
  int setUrlCallCount = 0;
  int playCallCount = 0;

  final BehaviorSubject<PlayerState> _playerStateSubject =
      BehaviorSubject<PlayerState>.seeded(PlayerState(false, ProcessingState.idle));
  final PublishSubject<PlaybackEvent> _playbackEventSubject = PublishSubject<PlaybackEvent>();
  final BehaviorSubject<Duration> _positionSubject = BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration> _bufferedPositionSubject = BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration?> _durationSubject = BehaviorSubject<Duration?>.seeded(null);
  final BehaviorSubject<double> _volumeSubject = BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<double> _speedSubject = BehaviorSubject<double>.seeded(1.0);

  @override
  bool get playing => isPlaying;

  @override
  ProcessingState get processingState => ProcessingState.ready;

  @override
  Duration get position => Duration.zero;

  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  Duration? get duration => _durationSubject.value;

  @override
  double get speed => 1.0;

  @override
  Stream<double> get speedStream => _speedSubject.stream;

  @override
  double get volume => 1.0;

  @override
  Stream<double> get volumeStream => _volumeSubject.stream;

  @override
  bool get hasPreloadedNext => false;

  @override
  String? get preloadedSource => null;

  @override
  Future<Duration?> setUrl(String url, {Map<String, String>? headers, Duration? initialPosition}) async {
    setUrlCallCount++;
    await Future.delayed(const Duration(milliseconds: 10));
    activeUrl = url;
    return const Duration(minutes: 3);
  }

  @override
  Future<Duration?> setFilePath(String path, {Duration? initialPosition}) async {
    activeUrl = path;
    return const Duration(minutes: 3);
  }

  @override
  Future<void> play() async {
    playCallCount++;
    isPlaying = true;
    _playerStateSubject.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _playerStateSubject.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    activeUrl = null;
    _playerStateSubject.add(PlayerState(false, ProcessingState.idle));
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  void clearPreloadedNext() {}

  @override
  Future<void> playPreloadedNext({Duration crossfade = Duration.zero}) async {}

  @override
  Future<void> preloadNextFilePath(String path) async {}

  @override
  Future<void> preloadNextUrl(String url, {Map<String, String>? headers}) async {}

  @override
  Future<void> setBassBoost(double boost) async {}

  @override
  Future<void> setEqualizerBands(List<double> gains) async {}

  @override
  Future<void> setEqualizerEnabled(bool enabled) async {}

  @override
  Future<void> setLoudnessEnhancerGain(double gain) async {}

  @override
  Future<List<double>> getBandFrequencies() async => [];

  @override
  Future<void> dispose() async {
    await _playerStateSubject.close();
    await _playbackEventSubject.close();
    await _positionSubject.close();
    await _bufferedPositionSubject.close();
    await _durationSubject.close();
    await _volumeSubject.close();
    await _speedSubject.close();
  }

  @override
  Stream<Duration> get bufferedPositionStream => _bufferedPositionSubject.stream;

  @override
  Stream<Duration?> get durationStream => _durationSubject.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _playbackEventSubject.stream;

  @override
  Stream<PlayerState> get playerStateStream => _playerStateSubject.stream;

  @override
  Stream<Duration> get positionStream => _positionSubject.stream;
}

class FakeDownloadRepo implements IDownloadRepository {
  @override
  Future<void> queueDownload(Track track, {AudioQualityPreset quality = AudioQualityPreset.standard}) async {}

  @override
  Future<void> pauseDownload(String trackId) async {}

  @override
  Future<void> resumeDownload(String trackId) async {}

  @override
  Future<void> cancelDownload(String trackId) async {}

  @override
  Future<void> deleteDownload(String trackId) async {}

  @override
  Stream<List<DownloadItem>> watchDownloads() => const Stream.empty();

  @override
  Stream<DownloadItem?> watchDownload(String trackId) => const Stream.empty();

  @override
  Future<DownloadItem?> getDownload(String trackId) async => null;

  @override
  Future<bool> isDownloaded(String trackId) async => false;

  @override
  Future<String?> getDownloadedFilePath(String trackId) async => null;

  @override
  Future<({int verified, int pruned})> verifyAndRepairDownloads() async => (verified: 0, pruned: 0);

  @override
  Future<void> dispose() async {}
}

void main() {
  group('Telemetry & Taste Profile Hard Isolation', () {
    late AppDatabase db;
    late DriftTasteProfileRepository tasteRepo;
    late DriftEventLogger eventLogger;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      tasteRepo = DriftTasteProfileRepository(db);
      eventLogger = DriftEventLogger(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Taste profile update rejects tracks where isYoutube == true or startsWith yt_/podcast_', () async {
      const ytTrack1 = Track(
        id: 'yt_abc123',
        sourceId: 'abc123',
        title: 'Video Stream',
        artist: 'YT Artist',
        duration: Duration(minutes: 4),
      );
      const podcastTrack = Track(
        id: 'podcast_ep_456',
        sourceId: 'podcast_456',
        title: 'Tech Podcast Ep 1',
        artist: 'Podcast Host',
        duration: Duration(minutes: 45),
      );

      await tasteRepo.updateFromPlay(track: ytTrack1, isStream: true, isEarlySkip: false, isSave: true);
      await tasteRepo.updateFromPlay(track: podcastTrack, isStream: true, isEarlySkip: false, isSave: true);

      final profiles = await db.select(db.tasteProfiles).get();
      expect(profiles, isEmpty, reason: 'YouTube and podcast plays must NEVER create or modify taste profiles');
    });

    test('Event logger logPlay rejects source: youtube_link, source: podcast, and yt_/podcast_ IDs', () async {
      eventLogger.logPlay(
        trackId: 'yt_vid_999',
        source: 'youtube_link',
        listenedMs: 60000,
        durationMs: 120000,
        saved: true,
        addedToPlaylist: false,
        rankerVersion: 'v2',
      );
      eventLogger.logPlay(
        trackId: 'podcast_ep_1',
        source: 'podcast',
        listenedMs: 1800000,
        durationMs: 1800000,
        saved: true,
        addedToPlaylist: false,
        rankerVersion: 'v2',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      final events = await db.select(db.playEvents).get();
      expect(events, isEmpty, reason: 'YouTube and podcast play events must NEVER be logged into play_events');
    });
  });

  group('Rapid Track Switching Concurrency & Debounce', () {
    late AppDatabase db;
    late DriftLibraryRepository libRepo;
    late SlowMockStreamResolver streamResolver;
    late TestMockPlayer player;
    late SoftifyAudioHandler handler;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      libRepo = DriftLibraryRepository(db);
      streamResolver = SlowMockStreamResolver();
      player = TestMockPlayer();

      handler = SoftifyAudioHandler(
        player: player,
        streamResolver: streamResolver,
        libraryRepo: libRepo,
        downloadRepo: FakeDownloadRepo(),
        autoRestoreState: false,
        enableAudioSession: false,
      );
    });

    tearDown(() async {
      await handler.stop();
      await db.close();
    });

    test('Rapidly skipping 10 tracks in 100ms does NOT stall, deadlocks 0 times, and plays final track', () async {
      final queue = List.generate(
        15,
        (i) => Track(
          id: 'track_$i',
          sourceId: 'src_$i',
          title: 'Track Title $i',
          artist: 'Artist $i',
          duration: const Duration(minutes: 3),
        ),
      );

      await handler.setQueue(queue, startIndex: 0);

      // Rapidly skip 10 times in 100ms (10ms intervals)
      for (int i = 0; i < 10; i++) {
        handler.skipToNext();
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // Wait for the final active request to resolve and settle
      await Future.delayed(const Duration(milliseconds: 300));

      // Active track should be track_10
      expect(handler.currentTrack?.id, equals('track_10'));
      // Active player URL must match the 10th track
      expect(player.activeUrl, contains('track_10'));
      expect(player.isPlaying, isTrue);
    });
  });
}
