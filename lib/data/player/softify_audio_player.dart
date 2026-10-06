import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Clean interface abstracting the low-level audio decoder/player engine.
/// Decouples SoftifyAudioHandler from direct platform channel calls.
abstract class ISoftifyAudioPlayer {
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<Duration?> setUrl(String url, {Map<String, String>? headers, Duration? initialPosition});
  Future<Duration?> setFilePath(String path, {Duration? initialPosition});

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
class JustAudioPlayerAdapter implements ISoftifyAudioPlayer {
  final AudioPlayer _player;

  JustAudioPlayerAdapter([AudioPlayer? player]) : _player = player ?? AudioPlayer();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<Duration?> setUrl(String url, {Map<String, String>? headers, Duration? initialPosition}) =>
      _player.setUrl(url, headers: headers, initialPosition: initialPosition);

  @override
  Future<Duration?> setFilePath(String path, {Duration? initialPosition}) =>
      _player.setFilePath(path, initialPosition: initialPosition);

  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _player.playbackEventStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Duration get position => _player.position;

  @override
  Duration get bufferedPosition => _player.bufferedPosition;

  @override
  double get speed => _player.speed;

  @override
  bool get playing => _player.playing;

  @override
  ProcessingState get processingState => _player.processingState;

  @override
  Future<void> dispose() => _player.dispose();
}
