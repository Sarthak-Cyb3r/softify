import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../domain/entities/stream_info.dart';
import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../data/podcast_history_dao.dart';
import '../data/podcast_metadata_service.dart';
import '../data/podcast_repository.dart';
import '../data/podcast_rss_resolver.dart';
import '../domain/parse_podcast_link.dart';
import '../domain/podcast_episode.dart';
import '../domain/podcast_failure.dart';
import '../domain/podcast_show.dart';

// Providers
final podcastMetadataServiceProvider = Provider<PodcastMetadataService>((ref) {
  final service = PodcastMetadataService();
  ref.onDispose(() => service.close());
  return service;
});

final podcastRssResolverProvider = Provider<PodcastRssResolver>((ref) {
  final metadata = ref.watch(podcastMetadataServiceProvider);
  final resolver = PodcastRssResolver(metadataService: metadata);
  ref.onDispose(() => resolver.close());
  return resolver;
});

final podcastRepositoryProvider = Provider<PodcastRepository>((ref) {
  final metadata = ref.watch(podcastMetadataServiceProvider);
  final rssResolver = ref.watch(podcastRssResolverProvider);
  final dao = ref.watch(podcastHistoryDaoProvider);
  final repo = PodcastRepository(
    metadataService: metadata,
    rssResolver: rssResolver,
    historyDao: dao,
  );
  ref.onDispose(() => repo.close());
  return repo;
});

final podcastHistoryDaoProvider = Provider<PodcastHistoryDao>((ref) {
  final db = ref.watch(databaseProvider);
  return PodcastHistoryDao(db);
});

final podcastRecentHistoryProvider =
    StreamProvider.autoDispose<List<PodcastHistoryRow>>((ref) {
  final dao = ref.watch(podcastHistoryDaoProvider);
  return dao.watchRecent(limit: 50);
});

// Sealed State Hierarchy
sealed class PodcastState {
  const PodcastState();
}

class PodcastIdle extends PodcastState {
  const PodcastIdle();
}

class PodcastLoading extends PodcastState {
  final String input;
  const PodcastLoading(this.input);
}

class PodcastReady extends PodcastState {
  final PodcastEpisode episode;
  final Track track;
  final int resumePositionMs;
  final List<PodcastEpisode>? feedEpisodes;
  final PodcastShow? show;

  const PodcastReady({
    required this.episode,
    required this.track,
    this.resumePositionMs = 0,
    this.feedEpisodes,
    this.show,
  });

  PodcastReady copyWith({
    PodcastEpisode? episode,
    Track? track,
    int? resumePositionMs,
    List<PodcastEpisode>? feedEpisodes,
    PodcastShow? show,
  }) {
    return PodcastReady(
      episode: episode ?? this.episode,
      track: track ?? this.track,
      resumePositionMs: resumePositionMs ?? this.resumePositionMs,
      feedEpisodes: feedEpisodes ?? this.feedEpisodes,
      show: show ?? this.show,
    );
  }
}

class PodcastErrorState extends PodcastState {
  final PodcastFailure failure;
  final String? lastInput;
  const PodcastErrorState(this.failure, {this.lastInput});
}

// Controller
class PodcastController extends Notifier<PodcastState> {
  int _submissionCounter = 0;
  String _lastSubmittedInput = '';
  StreamSubscription<Duration>? _positionSub;

  @override
  PodcastState build() {
    ref.onDispose(() {
      _positionSub?.cancel();
    });

    // Listen to playback position to periodically save resume position
    _initPositionTracking();

    return const PodcastIdle();
  }

  void _initPositionTracking() {
    try {
      final audioHandler = ref.read(audioHandlerProvider);
      _positionSub = audioHandler.positionStream.listen((pos) {
        if (state is PodcastReady) {
          final ready = state as PodcastReady;
          final posMs = pos.inMilliseconds;
          // Save every ~5 seconds or on major position changes
          if ((posMs - ready.resumePositionMs).abs() > 4000) {
            try {
              ref.read(podcastHistoryDaoProvider).updatePosition(
                    ready.episode.id,
                    posMs,
                  );
            } catch (_) {}
            state = ready.copyWith(resumePositionMs: posMs);
          }
        }
      });
    } catch (_) {}
  }

  /// Submits and plays a Spotify podcast episode link, show link, or search query.
  Future<void> submit(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty) return;

    if (state is PodcastLoading && (state as PodcastLoading).input == input) {
      return;
    }

    _lastSubmittedInput = input;
    final currentSubmissionId = ++_submissionCounter;
    state = PodcastLoading(input);

    final parsed = parsePodcastLink(input);

    if (parsed is InvalidPodcastLink) {
      state = PodcastErrorState(
        const InvalidPodcastLinkFailure(),
        lastInput: input,
      );
      return;
    }

    final repo = ref.read(podcastRepositoryProvider);
    final historyDao = ref.read(podcastHistoryDaoProvider);
    final audioHandler = ref.read(audioHandlerProvider);

    try {
      if (parsed is SpotifyShowLink) {
        final result = await repo.fetchShow(parsed.showId);
        if (_submissionCounter != currentSubmissionId) return;

        var first = result.episodes.first;
        if (first.audioUrl == null || first.audioUrl!.isEmpty) {
          try {
            final resolvedFirst = await repo.fetchEpisode(first.id);
            first = resolvedFirst.episode;
          } catch (_) {}
        }

        final firstTrack = Track(
          id: 'podcast_${first.id}',
          sourceId: 'podcast_${first.id}',
          title: first.title,
          artist: first.showName,
          album: 'Podcast',
          duration: first.duration,
          coverUrl: first.coverUrl,
          matchConfidence: 1.0,
        );

        await historyDao.upsertHistory(
          episodeId: first.id,
          showId: first.showId,
          showName: first.showName,
          title: first.title,
          description: first.description,
          thumbnailUrl: first.coverUrl,
          durationSeconds: first.duration.inSeconds,
          resumePositionMs: 0,
          lastPlayedAt: DateTime.now().millisecondsSinceEpoch,
        );

        state = PodcastReady(
          episode: first,
          track: firstTrack,
          resumePositionMs: 0,
          feedEpisodes: result.episodes,
          show: result.show,
        );

        audioHandler.setTrackSource('podcast');
        unawaited(
          audioHandler.playTrack(firstTrack).catchError((e) {
            if (_submissionCounter == currentSubmissionId) {
              state = PodcastErrorState(
                GenericPodcastFailure(e.toString()),
                lastInput: input,
              );
            }
          }),
        );
      } else if (parsed is PodcastSearchQuery) {
        final result = await repo.searchShow(parsed.query);
        if (_submissionCounter != currentSubmissionId) return;

        final first = result.episodes.first;
        final firstTrack = Track(
          id: 'podcast_${first.id}',
          sourceId: 'podcast_${first.id}',
          title: first.title,
          artist: first.showName,
          album: 'Podcast',
          duration: first.duration,
          coverUrl: first.coverUrl,
          matchConfidence: 1.0,
        );

        await historyDao.upsertHistory(
          episodeId: first.id,
          showId: first.showId,
          showName: first.showName,
          title: first.title,
          description: first.description,
          thumbnailUrl: first.coverUrl,
          durationSeconds: first.duration.inSeconds,
          resumePositionMs: 0,
          lastPlayedAt: DateTime.now().millisecondsSinceEpoch,
        );

        state = PodcastReady(
          episode: first,
          track: firstTrack,
          resumePositionMs: 0,
          feedEpisodes: result.episodes,
          show: result.show,
        );

        audioHandler.setTrackSource('podcast');
        unawaited(
          audioHandler.playTrack(firstTrack).catchError((e) {
            if (_submissionCounter == currentSubmissionId) {
              state = PodcastErrorState(
                GenericPodcastFailure(e.toString()),
                lastInput: input,
              );
            }
          }),
        );
      } else if (parsed is SpotifyEpisodeLink) {
        final result = await repo.fetchEpisode(parsed.episodeId);

        if (_submissionCounter != currentSubmissionId) return;

        // Check if there is existing saved position in history
        final history = await historyDao.getRecent(limit: 50);
        final match = history.where((h) => h.episodeId == parsed.episodeId).firstOrNull;
        final resumeMs = match?.resumePositionMs ?? 0;

        await historyDao.upsertHistory(
          episodeId: result.episode.id,
          showId: result.episode.showId,
          showName: result.episode.showName,
          title: result.episode.title,
          description: result.episode.description,
          thumbnailUrl: result.episode.coverUrl,
          durationSeconds: result.episode.duration.inSeconds,
          resumePositionMs: resumeMs,
          lastPlayedAt: DateTime.now().millisecondsSinceEpoch,
        );

        state = PodcastReady(
          episode: result.episode,
          track: result.track,
          resumePositionMs: resumeMs,
        );

        audioHandler.setTrackSource('podcast');
        unawaited(
          audioHandler.playTrack(result.track).then((_) {
            if (resumeMs > 3000) {
              return audioHandler.seek(Duration(milliseconds: resumeMs));
            }
          }).catchError((e) {
            if (_submissionCounter == currentSubmissionId) {
              state = PodcastErrorState(
                GenericPodcastFailure(e.toString()),
                lastInput: input,
              );
            }
          }),
        );

        // Lazily fetch sibling episodes of the show
        if (result.episode.showId.isNotEmpty) {
          unawaited(
            repo.fetchShow(result.episode.showId).then((s) {
              if (state is PodcastReady) {
                final curr = state as PodcastReady;
                if (curr.episode.id == result.episode.id) {
                  state = curr.copyWith(show: s.show, feedEpisodes: s.episodes);
                }
              }
            }).catchError((_) {}),
          );
        } else if (result.episode.showName.isNotEmpty && result.episode.showName != 'Podcast') {
          unawaited(
            repo.searchShow(result.episode.showName).then((s) {
              if (state is PodcastReady) {
                final curr = state as PodcastReady;
                if (curr.episode.id == result.episode.id) {
                  state = curr.copyWith(show: s.show, feedEpisodes: s.episodes);
                }
              }
            }).catchError((_) {}),
          );
        }
      } else if (parsed is DirectRssLink) {
        final episodes = await repo.fetchFromDirectRss(parsed.feedUri);
        if (_submissionCounter != currentSubmissionId) return;

        final first = episodes.first;

        await historyDao.upsertHistory(
          episodeId: first.episode.id,
          showId: first.episode.showId,
          showName: first.episode.showName,
          title: first.episode.title,
          description: first.episode.description,
          thumbnailUrl: first.episode.coverUrl,
          durationSeconds: first.episode.duration.inSeconds,
          resumePositionMs: 0,
          lastPlayedAt: DateTime.now().millisecondsSinceEpoch,
        );

        state = PodcastReady(
          episode: first.episode,
          track: first.track,
          resumePositionMs: 0,
          feedEpisodes: episodes.map((e) => e.episode).toList(),
        );

        audioHandler.setTrackSource('podcast');
        unawaited(
          audioHandler.playTrack(first.track).catchError((e) {
            if (_submissionCounter == currentSubmissionId) {
              state = PodcastErrorState(
                GenericPodcastFailure(e.toString()),
                lastInput: input,
              );
            }
          }),
        );
      }
    } on PodcastException catch (e) {
      if (_submissionCounter == currentSubmissionId) {
        state = PodcastErrorState(e.failure, lastInput: input);
      }
    } catch (e) {
      if (_submissionCounter == currentSubmissionId) {
        state = PodcastErrorState(
          GenericPodcastFailure(e.toString()),
          lastInput: input,
        );
      }
    }
  }

  /// Plays a specific episode from the show list.
  Future<void> playEpisode(PodcastEpisode ep) async {
    final repo = ref.read(podcastRepositoryProvider);
    final historyDao = ref.read(podcastHistoryDaoProvider);
    final audioHandler = ref.read(audioHandlerProvider);

    var episodeToPlay = ep;
    if (episodeToPlay.audioUrl == null || episodeToPlay.audioUrl!.isEmpty) {
      try {
        final resolved = await repo.fetchEpisode(ep.id);
        episodeToPlay = resolved.episode;
      } catch (_) {}
    }

    final track = Track(
      id: 'podcast_${episodeToPlay.id}',
      sourceId: 'podcast_${episodeToPlay.id}',
      title: episodeToPlay.title,
      artist: episodeToPlay.showName,
      album: 'Podcast',
      duration: episodeToPlay.duration,
      coverUrl: episodeToPlay.coverUrl,
      matchConfidence: 1.0,
    );

    // Precache direct unencrypted audio URL into shared resolver
    if (episodeToPlay.audioUrl != null && episodeToPlay.audioUrl!.isNotEmpty) {
      final isEncrypted = episodeToPlay.audioUrl!.contains('scdn.co') ||
          episodeToPlay.audioUrl!.contains('spotifycdn.com');
      if (!isEncrypted) {
        final uri = Uri.tryParse(episodeToPlay.audioUrl!);
        if (uri != null) {
          final isM4a = episodeToPlay.audioUrl!.contains('.m4a');
          final streamInfo = StreamInfo(
            url: uri,
            container: isM4a ? 'm4a' : 'mp3',
            bitrate: 192000,
            codec: isM4a ? 'aac' : 'mp3',
            expiresAt: DateTime.now().add(const Duration(hours: 12)),
            providerName: 'podcast_direct',
            headers: null,
          );
          repo.rssResolver.precacheStream(track.id, streamInfo);
          repo.rssResolver.precacheStream(episodeToPlay.id, streamInfo);
        }
      }
    }

    final history = await historyDao.getRecent(limit: 50);
    final match = history.where((h) => h.episodeId == ep.id).firstOrNull;
    final resumeMs = match?.resumePositionMs ?? 0;

    await historyDao.upsertHistory(
      episodeId: episodeToPlay.id,
      showId: episodeToPlay.showId,
      showName: episodeToPlay.showName,
      title: episodeToPlay.title,
      description: episodeToPlay.description,
      thumbnailUrl: episodeToPlay.coverUrl,
      durationSeconds: episodeToPlay.duration.inSeconds,
      resumePositionMs: resumeMs,
      lastPlayedAt: DateTime.now().millisecondsSinceEpoch,
    );

    if (state is PodcastReady) {
      state = (state as PodcastReady).copyWith(
        episode: episodeToPlay,
        track: track,
        resumePositionMs: resumeMs,
      );
    } else {
      state = PodcastReady(
        episode: episodeToPlay,
        track: track,
        resumePositionMs: resumeMs,
      );
    }

    audioHandler.setTrackSource('podcast');
    await audioHandler.playTrack(track);
    if (resumeMs > 3000) {
      await audioHandler.seek(Duration(milliseconds: resumeMs));
    }
  }

  /// Plays a previously listened episode from history, restoring resume position.
  Future<void> resumeFromHistory(PodcastHistoryRow row) async {
    final track = Track(
      id: 'podcast_${row.episodeId}',
      sourceId: 'podcast_${row.episodeId}',
      title: row.title,
      artist: row.showName,
      album: 'Podcast',
      duration: Duration(seconds: row.durationSeconds),
      coverUrl: row.thumbnailUrl,
      matchConfidence: 1.0,
    );

    final episode = PodcastEpisode(
      id: row.episodeId,
      showId: row.showId,
      showName: row.showName,
      title: row.title,
      description: row.description ?? '',
      duration: Duration(seconds: row.durationSeconds),
      coverUrl: row.thumbnailUrl,
    );

    if (state is PodcastReady) {
      state = (state as PodcastReady).copyWith(
        episode: episode,
        track: track,
        resumePositionMs: row.resumePositionMs,
      );
    } else {
      state = PodcastReady(
        episode: episode,
        track: track,
        resumePositionMs: row.resumePositionMs,
      );
    }

    final audioHandler = ref.read(audioHandlerProvider);
    audioHandler.setTrackSource('podcast');

    await audioHandler.playTrack(track);
    if (row.resumePositionMs > 3000) {
      await audioHandler.seek(Duration(milliseconds: row.resumePositionMs));
    }

    await ref.read(podcastHistoryDaoProvider).updatePosition(
          row.episodeId,
          row.resumePositionMs,
        );
  }

  /// Skips forward by 30 seconds (or specified seconds).
  Future<void> skipForward([int seconds = 30]) async {
    final audioHandler = ref.read(audioHandlerProvider);
    final current = audioHandler.playbackState.value.position;
    final target = current + Duration(seconds: seconds);
    await audioHandler.seek(target);
  }

  /// Skips backward by 15 seconds (or specified seconds).
  Future<void> skipBackward([int seconds = 15]) async {
    final audioHandler = ref.read(audioHandlerProvider);
    final current = audioHandler.playbackState.value.position;
    final target = (current - Duration(seconds: seconds)).inMilliseconds < 0
        ? Duration.zero
        : current - Duration(seconds: seconds);
    await audioHandler.seek(target);
  }

  /// Deletes an episode from history.
  Future<void> deleteHistory(String episodeId) async {
    await ref.read(podcastHistoryDaoProvider).deleteEntry(episodeId);
  }

  /// Retries last failed input.
  void retry() {
    if (_lastSubmittedInput.isNotEmpty) {
      submit(_lastSubmittedInput);
    }
  }

  /// Resets state to idle.
  void reset() {
    state = const PodcastIdle();
  }
}

final podcastControllerProvider =
    NotifierProvider<PodcastController, PodcastState>(
  PodcastController.new,
);
