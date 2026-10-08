import 'track.dart';

class SpotifyTrackItem {
  final String spotifyUri;
  final String title;
  final String artist;
  final Duration duration;
  final String? coverUrl;
  final Track? matchedTrack;
  final double confidence; // 0.0 to 1.0
  final bool isMatched;

  const SpotifyTrackItem({
    required this.spotifyUri,
    required this.title,
    required this.artist,
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
