class TasteProfileEntity {
  final int? id;
  final String entityType; // 'artist' | 'genre' | 'language'
  final String entityId;
  final double slowWeight; // 14-day half-life
  final double fastWeight; // 4-hour half-life
  final int updatedAt;

  const TasteProfileEntity({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.slowWeight,
    required this.fastWeight,
    required this.updatedAt,
  });

  /// Blended affinity score: 40% real-time fast session mood, 60% long-term slow taste
  double get blendedAffinity => (0.4 * fastWeight) + (0.6 * slowWeight);
}

class CooccurrenceEdge {
  final String trackA;
  final String trackB;
  final double score; // Pointwise Mutual Information (PMI)
  final int updatedAt;

  const CooccurrenceEdge({
    required this.trackA,
    required this.trackB,
    required this.score,
    required this.updatedAt,
  });
}
