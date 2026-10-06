import '../entities/track.dart';

abstract class ICatalogRepository {
  /// Searches YouTube Music keylessly for tracks matching the query.
  Future<List<Track>> search(String query, {int limit = 20});

  /// Fetches top trending / popular music tracks.
  Future<List<Track>> getTrendingTracks({int limit = 30});

  /// Returns real-time search suggestions for autocomplete.
  Future<List<String>> getSearchSuggestions(String query);

  /// Fetches top tracks for an artist.
  Future<List<Track>> getArtistTracks(String artist, {int limit = 25});

  /// Fetches track listing for an album.
  Future<List<Track>> getAlbumTracks(String album, String artist, {int limit = 25});

  /// Fetches recommended / related tracks for autoplay and radio.
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15});
}
