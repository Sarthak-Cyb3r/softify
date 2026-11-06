import 'track.dart';

enum SpotifyEntityType {
  playlist,
  album,
  track,
}

class SpotifyEntityRef {
  final String id;
  final SpotifyEntityType type;

  const SpotifyEntityRef({required this.id, required this.type});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotifyEntityRef &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ type.hashCode;

  @override
  String toString() => 'SpotifyEntityRef(id: $id, type: $type)';
}

class SpotifyTrackItem {
  final String spotifyUri;
  final String title;
  final String artist;
  final String? album;
  final Duration duration;
  final String? coverUrl;
  final Track? matchedTrack;
  final double confidence; // 0.0 to 1.0
  final bool isMatched;

  const SpotifyTrackItem({
    required this.spotifyUri,
    required this.title,
    required this.artist,
    this.album,
    required this.duration,
    this.coverUrl,
    this.matchedTrack,
    this.confidence = 0.0,
    this.isMatched = false,
  });

  SpotifyTrackItem copyWith({
    String? spotifyUri,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? coverUrl,
    Track? matchedTrack,
    double? confidence,
    bool? isMatched,
  }) {
    return SpotifyTrackItem(
      spotifyUri: spotifyUri ?? this.spotifyUri,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverUrl: coverUrl ?? this.coverUrl,
      matchedTrack: matchedTrack ?? this.matchedTrack,
      confidence: confidence ?? this.confidence,
      isMatched: isMatched ?? this.isMatched,
    );
  }
}

class SpotifyImportPlaylist {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final List<SpotifyTrackItem> tracks;

  /// Non-fatal warning shown to the user, e.g. when the Web API could only be
  /// partially consulted and the list came from the embed page instead.
  final String? notice;

  const SpotifyImportPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    required this.tracks,
    this.notice,
  });

  int get matchedCount => tracks.where((t) => t.isMatched).length;
  int get totalCount => tracks.length;
  double get matchPercentage =>
      totalCount == 0 ? 0.0 : (matchedCount / totalCount) * 100.0;

  SpotifyImportPlaylist copyWith({
    String? id,
    String? name,
    String? description,
    String? coverUrl,
    List<SpotifyTrackItem>? tracks,
    String? notice,
  }) {
    return SpotifyImportPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      tracks: tracks ?? this.tracks,
      notice: notice ?? this.notice,
    );
  }
}

class SpotifyUserProfile {
  final String id;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final String? product; // e.g. 'premium', 'free'
  final String? country;
  final int? totalPlaylists;

  const SpotifyUserProfile({
    required this.id,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.product,
    this.country,
    this.totalPlaylists,
  });

  bool get isPremium => product?.toLowerCase() == 'premium';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'avatar_url': avatarUrl,
      'product': product,
      'country': country,
      'total_playlists': totalPlaylists,
    };
  }

  factory SpotifyUserProfile.fromMap(Map<String, dynamic> map) {
    return SpotifyUserProfile(
      id: map['id'] as String? ?? '',
      displayName: map['display_name'] as String? ?? 'Spotify User',
      email: map['email'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      product: map['product'] as String?,
      country: map['country'] as String?,
      totalPlaylists: (map['total_playlists'] as num?)?.toInt(),
    );
  }
}

class SpotifyUserPlaylistSummary {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final int trackCount;
  final String? ownerName;
  final bool isPublic;
  final bool isCollaborative;
  final String? snapshotId;

  const SpotifyUserPlaylistSummary({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    required this.trackCount,
    this.ownerName,
    this.isPublic = true,
    this.isCollaborative = false,
    this.snapshotId,
  });

  String get spotifyUrl => 'https://open.spotify.com/playlist/$id';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cover_url': coverUrl,
      'track_count': trackCount,
      'owner_name': ownerName,
      'is_public': isPublic,
      'is_collaborative': isCollaborative,
      'snapshot_id': snapshotId,
    };
  }

  factory SpotifyUserPlaylistSummary.fromMap(Map<String, dynamic> map) {
    return SpotifyUserPlaylistSummary(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Untitled Playlist',
      description: map['description'] as String?,
      coverUrl: map['cover_url'] as String?,
      trackCount: (map['track_count'] as num?)?.toInt() ?? 0,
      ownerName: map['owner_name'] as String?,
      isPublic: (map['is_public'] as bool?) ?? true,
      isCollaborative: (map['is_collaborative'] as bool?) ?? false,
      snapshotId: map['snapshot_id'] as String?,
    );
  }
}
