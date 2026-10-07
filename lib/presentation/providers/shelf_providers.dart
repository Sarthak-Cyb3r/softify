import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/recommendations/logistic_regression_ranker.dart';
import '../../data/recommendations/shelf_engine.dart';
import '../../domain/entities/shelf.dart';
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

  return ShelfEngine(
    db: db,
    tasteProfileRepo: tasteRepo,
    cooccurrenceRepo: cooccurRepo,
    ranker: ranker,
    remoteConfig: remoteConfig,
    eventLogger: eventLogger,
    banditCalibrator: banditCalibrator,
    diversityController: diversityController,
  );
});

final homeShelvesProvider = FutureProvider<List<Shelf>>((ref) async {
  final shelfRepo = ref.watch(shelfRepositoryProvider);
  return shelfRepo.loadShelves();
});
