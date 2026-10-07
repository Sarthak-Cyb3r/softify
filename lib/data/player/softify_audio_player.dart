import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// Clean interface abstracting the low-level audio decoder/player engine.
/// Decouples SoftifyAudioHandler from direct platform channel calls.
abstract class ISoftifyAudioPlayer {
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<Duration?> setUrl(String url, {Map<String, String>? headers, Duration? initialPosition});
  Future<Duration?> setFilePath(String path, {Duration? initialPosition});

  // Gapless Next Track Preloading API
  Future<void> preloadNextUrl(String url, {Map<String, String>? headers});
  Future<void> preloadNextFilePath(String path);
  bool get hasPreloadedNext;
  String? get preloadedSource;
  Future<void> playPreloadedNext();
  void clearPreloadedNext();

  Stream<PlayerState> get playerStateStream;
  Stream<PlaybackEvent> get playbackEventStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<Duration?> get durationStream;

  Duration get position;
  Duration get bufferedPosition;
  double get speed;
  bool get playing;
  ProcessingState get processingState;

  Future<void> dispose();
}

/// Production implementation of ISoftifyAudioPlayer backed by just_audio.
/// Utilizes a dual-player active/standby architecture for true 0ms gapless track transitions.
class JustAudioPlayerAdapter implements ISoftifyAudioPlayer {
  final AudioPlayer _playerA;
  final AudioPlayer _playerB;
  late AudioPlayer _activePlayer;
  late AudioPlayer _standbyPlayer;

  String? _preloadedSource;
  bool _isStandbyReady = false;

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

  StreamSubscription? _playerStateSub;
  StreamSubscription? _playbackEventSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _bufferedPositionSub;
  StreamSubscription? _durationSub;

  JustAudioPlayerAdapter({
    AudioPlayer? playerA,
    AudioPlayer? playerB,
  })  : _playerA = playerA ?? AudioPlayer(),
        _playerB = playerB ?? AudioPlayer() {
    _activePlayer = _playerA;
    _standbyPlayer = _playerB;
    _bindActivePlayerStreams();
  }

  void _bindActivePlayerStreams() {
    _playerStateSub?.cancel();
    _playbackEventSub?.cancel();
    _positionSub?.cancel();
    _bufferedPositionSub?.cancel();
    _durationSub?.cancel();

    _playerStateSub = _activePlayer.playerStateStream.listen(_playerStateSubject.add);
    _playbackEventSub = _activePlayer.playbackEventStream.listen(_playbackEventSubject.add);
    _positionSub = _activePlayer.positionStream.listen(_positionSubject.add);
    _bufferedPositionSub = _activePlayer.bufferedPositionStream.listen(_bufferedPositionSubject.add);
    _durationSub = _activePlayer.durationStream.listen(_durationSubject.add);

    _playerStateSubject.add(_activePlayer.playerState);
    _positionSubject.add(_activePlayer.position);
    _bufferedPositionSubject.add(_activePlayer.bufferedPosition);
    _durationSubject.add(_activePlayer.duration);
    _playbackEventSubject.add(PlaybackEvent(
      processingState: _activePlayer.processingState,
      updatePosition: _activePlayer.position,
    ));
  }

  @override
  Future<void> play() => _activePlayer.play();

  @override
  Future<void> pause() => _activePlayer.pause();

  @override
  Future<void> stop() => _activePlayer.stop();

  @override
  Future<void> seek(Duration position) => _activePlayer.seek(position);

  @override
  Future<Duration?> setUrl(String url, {Map<String, String>? headers, Duration? initialPosition}) {
    clearPreloadedNext();
    return _activePlayer.setUrl(url, headers: headers, initialPosition: initialPosition);
  }

  @override
  Future<Duration?> setFilePath(String path, {Duration? initialPosition}) {
    clearPreloadedNext();
    return _activePlayer.setFilePath(path, initialPosition: initialPosition);
  }

  @override
  Future<void> preloadNextUrl(String url, {Map<String, String>? headers}) async {
    if (_preloadedSource == url && _isStandbyReady) return;
    _preloadedSource = url;
    _isStandbyReady = false;
    try {
      await _standbyPlayer.stop();
      await _standbyPlayer.setUrl(url, headers: headers, preload: true);
      _isStandbyReady = true;
    } catch (_) {
      if (_preloadedSource == url) {
        _preloadedSource = null;
        _isStandbyReady = false;
      }
    }
  }

  @override
  Future<void> preloadNextFilePath(String path) async {
    if (_preloadedSource == path && _isStandbyReady) return;
    _preloadedSource = path;
    _isStandbyReady = false;
    try {
      await _standbyPlayer.stop();
      await _standbyPlayer.setFilePath(path, preload: true);
      _isStandbyReady = true;
    } catch (_) {
      if (_preloadedSource == path) {
        _preloadedSource = null;
        _isStandbyReady = false;
      }
    }
  }

  @override
  bool get hasPreloadedNext => _isStandbyReady;

  @override
  String? get preloadedSource => _preloadedSource;

  @override
  Future<void> playPreloadedNext() async {
    if (!_isStandbyReady) return;

    await _activePlayer.stop();

    final temp = _activePlayer;
    _activePlayer = _standbyPlayer;
    _standbyPlayer = temp;

    _preloadedSource = null;
    _isStandbyReady = false;

    _bindActivePlayerStreams();
    await _activePlayer.play();
  }

  @override
  void clearPreloadedNext() {
    _preloadedSource = null;
    _isStandbyReady = false;
    unawaited(_standbyPlayer.stop());
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
  Duration get position => _activePlayer.position;

  @override
  Duration get bufferedPosition => _activePlayer.bufferedPosition;

  @override
  double get speed => _activePlayer.speed;

  @override
  bool get playing => _activePlayer.playing;

  @override
  ProcessingState get processingState => _activePlayer.processingState;

  @override
  Future<void> dispose() async {
    _playerStateSub?.cancel();
    _playbackEventSub?.cancel();
    _positionSub?.cancel();
    _bufferedPositionSub?.cancel();
    _durationSub?.cancel();

    await _playerStateSubject.close();
    await _playbackEventSubject.close();
    await _positionSubject.close();
    await _bufferedPositionSubject.close();
    await _durationSubject.close();

    await Future.wait([
      _playerA.dispose(),
      _playerB.dispose(),
    ]);
  }
}
