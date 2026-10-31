import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog/keyless_youtube_catalog.dart';
import '../../data/recommendations/logistic_regression_ranker.dart';
import '../../data/recommendations/shelf_engine.dart';
import '../../data/services/smart_playlists_service.dart';
import '../../domain/entities/shelf.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_shelf_repository.dart';
import 'diversity_providers.dart';
import 'player_providers.dart';
import 'recommendation_providers.dart';

final recommendationRankerProvider = Provider<LogisticRegressionRanker>((ref) {
  final db = ref.watch(databaseProvider);
  final ranker = LogisticRegressionRanker(db: db);
  // Asynchronously load any persisted SGD weights
  ranker.loadPersistedWeights();
  return ranker;
});

final shelfRepositoryProvider = Provider<IShelfRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final tasteRepo = ref.watch(tasteProfileRepositoryProvider);
  final cooccurRepo = ref.watch(cooccurrenceRepositoryProvider);
  final ranker = ref.watch(recommendationRankerProvider);
  final remoteConfig = ref.watch(remoteConfigProvider);
  final eventLogger = ref.watch(eventLoggerProvider);
  final banditCalibrator = ref.watch(banditCalibratorProvider);
  final diversityController = ref.watch(diversityControllerProvider);
  final spotifyApi = ref.watch(spotifyApiServiceProvider);

  return ShelfEngine(
    db: db,
    tasteProfileRepo: tasteRepo,
    cooccurrenceRepo: cooccurRepo,
    ranker: ranker,
    remoteConfig: remoteConfig,
    eventLogger: eventLogger,
    banditCalibrator: banditCalibrator,
    diversityController: diversityController,
    spotifyApi: spotifyApi,
  );
});

final homeShelvesProvider = FutureProvider<List<Shelf>>((ref) async {
  final shelfRepo = ref.watch(shelfRepositoryProvider);
  return shelfRepo.loadShelves();
});

final onRepeatTracksProvider = FutureProvider<List<Track>>((ref) async {
  final db = ref.watch(databaseProvider);
  return SmartPlaylistsService.getOnRepeatTracks(db);
});

final mostPlayedTracksProvider = FutureProvider<List<Track>>((ref) async {
  final db = ref.watch(databaseProvider);
  return SmartPlaylistsService.getMostPlayedThisMonth(db);
});

final forgottenFavoritesProvider = FutureProvider<List<Track>>((ref) async {
  final db = ref.watch(databaseProvider);
  return SmartPlaylistsService.getForgottenFavorites(db);
});

final listeningInsightsTimeframeProvider = StateProvider<InsightsTimeframe>((ref) {
  return InsightsTimeframe.allTime;
});

final listeningInsightsProvider = FutureProvider<ListeningInsights>((ref) async {
  final db = ref.watch(databaseProvider);
  final timeframe = ref.watch(listeningInsightsTimeframeProvider);
  return SmartPlaylistsService.getListeningInsights(db, timeframe: timeframe);
});

final topChartTracksProvider = FutureProvider.family<List<Track>, String>((ref, chartType) async {
  final catalogRepo = ref.watch(catalogRepositoryProvider);
  if (catalogRepo is KeylessYouTubeCatalog) {
    return catalogRepo.getTopChart(chartType, limit: 30);
  }
  return catalogRepo.getTrendingTracks(limit: 30);
});

final homeMoodTracksProvider = FutureProvider.family<List<Track>, String>((ref, mood) async {
  if (mood == 'All') return const [];
  final catalogRepo = ref.watch(catalogRepositoryProvider);
  final query = switch (mood) {
    'Relax' => 'chill relaxing acoustic songs peaceful calm',
    'Energize' => 'energizing upbeat pop dance hype workout hits',
    'Workout' => 'workout gym motivation fitness beats hip hop',
    'Focus' => 'lofi study beats ambient instrumental deep focus',
    'Commute' => 'road trip travel commute feel good vibes',
    'Party' => 'party club dance floor bangers edm pop',
    'Romance' => 'romantic love songs acoustic soft ballads',
    _ => '$mood songs mix',
  };
  try {
    return await catalogRepo.search(query, limit: 20);
  } catch (_) {
    return const [];
  }
});
