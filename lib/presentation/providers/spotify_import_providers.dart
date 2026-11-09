import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/importer/keyless_spotify_importer.dart';
import '../../domain/entities/spotify_import.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_library_repository.dart';
import '../../domain/ports/i_spotify_importer.dart';
import 'player_providers.dart';

import '../../data/services/spotify_api_service.dart';
import '../../data/services/spotify_auth_service.dart';

final spotifyAuthServiceProvider = Provider<SpotifyAuthService>((ref) {
  final db = ref.watch(databaseProvider);
  return SpotifyAuthService(db: db);
});

final spotifyImporterProvider = Provider<ISpotifyImporter>((ref) {
  final catalog = ref.watch(catalogRepositoryProvider);
  final authService = ref.watch(spotifyAuthServiceProvider);
  final spotifyApi = ref.watch(spotifyApiServiceProvider);
  return KeylessSpotifyImporter(
    catalog: catalog,
    authService: authService,
    spotifyApi: spotifyApi,
  );
});

final spotifyAuthStateProvider =
    FutureProvider.autoDispose<({bool isLoggedIn, String? userName})>((ref) async {
  final authService = ref.watch(spotifyAuthServiceProvider);
  final loggedIn = await authService.isLoggedIn();
  final userName = await authService.getConnectedUserName();
  return (isLoggedIn: loggedIn, userName: userName);
});

final spotifyUserProfileProvider =
    FutureProvider.autoDispose<SpotifyUserProfile?>((ref) async {
  final authService = ref.watch(spotifyAuthServiceProvider);
  return await authService.getConnectedUserProfile();
});

final spotifyUserPlaylistsProvider =
    FutureProvider.autoDispose<List<SpotifyUserPlaylistSummary>>((ref) async {
  final authService = ref.watch(spotifyAuthServiceProvider);
  final loggedIn = await authService.isLoggedIn();
  if (!loggedIn) return const [];
  final spotifyApi = ref.watch(spotifyApiServiceProvider);
  return await spotifyApi.getCurrentUserPlaylists();
});

enum SpotifyImportStatus {
  idle,
  fetchingPlaylist,
  matchingTracks,
  matched,
  importingToDb,
  importedSuccess,
  error,
}

class SpotifyImportState {
  final SpotifyImportStatus status;
  final String? errorMessage;
  final String inputUrl;
  final SpotifyImportPlaylist? playlist;
  final int matchedProgress;
  final int totalToMatch;
  final String? importedPlaylistId;

  /// Tracks pulled from the Web API so far while status is
  /// [SpotifyImportStatus.fetchingPlaylist].
  final int fetchProgress;

  const SpotifyImportState({
    this.status = SpotifyImportStatus.idle,
    this.errorMessage,
    this.inputUrl = '',
    this.playlist,
    this.matchedProgress = 0,
    this.totalToMatch = 0,
    this.importedPlaylistId,
    this.fetchProgress = 0,
  });

  SpotifyImportState copyWith({
    SpotifyImportStatus? status,
    String? errorMessage,
    String? inputUrl,
    SpotifyImportPlaylist? playlist,
    int? matchedProgress,
    int? totalToMatch,
    String? importedPlaylistId,
    int? fetchProgress,
  }) {
    return SpotifyImportState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      inputUrl: inputUrl ?? this.inputUrl,
      playlist: playlist ?? this.playlist,
      matchedProgress: matchedProgress ?? this.matchedProgress,
      totalToMatch: totalToMatch ?? this.totalToMatch,
      importedPlaylistId: importedPlaylistId ?? this.importedPlaylistId,
      fetchProgress: fetchProgress ?? this.fetchProgress,
    );
  }
}

class SpotifyImportNotifier extends StateNotifier<SpotifyImportState> {
  final ISpotifyImporter _importer;
  final ILibraryRepository _libraryRepo;
  final SpotifyApiService _spotifyApi;

  SpotifyImportNotifier({
    required ISpotifyImporter importer,
    required ILibraryRepository libraryRepo,
    required SpotifyApiService spotifyApi,
  })  : _importer = importer,
        _libraryRepo = libraryRepo,
        _spotifyApi = spotifyApi,
        super(const SpotifyImportState());

  void setInputUrl(String url) {
    state = state.copyWith(inputUrl: url);
  }

  void reset() {
    state = const SpotifyImportState();
  }

  Future<void> loadUserLikedSongs() async {
    state = state.copyWith(
      status: SpotifyImportStatus.fetchingPlaylist,
      inputUrl: 'spotify:user:liked-songs',
      errorMessage: null,
      fetchProgress: 0,
    );

    try {
      final playlist = await _spotifyApi.getCurrentUserLikedTracks(
        onProgress: (loaded, total) {
          if (mounted) state = state.copyWith(fetchProgress: loaded);
        },
      );

      if (playlist.tracks.isEmpty) {
        state = state.copyWith(
          status: SpotifyImportStatus.error,
          errorMessage: 'No Liked Songs found in your connected Spotify account.',
          playlist: playlist,
        );
        return;
      }

      await _prepareAndQuickMatchPlaylist(playlist);
    } catch (e) {
      state = state.copyWith(
        status: SpotifyImportStatus.error,
        errorMessage: 'Failed to load Spotify Liked Songs: $e',
      );
    }
  }

  Future<void> loadUserPlaylist(SpotifyUserPlaylistSummary summary) async {
    state = state.copyWith(
      status: SpotifyImportStatus.fetchingPlaylist,
      inputUrl: summary.spotifyUrl,
      errorMessage: null,
      fetchProgress: 0,
    );

    try {
      final playlist = await _spotifyApi.getPlaylistWithTracksWebApi(
        summary.id,
        onProgress: (loaded, total) {
          if (mounted) state = state.copyWith(fetchProgress: loaded);
        },
      );

      if (playlist.tracks.isEmpty) {
        state = state.copyWith(
          status: SpotifyImportStatus.error,
          errorMessage: 'No playable tracks found in "${summary.name}".',
          playlist: playlist,
        );
        return;
      }

      await _prepareAndQuickMatchPlaylist(playlist);
    } catch (e) {
      state = state.copyWith(
        status: SpotifyImportStatus.error,
        errorMessage: 'Failed to load "${summary.name}": $e',
      );
    }
  }

  Future<void> loadAndMatchPlaylist(String urlOrId) async {
    final cleanUrl = urlOrId.trim();
    if (cleanUrl.isEmpty) {
      state = state.copyWith(
        status: SpotifyImportStatus.error,
        errorMessage: 'Please enter a valid Spotify playlist link or URI.',
      );
      return;
    }

    state = state.copyWith(
      status: SpotifyImportStatus.fetchingPlaylist,
      inputUrl: cleanUrl,
      errorMessage: null,
      fetchProgress: 0,
    );

    try {
      final playlist = await _importer.fetchPlaylist(
        cleanUrl,
        onProgress: (loaded) {
          if (mounted) state = state.copyWith(fetchProgress: loaded);
        },
      );
      if (playlist.tracks.isEmpty) {
        state = state.copyWith(
          status: SpotifyImportStatus.error,
          errorMessage: 'No playable tracks found in this Spotify playlist.',
          playlist: playlist,
        );
        return;
      }

      await _prepareAndQuickMatchPlaylist(playlist);
    } catch (e) {
      final cleanMessage = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('FormatException: ', '');
      state = state.copyWith(
        status: SpotifyImportStatus.error,
        errorMessage: cleanMessage,
      );
    }
  }

  Future<void> _prepareAndQuickMatchPlaylist(SpotifyImportPlaylist playlist) async {
    final total = playlist.tracks.length;
    final playlistCover = playlist.coverUrl;

    state = state.copyWith(
      status: SpotifyImportStatus.matchingTracks,
      playlist: playlist,
      matchedProgress: 0,
      totalToMatch: total,
    );

    final List<SpotifyTrackItem> preparedTracks = [];
    for (int i = 0; i < total; i++) {
      final item = playlist.tracks[i];
      var rawUri = item.spotifyUri;
      if (rawUri.contains('?')) {
        rawUri = rawUri.split('?').first;
      }
      final trackId = rawUri.startsWith('spotify:track:')
          ? rawUri.replaceFirst('spotify:track:', '')
          : (rawUri.isNotEmpty
              ? rawUri.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
              : '${item.title}_${item.artist}'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_'));

      // Ensure track cover is NEVER the playlist's overall cover art
      final itemCover = (item.coverUrl != null &&
              item.coverUrl != playlistCover &&
              !item.coverUrl!.contains('hqdefault'))
          ? item.coverUrl
          : null;

      final canonicalTrack = Track(
        id: 'spotify_$trackId',
        sourceId: 'spotify_$trackId',
        title: item.title,
        artist: item.artist,
        album: item.album,
        duration: item.duration,
        coverUrl: itemCover,
        matchConfidence: 1.0,
      );

      preparedTracks.add(
        item.copyWith(
          coverUrl: itemCover,
          matchedTrack: canonicalTrack,
          isMatched: true,
          confidence: 1.0,
        ),
      );
    }

    state = state.copyWith(
      status: SpotifyImportStatus.matched,
      matchedProgress: total,
      totalToMatch: total,
      playlist: playlist.copyWith(tracks: preparedTracks),
    );
  }

  Future<void> _matchPlaylistItems(SpotifyImportPlaylist playlist) async {
    await _prepareAndQuickMatchPlaylist(playlist);
  }

  void updateTrackMatch(int index, Track newTrack) {
    final currentPlaylist = state.playlist;
    if (currentPlaylist == null || index < 0 || index >= currentPlaylist.tracks.length) {
      return;
    }

    final tracks = List<SpotifyTrackItem>.from(currentPlaylist.tracks);
    tracks[index] = tracks[index].copyWith(
      matchedTrack: newTrack,
      isMatched: true,
      confidence: 1.0,
    );

    state = state.copyWith(
      playlist: currentPlaylist.copyWith(tracks: tracks),
    );
  }

  Future<int> batchImportUserPlaylists(
    List<SpotifyUserPlaylistSummary> summaries, {
    void Function(int done, int total, String currentName)? onProgress,
  }) async {
    int importedCount = 0;
    for (int i = 0; i < summaries.length; i++) {
      final summary = summaries[i];
      onProgress?.call(importedCount, summaries.length, summary.name);
      try {
        final playlist =
            await _spotifyApi.getPlaylistWithTracksWebApi(summary.id);
        if (playlist.tracks.isEmpty) continue;

        final newPlaylist = await _libraryRepo.createPlaylist(
          playlist.name,
          description: playlist.description ?? 'Imported from Spotify',
          isImported: true,
          sourceUrl: summary.spotifyUrl,
        );

        final List<Track> tracksToInsert = [];
        final List<({String title, String artist})> meta = [];

        final playlistCover = playlist.coverUrl;
        for (final item in playlist.tracks) {
          var rawUri = item.spotifyUri;
          if (rawUri.contains('?')) {
            rawUri = rawUri.split('?').first;
          }
          final trackId = rawUri.startsWith('spotify:track:')
              ? rawUri.replaceFirst('spotify:track:', '')
              : (rawUri.isNotEmpty
                  ? rawUri.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
                  : '${item.title}_${item.artist}'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_'));

          final itemCover = (item.coverUrl != null &&
                  item.coverUrl != playlistCover &&
                  !item.coverUrl!.contains('hqdefault'))
              ? item.coverUrl
              : null;

          final track = Track(
            id: 'spotify_$trackId',
            sourceId: 'spotify_$trackId',
            title: item.title,
            artist: item.artist,
            album: item.album,
            duration: item.duration,
            coverUrl: itemCover,
          );
          tracksToInsert.add(track);
          meta.add((title: item.title, artist: item.artist));
        }

        if (tracksToInsert.isNotEmpty) {
          await _libraryRepo.addTracksToPlaylist(
            newPlaylist.id,
            tracksToInsert,
            originalMetadata: meta,
          );
          importedCount++;
        }
      } catch (_) {}
    }
    onProgress?.call(importedCount, summaries.length, 'Completed');
    return importedCount;
  }

  Future<String?> commitImportToLibrary() async {
    final currentPlaylist = state.playlist;
    if (currentPlaylist == null) return null;

    state = state.copyWith(status: SpotifyImportStatus.importingToDb);

    try {
      final newPlaylist = await _libraryRepo.createPlaylist(
        currentPlaylist.name,
        description: currentPlaylist.description ?? 'Imported from Spotify',
        isImported: true,
        sourceUrl: currentPlaylist.id.startsWith('me_')
            ? 'spotify:user:library'
            : 'https://open.spotify.com/playlist/${currentPlaylist.id}',
      );

      final List<Track> tracksToInsert = [];
      final List<({String title, String artist})> originalMeta = [];
      final playlistCover = currentPlaylist.coverUrl;

      for (final t in currentPlaylist.tracks) {
        var rawUri = t.spotifyUri;
        if (rawUri.contains('?')) {
          rawUri = rawUri.split('?').first;
        }
        final cleanTrackId = rawUri.startsWith('spotify:track:')
            ? rawUri.replaceFirst('spotify:track:', '')
            : (rawUri.isNotEmpty
                ? rawUri.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
                : '${t.title}_${t.artist}'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_'));

        // Never let playlist artwork bleed onto individual tracks
        String? finalCover = (t.coverUrl != null &&
                t.coverUrl != playlistCover &&
                !t.coverUrl!.contains('hqdefault'))
            ? t.coverUrl
            : null;
        if (finalCover == null || finalCover.contains('hqdefault')) {
          final candidateCover = t.matchedTrack?.coverUrl;
          if (candidateCover != null &&
              candidateCover != playlistCover &&
              !candidateCover.contains('hqdefault')) {
            finalCover = candidateCover;
          }
        }

        final canonicalTrack = Track(
          id: 'spotify_$cleanTrackId',
          sourceId: 'spotify_$cleanTrackId',
          title: t.title,
          artist: t.artist,
          album: t.album ?? t.matchedTrack?.album,
          duration: t.duration > Duration.zero
              ? t.duration
              : (t.matchedTrack?.duration ?? Duration.zero),
          coverUrl: finalCover,
          matchConfidence: t.confidence > 0 ? t.confidence : 1.0,
        );
        tracksToInsert.add(canonicalTrack);
        originalMeta.add((title: t.title, artist: t.artist));
      }

      // Atomic single-transaction batch insert with original Spotify titles & artists
      await _libraryRepo.addTracksToPlaylist(
        newPlaylist.id,
        tracksToInsert,
        originalMetadata: originalMeta,
      );

      // If importing Spotify Liked Songs, also mark each track as Liked in Softify's favorites table
      if (currentPlaylist.id == 'me_liked_songs') {
        for (final track in tracksToInsert) {
          try {
            await _libraryRepo.setLiked(track.id, true, track: track);
          } catch (_) {}
        }
      }

      state = state.copyWith(
        status: SpotifyImportStatus.importedSuccess,
        importedPlaylistId: newPlaylist.id,
      );

      return newPlaylist.id;
    } catch (e) {
      state = state.copyWith(
        status: SpotifyImportStatus.error,
        errorMessage: 'Failed to save imported playlist: $e',
      );
      return null;
    }
  }
}

final spotifyImportNotifierProvider =
    StateNotifierProvider.autoDispose<SpotifyImportNotifier, SpotifyImportState>((ref) {
  final importer = ref.watch(spotifyImporterProvider);
  final libraryRepo = ref.watch(libraryRepositoryProvider);
  final spotifyApi = ref.watch(spotifyApiServiceProvider);
  return SpotifyImportNotifier(
    importer: importer,
    libraryRepo: libraryRepo,
    spotifyApi: spotifyApi,
  );
});

class SpotifyPlaylistSyncService {
  final ISpotifyImporter _importer;
  final ILibraryRepository _libraryRepo;

  SpotifyPlaylistSyncService({
    required ISpotifyImporter importer,
    required ILibraryRepository libraryRepo,
  })  : _importer = importer,
        _libraryRepo = libraryRepo;

  static String _cleanString(String s) {
    return s
        .toLowerCase()
        // Remove text inside parentheses/brackets: (official video), [lyrics], (feat. x), etc.
        .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ')
        // Remove common YouTube fluff words
        .replaceAll(
            RegExp(r'\b(official|music|video|audio|lyric|lyrics|remastered|hd|4k|visualizer|ft|feat|featuring)\b'),
            ' ')
        // Keep alphanumeric characters and spaces
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        // Collapse multiple spaces
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Compares local imported playlist with the remote Spotify playlist.
  /// Finds any newly added tracks, matches them, and adds them to the playlist.
  /// Returns the number of newly added tracks (0 if up to date).
  Future<int> syncPlaylist(String playlistId) async {
    try {
      final playlistData = await _libraryRepo.getPlaylistWithTracks(playlistId);
      if (playlistData == null || !playlistData.playlist.isImported) {
        return 0;
      }

      final sourceUrl = playlistData.playlist.sourceUrl;
      if (sourceUrl == null || sourceUrl.isEmpty) {
        return 0;
      }

      final spotifyId = _importer.extractPlaylistId(sourceUrl);
      if (spotifyId == null || spotifyId.isEmpty) {
        return 0;
      }

      // 1. Fetch remote tracks from Spotify
      final remotePlaylist = await _importer.fetchPlaylist(spotifyId);
      if (remotePlaylist.tracks.isEmpty) {
        return 0;
      }

      // 2. Build multi-index structures of all existing tracks in playlist
      final existingTrackIds = <String>{};
      final existingSourceIds = <String>{};
      final exactSignatures = <String>{};
      final cleanSignatures = <String>{};
      final entryCombinedList = <String>[];

      for (final entry in playlistData.entries) {
        if (entry.trackId != null && entry.trackId!.isNotEmpty) {
          existingTrackIds.add(entry.trackId!.toLowerCase());
        }
        if (entry.track != null) {
          existingTrackIds.add(entry.track!.id.toLowerCase());
          existingSourceIds.add(entry.track!.sourceId.toLowerCase());

          final tTitle = entry.track!.title.toLowerCase().trim();
          final tArtist = entry.track!.artist.toLowerCase().trim();
          exactSignatures.add('${tTitle}___${tArtist}');
          cleanSignatures.add('${_cleanString(tTitle)}___${_cleanString(tArtist)}');
        }

        final oTitle = entry.originalTitle.toLowerCase().trim();
        final oArtist = entry.originalArtist.toLowerCase().trim();
        exactSignatures.add('${oTitle}___${oArtist}');
        cleanSignatures.add('${_cleanString(oTitle)}___${_cleanString(oArtist)}');

        final combined = _cleanString(
            '$oArtist $oTitle ${entry.track?.artist ?? ''} ${entry.track?.title ?? ''}');
        if (combined.isNotEmpty) {
          entryCombinedList.add(combined);
        }
      }

      // 3. Find newly added tracks from Spotify
      final newItems = <SpotifyTrackItem>[];
      for (final remoteTrack in remotePlaylist.tracks) {
        final rTitle = remoteTrack.title.toLowerCase().trim();
        final rArtist = remoteTrack.artist.toLowerCase().trim();
        final rawSig = '${rTitle}___${rArtist}';
        final cleanTitle = _cleanString(rTitle);
        final cleanArtist = _cleanString(rArtist);
        final cleanSig = '${cleanTitle}___${cleanArtist}';

        // Check exact match on raw title/artist
        if (exactSignatures.contains(rawSig)) continue;

        // Check clean match
        if (cleanSignatures.contains(cleanSig)) continue;

        // Fuzzy match against combined text of existing entries
        bool isAlreadyInPlaylist = false;
        if (cleanTitle.isNotEmpty) {
          for (final combined in entryCombinedList) {
            if (combined.contains(cleanTitle)) {
              if (cleanArtist.isEmpty ||
                  combined.contains(cleanArtist) ||
                  cleanArtist.contains(combined)) {
                isAlreadyInPlaylist = true;
                break;
              }
            }
          }
        }
        if (isAlreadyInPlaylist) continue;

        newItems.add(remoteTrack);
      }

      if (newItems.isEmpty) {
        return 0;
      }

      // 4. Match new tracks with duplicate protection & fallback canonical tracks
      final matchedTracks = <Track>[];
      final newMetadata = <({String title, String artist})>[];
      final newMatchedSourceIds = <String>{};
      final playlistCover = remotePlaylist.coverUrl;

      for (final item in newItems) {
        Track? matched;
        try {
          matched = await _importer.matchTrack(item);
        } catch (_) {}

        if (matched != null) {
          final mSourceId = matched.sourceId.toLowerCase().trim();
          final mId = matched.id.toLowerCase().trim();

          // Guard: Never add a track whose sourceId is already in the playlist
          if (existingSourceIds.contains(mSourceId) ||
              existingTrackIds.contains(mId) ||
              newMatchedSourceIds.contains(mSourceId)) {
            continue;
          }

          newMatchedSourceIds.add(mSourceId);
          matchedTracks.add(matched);
          newMetadata.add((title: item.title, artist: item.artist));
          continue;
        }

        var rawUri = item.spotifyUri;
        if (rawUri.contains('?')) {
          rawUri = rawUri.split('?').first;
        }
        final trackId = rawUri.startsWith('spotify:track:')
            ? rawUri.replaceFirst('spotify:track:', '')
            : (rawUri.isNotEmpty
                ? rawUri.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
                : '${item.title}_${item.artist}'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_'));

        final itemCover = (item.coverUrl != null &&
                item.coverUrl != playlistCover &&
                !item.coverUrl!.contains('hqdefault'))
            ? item.coverUrl
            : null;

        final track = Track(
          id: 'spotify_$trackId',
          sourceId: 'spotify_$trackId',
          title: item.title,
          artist: item.artist,
          album: item.album,
          duration: item.duration,
          coverUrl: itemCover,
          matchConfidence: 1.0,
        );
        matchedTracks.add(track);
        newMetadata.add((title: item.title, artist: item.artist));
      }

      if (matchedTracks.isEmpty) {
        return 0;
      }

      // 5. Append to playlist with original Spotify metadata
      await _libraryRepo.addTracksToPlaylist(
        playlistId,
        matchedTracks,
        originalMetadata: newMetadata,
      );
      return matchedTracks.length;
    } catch (_) {
      return 0;
    }
  }
}

final spotifyPlaylistSyncServiceProvider =
    Provider<SpotifyPlaylistSyncService>((ref) {
  final importer = ref.watch(spotifyImporterProvider);
  final libraryRepo = ref.watch(libraryRepositoryProvider);
  return SpotifyPlaylistSyncService(
    importer: importer,
    libraryRepo: libraryRepo,
  );
});
