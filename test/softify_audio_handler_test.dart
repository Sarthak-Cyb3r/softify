import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/data/player/softify_audio_player.dart';
import 'package:softify/data/repositories/drift_library_repository.dart';
import 'package:softify/domain/entities/audio_quality_preset.dart';
import 'package:softify/domain/entities/audio_repeat_mode.dart';
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

  @override
  bool get playing => _playing;

  @override
  ProcessingState get processingState => _processingState;

  @override
  Duration get position => _position;

  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  double get speed => 1.0;

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
  }
}

class MockStreamResolver implements IStreamResolver {
  int resolveCalls = 0;

  @override
  Future<StreamInfo> resolve(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
    bool forceFresh = false,
  }) async {
    resolveCalls++;
    return StreamInfo(
      url: Uri.parse('https://example.com/audio_${track.id}.m4a'),
      container: 'm4a',
      bitrate: 128000,
      codec: 'mp4a.40.2',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      providerName: 'mock',
    );
  }

  @override
  Future<void> prefetch(Track track, {AudioQualityPreset quality = AudioQualityPreset.standard}) async {}
}

class MockDownloadRepository implements IDownloadRepository {
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
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftLibraryRepository libraryRepo;
  late MockStreamResolver streamResolver;
  late MockDownloadRepository downloadRepo;
  late FakeSoftifyAudioPlayer fakePlayer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    libraryRepo = DriftLibraryRepository(db);
    streamResolver = MockStreamResolver();
    downloadRepo = MockDownloadRepository();
    fakePlayer = FakeSoftifyAudioPlayer();
  });

  tearDown(() async {
    await db.close();
  });

  const track1 = Track(
    id: 't-1',
    sourceId: 's-1',
    title: 'Starboy',
    artist: 'The Weeknd',
    duration: Duration(seconds: 230),
  );

  const track2 = Track(
    id: 't-2',
    sourceId: 's-2',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    duration: Duration(seconds: 200),
  );

  const track3 = Track(
    id: 't-3',
    sourceId: 's-3',
    title: 'Save Your Tears',
    artist: 'The Weeknd',
    duration: Duration(seconds: 215),
  );

  group('SoftifyAudioHandler: Queue & Playback Management', () {
    test('Queue operations: setQueue, addToQueue, playNext, reorder, remove', () async {
      final handler = SoftifyAudioHandler(
        player: fakePlayer,
        streamResolver: streamResolver,
        libraryRepo: libraryRepo,
        downloadRepo: downloadRepo,
      );

      // Initial queue
      await handler.setQueue([track1, track2], startIndex: 0);
      expect(handler.currentQueue.length, 2);
      expect(handler.currentTrack?.id, track1.id);
      expect(handler.currentIndex, 0);
      expect(fakePlayer.lastLoadedUrl, 'https://example.com/audio_t-1.m4a');
      expect(fakePlayer.playing, isTrue);

      // Add to queue
      await handler.addToQueue(track3);
      expect(handler.currentQueue.length, 3);
      expect(handler.currentQueue.last.id, track3.id);

      // Play next (insert immediately after current index 0)
      const track4 = Track(
        id: 't-4',
        sourceId: 's-4',
        title: 'In Your Eyes',
        artist: 'The Weeknd',
        duration: Duration(seconds: 237),
      );
      await handler.playNext(track4);
      expect(handler.currentQueue.length, 4);
      expect(handler.currentQueue[1].id, track4.id);

      // Reorder queue: move item from index 1 to 3
      await handler.reorderQueue(1, 3);
      expect(handler.currentQueue[3].id, track4.id);

      // Remove queue item
      await handler.removeQueueItemAt(3);
      expect(handler.currentQueue.length, 3);
      expect(handler.currentQueue.any((t) => t.id == track4.id), isFalse);

      // Clear queue
      await handler.clearQueue();
      expect(handler.currentQueue, isEmpty);
      expect(handler.currentTrack, isNull);

      await handler.dispose();
    });

    test('Repeat and Shuffle modes toggle correctly', () async {
      final handler = SoftifyAudioHandler(
        player: fakePlayer,
        streamResolver: streamResolver,
        libraryRepo: libraryRepo,
        downloadRepo: downloadRepo,
      );

      await handler.setQueue([track1, track2, track3], startIndex: 0);

      // Repeat mode
      expect(handler.repeatMode, AudioRepeatMode.off);
      await handler.setAudioRepeatMode(AudioRepeatMode.all);
      expect(handler.repeatMode, AudioRepeatMode.all);
      await handler.setAudioRepeatMode(AudioRepeatMode.one);
      expect(handler.repeatMode, AudioRepeatMode.one);

      // Shuffle mode
      expect(handler.isShuffleEnabled, isFalse);
      await handler.setShuffleEnabled(true);
      expect(handler.isShuffleEnabled, isTrue);
      // Current track remains active at index 0
      expect(handler.currentTrack?.id, track1.id);
      expect(handler.currentQueue.length, 3);

      // Unshuffle restores original order
      await handler.setShuffleEnabled(false);
      expect(handler.isShuffleEnabled, isFalse);
      expect(handler.currentQueue[0].id, track1.id);
      expect(handler.currentQueue[1].id, track2.id);
      expect(handler.currentQueue[2].id, track3.id);

      await handler.dispose();
    });

    test('Offline Playback Routing (D7): plays from local file when downloaded', () async {
      // Mark track1 as downloaded locally
      downloadRepo.downloadedFiles[track1.id] = '/local/storage/tracks/t-1.m4a';

      final handler = SoftifyAudioHandler(
        player: fakePlayer,
        streamResolver: streamResolver,
        libraryRepo: libraryRepo,
        downloadRepo: downloadRepo,
      );

      await handler.playTrack(track1);

      // Must play from local file with zero network data usage
      expect(fakePlayer.lastLoadedFilePath, '/local/storage/tracks/t-1.m4a');
      expect(streamResolver.resolveCalls, 0); // Resolver NOT called!

      await handler.dispose();
    });

    test('Persisted queue state restores on startup', () async {
      // Pre-save state in library repository
      await libraryRepo.saveQueueState([track1, track2], 1, const Duration(seconds: 42));

      final handler = SoftifyAudioHandler(
        player: fakePlayer,
        streamResolver: streamResolver,
        libraryRepo: libraryRepo,
        downloadRepo: downloadRepo,
      );

      await handler.restorePersistedState();

      expect(handler.currentQueue.length, 2);
      expect(handler.currentIndex, 1);
      expect(handler.currentTrack?.id, track2.id);

      await handler.dispose();
    });
  });
}
