import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../data/youtube_history_dao.dart';
import '../data/youtube_repository.dart';
import '../domain/parse_youtube_link.dart';
import '../domain/youtube_failure.dart';

// Providers
final youtubeRepositoryProvider = Provider<YoutubeRepository>((ref) {
  final repo = YoutubeRepository();
  ref.onDispose(() => repo.close());
  return repo;
});

final youtubeHistoryDaoProvider = Provider<YoutubeHistoryDao>((ref) {
  final db = ref.watch(databaseProvider);
  return YoutubeHistoryDao(db);
});

final youtubeRecentHistoryProvider =
    StreamProvider.autoDispose<List<dynamic>>((ref) {
  final dao = ref.watch(youtubeHistoryDaoProvider);
  return dao.watchRecent(limit: 50);
});

// Sealed State Hierarchy
sealed class YoutubeState {
  const YoutubeState();
}

class YoutubeIdle extends YoutubeState {
  const YoutubeIdle();
}

class YoutubeLoading extends YoutubeState {
  final String input;
  const YoutubeLoading(this.input);
}

class YoutubeReady extends YoutubeState {
  final Track track;
  final String? playlistId;
  final List<Track>? playlistTracks;
  final int? startSeconds;

  const YoutubeReady({
    required this.track,
    this.playlistId,
    this.playlistTracks,
    this.startSeconds,
  });
}

class YoutubeErrorState extends YoutubeState {
  final YoutubeFailure failure;
  final String? lastInput;
  const YoutubeErrorState(this.failure, {this.lastInput});
}

// Controller
class YoutubeController extends Notifier<YoutubeState> {
  int _submissionCounter = 0;
  String _lastSubmittedInput = '';

  @override
  YoutubeState build() {
    return const YoutubeIdle();
  }

  /// Submits and plays a YouTube video or playlist link.
  Future<void> submit(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty) return;

    // Prevent double taps while already processing the exact same input
    if (state is YoutubeLoading &&
        (state as YoutubeLoading).input == input) {
      return;
    }

    _lastSubmittedInput = input;
    final currentSubmissionId = ++_submissionCounter;
    state = YoutubeLoading(input);

    final parsed = parseYoutubeLink(input);

    if (parsed is InvalidLink) {
      state = YoutubeErrorState(
        InvalidLinkFailure(parsed.reason),
        lastInput: input,
      );
      return;
    }

    final repo = ref.read(youtubeRepositoryProvider);
    final historyDao = ref.read(youtubeHistoryDaoProvider);
    final audioHandler = ref.read(audioHandlerProvider);

    try {
      if (parsed is PlaylistLink) {
        final tracks = await repo.fetchPlaylistTracks(parsed.playlistId);

        if (_submissionCounter != currentSubmissionId) return; // Stale

        final firstTrack = tracks.first;

        // Upsert first track to history
        await historyDao.upsertHistory(
          videoId: firstTrack.sourceId.replaceFirst('yt_', ''),
          title: firstTrack.title,
          channel: firstTrack.artist,
          thumbnailUrl: firstTrack.coverUrl,
          durationSeconds: firstTrack.duration.inSeconds,
          lastPlayedAt: DateTime.now().millisecondsSinceEpoch,
        );

        audioHandler.setTrackSource('youtube_link');
        await audioHandler.setQueue(tracks, startIndex: 0);

        state = YoutubeReady(
          track: firstTrack,
          playlistId: parsed.playlistId,
          playlistTracks: tracks,
        );
      } else if (parsed is VideoLink || parsed is VideoInPlaylist) {
        final String videoId;
        final String? playlistId;
        final int? startSeconds;
        if (parsed is VideoLink) {
          videoId = parsed.videoId;
          playlistId = null;
          startSeconds = parsed.startSeconds;
        } else {
          final vp = parsed as VideoInPlaylist;
          videoId = vp.videoId;
          playlistId = vp.playlistId;
          startSeconds = vp.startSeconds;
        }

        final track = await repo.fetchTrack(videoId);

        if (_submissionCounter != currentSubmissionId) return; // Stale

        await historyDao.upsertHistory(
          videoId: videoId,
          title: track.title,
          channel: track.artist,
          thumbnailUrl: track.coverUrl,
          durationSeconds: track.duration.inSeconds,
          lastPlayedAt: DateTime.now().millisecondsSinceEpoch,
        );

        audioHandler.setTrackSource('youtube_link');
        await audioHandler.playTrack(track);

        if (startSeconds != null && startSeconds > 0) {
          await audioHandler.seek(Duration(seconds: startSeconds));
        }

        // If part of playlist, lazily fetch playlist tracks for "Play whole playlist"
        List<Track>? playlistTracks;
        if (playlistId != null) {
          unawaited(
            repo.fetchPlaylistTracks(playlistId).then((plTracks) {
              if (_submissionCounter == currentSubmissionId &&
                  state is YoutubeReady) {
                final currentReady = state as YoutubeReady;
                if (currentReady.track.id == track.id) {
                  state = YoutubeReady(
                    track: track,
                    playlistId: playlistId,
                    playlistTracks: plTracks,
                    startSeconds: startSeconds,
                  );
                }
              }
            }).catchError((_) {}),
          );
        }

        state = YoutubeReady(
          track: track,
          playlistId: playlistId,
          playlistTracks: playlistTracks,
          startSeconds: startSeconds,
        );
      }
    } on YoutubeException catch (e) {
      if (_submissionCounter == currentSubmissionId) {
        state = YoutubeErrorState(e.failure, lastInput: input);
      }
    } catch (e) {
      if (_submissionCounter == currentSubmissionId) {
        state = YoutubeErrorState(
          GenericYoutubeFailure(e.toString()),
          lastInput: input,
        );
      }
    }
  }

  /// Retries the last submitted input.
  void retry() {
    if (_lastSubmittedInput.isNotEmpty) {
      submit(_lastSubmittedInput);
    }
  }

  /// Plays all tracks in the currently loaded playlist.
  Future<void> playWholePlaylist() async {
    if (state is YoutubeReady) {
      final ready = state as YoutubeReady;
      if (ready.playlistTracks != null && ready.playlistTracks!.isNotEmpty) {
        final audioHandler = ref.read(audioHandlerProvider);
        audioHandler.setTrackSource('youtube_link');
        await audioHandler.setQueue(ready.playlistTracks!, startIndex: 0);
      }
    }
  }

  /// Clears state back to idle.
  void reset() {
    state = const YoutubeIdle();
  }
}

final youtubeControllerProvider =
    NotifierProvider<YoutubeController, YoutubeState>(
  YoutubeController.new,
);
