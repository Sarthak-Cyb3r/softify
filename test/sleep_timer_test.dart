import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/data/player/softify_audio_player.dart';
import 'package:softify/data/repositories/drift_library_repository.dart';
import 'package:softify/domain/entities/audio_quality_preset.dart';
import 'package:softify/domain/entities/download_item.dart';
import 'package:softify/domain/entities/stream_info.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_download_repository.dart';
import 'package:softify/domain/ports/i_stream_resolver.dart';

class FakeSoftifyAudioPlayer implements ISoftifyAudioPlayer {
  String? lastLoadedUrl;
  String? lastLoadedFilePath;
  bool _playing = false;
  ProcessingState _processingState = ProcessingState.idle;
  Duration _position = Duration.zero;

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
  double _volume = 1.0;
  final BehaviorSubject<double> _volumeSubject =
      BehaviorSubject<double>.seeded(1.0);
  double _speed = 1.0;
  final BehaviorSubject<double> _speedSubject =
      BehaviorSubject<double>.seeded(1.0);

  @override
  bool get playing => _playing;

  @override
  ProcessingState get processingState => _processingState;

  @override
  Duration get position => _position;

  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  Duration? get duration => _durationSubject.value;

  @override
  double get speed => _speed;

  @override
  Stream<double> get speedStream => _speedSubject.stream;

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    _speedSubject.add(speed);
  }

  @override
  double get volume => _volume;

  @override
  Stream<double> get volumeStream => _volumeSubject.stream;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    _volumeSubject.add(volume);
  }

  @override
  Future<void> setEqualizerEnabled(bool enabled) async {}

  @override
  Future<void> setEqualizerBands(List<double> gains) async {}

  @override
  Future<void> setLoudnessEnhancerGain(double gain) async {}

  @override
  Future<void> setBassBoost(double boost) async {}

  @override
  Future<List<double>> getBandFrequencies() async =>
      const [60.0, 230.0, 910.0, 3600.0, 14000.0];

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
  Future<void> play() async {
    _playing = true;
    _processingState = ProcessingState.ready;
    _playerStateSubject.add(PlayerState(_playing, _processingState));
    _playbackEventSubject.add(PlaybackEvent(
      processingState: _processingState,
      updatePosition: _position,
    ));
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _playerStateSubject.add(PlayerState(_playing, _processingState));
    _playbackEventSubject.add(PlaybackEvent(
      processingState: _processingState,
      updatePosition: _position,
    ));
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _processingState = ProcessingState.idle;
    _playerStateSubject.add(PlayerState(_playing, _processingState));
    _playbackEventSubject.add(PlaybackEvent(
      processingState: _processingState,
      updatePosition: _position,
    ));
  }

  @override
  Future<void> seek(Duration pos) async {
    _position = pos;
    _positionSubject.add(pos);
  }

  @override
  bool get hasPreloadedNext => false;

  @override
  bool get isCrossfading => false;

  @override
  String? get preloadedSource => null;

  @override
  Future<void> preloadNextUrl(String url, {Map<String, String>? headers}) async {}

  @override
  Future<void> preloadNextFilePath(String path) async {}

  @override
  Future<void> playPreloadedNext({Duration crossfade = Duration.zero}) async {}

  @override
  void clearPreloadedNext() {}

  @override
  Future<Duration?> setUrl(String url, {Map<String, String>? headers, Duration? initialPosition}) async {
    lastLoadedUrl = url;
    _position = initialPosition ?? Duration.zero;
    _processingState = ProcessingState.ready;
    _playerStateSubject.add(PlayerState(_playing, _processingState));
    return const Duration(minutes: 3);
  }

  @override
  Future<Duration?> setFilePath(String path, {Duration? initialPosition}) async {
    lastLoadedFilePath = path;
    _position = initialPosition ?? Duration.zero;
    _processingState = ProcessingState.ready;
    _playerStateSubject.add(PlayerState(_playing, _processingState));
    return const Duration(minutes: 3);
  }

  void simulateTrackCompletion() {
    _processingState = ProcessingState.completed;
    _playerStateSubject.add(PlayerState(_playing, _processingState));
  }

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
}

class MockStreamResolver implements IStreamResolver {
  @override
  Future<StreamInfo> resolve(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
    bool forceFresh = false,
  }) async {
    return StreamInfo(
      url: Uri.parse('https://audio.example.com/${track.id}.m4a'),
      container: 'm4a',
      bitrate: 320000,
      codec: 'mp4a.40.2',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      providerName: 'mock',
    );
  }

  @override
  Future<void> prefetch(Track track, {AudioQualityPreset quality = AudioQualityPreset.standard}) async {}
}

class MockDownloadRepository implements IDownloadRepository {
  @override
  Future<String?> getDownloadedFilePath(String trackId) async => null;
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
  Stream<List<DownloadItem>> watchDownloads() => Stream.value([]);
  @override
  Stream<DownloadItem?> watchDownload(String trackId) => Stream.value(null);
  @override
  Future<DownloadItem?> getDownload(String trackId) async => null;
  @override
  Future<bool> isDownloaded(String trackId) async => false;
  @override
  Future<({int verified, int pruned})> verifyAndRepairDownloads() async => (verified: 0, pruned: 0);
  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftLibraryRepository libraryRepo;
  late FakeSoftifyAudioPlayer fakePlayer;
  late MockStreamResolver mockResolver;
  late MockDownloadRepository mockDownloads;
  late SoftifyAudioHandler handler;

  const track1 = Track(
    id: 'track_1',
    sourceId: 'src_1',
    title: 'Track One',
    artist: 'Artist A',
    duration: Duration(minutes: 3),
  );

  const track2 = Track(
    id: 'track_2',
    sourceId: 'src_2',
    title: 'Track Two',
    artist: 'Artist B',
    duration: Duration(minutes: 4),
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    libraryRepo = DriftLibraryRepository(db);
    fakePlayer = FakeSoftifyAudioPlayer();
    mockResolver = MockStreamResolver();
    mockDownloads = MockDownloadRepository();

    handler = SoftifyAudioHandler(
      player: fakePlayer,
      streamResolver: mockResolver,
      libraryRepo: libraryRepo,
      downloadRepo: mockDownloads,
      enableAudioSession: false,
      autoRestoreState: false,
    );
  });

  tearDown(() async {
    await handler.dispose();
    await db.close();
  });

  group('Sleep Timer: Robustness & Worst-Case Scenarios', () {
    test('1. Timer countdown expires and pauses playback cleanly', () async {
      await handler.playTrack(track1);
      expect(fakePlayer.playing, isTrue);

      handler.setSleepTimer(const Duration(milliseconds: 100));
      expect(handler.isSleepTimerActive, isTrue);
      expect(handler.sleepTimerRemaining, isNotNull);

      // Await timer trigger
      await Future.delayed(const Duration(milliseconds: 180));

      expect(fakePlayer.playing, isFalse);
      expect(handler.isSleepTimerActive, isFalse);
      expect(handler.sleepTimerRemaining, isNull);
    });

    test('2. Timer expires while audio is ALREADY paused without crashing or resuming', () async {
      await handler.playTrack(track1);
      await handler.pause();
      expect(fakePlayer.playing, isFalse);

      handler.setSleepTimer(const Duration(milliseconds: 80));
      expect(handler.isSleepTimerActive, isTrue);

      await Future.delayed(const Duration(milliseconds: 150));

      expect(fakePlayer.playing, isFalse);
      expect(handler.isSleepTimerActive, isFalse);
      expect(handler.sleepTimerRemaining, isNull);
    });

    test('3. Overwriting active timer resets to new duration and cancels previous', () async {
      await handler.playTrack(track1);
      handler.setSleepTimer(const Duration(seconds: 10));

      // Overwrite immediately with 80ms
      handler.setSleepTimer(const Duration(milliseconds: 80));
      expect(handler.sleepTimerRemaining!.inMilliseconds, lessThanOrEqualTo(80));

      await Future.delayed(const Duration(milliseconds: 150));

      expect(fakePlayer.playing, isFalse);
      expect(handler.isSleepTimerActive, isFalse);
    });

    test('4. Cancelling sleep timer mid-flight stops timer and keeps audio playing', () async {
      await handler.playTrack(track1);
      expect(fakePlayer.playing, isTrue);

      handler.setSleepTimer(const Duration(milliseconds: 150));
      expect(handler.isSleepTimerActive, isTrue);

      await Future.delayed(const Duration(milliseconds: 30));
      handler.cancelSleepTimer();

      expect(handler.isSleepTimerActive, isFalse);
      expect(handler.sleepTimerRemaining, isNull);

      // Wait beyond the original 150ms
      await Future.delayed(const Duration(milliseconds: 180));
      expect(fakePlayer.playing, isTrue);
    });

    test('5. Zero or negative duration immediately pauses playback safely', () async {
      await handler.playTrack(track1);
      expect(fakePlayer.playing, isTrue);

      handler.setSleepTimer(Duration.zero);
      expect(fakePlayer.playing, isFalse);
      expect(handler.isSleepTimerActive, isFalse);

      await handler.play();
      expect(fakePlayer.playing, isTrue);

      handler.setSleepTimer(const Duration(seconds: -10));
      expect(fakePlayer.playing, isFalse);
      expect(handler.isSleepTimerActive, isFalse);
    });

    test('6. End of Track mode pauses playback when song ends and prevents track advancement', () async {
      await handler.setQueue([track1, track2], startIndex: 0);
      expect(handler.currentIndex, 0);
      expect(fakePlayer.playing, isTrue);

      handler.setSleepTimerEndOfTrack();
      expect(handler.isSleepTimerEndOfTrack, isTrue);
      expect(handler.isSleepTimerActive, isTrue);

      // Simulate natural end of track1
      fakePlayer.simulateTrackCompletion();
      await Future.delayed(const Duration(milliseconds: 50));

      // Should be paused and NOT advanced to track2
      expect(fakePlayer.playing, isFalse);
      expect(handler.currentIndex, 0);
      expect(handler.isSleepTimerEndOfTrack, isFalse);
      expect(handler.isSleepTimerActive, isFalse);
    });

    test('7. Cancelling End of Track mode allows normal track advancement on song end', () async {
      await handler.setQueue([track1, track2], startIndex: 0);
      expect(handler.currentIndex, 0);

      handler.setSleepTimerEndOfTrack();
      expect(handler.isSleepTimerEndOfTrack, isTrue);

      // User changes their mind and cancels
      handler.cancelSleepTimer();
      expect(handler.isSleepTimerEndOfTrack, isFalse);

      fakePlayer.simulateTrackCompletion();
      await Future.delayed(const Duration(milliseconds: 50));

      // Should advance to next track normally
      expect(handler.currentIndex, 1);
    });

    test('8. Switching from End of Track to timed duration seamlessly re-arms timer', () async {
      handler.setSleepTimerEndOfTrack();
      expect(handler.isSleepTimerEndOfTrack, isTrue);
      expect(handler.sleepTimerRemaining, isNull);

      handler.setSleepTimer(const Duration(minutes: 15));
      expect(handler.isSleepTimerEndOfTrack, isFalse);
      expect(handler.sleepTimerRemaining, isNotNull);
      expect(handler.sleepTimerRemaining!.inMinutes, 15);
    });

    test('9. stop() and onTaskRemoved() automatically cancel active sleep timer', () async {
      await handler.playTrack(track1);
      handler.setSleepTimer(const Duration(minutes: 30));
      expect(handler.isSleepTimerActive, isTrue);

      await handler.stop();
      expect(handler.isSleepTimerActive, isFalse);
      expect(handler.sleepTimerRemaining, isNull);

      // Test with onTaskRemoved
      handler.setSleepTimerEndOfTrack();
      expect(handler.isSleepTimerEndOfTrack, isTrue);

      await handler.onTaskRemoved();
      expect(handler.isSleepTimerEndOfTrack, isFalse);
      expect(handler.isSleepTimerActive, isFalse);
    });

    test('10. Rapid concurrent timer operations do not leak timers or cause race conditions', () async {
      await handler.playTrack(track1);

      for (int i = 0; i < 50; i++) {
        if (i % 3 == 0) {
          handler.setSleepTimer(Duration(seconds: i + 1));
        } else if (i % 3 == 1) {
          handler.setSleepTimerEndOfTrack();
        } else {
          handler.cancelSleepTimer();
        }
      }

      handler.cancelSleepTimer();
      expect(handler.isSleepTimerActive, isFalse);
      expect(handler.sleepTimerRemaining, isNull);
      expect(handler.isSleepTimerEndOfTrack, isFalse);
    });
  });
}
