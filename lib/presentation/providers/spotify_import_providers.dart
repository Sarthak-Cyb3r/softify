import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/importer/keyless_spotify_importer.dart';
import '../../domain/entities/spotify_import.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_library_repository.dart';
import '../../domain/ports/i_spotify_importer.dart';
import 'player_providers.dart';

final spotifyImporterProvider = Provider<ISpotifyImporter>((ref) {
  final catalog = ref.watch(catalogRepositoryProvider);
  return KeylessSpotifyImporter(catalog: catalog);
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

  const SpotifyImportState({
    this.status = SpotifyImportStatus.idle,
    this.errorMessage,
    this.inputUrl = '',
    this.playlist,
    this.matchedProgress = 0,
    this.totalToMatch = 0,
    this.importedPlaylistId,
  });

  SpotifyImportState copyWith({
    SpotifyImportStatus? status,
    String? errorMessage,
    String? inputUrl,
    SpotifyImportPlaylist? playlist,
    int? matchedProgress,
    int? totalToMatch,
    String? importedPlaylistId,
  }) {
    return SpotifyImportState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      inputUrl: inputUrl ?? this.inputUrl,
      playlist: playlist ?? this.playlist,
      matchedProgress: matchedProgress ?? this.matchedProgress,
      totalToMatch: totalToMatch ?? this.totalToMatch,
      importedPlaylistId: importedPlaylistId ?? this.importedPlaylistId,
    );
  }
}

class SpotifyImportNotifier extends StateNotifier<SpotifyImportState> {
  final ISpotifyImporter _importer;
  final ILibraryRepository _libraryRepo;

  SpotifyImportNotifier({
    required ISpotifyImporter importer,
    required ILibraryRepository libraryRepo,
  })  : _importer = importer,
        _libraryRepo = libraryRepo,
        super(const SpotifyImportState());

  void setInputUrl(String url) {
    state = state.copyWith(inputUrl: url);
  }

  void reset() {
    state = const SpotifyImportState();
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
    );

    try {
      final playlist = await _importer.fetchPlaylist(cleanUrl);
      if (playlist.tracks.isEmpty) {
        state = state.copyWith(
          status: SpotifyImportStatus.error,
          errorMessage: 'No playable tracks found in this Spotify playlist.',
          playlist: playlist,
        );
        return;
      }

      final total = playlist.tracks.length;
      state = state.copyWith(
        status: SpotifyImportStatus.matchingTracks,
        playlist: playlist,
        matchedProgress: 0,
        totalToMatch: total,
      );

      final List<SpotifyTrackItem> results = List<SpotifyTrackItem>.from(playlist.tracks);
      int completed = 0;

      // Match tracks in parallel chunks of 5 for ultra-fast throughput
      const chunkSize = 5;
      for (int i = 0; i < total; i += chunkSize) {
        final end = (i + chunkSize < total) ? i + chunkSize : total;
        final chunkIndices = List.generate(end - i, (k) => i + k);

        await Future.wait(
          chunkIndices.map((idx) async {
            final item = playlist.tracks[idx];
            Track? matchedTrack;
            try {
              matchedTrack = await _importer.matchTrack(item);
            } catch (_) {
              matchedTrack = null;
            }

            results[idx] = item.copyWith(
              matchedTrack: matchedTrack,
              isMatched: matchedTrack != null,
              confidence: matchedTrack?.matchConfidence ?? 0.0,
            );
            completed++;
          }),
        );

        state = state.copyWith(
          matchedProgress: completed,
          playlist: playlist.copyWith(tracks: List.from(results)),
        );
      }

      state = state.copyWith(
        status: SpotifyImportStatus.matched,
        matchedProgress: total,
        playlist: playlist.copyWith(tracks: results),
      );
    } catch (e) {
      state = state.copyWith(
        status: SpotifyImportStatus.error,
        errorMessage: 'Failed to import playlist: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
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

  Future<String?> commitImportToLibrary() async {
    final currentPlaylist = state.playlist;
    if (currentPlaylist == null) return null;

    state = state.copyWith(status: SpotifyImportStatus.importingToDb);

    try {
      final newPlaylist = await _libraryRepo.createPlaylist(
        currentPlaylist.name,
        description: currentPlaylist.description ?? 'Imported from Spotify',
        isImported: true,
        sourceUrl: 'https://open.spotify.com/playlist/${currentPlaylist.id}',
      );

      final matchedTracks = currentPlaylist.tracks
          .where((t) => t.isMatched && t.matchedTrack != null)
          .map((t) => t.matchedTrack!)
          .toList();

      // Atomic single-transaction batch insert
      await _libraryRepo.addTracksToPlaylist(newPlaylist.id, matchedTracks);

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
  return SpotifyImportNotifier(importer: importer, libraryRepo: libraryRepo);
});
