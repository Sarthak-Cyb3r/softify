import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import 'linux_audio_backend.dart';

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
  Future<void> playPreloadedNext({Duration crossfade = Duration.zero});
  void clearPreloadedNext();

  Stream<PlayerState> get playerStateStream;
  Stream<PlaybackEvent> get playbackEventStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<Duration?> get durationStream;

  Duration get position;
  Duration get bufferedPosition;
  Duration? get duration => null;
  double get speed;
  Stream<double> get speedStream;
  Future<void> setSpeed(double speed);
  bool get playing;
  ProcessingState get processingState;

  Future<void> setVolume(double volume);
  double get volume;
  Stream<double> get volumeStream;

  // Equalizer & Hardware DSP Effects API
  Future<void> setEqualizerEnabled(bool enabled);
  Future<void> setEqualizerBands(List<double> gains);
  Future<void> setLoudnessEnhancerGain(double gain);
  Future<void> setBassBoost(double boost);
  Future<List<double>> getBandFrequencies();

  Future<void> dispose();
}

/// Production implementation of ISoftifyAudioPlayer backed by just_audio.
/// Utilizes a dual-player active/standby architecture for true 0ms gapless track transitions.
class JustAudioPlayerAdapter implements ISoftifyAudioPlayer {
  final AudioPlayer _playerA;
  final AudioPlayer? _playerB;
  late AudioPlayer _activePlayer;
  AudioPlayer? _standbyPlayer;

  String? _preloadedSource;
  bool _isStandbyReady = false;
  int _crossfadeGenerationId = 0;

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

  StreamSubscription? _playerStateSub;
  StreamSubscription? _playbackEventSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _bufferedPositionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _volumeSub;
  StreamSubscription? _speedSub;

  final AndroidEqualizer? _equalizerA;
  final AndroidLoudnessEnhancer? _loudnessA;
  final AndroidEqualizer? _equalizerB;
  final AndroidLoudnessEnhancer? _loudnessB;

  bool _equalizerEnabled = true;
  List<double> _bandGains = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  double _loudnessGain = 0.0;
  double _bassBoost = 0.0;

  /// High-performance Spotify-grade audio load configuration:
  /// Sub-200ms initial buffer (250ms) for instantaneous playback start,
  /// with aggressive pre-buffering (15-60s) to guard 320kbps streams against network jitter.
  static const AudioLoadConfiguration defaultAudioLoadConfiguration =
      AudioLoadConfiguration(
    androidLoadControl: AndroidLoadControl(
      minBufferDuration: Duration(seconds: 15),
      maxBufferDuration: Duration(seconds: 60),
      bufferForPlaybackDuration: Duration(milliseconds: 250),
      bufferForPlaybackAfterRebufferDuration: Duration(milliseconds: 1000),
      prioritizeTimeOverSizeThresholds: true,
    ),
    darwinLoadControl: DarwinLoadControl(
      automaticallyWaitsToMinimizeStalling: false,
      preferredForwardBufferDuration: Duration(seconds: 30),
    ),
  );

  factory JustAudioPlayerAdapter({
    AudioPlayer? playerA,
    AudioPlayer? playerB,
    AudioLoadConfiguration? audioLoadConfiguration,
  }) {
    final bool enableEffects =
        Platform.isAndroid && Platform.environment['FLUTTER_TEST'] != 'true';
    final eqA = enableEffects ? AndroidEqualizer() : null;
    final loudA = enableEffects ? AndroidLoudnessEnhancer() : null;
    final eqB = enableEffects ? AndroidEqualizer() : null;
    final loudB = enableEffects ? AndroidLoudnessEnhancer() : null;

    final pA = playerA ??
        AudioPlayer(
          audioLoadConfiguration: audioLoadConfiguration,
          audioPipeline: (eqA != null && loudA != null)
              ? AudioPipeline(androidAudioEffects: [loudA, eqA])
              : null,
        );

    final pB = playerB ??
        (Platform.isLinux
            ? null
            : AudioPlayer(
                audioLoadConfiguration: audioLoadConfiguration,
                audioPipeline: (eqB != null && loudB != null)
                    ? AudioPipeline(androidAudioEffects: [loudB, eqB])
                    : null,
              ));

    return JustAudioPlayerAdapter._internal(
      playerA: pA,
      playerB: pB,
      equalizerA: eqA,
      loudnessA: loudA,
      equalizerB: eqB,
      loudnessB: loudB,
    );
  }

  JustAudioPlayerAdapter._internal({
    required AudioPlayer playerA,
    AudioPlayer? playerB,
    AndroidEqualizer? equalizerA,
    AndroidLoudnessEnhancer? loudnessA,
    AndroidEqualizer? equalizerB,
    AndroidLoudnessEnhancer? loudnessB,
  })  : _playerA = playerA,
        _playerB = playerB,
        _equalizerA = equalizerA,
        _loudnessA = loudnessA,
        _equalizerB = equalizerB,
        _loudnessB = loudnessB {
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
    _volumeSub?.cancel();
    _speedSub?.cancel();

    _playerStateSub = _activePlayer.playerStateStream.listen(
      _playerStateSubject.add,
      onError: (err) {
        _playerStateSubject.add(PlayerState(false, ProcessingState.idle));
      },
    );
    _playbackEventSub = _activePlayer.playbackEventStream.listen(
      _playbackEventSubject.add,
      onError: (err) {
        _playbackEventSubject.add(PlaybackEvent(
          processingState: ProcessingState.idle,
          updatePosition: _activePlayer.position,
        ));
      },
    );
    _positionSub = _activePlayer.positionStream.listen(
      _positionSubject.add,
      onError: (_) {},
    );
    _bufferedPositionSub = _activePlayer.bufferedPositionStream.listen(
      _bufferedPositionSubject.add,
      onError: (_) {},
    );
    _durationSub = _activePlayer.durationStream.listen(
      _durationSubject.add,
      onError: (_) {},
    );
    _volumeSub = _activePlayer.volumeStream.listen(
      _volumeSubject.add,
      onError: (_) {},
    );
    _speedSub = _activePlayer.speedStream.listen(
      _speedSubject.add,
      onError: (_) {},
    );

    _playerStateSubject.add(_activePlayer.playerState);
    _positionSubject.add(_activePlayer.position);
    _bufferedPositionSubject.add(_activePlayer.bufferedPosition);
    _durationSubject.add(_activePlayer.duration);
    _volumeSubject.add(_activePlayer.volume);
    _speedSubject.add(_activePlayer.speed);
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
  Future<Duration?> setUrl(String url, {Map<String, String>? headers, Duration? initialPosition}) async {
    clearPreloadedNext();
    final result = await _activePlayer.setUrl(url, headers: headers, initialPosition: initialPosition);
    _syncEqualizerEffects();
    return result;
  }

  @override
  Future<Duration?> setFilePath(String path, {Duration? initialPosition}) async {
    clearPreloadedNext();
    final result = await _activePlayer.setFilePath(path, initialPosition: initialPosition);
    _syncEqualizerEffects();
    return result;
  }

  AudioPlayer? _getStandbyPlayer() {
    if (_standbyPlayer != null) return _standbyPlayer;
    if (Platform.isLinux) {
      try {
        _standbyPlayer = AudioPlayer(
          audioLoadConfiguration: defaultAudioLoadConfiguration,
        );
      } catch (_) {
        _standbyPlayer = null;
      }
    }
    return _standbyPlayer;
  }

  @override
  Future<void> preloadNextUrl(String url, {Map<String, String>? headers}) async {
    final standby = _getStandbyPlayer();
    if (standby == null) return;
    if (_preloadedSource == url && _isStandbyReady) return;
    _preloadedSource = url;
    _isStandbyReady = false;
    try {
      await standby.stop();
      await standby.setUrl(url, headers: headers, preload: true);
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
    final standby = _getStandbyPlayer();
    if (standby == null) return;
    if (_preloadedSource == path && _isStandbyReady) return;
    _preloadedSource = path;
    _isStandbyReady = false;
    try {
      await standby.stop();
      await standby.setFilePath(path, preload: true);
      _isStandbyReady = true;
    } catch (_) {
      if (_preloadedSource == path) {
        _preloadedSource = null;
        _isStandbyReady = false;
      }
    }
  }

  @override
  bool get hasPreloadedNext =>
      _isStandbyReady &&
      _standbyPlayer != null &&
      _standbyPlayer!.processingState != ProcessingState.idle &&
      _standbyPlayer!.processingState != ProcessingState.completed;

  @override
  String? get preloadedSource => _preloadedSource;

  @override
  Future<void> playPreloadedNext({Duration crossfade = Duration.zero}) async {
    final standby = _standbyPlayer;
    if (!_isStandbyReady || standby == null) return;

    final outgoing = _activePlayer;
    final incoming = standby;

    _activePlayer = incoming;
    _standbyPlayer = outgoing;

    _preloadedSource = null;
    _isStandbyReady = false;

    _bindActivePlayerStreams();
    _syncEqualizerEffects();
    await _activePlayer.setSpeed(_speedSubject.value);

    final targetVol = _volumeSubject.value;
    final bool canCrossfade = crossfade > Duration.zero &&
        !Platform.isLinux &&
        outgoing.processingState != ProcessingState.idle;

    final currentGen = ++_crossfadeGenerationId;
    if (!canCrossfade) {
      await outgoing.stop();
      await incoming.setVolume(targetVol);
      await incoming.play();
      return;
    }

    // High-performance asynchronous equal-power crossfade:
    // Starts incoming playback immediately without stalling the caller or UI thread.
    await incoming.setVolume(0.0);
    await incoming.play();
    unawaited(_executeEqualPowerCrossfade(outgoing, incoming, crossfade, targetVol, currentGen));
  }

  Future<void> _executeEqualPowerCrossfade(
    AudioPlayer outgoing,
    AudioPlayer incoming,
    Duration crossfade,
    double targetVol,
    int generationId,
  ) async {
    const steps = 20;
    final stepDuration =
        Duration(milliseconds: (crossfade.inMilliseconds / steps).round());

    try {
      for (int i = 1; i <= steps; i++) {
        await Future.delayed(stepDuration);
        if (_crossfadeGenerationId != generationId || _activePlayer != incoming) break;
        final factor = i / steps;
        final theta = factor * (math.pi / 2.0);
        final outVol = (targetVol * math.cos(theta)).clamp(0.0, 1.0);
        final inVol = (targetVol * math.sin(theta)).clamp(0.0, 1.0);
        unawaited(outgoing.setVolume(outVol));
        unawaited(incoming.setVolume(inVol));
      }
    } finally {
      if (_crossfadeGenerationId == generationId) {
        await outgoing.stop();
        await outgoing.setVolume(targetVol);
        if (_activePlayer == incoming) {
          await incoming.setVolume(targetVol);
        }
      } else {
        // Superseded mid-transition: ensure incoming player is restored to full target volume
        if (_activePlayer == incoming) {
          await incoming.setVolume(targetVol);
        }
      }
    }
  }

  @override
  void clearPreloadedNext() {
    _crossfadeGenerationId++;
    _preloadedSource = null;
    _isStandbyReady = false;
    if (_standbyPlayer != null) {
      unawaited(_standbyPlayer!.stop());
    }
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
  Duration? get duration => _activePlayer.duration;

  @override
  Duration get bufferedPosition => _activePlayer.bufferedPosition;

  @override
  double get speed => _activePlayer.speed;

  @override
  Stream<double> get speedStream => _speedSubject.stream;

  @override
  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.25, 4.0);
    await _activePlayer.setSpeed(clamped);
    if (_standbyPlayer != null) {
      await _standbyPlayer!.setSpeed(clamped);
    }
    _speedSubject.add(clamped);
  }

  @override
  bool get playing => _activePlayer.playing;

  @override
  ProcessingState get processingState => _activePlayer.processingState;

  @override
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await _activePlayer.setVolume(clamped);
    if (_standbyPlayer != null) {
      await _standbyPlayer!.setVolume(clamped);
    }
    _volumeSubject.add(clamped);
  }

  @override
  double get volume => _activePlayer.volume;

  @override
  Stream<double> get volumeStream => _volumeSubject.stream;

  @override
  Future<void> setEqualizerEnabled(bool enabled) async {
    _equalizerEnabled = enabled;
    try {
      await _equalizerA?.setEnabled(enabled);
      await _equalizerB?.setEnabled(enabled);
    } catch (_) {}
    if (Platform.isLinux) {
      await _applyEqualizerSettings();
    }
  }

  @override
  Future<void> setEqualizerBands(List<double> gains) async {
    _bandGains = List.from(gains);
    await _applyEqualizerSettings();
  }

  @override
  Future<void> setLoudnessEnhancerGain(double gain) async {
    _loudnessGain = gain;
    final targetBels = gain.clamp(0.0, 1.0);
    try {
      final enabled = targetBels > 0.01;
      await _loudnessA?.setEnabled(enabled);
      await _loudnessB?.setEnabled(enabled);
      if (enabled) {
        await _loudnessA?.setTargetGain(targetBels);
        await _loudnessB?.setTargetGain(targetBels);
      }
    } catch (_) {}
    if (Platform.isLinux) {
      await _applyEqualizerSettings();
    }
  }

  @override
  Future<void> setBassBoost(double boost) async {
    _bassBoost = boost.clamp(0.0, 1.0);
    await _applyEqualizerSettings();
  }

  Future<void> _applyEqualizerSettings() async {
    await _applyToEqualizer(_equalizerA);
    await _applyToEqualizer(_equalizerB);
    if (Platform.isLinux) {
      await SoftifyLinuxAudioBackend.applyEqualizer(
        gains: _bandGains,
        bassBoost: _bassBoost,
        loudnessGain: _loudnessGain,
        enabled: _equalizerEnabled,
      );
    }
  }

  Future<void> _applyToEqualizer(AndroidEqualizer? eq) async {
    if (eq == null) return;
    try {
      final params = await eq.parameters.timeout(const Duration(milliseconds: 100));
      if (params.bands.length == 5 && _bandGains.length >= 10) {
        // Map 10 parametric bands into 5 hardware OpenSL bands
        final h0 = ((_bandGains[0] + _bandGains[1]) / 2.0 + _bassBoost * 5.0).clamp(params.minDecibels, params.maxDecibels);
        final h1 = ((_bandGains[2] + _bandGains[3]) / 2.0 + _bassBoost * 2.5).clamp(params.minDecibels, params.maxDecibels);
        final h2 = ((_bandGains[4] + _bandGains[5]) / 2.0).clamp(params.minDecibels, params.maxDecibels);
        final h3 = ((_bandGains[6] + _bandGains[7]) / 2.0).clamp(params.minDecibels, params.maxDecibels);
        final h4 = ((_bandGains[8] + _bandGains[9]) / 2.0).clamp(params.minDecibels, params.maxDecibels);
        final hardwareGains = [h0, h1, h2, h3, h4];
        for (int i = 0; i < 5; i++) {
          await params.bands[i].setGain(hardwareGains[i]);
        }
      } else {
        for (int i = 0; i < params.bands.length && i < _bandGains.length; i++) {
          double extraBass = 0.0;
          if (i == 0) extraBass = _bassBoost * 5.0;
          if (i == 1) extraBass = _bassBoost * 2.5;
          final effectiveGain = (_bandGains[i] + extraBass).clamp(params.minDecibels, params.maxDecibels);
          await params.bands[i].setGain(effectiveGain);
        }
      }
    } catch (_) {}
  }

  void _syncEqualizerEffects() {
    if (!_equalizerEnabled) return;
    unawaited(setEqualizerEnabled(_equalizerEnabled));
    unawaited(_applyEqualizerSettings());
    if (_loudnessGain > 0.01) {
      unawaited(setLoudnessEnhancerGain(_loudnessGain));
    }
  }

  @override
  Future<List<double>> getBandFrequencies() async {
    return const [
      31.0,
      62.0,
      125.0,
      250.0,
      500.0,
      1000.0,
      2000.0,
      4000.0,
      8000.0,
      16000.0,
    ];
  }

  @override
  Future<void> dispose() async {
    _playerStateSub?.cancel();
    _playbackEventSub?.cancel();
    _positionSub?.cancel();
    _bufferedPositionSub?.cancel();
    _durationSub?.cancel();
    _volumeSub?.cancel();
    _speedSub?.cancel();

    await _playerStateSubject.close();
    await _playbackEventSubject.close();
    await _positionSubject.close();
    await _bufferedPositionSubject.close();
    await _durationSubject.close();
    await _volumeSubject.close();
    await _speedSubject.close();

    await Future.wait([
      _playerA.dispose(),
      if (_playerB != null) _playerB.dispose(),
      if (_standbyPlayer != null &&
          _standbyPlayer != _playerA &&
          _standbyPlayer != _playerB)
        _standbyPlayer!.dispose(),
    ]);
  }
}
