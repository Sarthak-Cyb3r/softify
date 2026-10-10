import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import '../../domain/entities/audio_quality_preset.dart';
import '../../domain/entities/audio_repeat_mode.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_automix_tail_reorderer.dart';
import '../../domain/ports/i_catalog_repository.dart';
import '../../domain/ports/i_download_repository.dart';
import '../../domain/ports/i_event_logger.dart';
import '../../domain/ports/i_library_repository.dart';
import '../../domain/ports/i_stream_resolver.dart';
import '../../domain/ports/i_taste_profile_repository.dart';

import 'softify_audio_player.dart';

class SoftifyAudioHandler extends BaseAudioHandler
    with SeekHandler, QueueHandler {
  final ISoftifyAudioPlayer _player;
  final IStreamResolver _streamResolver;
  final ILibraryRepository _libraryRepo;
  final IDownloadRepository _downloadRepo;
  final ICatalogRepository? _catalogRepo;
  final IEventLogger? _eventLogger;
  final ITasteProfileRepository? _tasteRepo;
  final IAutomixTailReorderer? _automixTailReorderer;
  final AudioQualityPreset _qualityPreset;

  final List<Track> _queue = [];
  int _currentIndex = -1;
  int _consecutiveFailures = 0;
  AudioRepeatMode _repeatMode = AudioRepeatMode.off;
  bool _shuffleEnabled = false;
  bool _autoPlay = true;
  bool _isTransitioningTrack = false;
  bool _isPrefetchingRecommendations = false;
  List<Track> _unshuffledQueue = [];
  String? _currentlyPreloadingTrackId;
  DateTime? _currentTrackStartedAt;
  String _currentTrackSource = 'library';

  int _sessionConsecutiveSkips = 0;

  final BehaviorSubject<Track?> _currentTrackSubject =
      BehaviorSubject<Track?>.seeded(null);
  final BehaviorSubject<List<Track>> _tracksQueueSubject =
      BehaviorSubject<List<Track>>.seeded([]);
  final BehaviorSubject<AudioRepeatMode> _repeatModeSubject =
      BehaviorSubject<AudioRepeatMode>.seeded(AudioRepeatMode.off);
  final BehaviorSubject<bool> _shuffleModeSubject =
      BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<bool> _autoPlaySubject =
      BehaviorSubject<bool>.seeded(true);

  Timer? _saveQueueDebounceTimer;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playbackEventSubscription;
  StreamSubscription? _audioSessionSubscription;

  SoftifyAudioHandler({
    ISoftifyAudioPlayer? player,
    required IStreamResolver streamResolver,
    required ILibraryRepository libraryRepo,
    required IDownloadRepository downloadRepo,
    ICatalogRepository? catalogRepo,
    IEventLogger? eventLogger,
    ITasteProfileRepository? tasteRepo,
    IAutomixTailReorderer? automixTailReorderer,
    AudioQualityPreset qualityPreset = AudioQualityPreset.standard,
    bool enableAudioSession = true,
    bool autoRestoreState = true,
  })  : _player = player ?? JustAudioPlayerAdapter(),
        _streamResolver = streamResolver,
        _libraryRepo = libraryRepo,
        _downloadRepo = downloadRepo,
        _catalogRepo = catalogRepo,
        _eventLogger = eventLogger,
        _tasteRepo = tasteRepo,
        _automixTailReorderer = automixTailReorderer,
        _qualityPreset = qualityPreset {
    _init(
      enableAudioSession: enableAudioSession,
      autoRestoreState: autoRestoreState,
    );
  }

  void setTrackSource(String source) {
    _currentTrackSource = source;
  }

  void _logTrackPlayEvent(Track? track, {required bool isCompleted}) {
    if (track == null) return;
    if (_currentTrackSource == 'youtube_link') return;
    final int listenedMs;
    if (isCompleted) {
      listenedMs = track.duration.inMilliseconds;
    } else {
      final now = DateTime.now();
      listenedMs = _currentTrackStartedAt != null
          ? now.difference(_currentTrackStartedAt!).inMilliseconds
          : 0;
    }

    final isStream = listenedMs >= 30000;
    if (isCompleted || isStream) {
      _sessionConsecutiveSkips = 0;
    } else {
      _sessionConsecutiveSkips++;
      final automix = _automixTailReorderer;
      if (_sessionConsecutiveSkips >= 2 &&
          automix != null &&
          _queue.length > _currentIndex + 2) {
        final reordered = automix.reorderTail(
          currentQueue: _queue,
          currentIndex: _currentIndex,
          hasBufferedNext: _player.hasPreloadedNext,
          sessionConsecutiveSkips: _sessionConsecutiveSkips,
        );
        _queue.clear();
        _queue.addAll(reordered);
        _syncQueueState();
      }
    }

    if (_eventLogger != null) {
      _eventLogger.logPlay(
        trackId: track.id,
        source: _currentTrackSource,
        listenedMs: listenedMs,
        durationMs: track.duration.inMilliseconds,
        saved: track.isLiked,
        addedToPlaylist: false,
        rankerVersion: 'v2',
      );
    }

    if (_tasteRepo != null) {
      unawaited(_tasteRepo.updateFromPlay(
        track: track,
        isStream: isStream,
        isEarlySkip: !isStream,
        isSave: track.isLiked,
      ).catchError((_) {}));
    }
  }

  // ==========================================
  // Public Streams & Getters
  // ==========================================

  Stream<Track?> get currentTrackStream => _currentTrackSubject.stream;
  Stream<List<Track>> get tracksQueueStream => _tracksQueueSubject.stream;
  Stream<AudioRepeatMode> get repeatModeStream => _repeatModeSubject.stream;
  Stream<bool> get shuffleModeStream => _shuffleModeSubject.stream;
  Stream<bool> get autoPlayStream => _autoPlaySubject.stream;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Duration get position => _player.position;

  Track? get currentTrack =>
      (_currentIndex >= 0 && _currentIndex < _queue.length)
          ? _queue[_currentIndex]
          : null;
  List<Track> get currentQueue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  AudioRepeatMode get repeatMode => _repeatMode;
  bool get isShuffleEnabled => _shuffleEnabled;
  bool get isAutoPlayEnabled => _autoPlay;

  // ==========================================
  // Initialization
  // ==========================================

  Future<void> _init({
    required bool enableAudioSession,
    required bool autoRestoreState,
  }) async {
    if (enableAudioSession) {
      _initAudioSession();
    }

    // Listen to player state events and broadcast to audio_service
    _playbackEventSubscription =
        _player.playbackEventStream.listen(_broadcastPlaybackState);

    // Listen to completion of tracks
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onTrackCompleted();
      }
    });

    if (autoRestoreState) {
      await restorePersistedState();
    }
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _audioSessionSubscription = session.becomingNoisyEventStream.listen((_) {
        pause();
      });
    } catch (_) {
      // Non-fatal if audio session is unsupported in environment (e.g. tests)
    }
  }

  void _broadcastPlaybackState(PlaybackEvent event) {
    final playing = _player.playing;
    final processingState = _mapProcessingState(_player.processingState);

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex >= 0 ? _currentIndex : null,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  MediaItem _trackToMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      artUri: track.coverUrl != null ? Uri.tryParse(track.coverUrl!) : null,
      extras: {
        'sourceId': track.sourceId,
        'isLiked': track.isLiked,
      },
    );
  }

  void _syncQueueState() {
    queue.add(_queue.map(_trackToMediaItem).toList());
    _tracksQueueSubject.add(List.unmodifiable(_queue));

    final cur = currentTrack;
    _currentTrackSubject.add(cur);
    if (cur != null) {
      mediaItem.add(_trackToMediaItem(cur));
    } else {
      mediaItem.add(null);
    }
  }

  // ==========================================
  // Playback Control (Overrides)
  // ==========================================

  @override
  Future<void> play() async {
    if (_queue.isEmpty) return;

    if (_player.processingState == ProcessingState.idle ||
        _player.processingState == ProcessingState.completed) {
      await _playCurrentIndex();
    } else {
      await _player.play();
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    await _saveQueueStateImmediately();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _saveQueueStateImmediately();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    final previousTrack = currentTrack;
    _logTrackPlayEvent(previousTrack, isCompleted: false);

    if (_currentIndex < _queue.length - 1) {
      if (_player.hasPreloadedNext) {
        _currentIndex++;
        _syncQueueState();
        final nextTrack = currentTrack;
        _currentlyPreloadingTrackId = null;
        _currentTrackStartedAt = DateTime.now();
        await _player.playPreloadedNext();
        if (nextTrack != null && !nextTrack.supportsSpeedPlayback && _player.speed != 1.0) {
          await _player.setSpeed(1.0);
        }
        _consecutiveFailures = 0;
        _debouncedSaveQueue();
        if (nextTrack != null) {
          unawaited(_libraryRepo.recordPlayHistory(nextTrack, 0.0).catchError((_) {}));
        }
        unawaited(_prefetchNextTrackStream());
        _checkAndPrefetchRecommendations();
        return;
      }

      _currentIndex++;
      _syncQueueState();
      await _playCurrentIndex();
      _checkAndPrefetchRecommendations();
    } else if (_repeatMode == AudioRepeatMode.all) {
      if (_player.hasPreloadedNext && _queue.isNotEmpty) {
        _currentIndex = 0;
        _syncQueueState();
        final nextTrack = currentTrack;
        _currentlyPreloadingTrackId = null;
        _currentTrackStartedAt = DateTime.now();
        await _player.playPreloadedNext();
        if (nextTrack != null && !nextTrack.supportsSpeedPlayback && _player.speed != 1.0) {
          await _player.setSpeed(1.0);
        }
        _consecutiveFailures = 0;
        _debouncedSaveQueue();
        if (nextTrack != null) {
          unawaited(_libraryRepo.recordPlayHistory(nextTrack, 0.0).catchError((_) {}));
        }
        unawaited(_prefetchNextTrackStream());
        _checkAndPrefetchRecommendations();
        return;
      }

      _currentIndex = 0;
      _syncQueueState();
      await _playCurrentIndex();
      _checkAndPrefetchRecommendations();
    } else if (_autoPlay && _catalogRepo != null && currentTrack != null) {
      await _fetchAndPlayRecommendations(currentTrack!);
    } else {
      await stop();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;

    // If played more than 3 seconds, restart current track
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    final previousTrack = currentTrack;
    _logTrackPlayEvent(previousTrack, isCompleted: false);

    if (_currentIndex > 0) {
      _currentIndex--;
      _syncQueueState();
      await _playCurrentIndex();
    } else if (_repeatMode == AudioRepeatMode.all) {
      _currentIndex = _queue.length - 1;
      _syncQueueState();
      await _playCurrentIndex();
    } else {
      await seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final previousTrack = currentTrack;
    _logTrackPlayEvent(previousTrack, isCompleted: false);
    _currentIndex = index;
    _syncQueueState();
    await _playCurrentIndex();
    _checkAndPrefetchRecommendations();
  }

  // ==========================================
  // Custom Playback Operations
  // ==========================================

  Future<void> playTrack(Track track, {List<Track>? queue, int? startIndex}) async {
    if (queue != null && queue.isNotEmpty) {
      final index = startIndex ?? queue.indexWhere((t) => t.id == track.id);
      await setQueue(queue, startIndex: index >= 0 ? index : 0);
      return;
    }
    _player.clearPreloadedNext();
    _currentlyPreloadingTrackId = null;
    _queue.clear();
    _queue.add(track);
    _currentIndex = 0;
    _syncQueueState();
    await _playCurrentIndex();
    _checkAndPrefetchRecommendations();
  }

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    _player.clearPreloadedNext();
    _currentlyPreloadingTrackId = null;
    _queue.clear();
    _queue.addAll(tracks);
    _unshuffledQueue = List.from(tracks);
    _currentIndex =
        (startIndex >= 0 && startIndex < tracks.length) ? startIndex : 0;
    _syncQueueState();
    await _playCurrentIndex();
    _checkAndPrefetchRecommendations();
  }

  Future<void> addToQueue(Track track) async {
    _queue.add(track);
    _unshuffledQueue.add(track);
    if (_currentIndex == -1) {
      _currentIndex = 0;
    }
    _syncQueueState();
    _debouncedSaveQueue();
    if (_queue.length == 2 && _currentIndex == 0) {
      unawaited(_prefetchNextTrackStream());
    }
  }

  Future<void> playNext(Track track) async {
    if (_queue.isEmpty || _currentIndex == -1) {
      await playTrack(track);
      return;
    }

    _player.clearPreloadedNext();
    _currentlyPreloadingTrackId = null;
    _queue.insert(_currentIndex + 1, track);
    _unshuffledQueue.add(track);
    _syncQueueState();
    _debouncedSaveQueue();
    unawaited(_prefetchNextTrackStream());
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _queue.length ||
        newIndex < 0 ||
        newIndex >= _queue.length) {
      return;
    }

    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    _player.clearPreloadedNext();
    _currentlyPreloadingTrackId = null;
    _syncQueueState();
    _debouncedSaveQueue();
    unawaited(_prefetchNextTrackStream());
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _queue.length) return;

    if (index == _currentIndex) {
      _queue.removeAt(index);
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
      _syncQueueState();
      if (_currentIndex >= 0) {
        await _playCurrentIndex();
      } else {
        await stop();
      }
    } else {
      if (index < _currentIndex) {
        _currentIndex--;
      }
      _queue.removeAt(index);
      _syncQueueState();
    }

    _debouncedSaveQueue();
  }

  Future<void> clearQueue() async {
    _player.clearPreloadedNext();
    _currentlyPreloadingTrackId = null;
    _queue.clear();
    _unshuffledQueue.clear();
    _currentIndex = -1;
    _syncQueueState();
    await _player.stop();
    await _libraryRepo.clearQueueState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final mode = switch (repeatMode) {
      AudioServiceRepeatMode.none => AudioRepeatMode.off,
      AudioServiceRepeatMode.all => AudioRepeatMode.all,
      AudioServiceRepeatMode.one => AudioRepeatMode.one,
      _ => AudioRepeatMode.off,
    };
    await setAudioRepeatMode(mode);
  }

  Future<void> setAudioRepeatMode(AudioRepeatMode mode) async {
    _repeatMode = mode;
    _repeatModeSubject.add(mode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all ||
        shuffleMode == AudioServiceShuffleMode.group;
    await setShuffleEnabled(enabled);
  }

  Future<void> setShuffleEnabled(bool enabled) async {
    if (_shuffleEnabled == enabled) return;
    _shuffleEnabled = enabled;
    _shuffleModeSubject.add(enabled);

    if (enabled) {
      if (_queue.isNotEmpty && _currentIndex >= 0) {
        final current = _queue[_currentIndex];
        final remaining = _queue.where((t) => t.id != current.id).toList();
        remaining.shuffle(Random());
        _queue.clear();
        _queue.add(current);
        _queue.addAll(remaining);
        _currentIndex = 0;
      }
    } else {
      if (_unshuffledQueue.isNotEmpty && currentTrack != null) {
        final current = currentTrack!;
        final newIdx = _unshuffledQueue.indexWhere((t) => t.id == current.id);
        _queue.clear();
        _queue.addAll(_unshuffledQueue);
        _currentIndex = newIdx != -1 ? newIdx : 0;
      }
    }

    _syncQueueState();
    _debouncedSaveQueue();
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume);
  double get volume => _player.volume;
  Stream<double> get volumeStream => _player.volumeStream;

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _broadcastPlaybackState(PlaybackEvent());
  }

  double get speed => _player.speed;
  Stream<double> get speedStream => _player.speedStream;

  // Equalizer API
  Future<void> setEqualizerEnabled(bool enabled) => _player.setEqualizerEnabled(enabled);
  Future<void> setEqualizerBands(List<double> gains) => _player.setEqualizerBands(gains);
  Future<void> setLoudnessEnhancerGain(double gain) => _player.setLoudnessEnhancerGain(gain);
  Future<void> setBassBoost(double boost) => _player.setBassBoost(boost);
  Future<List<double>> getBandFrequencies() => _player.getBandFrequencies();

  // ==========================================
  // JIT Resolution & Offline-First Playback
  // ==========================================

  Future<void> _playCurrentIndex({
    bool forceFresh = false,
    Duration? initialPosition,
  }) async {
    if (_queue.isEmpty || _currentIndex < 0 || _currentIndex >= _queue.length) {
      return;
    }

    final track = _queue[_currentIndex];
    _syncQueueState();
    _currentTrackStartedAt = DateTime.now();

    // Reset playback speed to 1.0x for standard music tracks
    if (!track.supportsSpeedPlayback && _player.speed != 1.0) {
      await _player.setSpeed(1.0);
    }

    try {
      // 1. Check offline download first (D7: zero network data usage)
      final downloadedFilePath =
          await _downloadRepo.getDownloadedFilePath(track.id);

      if (downloadedFilePath != null) {
        try {
          await _player.setFilePath(
            downloadedFilePath,
            initialPosition: initialPosition,
          );
          await _player.play();
          _consecutiveFailures = 0;
          _debouncedSaveQueue();
          unawaited(_libraryRepo.recordPlayHistory(track, 0.0).catchError((_) {}));
          unawaited(_prefetchNextTrackStream());
          return;
        } catch (downloadErr) {
          // ignore: avoid_print
          print('[SoftifyAudioHandler] Local file playback failed ($downloadErr), falling back to online stream...');
        }
      }

      // 2. JIT Stream URL Resolution (D5)
      // ignore: avoid_print
      print('[SoftifyAudioHandler] Resolving stream for "${track.title}" (${track.artist})...');
      final streamInfo = await _streamResolver.resolve(
        track,
        quality: _qualityPreset,
        forceFresh: forceFresh,
      );
      // ignore: avoid_print
      print('[SoftifyAudioHandler] Resolved stream: ${streamInfo.providerName}, container=${streamInfo.container}');

      await _player.setUrl(
        streamInfo.url.toString(),
        headers: streamInfo.headers,
        initialPosition: initialPosition,
      );
      // ignore: avoid_print
      print('[SoftifyAudioHandler] Player setUrl completed, calling play()...');
      await _player.play();
      // ignore: avoid_print
      print('[SoftifyAudioHandler] Player play() called successfully!');
      _consecutiveFailures = 0;
      _debouncedSaveQueue();
      unawaited(_libraryRepo.recordPlayHistory(track, 0.0).catchError((_) {}));
      unawaited(_prefetchNextTrackStream());
      _checkAndPrefetchRecommendations();
    } catch (e, st) {
      // ignore: avoid_print
      print('[SoftifyAudioHandler] ERROR playing "${track.title}": $e\n$st');
      // HTTP 403 Forbidden / Expired URL: Trigger transparent JIT re-resolution
      if (!forceFresh) {
        final savedPos = _player.position;
        return _playCurrentIndex(
          forceFresh: true,
          initialPosition: savedPos,
        );
      }

      // Track failed after fresh resolution
      _consecutiveFailures++;
      if (_currentTrackSource == 'youtube_link') {
        rethrow;
      }
      if (_consecutiveFailures < 3) {
        await _libraryRepo.markTrackUnavailable(track.id, true);
        await skipToNext();
      } else {
        // Exhausted fallbacks: Stop playback after N = 3 consecutive failures
        _consecutiveFailures = 0;
        await pause();
      }
    }
  }

  Future<void> _onTrackCompleted() async {
    if (_isTransitioningTrack) return;
    _isTransitioningTrack = true;

    try {
      final completed = currentTrack;
      if (completed != null) {
        _logTrackPlayEvent(completed, isCompleted: true);
        _currentTrackStartedAt = null;
        unawaited(_libraryRepo.recordPlayHistory(completed, 1.0).catchError((_) {}));
      }

      if (_repeatMode == AudioRepeatMode.one) {
        await seek(Duration.zero);
        await play();
        return;
      }

      await skipToNext();
    } finally {
      _isTransitioningTrack = false;
    }
  }

  Future<void> _prefetchNextTrackStream() async {
    if (_queue.isEmpty || _currentIndex < 0) return;

    final int nextIdx;
    if (_currentIndex < _queue.length - 1) {
      nextIdx = _currentIndex + 1;
    } else if (_repeatMode == AudioRepeatMode.all && _queue.isNotEmpty) {
      nextIdx = 0;
    } else {
      return;
    }

    final nextTrack = _queue[nextIdx];
    if (_currentlyPreloadingTrackId == nextTrack.id && _player.hasPreloadedNext) {
      return;
    }
    _currentlyPreloadingTrackId = nextTrack.id;

    try {
      // 1. Check if next track is downloaded offline
      final downloadedPath =
          await _downloadRepo.getDownloadedFilePath(nextTrack.id);
      if (downloadedPath != null) {
        if (_currentlyPreloadingTrackId == nextTrack.id) {
          await _player.preloadNextFilePath(downloadedPath);
        }
        return;
      }

      // 2. Resolve network stream URL in background
      final streamInfo = await _streamResolver.resolve(
        nextTrack,
        quality: _qualityPreset,
        forceFresh: false,
      );

      if (_currentlyPreloadingTrackId == nextTrack.id) {
        await _player.preloadNextUrl(
          streamInfo.url.toString(),
          headers: streamInfo.headers,
        );
      }
    } catch (_) {
      // Best-effort prefetch
    }
  }

  Future<void> setAutoPlayEnabled(bool enabled) async {
    if (_autoPlay == enabled) return;
    _autoPlay = enabled;
    _autoPlaySubject.add(enabled);
    if (enabled) {
      _checkAndPrefetchRecommendations();
    }
  }

  void _checkAndPrefetchRecommendations() {
    if (_currentTrackSource == 'youtube_link') return;
    if (_repeatMode != AudioRepeatMode.off) return; // Never append autoplay recommendations when repeat is active
    if (!_autoPlay || _catalogRepo == null || _isPrefetchingRecommendations) return;
    if (_queue.isEmpty || _currentIndex < 0) return;

    final remaining = _queue.length - 1 - _currentIndex;
    if (remaining <= 1) {
      final seedTrack = _queue.last;
      _prefetchQueueRecommendations(seedTrack);
    }
  }

  Future<void> _prefetchQueueRecommendations(Track seedTrack) async {
    if (_isPrefetchingRecommendations) return;
    _isPrefetchingRecommendations = true;
    try {
      // ignore: avoid_print
      print('[SoftifyAudioHandler] Autoplay pre-fetching similar tracks for "${seedTrack.title}" in background...');
      final related = await _catalogRepo!.getRelatedTracks(seedTrack);
      final existingIds = _queue.map((t) => t.sourceId).toSet();
      final fresh = related.where((t) => !existingIds.contains(t.sourceId)).toList();

      if (fresh.isNotEmpty) {
        _queue.addAll(fresh);
        _unshuffledQueue.addAll(fresh);
        _syncQueueState();
        _debouncedSaveQueue();
        // ignore: avoid_print
        print('[SoftifyAudioHandler] Appended ${fresh.length} recommended tracks to queue.');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[SoftifyAudioHandler] Background pre-fetch recommendations error: $e');
    } finally {
      _isPrefetchingRecommendations = false;
    }
  }

  Future<void> _fetchAndPlayRecommendations(Track seedTrack) async {
    // If the queue already got new items (e.g. from background prefetch):
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _syncQueueState();
      await _playCurrentIndex();
      _checkAndPrefetchRecommendations();
      return;
    }

    try {
      // ignore: avoid_print
      print('[SoftifyAudioHandler] End of queue reached. Autoplay fetching recommendations for "${seedTrack.title}" (${seedTrack.artist})...');
      final related = await _catalogRepo!.getRelatedTracks(seedTrack);

      // Re-check: did the queue get more tracks while awaiting?
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
        _syncQueueState();
        await _playCurrentIndex();
        _checkAndPrefetchRecommendations();
        return;
      }

      final existingIds = _queue.map((t) => t.sourceId).toSet();
      final fresh = related.where((t) => !existingIds.contains(t.sourceId)).toList();

      if (fresh.isNotEmpty) {
        _queue.addAll(fresh);
        _unshuffledQueue.addAll(fresh);
        _currentIndex++;
        _syncQueueState();
        await _playCurrentIndex();
        _checkAndPrefetchRecommendations();
        return;
      }
    } catch (e) {
      // ignore: avoid_print
      print('[SoftifyAudioHandler] Failed to load autoplay recommendations: $e');
    }
    await stop();
  }

  // ==========================================
  // State Persistence
  // ==========================================

  void _debouncedSaveQueue() {
    _saveQueueDebounceTimer?.cancel();
    _saveQueueDebounceTimer = Timer(const Duration(seconds: 2), () {
      _saveQueueStateImmediately();
    });
  }

  Future<void> _saveQueueStateImmediately() async {
    if (_queue.isNotEmpty && _currentIndex >= 0) {
      await _libraryRepo.saveQueueState(
        _queue,
        _currentIndex,
        _player.position,
      );
    }
  }

  Future<void> restorePersistedState() async {
    try {
      final state = await _libraryRepo.getQueueState();
      if (state.tracks.isNotEmpty) {
        _queue.clear();
        _queue.addAll(state.tracks);
        _unshuffledQueue = List.from(state.tracks);
        _currentIndex = state.currentIndex.clamp(0, _queue.length - 1);
        _syncQueueState();

        // Pre-seek without auto-playing
        if (currentTrack != null) {
          final downloadedFilePath =
              await _downloadRepo.getDownloadedFilePath(currentTrack!.id);
          if (downloadedFilePath != null) {
            await _player.setFilePath(
              downloadedFilePath,
              initialPosition: state.position,
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    _saveQueueDebounceTimer?.cancel();
    await _playerStateSubscription?.cancel();
    await _playbackEventSubscription?.cancel();
    await _audioSessionSubscription?.cancel();
    await _currentTrackSubject.close();
    await _tracksQueueSubject.close();
    await _repeatModeSubject.close();
    await _shuffleModeSubject.close();
    await _autoPlaySubject.close();
    await _player.dispose();
  }
}
