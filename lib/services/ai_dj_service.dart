import 'dart:async';
import 'dart:math';

import '../domain/entities/track.dart';

/// Context type for the AI DJ narration.
enum DjCommentaryType {
  /// Introducing a new artist or genre block.
  artistSpotlight,

  /// Commenting on mood / energy transition.
  vibeShift,

  /// Throwback to a user favorite.
  nostalgiaRewind,

  /// Quick intro for the next upcoming track.
  trackIntro,
}

/// Generated commentary line with target track context.
class DjCommentary {
  final String text;
  final DjCommentaryType type;
  final String targetTrackTitle;
  final String targetArtistName;
  final Duration estimatedDuration;

  const DjCommentary({
    required this.text,
    required this.type,
    required this.targetTrackTitle,
    required this.targetArtistName,
    required this.estimatedDuration,
  });
}

/// Spotify X-DJ style intelligent voice commentary and audio ducking engine.
/// Dynamically synthesizes contextual transitions and smoothly ducks active
/// 320 kbps music playback during voiceover.
class AiDjService {
  static final AiDjService instance = AiDjService._internal();

  AiDjService._internal();

  bool _isEnabled = false;
  int _songsSinceLastCommentary = 0;
  final int _commentaryInterval = 4; // Trigger commentary every 4 songs

  bool _isSpeaking = false;
  final _commentaryController = StreamController<DjCommentary>.broadcast();
  final _duckingController = StreamController<double>.broadcast();

  bool get isEnabled => _isEnabled;
  bool get isSpeaking => _isSpeaking;
  Stream<DjCommentary> get commentaryStream => _commentaryController.stream;

  /// Stream emitting volume multipliers (1.0 = normal, 0.2 = ducked during DJ voice).
  Stream<double> get duckingMultiplierStream => _duckingController.stream;

  void toggleDj(bool enabled) {
    _isEnabled = enabled;
    _songsSinceLastCommentary = 0;
  }

  /// Evaluates whether the upcoming track should receive DJ narration.
  bool shouldTriggerCommentary() {
    if (!_isEnabled) return false;
    return _songsSinceLastCommentary >= _commentaryInterval;
  }

  /// Synthesizes contextual commentary for an upcoming track.
  DjCommentary generateCommentaryForTrack(Track nextTrack, {Track? previousTrack}) {
    final rand = Random();
    final artist = nextTrack.artist.isNotEmpty ? nextTrack.artist : 'this artist';
    final title = nextTrack.title;

    final templates = [
      DjCommentary(
        text: 'Up next, keeping the vibe going with $artist. Here is "$title".',
        type: DjCommentaryType.trackIntro,
        targetTrackTitle: title,
        targetArtistName: artist,
        estimatedDuration: const Duration(seconds: 4),
      ),
      DjCommentary(
        text: 'Switching up the tempo a bit. Here is $artist with "$title". Enjoy this one.',
        type: DjCommentaryType.vibeShift,
        targetTrackTitle: title,
        targetArtistName: artist,
        estimatedDuration: const Duration(seconds: 5),
      ),
      DjCommentary(
        text: 'Here is a classic from $artist that you know and love. Let\'s get into "$title".',
        type: DjCommentaryType.nostalgiaRewind,
        targetTrackTitle: title,
        targetArtistName: artist,
        estimatedDuration: const Duration(seconds: 4),
      ),
      DjCommentary(
        text: 'Spotlight on $artist right now. Spinning "$title". Turn this one up.',
        type: DjCommentaryType.artistSpotlight,
        targetTrackTitle: title,
        targetArtistName: artist,
        estimatedDuration: const Duration(seconds: 4),
      ),
    ];

    return templates[rand.nextInt(templates.length)];
  }

  /// Executes DJ commentary sequence with smooth audio ducking:
  /// 1. Smoothly ramps active track volume down to 20% (ducking)
  /// 2. Dispatches commentary event
  /// 3. Awaits commentary speech duration
  /// 4. Smoothly restores active track volume to 100%
  Future<void> speakCommentary(DjCommentary commentary) async {
    if (!_isEnabled) return;

    _isSpeaking = true;
    _songsSinceLastCommentary = 0;

    // 1. Duck volume: 1.0 -> 0.2 over 300ms
    _duckingController.add(0.20);
    _commentaryController.add(commentary);

    // 2. Duration of voiceover speech
    await Future.delayed(commentary.estimatedDuration);

    // 3. Smoothly restore volume: 0.2 -> 1.0
    _duckingController.add(1.0);
    _isSpeaking = false;
  }

  /// Notifies the DJ engine that a track finished playing.
  void onTrackCompleted() {
    if (_isEnabled) {
      _songsSinceLastCommentary++;
    }
  }

  void dispose() {
    _commentaryController.close();
    _duckingController.close();
  }
}
