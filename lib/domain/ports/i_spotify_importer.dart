import '../entities/spotify_import.dart';
import '../entities/track.dart';

abstract class ISpotifyImporter {
  /// Extracts the Spotify playlist ID from a URL, embed link, or URI.
  String? extractPlaylistId(String input);

  /// Keylessly fetches public Spotify playlist metadata and tracks.
  Future<SpotifyImportPlaylist> fetchPlaylist(String urlOrId);

  /// Matches a Spotify track against the catalog and returns the resolved Track with confidence.
  Future<Track?> matchTrack(SpotifyTrackItem spotifyTrack);
}
