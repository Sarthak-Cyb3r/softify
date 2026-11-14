import 'track.dart';

class HistoryItem {
  final int id;
  final Track track;
  final DateTime playedAt;
  final double completedRatio;

  const HistoryItem({
    required this.id,
    required this.track,
    required this.playedAt,
    required this.completedRatio,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
