class Playlist {
  final String id;
  final String name;
  final String? description;
  final bool isImported;
  final String? sourceUrl;
  final DateTime createdAt;
  final int trackCount;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.isImported = false,
    this.sourceUrl,
    required this.createdAt,
    this.trackCount = 0,
  });

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    bool? isImported,
    String? sourceUrl,
    DateTime? createdAt,
    int? trackCount,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isImported: isImported ?? this.isImported,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      trackCount: trackCount ?? this.trackCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_imported': isImported,
      'source_url': sourceUrl,
      'created_at': createdAt.millisecondsSinceEpoch,
      'track_count': trackCount,
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      isImported: (map['is_imported'] as bool?) ?? false,
      sourceUrl: map['source_url'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      trackCount: (map['track_count'] as int?) ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Playlist(id: $id, name: "$name", tracks: $trackCount)';
}
