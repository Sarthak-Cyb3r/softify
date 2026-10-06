class Track {
  final String id;
  final String sourceId;
  final String title;
  final String artist;
  final String? album;
  final Duration duration;
  final String? coverUrl;
  final double? matchConfidence;
  final bool isLiked;
  final bool isUnavailable;

  const Track({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.artist,
    this.album,
    required this.duration,
    this.coverUrl,
    this.matchConfidence,
    this.isLiked = false,
    this.isUnavailable = false,
  });

  Track copyWith({
    String? id,
    String? sourceId,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? coverUrl,
    double? matchConfidence,
    bool? isLiked,
    bool? isUnavailable,
  }) {
    return Track(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverUrl: coverUrl ?? this.coverUrl,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      isLiked: isLiked ?? this.isLiked,
      isUnavailable: isUnavailable ?? this.isUnavailable,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_id': sourceId,
      'title': title,
      'artist': artist,
      'album': album,
      'duration_ms': duration.inMilliseconds,
      'cover_url': coverUrl,
      'match_confidence': matchConfidence,
      'is_liked': isLiked,
      'is_unavailable': isUnavailable,
    };
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'] as String,
      sourceId: map['source_id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String?,
      duration: Duration(milliseconds: map['duration_ms'] as int),
      coverUrl: map['cover_url'] as String?,
      matchConfidence: (map['match_confidence'] as num?)?.toDouble(),
      isLiked: (map['is_liked'] as bool?) ?? false,
      isUnavailable: (map['is_unavailable'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Track &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sourceId == other.sourceId;

  @override
  int get hashCode => id.hashCode ^ sourceId.hashCode;

  @override
  String toString() => 'Track(id: $id, sourceId: $sourceId, title: "$title", artist: "$artist")';
}
