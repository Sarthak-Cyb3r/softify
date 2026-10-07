import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../database/app_database.dart';

class EpsilonGreedyBandit {
  final AppDatabase? _db;
  final math.Random _random;

  static const List<double> arms = [0.0, 0.1, 0.2, 0.3, 0.5];

  final Map<String, _BanditArmStats> _inMemoryStats = {};

  EpsilonGreedyBandit({
    AppDatabase? db,
    math.Random? random,
  })  : _db = db,
        _random = random ?? math.Random();

  /// Chooses a novelty ratio arm for the given shelf using epsilon-greedy strategy.
  Future<double> getNoveltyRatio(String shelfId) async {
    final stats = await _getOrCreateStats(shelfId);

    // Exploration: with probability epsilon, choose a random arm
    if (_random.nextDouble() < stats.epsilon) {
      final chosenArm = arms[_random.nextInt(arms.length)];
      stats.currentRatio = chosenArm;
      return chosenArm;
    }

    // Exploitation: choose arm with best average reward (or current ratio)
    double bestRatio = stats.currentRatio;
    double bestAvgReward = -1.0;

    for (final arm in arms) {
      final armPulls = stats.armPulls[arm] ?? 0;
      final armReward = stats.armRewards[arm] ?? 0.0;
      final avg = armPulls > 0 ? (armReward / armPulls) : 0.5; // neutral prior
      if (avg > bestAvgReward) {
        bestAvgReward = avg;
        bestRatio = arm;
      }
    }

    stats.currentRatio = bestRatio;
    return bestRatio;
  }

  /// Records downstream feedback (stream or save = success, early skip = failure).
  Future<void> recordFeedback({
    required String shelfId,
    required double ratioUsed,
    required bool success,
  }) async {
    final stats = await _getOrCreateStats(shelfId);
    final reward = success ? 1.0 : 0.0;

    stats.pullCount++;
    stats.cumulativeReward += reward;
    stats.currentRatio = ratioUsed;

    // Track per-arm statistics
    stats.armPulls[ratioUsed] = (stats.armPulls[ratioUsed] ?? 0) + 1;
    stats.armRewards[ratioUsed] = (stats.armRewards[ratioUsed] ?? 0.0) + reward;

    // Slowly decay epsilon down to minimum 0.05
    stats.epsilon = math.max(0.05, stats.epsilon * 0.98);

    // Persist to database if available
    final db = _db;
    if (db != null) {
      try {
        await db.into(db.banditStates).insertOnConflictUpdate(
          BanditStatesCompanion(
            shelfId: Value(shelfId),
            epsilon: Value(stats.epsilon),
            pullCount: Value(stats.pullCount),
            cumulativeReward: Value(stats.cumulativeReward),
            currentNoveltyRatio: Value(stats.currentRatio),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
      } catch (_) {}
    }
  }

  Future<_BanditArmStats> _getOrCreateStats(String shelfId) async {
    if (_inMemoryStats.containsKey(shelfId)) {
      return _inMemoryStats[shelfId]!;
    }

    final db = _db;
    if (db != null) {
      try {
        final row = await (db.select(db.banditStates)
              ..where((tbl) => tbl.shelfId.equals(shelfId)))
            .getSingleOrNull();
        if (row != null) {
          final loaded = _BanditArmStats(
            epsilon: row.epsilon,
            pullCount: row.pullCount,
            cumulativeReward: row.cumulativeReward,
            currentRatio: row.currentNoveltyRatio,
          );
          _inMemoryStats[shelfId] = loaded;
          return loaded;
        }
      } catch (_) {}
    }

    final defaultStats = _BanditArmStats(
      epsilon: 0.1,
      pullCount: 0,
      cumulativeReward: 0.0,
      currentRatio: 0.2,
    );
    _inMemoryStats[shelfId] = defaultStats;
    return defaultStats;
  }
}

class _BanditArmStats {
  double epsilon;
  int pullCount;
  double cumulativeReward;
  double currentRatio;
  final Map<double, int> armPulls = {};
  final Map<double, double> armRewards = {};

  _BanditArmStats({
    required this.epsilon,
    required this.pullCount,
    required this.cumulativeReward,
    required this.currentRatio,
  });
}
