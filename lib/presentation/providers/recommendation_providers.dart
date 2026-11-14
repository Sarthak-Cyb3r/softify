import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/recommendations/automix_tail_reorderer.dart';
import '../../data/recommendations/drift_cooccurrence_repository.dart';
import '../../data/recommendations/drift_taste_profile_repository.dart';
import '../../data/recommendations/epsilon_greedy_bandit.dart';
import '../../data/recommendations/kl_divergence_calibrator.dart';
import '../../domain/ports/i_automix_tail_reorderer.dart';
import '../../domain/ports/i_bandit_calibrator.dart';
import '../../domain/ports/i_cooccurrence_repository.dart';
import '../../domain/ports/i_taste_profile_repository.dart';
import 'player_providers.dart';

final tasteProfileRepositoryProvider = Provider<ITasteProfileRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftTasteProfileRepository(db);
});

final cooccurrenceRepositoryProvider = Provider<ICooccurrenceRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftCooccurrenceRepository(db);
});

final automixTailReordererProvider = Provider<IAutomixTailReorderer>((ref) {
  return AutomixTailReorderer();
});

final epsilonGreedyBanditProvider = Provider<EpsilonGreedyBandit>((ref) {
  final db = ref.watch(databaseProvider);
  return EpsilonGreedyBandit(db: db);
});

final banditCalibratorProvider = Provider<IBanditCalibrator>((ref) {
  final bandit = ref.watch(epsilonGreedyBanditProvider);
  return KlDivergenceCalibrator(bandit: bandit);
});
