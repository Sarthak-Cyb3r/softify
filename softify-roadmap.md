# Softify Roadmap: Search and Recommendations

Based on the Spotify search and recommendation deep study (Oct 2026) and the current Softify v1.0.1 (Flutter, Riverpod, Drift, just_audio, Clean Architecture, keyless catalog, no backend, 54/54 tests).

Hand this file to OpenCode. Do one step at a time. Each step has: the Spotify idea, what to build, how to know it is done, and a prompt.

---

## Ground rules (apply to every step)

1. **Client-side only.** No server, no accounts, no telemetry. All learning happens on the device. Nothing is uploaded.
2. **Clean Architecture stays.** New logic goes in domain/data layers behind interfaces, with Riverpod providers. UI only reads providers.
3. **Tests ship with the feature.** Keep the existing test suite green and add tests for every new class. Do not claim coverage numbers without a coverage report.
4. **Respect the pre-buffer.** The dual-engine pre-buffer resolves track N+1 about 15 seconds before the current track ends. Never re-order the buffered next track. Ranking changes only apply to the unbuffered tail of the queue.
5. **Stay fast.** Local search results must appear in under 100 ms. Ranking must run off the UI isolate when it touches more than a few hundred items.
6. **Remote config, not telemetry.** Aliases, shelf definitions and default ranker weights live in a JSON file in the GitHub repo, fetched by the existing release/update checker mechanism, cached in Drift, with a bundled fallback.
7. **Definitions used everywhere.**
   - **Stream** = a play that lasts at least 30 seconds.
   - **Skip** = a play that ends before 30 seconds because the user moved on.
   - **Impression** = an item that was actually shown on screen in a list.
   - **Success** = stream, save, or playlist-add after a click.
8. **Do not invent weights.** The study says numbers like "save = 2.5x" circulating online are not real Spotify disclosures. Start with simple weights, log outcomes, then tune.

---

## Order of work

| # | Step | Needs | Status |
|---|---|---|:---:|
| F0 | Local event log and debug metrics | none | Completed [x] |
| S1 | Local-first instant search | F0 | Completed [x] |
| S2 | Local FTS index, fuzzy match, aliases | S1 | Completed [x] |
| S3 | Multi-source retrieval and re-ranker | S2 | Completed [x] |
| R1 | Taste profile (slow and fast interest) | F0 | Completed [x] |
| R2 | Co-occurrence candidates ("playlist as sentence") | F0 | Completed [x] |
| R3 | Skip-aware ranker | R1, R2 | Completed [x] |
| R4 | Home shelves | R3 | Completed [x] |
| S4 | Autocomplete and suggestions | S3 | Completed [x] |
| S5 | Intent router | S3, R3 | Completed [x] |
| R5 | Smarter Automix and autoplay | R3 | Completed [x] |
| R6 | Explore/exploit and calibration | R4 | Completed [x] |
| R7 | Diversity, controls, explanations | R4 | Completed [x] |
| R8 | Cold start (onboarding and import seeding) | R1, R2 | Completed [x] |
| E1 | Single-device interleaving | S3, R3 | Completed [x] |
| E2 | Golden sets and guardrails | S3, R3 | Completed [x] |
| E3 | Optional semantic search | all above, measured | Completed [x] |

All 17 roadmap steps are 100% complete with 170/170 passing tests for the v2.0.0 production milestone.

---

## F0. Local event log and debug metrics

**Spotify idea:** log features at serving time so training and serving never drift apart (their transform mismatch went unnoticed for four months). Success is impression-to-stream.

**Build**
- Drift tables:
  - `search_events`: id, ts, query, result_ids (JSON), shown_count, clicked_id, clicked_position, ms_to_click, ranker_version.
  - `play_events`: id, ts, track_id, source (search / shelf name / autoplay / library / radio), listened_ms, duration_ms, skipped_early (bool), saved (bool), added_to_playlist (bool), ranker_version, features_json (the exact feature values used when this item was ranked).
  - `impressions`: id, ts, surface, item_id, position.
- Hook into existing play history recording (it is already asynchronous, so keep logging off the transition path).
- A hidden debug screen (Settings, tap the version 7 times) with: stream rate, early-skip rate, search top-1 click rate, median time to click.
- A "Clear all learning data" button.

**Done when**
- Every play has a source and a listened_ms value.
- Logging never delays a track transition (add a test that logging is fire-and-forget).
- Unit tests cover the 30-second rule at 29.9 s, 30.0 s and 30.1 s.

**Prompt for OpenCode**
> Add local-only event logging to Softify. Create Drift tables search_events, play_events and impressions as specified in softify-roadmap.md step F0. Hook play_events into the existing play-history path without blocking transitions. Add a hidden debug screen showing stream rate, early-skip rate, search top-1 click rate and median time to click. Add a "Clear learning data" action. Write unit tests for the 30-second stream rule and for non-blocking logging. Do not add any network calls.

---

## S1. Local-first instant search

**Spotify idea:** instant search refreshes on every keystroke. Around 80 to 85 percent of clicks go to the top result and users type about six characters before acting.

**Build**
- On each keystroke: cancel the in-flight network request, debounce about 120 ms, then query.
- Show local results immediately (library, downloads, history), then merge network results when they arrive, without making the list jump (keep existing rows in place and insert below).
- Log a `search_events` row when the user acts.

**Done when**
- Local results render in under 100 ms in a widget test with a fake network that takes 800 ms.
- Typing fast never shows stale results from an older query (test with out-of-order responses).

**Prompt**
> Implement local-first instant search in Softify: debounced (about 120 ms) with cancellation of stale requests, local results first then network results merged without reordering rows already shown. Log search_events. Add tests for out-of-order responses and the 100 ms local budget using a fake slow network.

---

## S2. Local FTS index, fuzzy match, aliases

**Spotify idea:** the confirmed parts of their pipeline are normalization, fuzzy matching and manual aliases. Their spell-correction internals are not public, so keep this simple.

**Build**
- Drift FTS5 virtual table over tracks, artists and playlists in the library and history.
- Normalizer: lowercase, strip diacritics, collapse punctuation, trim.
- Prefix matching, plus Damerau-Levenshtein (or trigram) fallback for typos.
- An `aliases.json` in remote config (for example Hinglish spellings and nicknames), cached locally with a bundled fallback.

**Done when**
- A golden test file of at least 50 typo, prefix and alias queries passes.
- Index updates when a track is added, removed or downloaded.

**Prompt**
> Add a Drift FTS5 index for library/history search with a text normalizer, prefix matching, a typo fallback and an aliases.json loaded from remote config with a bundled fallback. Create a golden test file with 50+ queries (typos, prefixes, aliases) and make them pass.

---

## S3. Multi-source retrieval and re-ranker

**Spotify idea:** never one engine. Lexical and dense sources feed a learned re-ranker. Documented features: item popularity, previously searched, edit distance between the typed prefix and the title, taste similarity, and recent search behavior.

**Build**
- A `SearchCandidate` with: id, source (local / network / recent), and a feature map.
- Features: network rank position (as a popularity proxy), played-before count, prefix-to-title edit distance, taste similarity (stubbed to 0 until R1), recent-query match, exact-match flag.
- Version 1: hand-weighted linear scorer, weights from remote config.
- Version 2 (later): fit weights on-device from `search_events` using success as the label (logistic regression). Gate behind a toggle and compare using E1.
- Store the feature map in `search_events` for every shown result.

**Done when**
- Debug screen shows top-1 click rate by ranker_version.
- Tests: exact match always beats fuzzy; a previously played item beats an unplayed one when text match is equal.

**Prompt**
> Build a SearchCandidate pipeline with sources local, network and recent, a feature map per candidate, and a linear re-ranker whose weights come from remote config. Save the feature map for each shown result in search_events. Add tests for ordering rules in softify-roadmap.md step S3.

---

## R1. Taste profile (slow and fast interest)

**Spotify idea:** separate long-term interest from short-term session state (the FS-VAE idea).

**Build**
- `taste_profile` table: entity type (artist / genre / language), entity id, slow_weight, fast_weight, updated_at.
- Update on each play event: stream and save increase weights, early skip decreases them.
- Time decay: slow half-life in weeks, fast half-life in hours. Make both configurable.
- Expose `tasteSimilarity(trackMetadata) -> double`.

**Done when**
- Profile survives restarts.
- Decay is unit-tested with a fake clock.
- S3's taste feature now uses real values.

**Prompt**
> Implement a taste_profile in Drift with slow and fast weights per artist, genre and language, updated from play_events (streams up, early skips down) with configurable time decay tested using a fake clock. Expose tasteSimilarity(trackMetadata) and wire it into the search re-ranker feature.

---

## R2. Co-occurrence candidates ("playlist as sentence")

**Spotify idea:** a playlist is a sentence and tracks are words. Tracks that appear near each other in many playlists are similar.

**Build**
- `cooccurrence` table: track_a, track_b, score.
- Build "sentences" from: your playlists, imported Spotify playlists, and listening sessions (plays separated by less than 60 seconds belong to one session; this is the study's session definition).
- Score with PMI or simple normalized counts. Prune to the top N neighbours per track.
- Also pull Innertube radio / up-next results as an extra candidate source.
- Run the rebuild in a background isolate, and update incrementally after each session.

**Done when**
- "Similar to X" returns results offline for any track that appears in at least one playlist.
- Tests: two tracks in the same playlist get a positive score, unrelated tracks get none.

**Prompt**
> Add a cooccurrence table built from playlists, imported playlists and listening sessions (60-second gap rule), scored by PMI with per-track pruning, rebuilt incrementally in a background isolate. Expose similarTo(trackId) that merges local co-occurrence with network radio results. Add tests.

---

## R3. Skip-aware ranker

**Spotify idea:** negatives are first-class. Skipped tracks push similar items down. Features are logged at ranking time.

**Build**
- Feature vector per (user, candidate): taste similarity, co-occurrence score, recency since last played, novelty (never played), skip penalty for the artist (recent skips), source.
- Pointwise logistic regression, trained by on-device SGD from `play_events.features_json` (label = stream or save vs early skip).
- Ship default weights from remote config. Personal weights are a blend that moves slowly.
- Save the feature values in `play_events` for each recommended play.

**Done when**
- Debug screen shows early-skip rate on recommended tracks, split by ranker_version.
- Test: after three skips of one artist, that artist's candidates rank lower.

**Prompt**
> Implement a pointwise logistic ranker over features taste, cooccurrence, recency, novelty and artist skip penalty, trained incrementally on-device from play_events.features_json with default weights from remote config. Log features for every recommended play. Add tests that repeated skips lower an artist's rank.

---

## R4. Home shelves

**Spotify idea:** "algotorial". Humans define the candidate pool, ML ranks it per listener.

**Build**
- Shelf definitions in remote config (name, candidate rule, size, refresh policy).
- Shelves:
  - **Jump back in**: recently and frequently played.
  - **Daily Mix**: cluster the taste profile (k-means on artist and genre weights) into up to 3 mixes.
  - **Discover**: novelty-first, weekly, but about 1 in 10 tracks is deliberately familiar (the Discover Weekly trust trick).
  - **Release Radar**: new releases from followed or most-played artists.
- Refresh on app open when stale. Do not depend on background tasks, because they are unreliable on sideloaded iOS.
- Log impressions and plays per shelf name.

**Done when**
- Each shelf shows its own stream rate on the debug screen.
- Test: Discover contains roughly 10 percent familiar tracks.

**Prompt**
> Add Home shelves driven by remote-config definitions: Jump back in, Daily Mix (k-means over taste profile), Discover (weekly, novelty-first with about 10 percent familiar), Release Radar. Refresh on app open if stale. Log impressions and plays per shelf. Add tests for the familiar ratio.

---

## S4. Autocomplete and suggestions

**Spotify idea:** five candidate sources plus a point-wise ranker trained on downstream success. Removing the ranker cut suggestion clicks by 20 percent.

**Build**
- Sources: the catalog's keyless suggestion endpoint, your own past queries that led to a stream or save, recent searches, library titles, and expansion rules (`[artist] songs`, `[artist] live`).
- Only log a query as "complete" when the user acts on a result. This replaces their DistilBERT classifier with a simple rule.
- Rank suggestions by past success of similar prefixes.

**Done when**
- Past successful queries rank above untested ones for the same prefix.

**Prompt**
> Add search suggestions from five sources (network suggestions, successful past queries, recents, library titles, expansion rules) ranked by past success. Mark a query complete only after a result action. Add tests for ranking by past success.

---

## S5. Intent router

**Spotify idea:** an LLM router turns a query into a structured route such as `{route: personalized_recs, genre: ...}`, and sends exploratory queries to recommendations.

**Build**
- Sealed class `SearchIntent`: `exactItem`, `artist`, `similarTo(x)`, `moodOrGenre(tags)`, `newReleases`.
- Rule-based classifier first (keywords, known artist match, "like X", "new", mood and genre word lists in remote config).
- `moodOrGenre` opens a generated mix from the ranker instead of a plain result list.
- No LLM in this step.

**Done when**
- "sad hindi songs" opens a mix, "arijit singh" opens the artist, "songs like X" opens similar tracks. Covered by tests.

**Prompt**
> Implement a rule-based SearchIntent router (exactItem, artist, similarTo, moodOrGenre, newReleases) with word lists in remote config. Route moodOrGenre to a ranker-generated mix. Add table-driven tests for at least 30 queries.

---

## R5. Smarter Automix and autoplay

**Spotify idea:** radio learns transitions and re-ranks within the session.

**Build**
- Keep genre and language isolation. Re-rank only the unbuffered tail using R3 scores plus session skip feedback.
- Two skips in a row shift the next candidates toward the fast interest weights.

**Done when**
- Test: simulated two skips visibly change the next candidates, and the buffered track is never touched.

**Prompt**
> Re-rank the unbuffered tail of the Automix queue using the R3 ranker and session skip feedback, keeping genre and language isolation. Never modify the buffered next track. Add tests.

---

## R6. Explore/exploit and calibration

**Spotify idea:** an epsilon-greedy contextual bandit chooses the content distribution on Home, with a KL-divergence penalty so slates stay balanced.

**Build**
- Per shelf, an epsilon-greedy choice over the familiar-to-novel ratio. Reward = stream or save.
- Calibration: genre and language shares of a mix should roughly match the taste profile (compute KL divergence, penalize large gaps when selecting items).
- Persist bandit state in Drift.

**Done when**
- Debug screen shows the chosen ratio and reward per shelf. Tests use a seeded random generator.

**Prompt**
> Add an epsilon-greedy bandit per shelf over the familiar/novel ratio with reward = stream or save, plus a KL-divergence calibration against the taste profile when building mixes. Persist state, seed randomness in tests.

---

## R7. Diversity, controls and explanations

**Spotify idea:** personalized recommendations raised streams but reduced individual diversity. Their steering controls include hide and a 30-day snooze.

**Build**
- MMR re-rank with a per-artist cap in any generated list.
- Actions: Not interested, Snooze artist for 30 days, Reset taste profile, Pause learning.
- A Discovery slider that changes the familiar/novel ratio.
- A "Because you played X" line per recommendation, derived from the top contributing feature.

**Done when**
- No generated list contains more than N tracks from one artist (test).
- Snoozed artists never appear until the snooze expires (test with a fake clock).

**Prompt**
> Add MMR diversity with an artist cap, Not interested and 30-day Snooze actions, Reset taste profile, Pause learning, a Discovery slider, and a "Because you played X" explanation from the top ranker feature. Add tests with a fake clock.

---

## R8. Cold start

**Spotify idea:** each vertical solves cold start with whatever signal exists.

**Build**
- Onboarding: pick favourite artists, or import a public Spotify playlist.
- Imported playlist tracks seed R1 weights and R2 co-occurrence immediately.

**Done when**
- A fresh install plus one import yields a non-empty, sensible Home.

**Prompt**
> Add onboarding that seeds taste_profile and cooccurrence from selected artists or an imported public Spotify playlist. Add a test that a fresh database plus one import produces non-empty shelves.

---

## E1. Single-device interleaving

**Why:** Spotify distrusts offline metrics (about 42 percent of shipped experiments were rolled back). One user cannot run an A/B test, so compare rankers inside the same list.

**Build**
- Team-draft interleaving of the old and new ranker, with each item tagged by ranker_version.
- A 5 to 10 percent holdback slot that uses the baseline order.
- Debug screen: wins per ranker, based on streams and saves.

**Done when:** after a week of use the debug screen shows which ranker won, with counts.

---

## E2. Golden sets and guardrails

**Build**
- A golden file of queries and expected top results (extend the existing validation corpus idea).
- Guardrail tests: search latency p75 must not regress, early-skip rate must not worsen versus the previous ranker_version.
- Run all of it in CI next to the existing tests.

---

## E3. Optional semantic search

Only after S1 to S5 and R1 to R4 are measured. An on-device embedding model would add roughly 20 to 25 MB to a 65 MB APK. Evaluate it against the golden set from E2 and ship only if it beats the current ranker by a margin you chose in advance.

---

## Intentionally skipped

Two-tower retrieval, SASRec on billions of events, Semantic IDs, diffusion slate models, RL Q-learning and the Kubeflow/Jukebox chain. They need data scale and servers. The study also lists unverified items (FAISS use, search latency SLOs, spell-correction internals), so do not copy numbers from it as facts.

---

## Update the portfolio

When a step ships, flip its status in the portfolio's Softify Roadmap data file (see `portfolio-changes.md`, task D1).
