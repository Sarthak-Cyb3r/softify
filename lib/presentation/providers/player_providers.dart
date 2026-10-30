import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/player/softify_audio_handler.dart';
import '../../data/services/local_audio_scanner.dart';
import '../../domain/entities/audio_repeat_mode.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/entities/history_item.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/playlist_entry.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/track.dart';
import '../../data/catalog/keyless_youtube_catalog.dart';
import '../../data/lyrics/composite_lyrics_provider.dart';
import '../../data/lyrics/lrclib_lyrics_provider.dart';
import '../../data/lyrics/spotify_lyrics_provider.dart';
import '../../services/lyrics/better_lyrics_provider.dart';
import '../../services/lyrics/lyrics_provider_registry.dart';
import '../../domain/ports/i_catalog_repository.dart';
import '../../domain/ports/i_download_repository.dart';
import '../../domain/ports/i_event_logger.dart';
import '../../domain/ports/i_library_repository.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import '../../domain/ports/i_stream_resolver.dart';
import '../../domain/ports/i_fts_repository.dart';
import '../../domain/ports/i_remote_config.dart';
import '../../domain/ports/i_search_reranker.dart';
import '../../data/repositories/drift_event_logger.dart';
import '../../data/repositories/remote_config_repository.dart';
import '../../data/search/drift_fts_repository.dart';
import '../../data/search/linear_search_reranker.dart';
import '../../data/services/discord_rpc_service.dart';
import '../../data/services/spotify_api_service.dart';
import '../../services/recognition/song_recognition_service.dart';
import 'spotify_import_providers.dart';

// ==========================================
// Core Dependency Providers (Injected at Startup)
// ==========================================

final spotifyApiServiceProvider = Provider<SpotifyApiService>((ref) {
  final authService = ref.watch(spotifyAuthServiceProvider);
  return SpotifyApiService(authService: authService);
});

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden at startup');
});

final eventLoggerProvider = Provider<IEventLogger>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftEventLogger(db: db);
});

final libraryRepositoryProvider = Provider<ILibraryRepository>((ref) {
  throw UnimplementedError('libraryRepositoryProvider must be overridden at startup');
});

final downloadRepositoryProvider = Provider<IDownloadRepository>((ref) {
  throw UnimplementedError('downloadRepositoryProvider must be overridden at startup');
});

final streamResolverProvider = Provider<IStreamResolver>((ref) {
  throw UnimplementedError('streamResolverProvider must be overridden at startup');
});

final audioHandlerProvider = Provider<SoftifyAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden at startup');
});

final catalogRepositoryProvider = Provider<ICatalogRepository>((ref) {
  final spotifyApi = ref.watch(spotifyApiServiceProvider);
  return KeylessYouTubeCatalog(spotifyApi: spotifyApi);
});

final ftsRepositoryProvider = Provider<IFtsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftFtsRepository(db);
});

final searchRerankerProvider = Provider<ISearchReranker>((ref) {
  return LinearSearchReranker();
});

final remoteConfigProvider = Provider<IRemoteConfig>((ref) {
  final db = ref.watch(databaseProvider);
  return RemoteConfigRepository(db: db);
});

final discordRpcServiceProvider = Provider<DiscordRpcService>((ref) {
  final service = DiscordRpcService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ==========================================
// Reactive Playback & Queue State Streams
// ==========================================

final currentTrackProvider = StreamProvider<Track?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.currentTrackStream;
});

final mediaItemStreamProvider = StreamProvider<MediaItem?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.mediaItem;
});

final songRecognitionServiceProvider = Provider<SongRecognitionService>((ref) {
  return SongRecognitionService();
});

final queueProvider = StreamProvider<List<Track>>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.tracksQueueStream;
});

final playbackStateStreamProvider = StreamProvider<PlaybackState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playbackState;
});

final isPlayingProvider = Provider<bool>((ref) {
  final playbackState = ref.watch(playbackStateStreamProvider).value;
  return playbackState?.playing ?? false;
});

final activeLyricStreamProvider = StreamProvider<String?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.activeLyricStream;
});

final positionStreamProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.positionStream;
});

final bufferedPositionStreamProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.bufferedPositionStream;
});

final durationStreamProvider = StreamProvider<Duration?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.durationStream;
});

final repeatModeStreamProvider = StreamProvider<AudioRepeatMode>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.repeatModeStream;
});

final shuffleModeStreamProvider = StreamProvider<bool>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.shuffleModeStream;
});

final autoPlayStreamProvider = StreamProvider<bool>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.autoPlayStream;
});

final volumeStreamProvider = StreamProvider<double>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.volumeStream;
});

final playbackSpeedStreamProvider = StreamProvider<double>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.speedStream;
});

final currentStreamInfoProvider = StreamProvider<StreamInfo?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.currentStreamInfoStream;
});

final sleepTimerRemainingProvider = StreamProvider<Duration?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.sleepTimerRemainingStream;
});

final sleepTimerEndOfTrackProvider = StreamProvider<bool>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.sleepEndOfTrackStream;
});

// ==========================================
// Library & Downloads Streams
// ==========================================

final likedTracksStreamProvider = StreamProvider<List<Track>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchLikedTracks();
});

final isTrackLikedProvider = StreamProvider.family<bool, String>((ref, trackId) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchLikedTracks().map((tracks) => tracks.any((t) => t.id == trackId)).distinct();
});

final playlistsStreamProvider = StreamProvider<List<Playlist>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchPlaylists();
});

final playlistWithTracksStreamProvider =
    StreamProvider.family<PlaylistWithTracks?, String>((ref, playlistId) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchPlaylistWithTracks(playlistId);
});

final downloadsStreamProvider = StreamProvider<List<DownloadItem>>((ref) {
  final repo = ref.watch(downloadRepositoryProvider);
  return repo.watchDownloads();
});

final isTrackDownloadedProvider = StreamProvider.family<bool, String>((ref, trackId) {
  final repo = ref.watch(downloadRepositoryProvider);
  return repo.watchDownload(trackId).map((d) => d?.isCompleted ?? false).distinct();
});

final localTracksStreamProvider = StreamProvider<List<Track>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.tracks)
        ..where((t) => t.id.like('local_%') | t.sourceId.like('local_%'))
        ..orderBy([(t) => OrderingTerm.asc(t.title)]))
      .watch()
      .map((rows) => rows
          .where((r) =>
              File(r.sourceId).existsSync() &&
              !LocalAudioScanner.isExcludedPath(r.sourceId))
          .map((r) => Track(
                id: r.id,
                sourceId: r.sourceId,
                title: r.title,
                artist: r.artist,
                album: r.album,
                duration: Duration(milliseconds: r.durationMs),
                coverUrl: r.coverUrl,
                matchConfidence: r.matchConfidence,
                isLiked: r.isLiked,
                isUnavailable: r.isUnavailable,
              ))
          .toList());
});

// ==========================================
// Synced Lyrics Provider with Local Cache
// ==========================================

final lyricsProvider = Provider<ILyricsProvider>((ref) {
  try {
    final audioHandler = ref.watch(audioHandlerProvider);
    if (audioHandler.lyricsProvider != null) {
      return audioHandler.lyricsProvider!;
    }
  } catch (_) {}
  final db = ref.watch(databaseProvider);
  final authService = ref.watch(spotifyAuthServiceProvider);
  final spotifyApi = ref.watch(spotifyApiServiceProvider);
  return CompositeLyricsProvider(
    spotify: SpotifyLyricsProvider(
      db: db,
      authService: authService,
      spotifyApi: spotifyApi,
    ),
    betterLyrics: BetterLyricsProvider(),
  );
});

final lyricsProviderRegistryProvider = Provider<LyricsProviderRegistry>((ref) {
  final db = ref.watch(databaseProvider);
  final authService = ref.watch(spotifyAuthServiceProvider);
  final spotifyApi = ref.watch(spotifyApiServiceProvider);
  return LyricsProviderRegistry(
    spotify: SpotifyLyricsProvider(
      db: db,
      authService: authService,
      spotifyApi: spotifyApi,
    ),
  );
});

final trackLyricsProvider =
    FutureProvider.family<SyncedLyrics?, Track>((ref, track) async {
  final libraryRepo = ref.watch(libraryRepositoryProvider);
  final lyricsEngine = ref.watch(lyricsProvider);

  // 1. Check local SQLite cache first (if valid synced lyrics exist)
  final cached = await libraryRepo.getCachedLyrics(track.id);
  if (cached != null) {
    if (cached.syncedLrc != null && cached.syncedLrc!.trim().isNotEmpty) {
      final lines = LrclibLyricsProvider.parseLrc(cached.syncedLrc!);
      if (lines.isNotEmpty) {
        return SyncedLyrics(
          trackId: track.id,
          lines: lines,
          plainLyrics: cached.plainText,
          rawLrc: cached.syncedLrc,
          syncType: 'LINE_SYNCED',
          providerName: 'Local Cache',
        );
      }
    } else if (cached.isNotFound) {
      // Known track without lyrics recorded in SQLite
      return null;
    }
  }

  // 2. Query multi-source lyrics engine with strict 7-second safeguard
  SyncedLyrics? lyrics;
  try {
    lyrics = await lyricsEngine.getLyrics(track).timeout(
          const Duration(seconds: 7),
          onTimeout: () => null,
        );
  } catch (_) {
    lyrics = null;
  }

  if (lyrics != null) {
    try {
      await libraryRepo.cacheLyrics(
        track.id,
        syncedLrc: lyrics.rawLrc,
        plainText: lyrics.plainLyrics,
        isNotFound: false,
      );
    } catch (_) {}
    return lyrics;
  }

  // Negative cache in SQLite to avoid recurring network stalls
  try {
    await libraryRepo.cacheLyrics(
      track.id,
      isNotFound: true,
    );
  } catch (_) {}

  // 3. Fallback to cached plain lyrics if synced could not be resolved
  if (cached != null &&
      cached.plainText != null &&
      cached.plainText!.trim().isNotEmpty) {
    return SyncedLyrics(
      trackId: track.id,
      lines: const [],
      plainLyrics: cached.plainText!.trim(),
      syncType: 'UNSYNCED',
      providerName: 'Local Cache (Plain)',
    );
  }

  return null;
});

// ==========================================
// Play History Stream Provider
// ==========================================

final playHistoryStreamProvider = StreamProvider<List<HistoryItem>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchPlayHistory(limit: 15);
});

// ==========================================
// Personalized Featured Music Provider
// ==========================================

class FeaturedMusic {
  final List<Track> tracks;
  final String subtitle;

  const FeaturedMusic({
    required this.tracks,
    required this.subtitle,
  });
}

final featuredMusicProvider = FutureProvider<FeaturedMusic>((ref) async {
  // Read dependencies once at startup without subscribing to reactive change streams.
  // This ensures Featured Music refreshes on app startup, and NEVER flickers or reloads when liking songs!
  final libraryRepo = ref.watch(libraryRepositoryProvider);
  final catalogRepo = ref.watch(catalogRepositoryProvider);

  Track? seedTrack;
  String subtitle = 'Trending Hits';

  try {
    final history = await libraryRepo.watchPlayHistory(limit: 1).first;
    if (history.isNotEmpty) {
      seedTrack = history.first.track;
      subtitle = 'Based on "${seedTrack.title}"';
    }
  } catch (_) {}

  if (seedTrack == null) {
    try {
      final liked = await libraryRepo.getLikedTracks();
      if (liked.isNotEmpty) {
        seedTrack = liked.first;
        subtitle = 'Based on "${seedTrack.title}"';
      }
    } catch (_) {}
  }

  if (seedTrack != null) {
    try {
      final related = await catalogRepo.getRelatedTracks(seedTrack, limit: 12);
      if (related.isNotEmpty) {
        return FeaturedMusic(tracks: related, subtitle: subtitle);
      }
    } catch (_) {}
  }

  // Fallback to trending hits
  try {
    final trending = await catalogRepo.getTrendingTracks(limit: 12);
    if (trending.isNotEmpty) {
      return FeaturedMusic(tracks: trending, subtitle: 'Trending Hits');
    }
  } catch (_) {}

  // Safe offline fallback
  return const FeaturedMusic(
    tracks: [
      Track(
        id: 'featured-1',
        sourceId: '4NRXx6U8ABQ',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: Duration(seconds: 200),
        coverUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
      ),
      Track(
        id: 'featured-2',
        sourceId: 'TUVcZfQe-Kw',
        title: 'Levitating',
        artist: 'Dua Lipa',
        album: 'Future Nostalgia',
        duration: Duration(seconds: 203),
        coverUrl: 'https://i.ytimg.com/vi/TUVcZfQe-Kw/hqdefault.jpg',
      ),
      Track(
        id: 'featured-3',
        sourceId: 'JGwWNGJdvx8',
        title: 'Shape of You',
        artist: 'Ed Sheeran',
        album: '÷ (Divide)',
        duration: Duration(seconds: 233),
        coverUrl: 'https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg',
      ),
      Track(
        id: 'featured-4',
        sourceId: 'kJQP7kiw5Fk',
        title: 'Despacito',
        artist: 'Luis Fonsi ft. Daddy Yankee',
        album: 'VIDA',
        duration: Duration(seconds: 229),
        coverUrl: 'https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
      ),
    ],
    subtitle: 'Popular Classics',
  );
});

