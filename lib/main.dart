import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/catalog/keyless_youtube_catalog.dart';
import 'data/database/app_database.dart';
import 'data/player/softify_audio_handler.dart';
import 'data/repositories/background_download_repository.dart';
import 'data/repositories/drift_event_logger.dart';
import 'data/repositories/drift_library_repository.dart';
import 'data/recommendations/automix_tail_reorderer.dart';
import 'data/recommendations/drift_taste_profile_repository.dart';
import 'data/resolvers/hybrid_stream_resolver.dart';
import 'data/services/spotify_api_service.dart';
import 'data/services/spotify_auth_service.dart';
import 'features/podcasts/data/podcast_metadata_service.dart';
import 'features/podcasts/data/podcast_rss_resolver.dart';
import 'features/podcasts/presentation/podcast_controller.dart';
import 'presentation/providers/player_providers.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'presentation/screens/app_scaffold.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit audio backend for Linux & desktop platforms
  JustAudioMediaKit.ensureInitialized(
    linux: true,
    windows: true,
    android: false,
    iOS: false,
    macOS: false,
  );

  // Fine-tune image decoding cache for smooth 60fps on mid-range devices (e.g. Moto G34)
  PaintingBinding.instance.imageCache.maximumSize = 150;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 * 1024 * 1024; // 60 MB

  // Enforce pristine dark system UI without green edges or lines
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // 1. Core Data Persistence & Repositories
  final db = AppDatabase();
  final authService = SpotifyAuthService(db: db);
  final spotifyApi = SpotifyApiService(authService: authService);
  final eventLogger = DriftEventLogger(db: db);
  final tasteRepo = DriftTasteProfileRepository(db);
  final libraryRepo = DriftLibraryRepository(db);
  final podcastMetadata = PodcastMetadataService();
  final podcastResolver = PodcastRssResolver(metadataService: podcastMetadata);
  final streamResolver = HybridStreamResolver(podcastResolver: podcastResolver);
  final catalogRepo = KeylessYouTubeCatalog(spotifyApi: spotifyApi);
  final downloadRepo = BackgroundDownloadRepository(
    db: db,
    streamResolver: streamResolver,
    libraryRepo: libraryRepo,
  );

  // 2. Audio Service Startup Dependency Injection (D6 / D14)
  final audioHandler = await AudioService.init(
    builder: () => SoftifyAudioHandler(
      streamResolver: streamResolver,
      libraryRepo: libraryRepo,
      downloadRepo: downloadRepo,
      catalogRepo: catalogRepo,
      eventLogger: eventLogger,
      tasteRepo: tasteRepo,
      automixTailReorderer: AutomixTailReorderer(),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.softify.audio',
      androidNotificationChannelName: 'Softify Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        eventLoggerProvider.overrideWithValue(eventLogger),
        libraryRepositoryProvider.overrideWithValue(libraryRepo),
        downloadRepositoryProvider.overrideWithValue(downloadRepo),
        streamResolverProvider.overrideWithValue(streamResolver),
        podcastMetadataServiceProvider.overrideWithValue(podcastMetadata),
        podcastRssResolverProvider.overrideWithValue(podcastResolver),
        spotifyApiServiceProvider.overrideWithValue(spotifyApi),
        catalogRepositoryProvider.overrideWithValue(catalogRepo),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const SoftifyApp(),
    ),
  );
}

class SoftifyApp extends StatelessWidget {
  const SoftifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Softify',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
      theme: AppTheme.darkTheme,
      home: const AppScaffold(),
    );
  }
}
