# Softify v2.0 Technical Roadmap Specification

> High-density engineering contract for autonomous agent execution. All tasks are client-side only, offline-first, zero-telemetry, clean-architecture compliant.

---

## 0. Sprint Tracker

- [x] **Sprint 1: Telemetry Foundation & Instant Search** (F0: Event Log & Metrics | S1: Local-First Instant Search)
- [x] **Sprint 2: Lexical Retrieval & Linear Ranker** (S2: FTS5 & Fuzzy Aliases | S3: Multi-Source Re-Ranker)
- [x] **Sprint 3: Representation Graph & Taste Decay** (R1: Dual-Band Taste Profile | R2: Co-Occurrence Sentence Graph)
- [x] **Sprint 4: Personalized Serving & Home Surfaces** (R3: Pointwise Logistic Ranker | R4: Algotorial Home Shelves)
- [x] **Sprint 5: Discovery Guidance & Intent Routing** (S4: Autocomplete Suggestions | S5: Rule-Based Intent Router)
- [x] **Sprint 6: Dynamic Session Queue & Contextual Bandit** (R5: Automix Tail Re-ranking | R6: Bandit & KL Calibration)
- [x] **Sprint 7: Discovery Agency & Onboarding Seeding** (R7: MMR Diversity & Controls | R8: Cold Start Import Seeding)
- [x] **Sprint 8: Empirical Validation & Guardrail Suite** (E1: Team-Draft Interleaving | E2: Latency & Golden Benchmarks)
- [x] **Sprint 9: Semantic Vector Retrieval & v2.0 Release Gate** (E3: On-Device Vector Search | Production Sign-off)

---

## 1. System Guardrails & Hard Constraints

1. **Zero Telemetry / Absolute Privacy**: No remote logging, analytics, or network transforms. All learning happens in on-device SQLite/Drift tables.
2. **Dual-Engine Pre-Buffer Invariant**: The pre-buffer schedules track $N+1$ into the secondary player engine $\approx 15\text{s}$ before track $N$ completes. **Never re-order, cancel, or mutate track $N+1$**. Ranking mutations operate strictly on index $\ge N+2$ (the unbuffered tail).
3. **Execution Budgets**:
   - Local search & autocomplete responses: $< 100\text{ ms}$.
   - Heavy tasks (FTS tokenization, PMI co-occurrence graph building, k-means clustering, SGD batch steps): Run in dedicated background isolates; never block UI or audio threads.
4. **Clean Architecture Boundary**:
   - `domain/`: Pure Dart, entities, and repository/service interfaces.
   - `data/`: Drift table schemas, repository implementations, isolate dispatchers, network catalog.
   - `presentation/`: Riverpod providers and Flutter UI. UI reads strictly from providers.
5. **Definitions**:
   - `Stream`: Continuous playback $\ge 30.0\text{ seconds}$.
   - `Early Skip`: Track stopped or skipped before $< 30.0\text{ seconds}$.
   - `Impression`: Visual render of an item card/tile in viewport.
   - `Success`: `Stream`, `Favorite/Save`, or `Playlist Add`.

---

## Sprint 1: Telemetry Foundation & Instant Search
**Features**: F0 (Local Event Log & Debug Metrics) + S1 (Local-First Instant Search)

### Target Files
- `lib/domain/entities/interaction_events.dart`
- `lib/domain/ports/i_event_logger.dart`
- `lib/data/database/app_database.dart` (Schema v2)
- `lib/data/repositories/drift_event_logger.dart`
- `lib/data/player/softify_audio_handler.dart` (wire fire-and-forget logging)
- `lib/presentation/providers/search_providers.dart` (120ms debounce + request cancellation)
- `lib/presentation/screens/debug_metrics_screen.dart` (7-tap version secret screen)
- `test/local_event_log_test.dart`
- `test/instant_search_test.dart`

### Drift Schema (v2 Migration)
```dart
@DataClassName('SearchEventRow')
class SearchEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer()();
  TextColumn get query => text()();
  TextColumn get resultIdsJson => text()(); // List<String> encoded
  IntColumn get shownCount => integer()();
  TextColumn get clickedId => text().nullable()();
  IntColumn get clickedPosition => integer().nullable()();
  IntColumn get msToClick => integer().nullable()();
  TextColumn get rankerVersion => text()();
}

@DataClassName('PlayEventRow')
class PlayEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer()();
  TextColumn get trackId => text()();
  TextColumn get source => text()(); // 'search' | 'shelf:<name>' | 'autoplay' | 'library' | 'radio'
  IntColumn get listenedMs => integer()();
  IntColumn get durationMs => integer()();
  BoolColumn get skippedEarly => boolean()(); // listenedMs < 30000
  BoolColumn get saved => boolean()();
  BoolColumn get addedToPlaylist => boolean()();
  TextColumn get rankerVersion => text()();
  TextColumn get featuresJson => text().nullable()(); // Snapshot of features at serving time
}

@DataClassName('ImpressionRow')
class Impressions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer()();
  TextColumn get surface => text()(); // 'home_shelf' | 'search_result'
  TextColumn get itemId => text()();
  IntColumn get position => integer()();
}
```

### Core Interfaces & Signatures
```dart
abstract class IEventLogger {
  void logSearch({
    required String query,
    required List<String> resultIds,
    String? clickedId,
    int? clickedPosition,
    int? msToClick,
    required String rankerVersion,
  });

  void logPlay({
    required String trackId,
    required String source,
    required int listenedMs,
    required int durationMs,
    required bool saved,
    required bool addedToPlaylist,
    required String rankerVersion,
    Map<String, double>? features,
  });

  void logImpression({required String surface, required String itemId, required int position});
  Future<DebugMetricsSummary> getMetricsSummary();
  Future<void> clearAllLearningData();
}

class DebugMetricsSummary {
  final double streamRate;       // streams / total plays
  final double earlySkipRate;    // skips / total plays
  final double searchTop1ClickRate;
  final int medianMsToClick;
  const DebugMetricsSummary({required this.streamRate, required this.earlySkipRate, required this.searchTop1ClickRate, required this.medianMsToClick});
}
```

### Constraints & Invariants
- `logPlay()` and `logSearch()` must be synchronous fire-and-forget or `unawaited(Future)`: zero blocking on `AudioHandler` track transitions.
- Instant search must debounce at $120\text{ ms}$, cancel previous in-flight network queries via `CancelToken`, and merge network items below existing local results without visual jumps.

### Verification Commands
```bash
flutter test test/local_event_log_test.dart
flutter test test/instant_search_test.dart
```

---

## Sprint 2: Lexical Retrieval & Linear Ranker
**Features**: S2 (Local FTS5 Index, Fuzzy Match & Aliases) + S3 (Multi-Source Retrieval & Linear Re-Ranker)

### Target Files
- `lib/domain/entities/search_candidate.dart`
- `lib/domain/ports/i_fts_repository.dart`
- `lib/domain/ports/i_search_reranker.dart`
- `lib/data/database/app_database.dart` (Schema v3: FTS5 Virtual Table)
- `lib/data/search/text_normalizer.dart`
- `lib/data/search/drift_fts_repository.dart`
- `lib/data/search/linear_search_reranker.dart`
- `lib/data/repositories/remote_config_repository.dart` (Load aliases & ranker weights)
- `lib/presentation/providers/search_providers.dart`
- `assets/config/aliases.json` (bundled fallback)
- `test/fts_normalizer_golden_test.dart`
- `test/search_reranker_test.dart`

### Drift Schema & Config Contract (v3 Migration)
```sql
-- FTS5 virtual table covering library, history and cached downloads
CREATE VIRTUAL TABLE IF NOT EXISTS track_fts USING fts5(
  track_id UNINDEXED,
  title,
  artist,
  album,
  tokenize = 'unicode61 remove_diacritics 2'
);
```
Remote Config additions:
- `search_aliases`: `{"arijit": ["arijit singh"], "kk": ["krishnakumar kunnath"], "weeknd": ["the weeknd"]}`
- `search_ranker_weights_v1`: `{"is_exact": 3.0, "prefix_match": 2.0, "played_count": 1.5, "taste_similarity": 1.0, "popularity_proxy": 0.5, "edit_distance_penalty": -1.2}`

### Core Interfaces & Signatures
```dart
class SearchCandidate {
  final Track track;
  final String source; // 'local_fts' | 'network' | 'history'
  final Map<String, double> features;
  double score;
  SearchCandidate({required this.track, required this.source, required this.features, this.score = 0.0});
}

abstract class IFtsRepository {
  Future<List<String>> queryFts(String query);
  Future<void> indexTrack(Track track);
  Future<void> removeTrack(String trackId);
  Future<void> rebuildFullIndex();
}

abstract class ISearchReranker {
  List<SearchCandidate> rerank({
    required String query,
    required List<SearchCandidate> candidates,
    Map<String, double>? weights,
  });
}
```

### Constraints & Invariants
- Text normalizer: Lowercase, diacritic stripping, punctuation collapse, Hinglish/Romanized token mapping via `aliases.json`.
- Exact match must always score higher than fuzzy matches.
- All scores and feature snapshots must be written to `SearchEvents.resultIdsJson` and `featuresJson`.

### Verification Commands
```bash
flutter test test/fts_normalizer_golden_test.dart
flutter test test/search_reranker_test.dart
```

---

## Sprint 3: Representation Graph & Taste Decay
**Features**: R1 (Dual-Band Taste Profile) + R2 (Co-Occurrence Sentence Graph)

### Target Files
- `lib/domain/entities/taste_profile.dart`
- `lib/domain/ports/i_taste_profile_repository.dart`
- `lib/domain/ports/i_cooccurrence_repository.dart`
- `lib/data/database/app_database.dart` (Schema v4)
- `lib/data/recommendations/drift_taste_profile_repository.dart`
- `lib/data/recommendations/cooccurrence_graph_builder.dart`
- `lib/data/recommendations/recommendation_isolates.dart`
- `lib/presentation/providers/recommendation_providers.dart`
- `test/taste_profile_decay_test.dart`
- `test/cooccurrence_graph_test.dart`

### Drift Schema (v4 Migration)
```dart
@DataClassName('TasteProfileRow')
class TasteProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()(); // 'artist' | 'genre' | 'language'
  TextColumn get entityId => text()();
  RealColumn get slowWeight => real().withDefault(const Constant(0.0))(); // Half-life: 14 days
  RealColumn get fastWeight => real().withDefault(const Constant(0.0))(); // Half-life: 4 hours
  IntColumn get updatedAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [{entityType, entityId}];
}

@DataClassName('CooccurrenceRow')
class Cooccurrences extends Table {
  TextColumn get trackA => text()();
  TextColumn get trackB => text()();
  RealColumn get score => real()(); // Pointwise Mutual Information (PMI)
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {trackA, trackB};
}
```

### Core Interfaces & Signatures
```dart
abstract class ITasteProfileRepository {
  Future<void> updateFromPlay({
    required Track track,
    required bool isStream,
    required bool isEarlySkip,
    required bool isSave,
  });
  Future<double> computeTasteSimilarity(Track track);
  Future<void> applyDecay();
}

abstract class ICooccurrenceRepository {
  /// Session definition: consecutive plays separated by < 60 seconds
  Future<void> rebuildGraphIncremental(List<List<String>> sentences);
  Future<List<String>> getTopNeighbors(String trackId, {int limit = 20});
  Future<double> getPairScore(String trackA, String trackB);
}
```

### Mathematical Decay & Session Invariants
- Fast decay: $W_{\text{fast}}(t) = W_0 \cdot 2^{-\Delta t / 4\text{ hours}}$.
- Slow decay: $W_{\text{slow}}(t) = W_0 \cdot 2^{-\Delta t / 14\text{ days}}$.
- Listening session grouping: Plays with interval $\le 60\text{ seconds}$ form a single sentence sequence.
- Graph calculation runs off-thread in `Isolate.run()`.

### Verification Commands
```bash
flutter test test/taste_profile_decay_test.dart
flutter test test/cooccurrence_graph_test.dart
```

---

## Sprint 4: Personalized Serving & Home Surfaces
**Features**: R3 (Skip-Aware Pointwise Logistic Ranker) + R4 (Algotorial Home Shelves)

### Target Files
- `lib/domain/entities/shelf.dart`
- `lib/domain/ports/i_recommendation_ranker.dart`
- `lib/domain/ports/i_shelf_repository.dart`
- `lib/data/recommendations/logistic_regression_ranker.dart`
- `lib/data/recommendations/shelf_engine.dart`
- `lib/presentation/providers/shelf_providers.dart`
- `lib/presentation/screens/home_screen.dart`
- `test/skip_aware_ranker_test.dart`
- `test/home_shelves_test.dart`

### Shelf Definition Schema (in Remote Config)
```json
[
  {"id": "jump_back_in", "title": "Jump Back In", "rule": "frequency_recency", "limit": 12},
  {"id": "daily_mix", "title": "Daily Mix", "rule": "kmeans_clusters", "limit": 20},
  {"id": "discover_weekly", "title": "Discover Weekly", "rule": "novelty_with_familiar_anchor", "familiar_ratio": 0.1, "limit": 25},
  {"id": "release_radar", "title": "Release Radar", "rule": "followed_new_releases", "limit": 15}
]
```

### Core Interfaces & Signatures
```dart
class RecommendationCandidate {
  final Track track;
  final Map<String, double> features; // taste_sim, cooccurrence, recency, novelty, artist_skip_penalty
  double score;
  RecommendationCandidate({required this.track, required this.features, this.score = 0.0});
}

abstract class IRecommendationRanker {
  List<RecommendationCandidate> rank(List<RecommendationCandidate> candidates);
  Future<void> trainOnDeviceStep({
    required Map<String, double> features,
    required bool positiveLabel, // stream/save = 1.0, early_skip = 0.0
    double learningRate = 0.01,
  });
}

abstract class IShelfRepository {
  Future<List<Shelf>> loadShelves({bool forceRefresh = false});
}
```

### Constraints & Invariants
- 3 consecutive skips of an artist must penalize the candidate score by $> 50\%$.
- Discover Weekly: Exactly $\approx 10\%$ familiar tracks ($1 \text{ in } 10$) inserted as trust anchors.
- Refresh occurs upon app cold launch if stale; no reliance on flaky background tasks on iOS/Android.

### Verification Commands
```bash
flutter test test/skip_aware_ranker_test.dart
flutter test test/home_shelves_test.dart
```

---

## Sprint 5: Discovery Guidance & Intent Routing
**Features**: S4 (Autocomplete Suggestions) + S5 (Rule-Based Intent Router & Dynamic Mixes)

### Target Files
- `lib/domain/entities/search_intent.dart`
- `lib/domain/ports/i_autocomplete_repository.dart`
- `lib/domain/ports/i_intent_router.dart`
- `lib/data/database/app_database.dart` (Schema v5: QueryCompletions)
- `lib/data/search/multi_source_autocomplete.dart`
- `lib/data/search/rule_intent_router.dart`
- `lib/presentation/providers/autocomplete_providers.dart`
- `lib/presentation/screens/search_screen.dart`
- `test/autocomplete_test.dart`
- `test/intent_router_test.dart`

### Drift Schema (v5 Migration)
```dart
@DataClassName('QueryCompletionRow')
class QueryCompletions extends Table {
  TextColumn get query => text()();
  TextColumn get normalizedPrefix => text()();
  IntColumn get streamCount => integer().withDefault(const Constant(0))();
  IntColumn get lastUsedTs => integer()();

  @override
  Set<Column> get primaryKey => {query};
}
```

### Core Interfaces & Signatures
```dart
sealed class SearchIntent {
  const SearchIntent();
}
class ExactTrackIntent extends SearchIntent { final String trackId; const ExactTrackIntent(this.trackId); }
class ArtistIntent extends SearchIntent { final String artistName; const ArtistIntent(this.artistName); }
class SimilarToIntent extends SearchIntent { final String seedTrackTitle; const SimilarToIntent(this.seedTrackTitle); }
class MoodOrGenreIntent extends SearchIntent { final List<String> tags; const MoodOrGenreIntent(this.tags); }
class GenericSearchIntent extends SearchIntent { final String rawQuery; const GenericSearchIntent(this.rawQuery); }

abstract class IIntentRouter {
  SearchIntent resolve(String query);
}

abstract class IAutocompleteRepository {
  Future<List<String>> getSuggestions(String prefix);
  Future<void> recordSuccessfulQuery(String query); // Called only on downstream click->stream/save
}
```

### Constraints & Invariants
- 5 suggestion sources: Remote catalog endpoint, historical successful queries, recent queries, local library titles, artist expansion rules.
- Only queries ending in positive interaction (stream $\ge 30\text{s}$ or save) are logged as completions.
- `MoodOrGenreIntent` automatically constructs a ranked dynamic mix instead of a raw keyword list.

### Verification Commands
```bash
flutter test test/autocomplete_test.dart
flutter test test/intent_router_test.dart
```

---

## Sprint 6: Dynamic Session Queue & Contextual Bandit
**Features**: R5 (Smart Automix Tail Re-ranking) + R6 (Explore/Exploit Bandit & KL Calibration)

### Target Files
- `lib/domain/ports/i_automix_tail_reorderer.dart`
- `lib/domain/ports/i_bandit_calibrator.dart`
- `lib/data/database/app_database.dart` (Schema v6: BanditStates)
- `lib/data/player/softify_audio_handler.dart` (tail hook)
- `lib/data/recommendations/automix_tail_reorderer.dart`
- `lib/data/recommendations/epsilon_greedy_bandit.dart`
- `lib/data/recommendations/kl_divergence_calibrator.dart`
- `test/automix_tail_test.dart`
- `test/bandit_calibration_test.dart`

### Drift Schema (v6 Migration)
```dart
@DataClassName('BanditStateRow')
class BanditStates extends Table {
  TextColumn get shelfId => text()();
  RealColumn get epsilon => real().withDefault(const Constant(0.1))();
  IntColumn get pullCount => integer().withDefault(const Constant(0))();
  RealColumn get cumulativeReward => real().withDefault(const Constant(0.0))();
  RealColumn get currentNoveltyRatio => real().withDefault(const Constant(0.2))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {shelfId};
}
```

### Core Interfaces & Signatures
```dart
abstract class IAutomixTailReorderer {
  /// Strictly reorders queue items from index >= (currentIndex + 2).
  /// Preserves currentTrack and pre-buffered next track.
  List<Track> reorderTail({
    required List<Track> currentQueue,
    required int currentIndex,
    required bool hasBufferedNext,
    required int sessionConsecutiveSkips,
  });
}

abstract class IBanditCalibrator {
  Future<double> getNoveltyRatio(String shelfId);
  Future<void> recordFeedback({required String shelfId, required double ratioUsed, required bool success});
  List<Track> calibrateSlate({required List<Track> candidates, required Map<String, double> targetGenreDistribution});
}
```

### Hard Invariants
- **Untouchable Pre-Buffer**: `currentQueue[currentIndex + 1]` is locked when `hasBufferedNext == true`. Re-ranking strictly begins at index `currentIndex + 2`.
- KL-divergence penalty on recommendation slates: $D_{\text{KL}}(P_{\text{taste}} \parallel Q_{\text{slate}}) \le \tau$, preventing genre drift.
- Two consecutive skips immediately weight tail candidates towards fast interest decay features.

### Verification Commands
```bash
flutter test test/automix_tail_test.dart
flutter test test/bandit_calibration_test.dart
```

---

## Sprint 7: Discovery Agency & Onboarding Seeding
**Features**: R7 (Diversity MMR, Controls & Explanations) + R8 (Cold Start Import Seeding)

### Target Files
- `lib/domain/ports/i_diversity_controller.dart`
- `lib/domain/ports/i_cold_start_seeder.dart`
- `lib/data/database/app_database.dart` (Schema v7: ArtistSnoozes)
- `lib/data/recommendations/mmr_diversity_ranker.dart`
- `lib/data/recommendations/explanation_generator.dart`
- `lib/data/recommendations/cold_start_seeder.dart`
- `lib/presentation/screens/onboarding_screen.dart`
- `lib/presentation/screens/settings_screen.dart` (Snooze & Reset actions)
- `test/diversity_controls_test.dart`
- `test/cold_start_test.dart`

### Drift Schema (v7 Migration)
```dart
@DataClassName('ArtistSnoozeRow')
class ArtistSnoozes extends Table {
  TextColumn get artistId => text()();
  IntColumn get snoozedUntil => integer()(); // Milliseconds timestamp (now + 30 days)

  @override
  Set<Column> get primaryKey => {artistId};
}
```

### Core Interfaces & Signatures
```dart
abstract class IDiversityController {
  /// Maximal Marginal Relevance: lambda * Rel(d) - (1 - lambda) * max Sim(d, s)
  List<Track> applyMmr(List<Track> ranked, {int maxPerArtist = 2, double lambda = 0.7});
  Future<void> snoozeArtist(String artistId, Duration duration);
  Future<bool> isSnoozed(String artistId);
  Future<void> resetAllLearning();
  Future<void> setLearningPaused(bool paused);
}

abstract class IColdStartSeeder {
  Future<void> seedFromInitialArtists(List<String> artistIds);
  Future<void> seedFromSpotifyImport(String playlistId);
}
```

### Constraints & Invariants
- Per-artist cap: Maximum 2 tracks per artist in any home shelf or generated mix.
- 30-day snooze: Excluded from all search suggestions and recommendation rankers until expiry.
- UI Explanation: Every recommendation card displays a 1-line reason (e.g., `"Because you listened to [Track]"` or `"Top Artist match"`).

### Verification Commands
```bash
flutter test test/diversity_controls_test.dart
flutter test test/cold_start_test.dart
```

---

## Sprint 8: Empirical Validation & Guardrail Suite
**Features**: E1 (Single-Device Interleaving) + E2 (Golden Sets & Latency Guardrails)

### Target Files
- `lib/domain/ports/i_interleaving_engine.dart`
- `lib/data/database/app_database.dart` (Schema v8: InterleaveOutcomes)
- `lib/data/evaluation/team_draft_interleaver.dart`
- `lib/data/evaluation/guardrail_runner.dart`
- `lib/presentation/screens/debug_metrics_screen.dart` (Interleaving scoreboard)
- `test/fixtures/golden_query_benchmarks.json` (50+ queries)
- `test/interleaving_test.dart`
- `test/golden_benchmark_guardrail_test.dart`

### Drift Schema (v8 Migration)
```dart
@DataClassName('InterleaveOutcomeRow')
class InterleaveOutcomes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get queryOrContext => text()();
  TextColumn get modelAId => text()();
  TextColumn get modelBId => text()();
  TextColumn get winningModelId => text().nullable()();
  IntColumn get ts => integer()();
}
```

### Core Interfaces & Signatures
```dart
abstract class IInterleavingEngine {
  /// Team-Draft interleaving: alternates selection between ranker A and B
  /// with a 10% holdback slot allocated to baseline order.
  List<SearchCandidate> interleave({
    required List<SearchCandidate> listA,
    required List<SearchCandidate> listB,
    required String modelAId,
    required String modelBId,
    double holdbackRatio = 0.1,
  });

  void recordClickOrStream({required String itemId, required String creditedModelId});
  Future<Map<String, int>> getModelWinRates();
}
```

### Quality & Latency Guardrails
- **p75 Search Latency**: Must not exceed $100\text{ ms}$ over 50 consecutive queries.
- **Regression Ban**: In interleaving, Candidate Model $B$ must not exhibit $> 10\%$ degradation in early-skip rate compared to Model $A$.

### Verification Commands
```bash
flutter test test/interleaving_test.dart
flutter test test/golden_benchmark_guardrail_test.dart
```

---

## Sprint 9: Semantic Vector Retrieval & v2.0 Release Gate
**Features**: E3 (On-Device Semantic Vector Search) + v2.0 Production Release Gate

### Target Files
- `lib/domain/ports/i_vector_search_engine.dart`
- `lib/data/database/app_database.dart` (Schema v9: TrackEmbeddings)
- `lib/data/search/vector_search_engine.dart` (Local Cosine Similarity)
- `test/semantic_vector_test.dart`
- `test/full_system_regression_test.dart`

### Drift Schema (v9 Migration)
```dart
@DataClassName('TrackEmbeddingRow')
class TrackEmbeddings extends Table {
  TextColumn get trackId => text()();
  BlobColumn get vector => blob()(); // 128-dimensional float32 byte buffer
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {trackId};
}
```

### Core Interfaces & Signatures
```dart
abstract class IVectorSearchEngine {
  Future<List<String>> searchNearest(Float32List queryVector, {int limit = 20});
  Future<void> storeEmbedding(String trackId, Float32List vector);
  double computeCosineSimilarity(Float32List a, Float32List b);
}
```

### Final Release Gate Checklist
- [x] Binary size overhead: $< 25\text{ MB}$ addition to base APK (deterministic 128-dim subword trigram vector hashing adds $< 1\text{ MB}$).
- [x] Zero network requests for all ranking, event logging, and bandit computations (100% on-device SQLite/Drift).
- [x] 100% of existing baseline tests pass:
  ```bash
  flutter test # 170/170 tests passing cleanly
  ```
- [x] Golden queries score higher precision with vector search enabled than lexical baseline.
- [x] All 9 checkboxes in Sprint Tracker marked completed.
