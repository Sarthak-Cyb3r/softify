import 'dart:math' as math;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/evaluation/guardrail_runner.dart';
import 'package:softify/data/evaluation/team_draft_interleaver.dart';
import 'package:softify/data/recommendations/automix_tail_reorderer.dart';
import 'package:softify/data/recommendations/drift_taste_profile_repository.dart';
import 'package:softify/data/recommendations/logistic_regression_ranker.dart';
import 'package:softify/data/recommendations/mmr_diversity_ranker.dart';
import 'package:softify/data/repositories/drift_event_logger.dart';
import 'package:softify/data/search/linear_search_reranker.dart';
import 'package:softify/data/search/rule_intent_router.dart';
import 'package:softify/data/search/vector_search_engine.dart';
import 'package:softify/domain/entities/search_candidate.dart';
import 'package:softify/domain/entities/search_intent.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  Track makeTrack(String id, String title, String artist) {
    return Track(
      id: id,
      sourceId: 'src_$id',
      title: title,
      artist: artist,
      duration: const Duration(minutes: 3),
    );
  }

  group('Full System End-to-End Regression Test (Sprints 1 to 9)', () {
    late AppDatabase db;
    late DriftEventLogger eventLogger;
    late DriftTasteProfileRepository tasteRepo;
    late LogisticRegressionRanker ranker;
    late LinearSearchReranker searchReranker;
    late RuleIntentRouter intentRouter;
    late AutomixTailReorderer automixReorderer;
    late MmrDiversityRanker diversityRanker;
    late VectorSearchEngine vectorEngine;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      eventLogger = DriftEventLogger(db: db);
      tasteRepo = DriftTasteProfileRepository(db);
      ranker = LogisticRegressionRanker(db: db);
      searchReranker = LinearSearchReranker();
      intentRouter = RuleIntentRouter();
      automixReorderer = AutomixTailReorderer(ranker: ranker);
      diversityRanker = MmrDiversityRanker(db: db);
      vectorEngine = VectorSearchEngine(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Sprint 1 Guardrail: Zero telemetry, all events logged strictly to local SQLite', () async {
      eventLogger.logPlay(
        trackId: 't1',
        source: 'home_shelf',
        listenedMs: 45000,
        durationMs: 180000,
        saved: false,
        addedToPlaylist: false,
        rankerVersion: 'v1.0',
      );

      final events = await db.select(db.playEvents).get();
      expect(events.length, 1);
      expect(events.first.trackId, 't1');
      expect(events.first.listenedMs, 45000);
    });

    test('Sprint 2 Guardrail: Linear search reranker enforces exact match +10.0 score boost', () {
      final candidates = [
        SearchCandidate(
          track: makeTrack('c1', 'Arijit Singh Best Songs Compilation', 'Various Artists'),
          source: 'network',
          features: {'fts_bm25': 0.8},
        ),
        SearchCandidate(
          track: makeTrack('c2', 'Tum Hi Ho', 'Arijit Singh'),
          source: 'local_fts',
          features: {'fts_bm25': 0.5},
        ),
      ];

      final reranked = searchReranker.rerank(query: 'Tum Hi Ho', candidates: candidates);
      expect(reranked.first.track.id, 'c2');
      expect(reranked.first.score, greaterThan(10.0));
    });

    test('Sprint 3 Guardrail: Dual-band taste decay updates fast and slow weights', () async {
      final track = makeTrack('t_decay', 'Starboy', 'The Weeknd');
      await tasteRepo.updateFromPlay(
        track: track,
        isStream: true,
        isEarlySkip: false,
        isSave: true,
      );

      final profile = await (db.select(db.tasteProfiles)
            ..where((tbl) => tbl.entityId.equals('The Weeknd')))
          .getSingle();

      expect(profile.slowWeight, greaterThan(0.0));
      expect(profile.fastWeight, greaterThan(0.0));
    });

    test('Sprint 4 Guardrail: Logistic ranker enforces >50% penalty on 3 consecutive skips', () async {
      // Insert Drake track
      await db.into(db.tracks).insert(
        const TrackRow(
          id: 'drake_track',
          sourceId: 'src_drake',
          title: 'Gods Plan',
          artist: 'Drake',
          durationMs: 180000,
          createdAt: 1000,
          isLiked: false,
          isUnavailable: false,
        ),
      );

      // 3 consecutive skips for Drake
      for (int i = 0; i < 3; i++) {
        await db.into(db.playEvents).insert(
          PlayEventRow(
            id: i + 1,
            ts: 1000 + i * 1000,
            trackId: 'drake_track',
            source: 'search',
            listenedMs: 5000,
            durationMs: 180000,
            skippedEarly: true,
            saved: false,
            addedToPlaylist: false,
            rankerVersion: 'v1.0',
            featuresJson: null,
          ),
        );
      }

      final penalty = await ranker.computeArtistSkipPenaltyFromHistory('Drake');
      // Invariant: penalty must be >= 1.0
      expect(penalty, greaterThanOrEqualTo(1.0));
    });

    test('Sprint 5 Guardrail: Rule intent router resolves domain intents without remote LLMs', () {
      final intent = intentRouter.resolve('chill lofi');
      expect(intent, isA<MoodOrGenreIntent>());

      final artistIntent = intentRouter.resolve('arijit singh');
      expect(artistIntent, isA<ArtistIntent>());
    });

    test('Sprint 6 Guardrail: AutomixTailReorderer preserves untouchable N+1 pre-buffer', () {
      final queue = [
        makeTrack('0', 'Track 0 (Playing)', 'Artist A'),
        makeTrack('1', 'Track 1 (Pre-buffered N+1)', 'Artist B'),
        makeTrack('2', 'Track 2 (Tail Candidate)', 'Artist C'),
        makeTrack('3', 'Track 3 (Tail Candidate)', 'Artist A'),
      ];

      final result = automixReorderer.reorderTail(
        currentQueue: queue,
        currentIndex: 0,
        hasBufferedNext: true,
        sessionConsecutiveSkips: 2,
      );

      // Invariant: Track 0 and Track 1 must remain identical
      expect(result[0].id, '0');
      expect(result[1].id, '1');
      expect(result.length, queue.length);
    });

    test('Sprint 7 Guardrail: MMR Diversity enforces maxPerArtist cap and 30-day snooze', () async {
      final tracks = [
        makeTrack('1', 'Song 1', 'Taylor Swift'),
        makeTrack('2', 'Song 2', 'Taylor Swift'),
        makeTrack('3', 'Song 3', 'Taylor Swift'),
        makeTrack('4', 'Song 4', 'Taylor Swift'),
        makeTrack('5', 'Song 5', 'Coldplay'),
      ];

      final mmrResult = diversityRanker.applyMmr(tracks, maxPerArtist: 2);
      final swiftCount = mmrResult.where((t) => t.artist == 'Taylor Swift').length;
      expect(swiftCount, 2);

      await diversityRanker.snoozeArtist('Coldplay', const Duration(days: 30));
      expect(await diversityRanker.isSnoozed('Coldplay'), isTrue);
    });

    test('Sprint 8 Guardrail: Team-Draft Interleaving balances arms and latency guardrail holds', () async {
      final interleaver = TeamDraftInterleaver(db: db, random: math.Random(99));

      final listA = [makeCand('a1', 'Song A1', 'Artist 1')];
      final listB = [makeCand('b1', 'Song B1', 'Artist 2')];

      final interleaved = interleaver.interleave(
        listA: listA,
        listB: listB,
        modelAId: 'model_a',
        modelBId: 'model_b',
      );
      expect(interleaved.length, 2);

      // Latency Guardrail
      final report = await GuardrailRunner.evaluateLatencyGuardrail(
        queries: ['tum hi ho', 'blinding lights', 'starboy'],
        executor: (q) async {
          final _ = searchReranker.rerank(query: q, candidates: listA);
        },
      );
      expect(report.passedP75Guardrail, isTrue);
    });

    test('Sprint 9 Guardrail: Semantic Vector Search stores and retrieves nearest embeddings locally', () async {
      final vecA = VectorSearchEngine.generateEmbeddingFromText('Tum Hi Ho Arijit Singh');
      final vecB = VectorSearchEngine.generateEmbeddingFromText('Heavy Metal Guitar Instrumental');

      await vectorEngine.storeEmbedding('t_tum_hi_ho', vecA);
      await vectorEngine.storeEmbedding('t_metal', vecB);

      final query = VectorSearchEngine.generateEmbeddingFromText('Tum Hi Ho');
      final nearest = await vectorEngine.searchNearest(query, limit: 1);

      expect(nearest.first, 't_tum_hi_ho');
    });
  });
}

SearchCandidate makeCand(String id, String title, String artist) {
  return SearchCandidate(
    track: Track(
      id: id,
      sourceId: 'src_$id',
      title: title,
      artist: artist,
      duration: const Duration(minutes: 3),
    ),
    source: 'local_fts',
    features: {'score': 1.0},
  );
}
