import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/player/softify_audio_handler.dart';
import '../../domain/entities/audio_repeat_mode.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/entities/history_item.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/playlist_entry.dart';
import '../../domain/entities/track.dart';
import '../../data/catalog/keyless_youtube_catalog.dart';
import '../../data/lyrics/lrclib_lyrics_provider.dart';
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

// ==========================================
// Core Dependency Providers (Injected at Startup)
// ==========================================

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
  return KeylessYouTubeCatalog();
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

// ==========================================
// Reactive Playback & Queue State Streams
// ==========================================

final currentTrackProvider = StreamProvider<Track?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.currentTrackStream;
});

final queueProvider = StreamProvider<List<Track>>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.tracksQueueStream;
});

final playbackStateStreamProvider = StreamProvider<PlaybackState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playbackState;
});

final positionStreamProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.positionStream;
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

// ==========================================
// Synced Lyrics Provider with Local Cache
// ==========================================

final lyricsProvider = Provider<ILyricsProvider>((ref) => LrclibLyricsProvider());

final trackLyricsProvider =
    FutureProvider.family<SyncedLyrics?, Track>((ref, track) async {
  final libraryRepo = ref.watch(libraryRepositoryProvider);
  final lyricsEngine = ref.watch(lyricsProvider);

  // 1. Check local SQLite cache first
  final cached = await libraryRepo.getCachedLyrics(track.id);
  if (cached != null) {
    if (cached.isNotFound) return null;
    if (cached.syncedLrc != null) {
      final lines = LrclibLyricsProvider.parseLrc(cached.syncedLrc!);
      return SyncedLyrics(
        trackId: track.id,
        lines: lines,
        plainLyrics: cached.plainText,
        rawLrc: cached.syncedLrc,
      );
    }
  }

  // 2. Query LRCLIB
  final lyrics = await lyricsEngine.getLyrics(track);
  if (lyrics != null) {
    await libraryRepo.cacheLyrics(
      track.id,
      syncedLrc: lyrics.rawLrc,
      plainText: lyrics.plainLyrics,
      isNotFound: false,
    );
  } else {
    // Negative response caching (DESIGN.md Section 2)
    await libraryRepo.cacheLyrics(
      track.id,
      isNotFound: true,
    );
  }

  return lyrics;
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

