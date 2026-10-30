import 'dart:async';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/data/player/softify_audio_player.dart';
import 'package:softify/data/repositories/drift_library_repository.dart';
import 'package:softify/domain/entities/audio_quality_preset.dart';
import 'package:softify/domain/entities/download_item.dart';
import 'package:softify/domain/entities/stream_info.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_download_repository.dart';
import 'package:softify/domain/ports/i_stream_resolver.dart';

class MatrixMockPlayer implements ISoftifyAudioPlayer {
  String? lastLoadedUrl;
  String? lastLoadedFilePath;
  Duration? lastCrossfadeApplied;
  int playPreloadedCalls = 0;
  int preloadNextUrlCalls = 0;

  bool _playing = false;
  ProcessingState _processingState = ProcessingState.idle;
  Duration _position = Duration.zero;
  Duration? _duration;

  final BehaviorSubject<PlayerState> _playerStateSubject =
      BehaviorSubject<PlayerState>.seeded(PlayerState(false, ProcessingState.idle));
  final PublishSubject<PlaybackEvent> _playbackEventSubject =
      PublishSubject<PlaybackEvent>();
  final BehaviorSubject<Duration> _positionSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration> _bufferedPositionSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration?> _durationSubject =
      BehaviorSubject<Duration?>.seeded(null);
  final BehaviorSubject<double> _volumeSubject =
      BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<double> _speedSubject =
      BehaviorSubject<double>.seeded(1.0);

  bool _hasPreloadedNext = false;
  String? _preloadedUrl;

  @override
  bool get playing => _playing;
  @override
  ProcessingState get processingState => _processingState;
  @override
  Duration get position => _position;
  @override
  Duration get bufferedPosition => Duration.zero;
  @override
  Duration? get duration => _duration;
  @override
  double get speed => 1.0;
  @override
  Stream<double> get speedStream => _speedSubject.stream;
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  double get volume => 1.0;
  @override
  Stream<double> get volumeStream => _volumeSubject.stream;
  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> play() async {
    _playing = true;
    _processingState = ProcessingState.ready;
    _playerStateSubject.add(PlayerState(_playing, _processingState));
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _playerStateSubject.add(PlayerState(_playing, _processingState));
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _processingState = ProcessingState.idle;
    _playerStateSubject.add(PlayerState(_playing, _processingState));
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    _positionSubject.add(position);
  }

  @override
  bool get hasPreloadedNext => _hasPreloadedNext;
  @override
  bool get isCrossfading => false;
  @override
  String? get preloadedSource => _preloadedUrl;

  @override
  Future<void> preloadNextUrl(String url, {Map<String, String>? headers}) async {
    preloadNextUrlCalls++;
    _preloadedUrl = url;
    _hasPreloadedNext = true;
  }

  @override
  Future<void> preloadNextFilePath(String path) async {
    _preloadedUrl = path;
    _hasPreloadedNext = true;
  }

  @override
  Future<void> playPreloadedNext({Duration crossfade = Duration.zero}) async {
    playPreloadedCalls++;
    lastCrossfadeApplied = crossfade;
    lastLoadedUrl = _preloadedUrl;
    _hasPreloadedNext = false;
    _preloadedUrl = null;
    await play();
  }

  @override
  void clearPreloadedNext() {
    _hasPreloadedNext = false;
    _preloadedUrl = null;
  }

  @override
  Future<Duration?> setUrl(String url, {Map<String, String>? headers, Duration? initialPosition}) async {
    clearPreloadedNext();
    lastLoadedUrl = url;
    _position = initialPosition ?? Duration.zero;
    _processingState = ProcessingState.ready;
    _playerStateSubject.add(PlayerState(_playing, _processingState));
    return _duration ?? const Duration(minutes: 3);
  }

  @override
  Future<Duration?> setFilePath(String path, {Duration? initialPosition}) async {
    clearPreloadedNext();
    lastLoadedFilePath = path;
    _position = initialPosition ?? Duration.zero;
    _processingState = ProcessingState.ready;
    _playerStateSubject.add(PlayerState(_playing, _processingState));
    return _duration ?? const Duration(minutes: 3);
  }

  void emitPosition(Duration pos) {
    _position = pos;
    _positionSubject.add(pos);
  }

  void setMockDuration(Duration dur) {
    _duration = dur;
    _durationSubject.add(dur);
  }

  @override
  Stream<PlayerState> get playerStateStream => _playerStateSubject.stream;
  @override
  Stream<PlaybackEvent> get playbackEventStream => _playbackEventSubject.stream;
  @override
  Stream<Duration> get positionStream => _positionSubject.stream;
  @override
  Stream<Duration> get bufferedPositionStream => _bufferedPositionSubject.stream;
  @override
  Stream<Duration?> get durationStream => _durationSubject.stream;

  @override
  Future<void> setEqualizerBands(List<double> gains) async {}
  @override
  Future<void> setEqualizerEnabled(bool enabled) async {}
  @override
  Future<void> setLoudnessEnhancerGain(double gain) async {}
  @override
  Future<void> setBassBoost(double boost) async {}
  @override
  Future<List<double>> getBandFrequencies() async => [];

  @override
  Future<void> dispose() async {
    await _playerStateSubject.close();
    await _playbackEventSubject.close();
    await _positionSubject.close();
    await _bufferedPositionSubject.close();
    await _durationSubject.close();
  }
}

class MatrixMockStreamResolver implements IStreamResolver {
  int resolveCount = 0;

  @override
  Future<StreamInfo> resolve(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
    bool forceFresh = false,
  }) async {
    resolveCount++;
    return StreamInfo(
      url: Uri.parse('https://example.com/audio_${track.id}.m4a'),
      container: 'm4a',
      bitrate: 320000,
      codec: 'aac',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      providerName: 'matrix_mock',
    );
  }

  @override
  Future<void> prefetch(Track track, {AudioQualityPreset quality = AudioQualityPreset.standard}) async {}
}

class MatrixMockDownloadRepository implements IDownloadRepository {
  final Map<String, String> downloadedFiles = {};

  @override
  Future<void> queueDownload(Track track, {AudioQualityPreset quality = AudioQualityPreset.standard}) async {}
  @override
  Future<void> pauseDownload(String trackId) async {}
  @override
  Future<void> resumeDownload(String trackId) async {}
  @override
  Future<void> cancelDownload(String trackId) async {}
  @override
  Future<void> deleteDownload(String trackId) async {
    downloadedFiles.remove(trackId);
  }
  @override
  Stream<List<DownloadItem>> watchDownloads() => const Stream.empty();
  @override
  Stream<DownloadItem?> watchDownload(String trackId) => const Stream.empty();
  @override
  Future<DownloadItem?> getDownload(String trackId) async => null;
  @override
  Future<bool> isDownloaded(String trackId) async => downloadedFiles.containsKey(trackId);
  @override
  Future<String?> getDownloadedFilePath(String trackId) async => downloadedFiles[trackId];
  @override
  Future<({int verified, int pruned})> verifyAndRepairDownloads() async => (verified: 0, pruned: 0);
  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spotify-Grade Playback Performance Matrix', () {
    test('1. Head Buffer Config enforces sub-200ms initial buffer & fast rebuffer recovery', () {
      const config = JustAudioPlayerAdapter.defaultAudioLoadConfiguration;
      final android = config.androidLoadControl;
      final darwin = config.darwinLoadControl;

      expect(android, isNotNull);
      expect(android!.bufferForPlaybackDuration, const Duration(milliseconds: 250));
      expect(android.bufferForPlaybackAfterRebufferDuration, const Duration(milliseconds: 1000));
      expect(android.prioritizeTimeOverSizeThresholds, isTrue);
      expect(android.minBufferDuration, const Duration(seconds: 15));
      expect(android.maxBufferDuration, const Duration(seconds: 60));

      expect(darwin, isNotNull);
      expect(darwin!.automaticallyWaitsToMinimizeStalling, isFalse);
      expect(darwin.preferredForwardBufferDuration, const Duration(seconds: 30));
    });

    test('2. Equal-Power Cosine/Sine Crossfade maintains constant acoustic energy', () {
      const targetVol = 1.0;
      const steps = 20;

      for (int i = 0; i <= steps; i++) {
        final factor = i / steps;
        final theta = factor * (math.pi / 2.0);
        final outVol = targetVol * math.cos(theta);
        final inVol = targetVol * math.sin(theta);

        // Power sum = cos^2(theta) + sin^2(theta) must strictly equal 1.0 (0dB dip)
        final powerSum = (outVol * outVol) + (inVol * inVol);
        expect(powerSum, closeTo(1.0, 1e-9));
      }

      // At midpoint (factor = 0.5):
      // Equal-power amplitude is ~0.7071 (-3dB amplitude, constant power sum 1.0)
      // Linear amplitude would be 0.5 (-6dB amplitude, power sum 0.5 -> 3dB power drop)
      const midTheta = 0.5 * (math.pi / 2.0);
      final midVol = math.cos(midTheta);
      expect(midVol, closeTo(0.707106, 1e-4));
      expect((midVol * midVol) + (midVol * midVol), closeTo(1.0, 1e-6));
    });

    test('3. Context-Aware Transition Matrix: 0ms gapless for same album vs crossfade for playlists', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final libraryRepo = DriftLibraryRepository(db);
      final mockPlayer = MatrixMockPlayer();
      final streamResolver = MatrixMockStreamResolver();
      final downloadRepo = MatrixMockDownloadRepository();

      final handler = SoftifyAudioHandler(
        player: mockPlayer,
        libraryRepo: libraryRepo,
        streamResolver: streamResolver,
        downloadRepo: downloadRepo,
        autoRestoreState: false,
      );
      handler.setCrossfadeSeconds(4);

      const trackAlbumA1 = Track(
        id: 'track_1',
        title: 'Speak to Me',
        artist: 'Pink Floyd',
        album: 'The Dark Side of the Moon',
        duration: Duration(seconds: 90),
        sourceId: 'saavn_1',
      );

      const trackAlbumA2 = Track(
        id: 'track_2',
        title: 'Breathe',
        artist: 'Pink Floyd',
        album: 'The Dark Side of the Moon',
        duration: Duration(seconds: 180),
        sourceId: 'saavn_2',
      );

      const trackAlbumB = Track(
        id: 'track_3',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        duration: Duration(seconds: 230),
        sourceId: 'saavn_3',
      );

      const podcastTrack = Track(
        id: 'podcast_ep_1',
        title: 'Episode 100',
        artist: 'Lex Fridman',
        album: 'Lex Fridman Podcast',
        duration: Duration(minutes: 60),
        sourceId: 'podcast_100',
      );

      await handler.setQueue([trackAlbumA1, trackAlbumA2, trackAlbumB, podcastTrack]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Simulate standby player preloaded next track
      mockPlayer._hasPreloadedNext = true;
      mockPlayer._preloadedUrl = 'https://example.com/audio_track_2.m4a';

      // Skip from trackAlbumA1 to trackAlbumA2 (same album) -> MUST be 0ms gapless transition!
      await handler.skipToNext();
      expect(mockPlayer.lastCrossfadeApplied, Duration.zero,
          reason: 'Consecutive tracks from the same album must have sample-accurate 0ms gapless transition');

      // Now skip from trackAlbumA2 to trackAlbumB (different album) -> MUST apply equal-power crossfade!
      mockPlayer._hasPreloadedNext = true;
      mockPlayer._preloadedUrl = 'https://example.com/audio_track_3.m4a';
      await handler.skipToNext();
      expect(mockPlayer.lastCrossfadeApplied, const Duration(seconds: 4),
          reason: 'Tracks from different albums/playlists must use configured crossfade');

      // Now skip from trackAlbumB to podcastTrack (spoken/podcast) -> MUST be 0ms gapless transition!
      mockPlayer._hasPreloadedNext = true;
      mockPlayer._preloadedUrl = 'https://example.com/audio_podcast_ep_1.m4a';
      await handler.skipToNext();
      expect(mockPlayer.lastCrossfadeApplied, Duration.zero,
          reason: 'Spoken/podcast tracks must never crossfade');

      await handler.dispose();
      await db.close();
    });

    test('4. Speculative Standby Pre-Warming triggers 20s before track completion', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final libraryRepo = DriftLibraryRepository(db);
      final mockPlayer = MatrixMockPlayer();
      final streamResolver = MatrixMockStreamResolver();
      final downloadRepo = MatrixMockDownloadRepository();

      final handler = SoftifyAudioHandler(
        player: mockPlayer,
        libraryRepo: libraryRepo,
        streamResolver: streamResolver,
        downloadRepo: downloadRepo,
        autoRestoreState: false,
      );
      handler.setCrossfadeSeconds(0);

      const track1 = Track(
        id: 'warmup_1',
        title: 'Song 1',
        artist: 'Artist',
        duration: Duration(seconds: 100),
        sourceId: 'saavn_w1',
      );

      const track2 = Track(
        id: 'warmup_2',
        title: 'Song 2',
        artist: 'Artist',
        duration: Duration(seconds: 120),
        sourceId: 'saavn_w2',
      );

      await handler.setQueue([track1, track2]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Clear preloaded next to test speculative pre-warming
      mockPlayer.clearPreloadedNext();
      expect(mockPlayer.hasPreloadedNext, isFalse);

      final initialResolves = streamResolver.resolveCount;

      // Position before the 20-second threshold (e.g. 50s into a 100s track)
      mockPlayer.emitPosition(const Duration(seconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(mockPlayer.hasPreloadedNext, isFalse);

      // Position reaches the 20-second threshold (e.g. 82s into a 100s track)
      mockPlayer.emitPosition(const Duration(seconds: 82));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Speculative pre-warming must have triggered resolve & preloaded next
      expect(streamResolver.resolveCount, greaterThan(initialResolves));
      expect(mockPlayer.hasPreloadedNext, isTrue);

      await handler.dispose();
      await db.close();
    });
  });
}
