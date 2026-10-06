import 'playlist.dart';
import 'track.dart';

enum MatchStatus {
  matched,
  unmatched,
  pending;

  static MatchStatus fromString(String status) {
    return switch (status.toLowerCase()) {
      'matched' => MatchStatus.matched,
      'unmatched' => MatchStatus.unmatched,
      _ => MatchStatus.pending,
    };
  }

  String toDbString() => name;
}

class PlaylistEntry {
  final String playlistId;
  final int position;
  final String? trackId;
  final Track? track;
  final String originalTitle;
  final String originalArtist;
  final MatchStatus matchStatus;

  const PlaylistEntry({
    required this.playlistId,
    required this.position,
    this.trackId,
    this.track,
    required this.originalTitle,
    required this.originalArtist,
    this.matchStatus = MatchStatus.matched,
  });

  PlaylistEntry copyWith({
    String? playlistId,
    int? position,
    String? trackId,
    Track? track,
    String? originalTitle,
    String? originalArtist,
    MatchStatus? matchStatus,
  }) {
    return PlaylistEntry(
      playlistId: playlistId ?? this.playlistId,
      position: position ?? this.position,
      trackId: trackId ?? this.trackId,
      track: track ?? this.track,
      originalTitle: originalTitle ?? this.originalTitle,
      originalArtist: originalArtist ?? this.originalArtist,
      matchStatus: matchStatus ?? this.matchStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistEntry &&
          runtimeType == other.runtimeType &&
          playlistId == other.playlistId &&
          position == other.position;

  @override
  int get hashCode => playlistId.hashCode ^ position.hashCode;
}

class PlaylistWithTracks {
  final Playlist playlist;
  final List<PlaylistEntry> entries;

  const PlaylistWithTracks({
    required this.playlist,
    required this.entries,
  });

  List<Track> get resolvedTracks =>
      entries.where((e) => e.track != null).map((e) => e.track!).toList();
}
