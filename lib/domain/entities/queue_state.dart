import 'track.dart';

class QueueState {
  final List<Track> tracks;
  final int currentIndex;
  final Duration position;

  const QueueState({
    required this.tracks,
    this.currentIndex = 0,
    this.position = Duration.zero,
  });

  Track? get currentTrack =>
      (currentIndex >= 0 && currentIndex < tracks.length) ? tracks[currentIndex] : null;

  QueueState copyWith({
    List<Track>? tracks,
    int? currentIndex,
    Duration? position,
  }) {
    return QueueState(
      tracks: tracks ?? this.tracks,
      currentIndex: currentIndex ?? this.currentIndex,
      position: position ?? this.position,
    );
  }

  static const QueueState empty = QueueState(tracks: []);
}
