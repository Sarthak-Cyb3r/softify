import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../domain/entities/search_candidate.dart';
import '../../domain/ports/i_interleaving_engine.dart';
import '../database/app_database.dart';

class TeamDraftInterleaver implements IInterleavingEngine {
  final AppDatabase? _db;
  final math.Random _random;

  // In-memory mapping of track ID to credited model ID for active search session
  final Map<String, String> _activeSessionCredits = {};

  TeamDraftInterleaver({
    AppDatabase? db,
    math.Random? random,
  })  : _db = db,
        _random = random ?? math.Random();

  @override
  List<SearchCandidate> interleave({
    required List<SearchCandidate> listA,
    required List<SearchCandidate> listB,
    required String modelAId,
    required String modelBId,
    double holdbackRatio = 0.1,
  }) {
    if (listA.isEmpty) return List.unmodifiable(listB);
    if (listB.isEmpty) return List.unmodifiable(listA);

    final interleaved = <SearchCandidate>[];
    final seenIds = <String>{};

    int ptrA = 0;
    int ptrB = 0;
    int teamASize = 0;
    int teamBSize = 0;

    final holdbackInterval = holdbackRatio > 0.0
        ? (1.0 / holdbackRatio).round().clamp(2, 50)
        : 1000;

    int slotIndex = 0;

    while (ptrA < listA.length || ptrB < listB.length) {
      // 1. Check holdback baseline slot (e.g. index 9, 19, 29)
      if (slotIndex > 0 && (slotIndex % holdbackInterval == holdbackInterval - 1)) {
        while (ptrA < listA.length && seenIds.contains(listA[ptrA].track.id)) {
          ptrA++;
        }
        if (ptrA < listA.length) {
          final cand = listA[ptrA++];
          seenIds.add(cand.track.id);
          interleaved.add(cand);
          _activeSessionCredits[cand.track.id] = 'baseline_holdback';
          slotIndex++;
          continue;
        }
      }

      // 2. Team Draft Selection
      bool pickFromA;
      if (teamASize < teamBSize) {
        pickFromA = true;
      } else if (teamBSize < teamASize) {
        pickFromA = false;
      } else {
        // Fair coin toss on ties
        pickFromA = _random.nextBool();
      }

      SearchCandidate? selectedCand;
      String? creditedModel;

      if (pickFromA) {
        while (ptrA < listA.length && seenIds.contains(listA[ptrA].track.id)) {
          ptrA++;
        }
        if (ptrA < listA.length) {
          selectedCand = listA[ptrA++];
          creditedModel = modelAId;
          teamASize++;
        } else {
          // Fallback to B if A exhausted
          while (ptrB < listB.length && seenIds.contains(listB[ptrB].track.id)) {
            ptrB++;
          }
          if (ptrB < listB.length) {
            selectedCand = listB[ptrB++];
            creditedModel = modelBId;
            teamBSize++;
          }
        }
      } else {
        while (ptrB < listB.length && seenIds.contains(listB[ptrB].track.id)) {
          ptrB++;
        }
        if (ptrB < listB.length) {
          selectedCand = listB[ptrB++];
          creditedModel = modelBId;
          teamBSize++;
        } else {
          // Fallback to A if B exhausted
          while (ptrA < listA.length && seenIds.contains(listA[ptrA].track.id)) {
            ptrA++;
          }
          if (ptrA < listA.length) {
            selectedCand = listA[ptrA++];
            creditedModel = modelAId;
            teamASize++;
          }
        }
      }

      if (selectedCand != null && creditedModel != null) {
        seenIds.add(selectedCand.track.id);
        interleaved.add(selectedCand);
        _activeSessionCredits[selectedCand.track.id] = creditedModel;
        slotIndex++;
      } else {
        // Both exhausted
        break;
      }
    }

    return interleaved;
  }

  @override
  Future<void> recordClickOrStream({
    required String itemId,
    required String creditedModelId,
    String? queryOrContext,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = _db;
    if (db != null) {
      try {
        await db.into(db.interleaveOutcomes).insert(
          InterleaveOutcomesCompanion(
            queryOrContext: Value(queryOrContext ?? 'search'),
            modelAId: const Value('baseline_lexical'),
            modelBId: const Value('candidate_hybrid'),
            winningModelId: Value(creditedModelId),
            ts: Value(now),
          ),
        );
      } catch (_) {}
    }
  }

  /// Gets credited model for track in current session
  String? getCreditedModelForTrack(String trackId) {
    return _activeSessionCredits[trackId];
  }

  @override
  Future<Map<String, int>> getModelWinRates() async {
    final counts = <String, int>{};
    final db = _db;
    if (db != null) {
      try {
        final rows = await db.select(db.interleaveOutcomes).get();
        for (final row in rows) {
          final winner = row.winningModelId;
          if (winner != null) {
            counts[winner] = (counts[winner] ?? 0) + 1;
          }
        }
      } catch (_) {}
    }
    return counts;
  }
}
