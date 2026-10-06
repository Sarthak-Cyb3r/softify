import '../entities/history_item.dart';
import '../entities/playlist.dart';
import '../entities/playlist_entry.dart';
import '../entities/queue_state.dart';
import '../entities/track.dart';

abstract class ILibraryRepository {
  // Track operations
  Future<void> upsertTrack(Track track);
  Future<Track?> getTrackById(String id);
  Future<Track?> getTrackBySourceId(String sourceId);
  Future<void> markTrackUnavailable(String id, bool isUnavailable);

  // Favorites / Liked Tracks
  Future<void> setLiked(String trackId, bool isLiked, {Track? track});
  Future<bool> isLiked(String trackId);
  Stream<List<Track>> watchLikedTracks();
  Future<List<Track>> getLikedTracks();

  // Playlists
  Future<Playlist> createPlaylist(
    String name, {
    String? description,
    bool isImported = false,
    String? sourceUrl,
  });
  Future<void> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
  });
  Future<void> deletePlaylist(String playlistId);
  Stream<List<Playlist>> watchPlaylists();
  Future<List<Playlist>> getPlaylists();
  Stream<PlaylistWithTracks?> watchPlaylistWithTracks(String playlistId);
  Future<PlaylistWithTracks?> getPlaylistWithTracks(String playlistId);
  Future<void> addTrackToPlaylist(String playlistId, Track track);
  Future<void> addTracksToPlaylist(String playlistId, List<Track> tracks);
  Future<void> removeTrackFromPlaylist(String playlistId, int position);
  Future<void> reorderPlaylistTrack(String playlistId, int oldPosition, int newPosition);

  // Play History
  Future<void> recordPlayHistory(Track track, double completedRatio);
  Stream<List<HistoryItem>> watchPlayHistory({int limit = 50});
  Future<void> clearPlayHistory();

  // Queue State Persistence
  Future<void> saveQueueState(List<Track> queue, int currentIndex, Duration position);
  Future<QueueState> getQueueState();
  Future<void> clearQueueState();

  // Lyrics Cache
  Future<void> cacheLyrics(
    String trackId, {
    String? syncedLrc,
    String? plainText,
    bool isNotFound = false,
  });
  Future<({String? syncedLrc, String? plainText, bool isNotFound})?> getCachedLyrics(String trackId);
}
