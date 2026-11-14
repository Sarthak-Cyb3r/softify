import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/importer/keyless_spotify_importer.dart';
import '../../data/recommendations/cold_start_seeder.dart';
import '../../data/recommendations/explanation_generator.dart';
import '../../data/recommendations/mmr_diversity_ranker.dart';
import '../../domain/ports/i_cold_start_seeder.dart';
import '../../domain/ports/i_diversity_controller.dart';
import 'player_providers.dart';
import 'recommendation_providers.dart';

final diversityControllerProvider = Provider<IDiversityController>((ref) {
  final db = ref.watch(databaseProvider);
  return MmrDiversityRanker(db: db);
});

final explanationGeneratorProvider = Provider<ExplanationGenerator>((ref) {
  final tasteRepo = ref.watch(tasteProfileRepositoryProvider);
  final cooccurRepo = ref.watch(cooccurrenceRepositoryProvider);
  return ExplanationGenerator(
    tasteRepo: tasteRepo,
    cooccurRepo: cooccurRepo,
  );
});

final coldStartSeederProvider = Provider<IColdStartSeeder>((ref) {
  final db = ref.watch(databaseProvider);
  return ColdStartSeeder(
    db: db,
    spotifyImporter: KeylessSpotifyImporter(),
  );
});

final snoozedArtistsProvider = FutureProvider<List<String>>((ref) async {
  final controller = ref.watch(diversityControllerProvider);
  return controller.getSnoozedArtists();
});

final learningPausedProvider = FutureProvider<bool>((ref) async {
  final controller = ref.watch(diversityControllerProvider);
  return controller.isLearningPaused();
});
