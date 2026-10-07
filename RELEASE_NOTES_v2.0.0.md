## Softify v2.0.0 — On-Device Search & Recommendations Intelligence Engine

Softify v2.0.0 is a milestone release introducing a state-of-the-art, **100% client-side, zero-telemetry** search and recommendation intelligence system built directly on top of SQLite/Drift tables with zero cloud machine learning dependencies.

---

### 🌟 What's New in v2.0.0

#### 1. ⚡ Local-First Instant Search & FTS5 Retrieval (S1, S2, S3)
- **Sub-100ms Debounced Instant Search**: Cancels in-flight requests on every keystroke, rendering local results instantly before merging network tracks.
- **SQLite FTS5 Full-Text Search**: Diacritic stripping, punctuation normalization, and tokenized prefix search across your entire library, history, and playlists.
- **Fuzzy Damerau-Levenshtein Matching & Aliases**: Built-in typo tolerance and domain aliases (e.g. "Weeknd" $\leftrightarrow$ "The Weeknd").
- **Linear Search Re-Ranker**: Combines BM25 lexical signals, listen counts, and recency with a strict `+10.0` exact-match boost so the exact title always claims position #1.

#### 2. 📈 Dual-Band Taste Decay & Co-occurrence Sentence Graph (R1, R2)
- **Dual-Band Exponential Half-Life Modeling**:
  - $W_{\text{fast}}$ (4-hour half-life) captures current mood, momentary impulses, and session trends.
  - $W_{\text{slow}}$ (14-day half-life) captures lasting taste and favorite genres/artists.
- **Session Sentence Graph & PPMI**: Consecutive plays with $\le 60\text{s}$ gaps are treated as natural language sentences to compute Positive Pointwise Mutual Information (PPMI) between co-occurring tracks in background isolates.

#### 3. 🎯 Pointwise Logistic Regression & Algotorial Shelves (R3, R4)
- **On-Device SGD Classifier**: Estimates stream probabilities $\sigma(z) = 1 / (1 + e^{-z})$ locally without remote inference servers.
- **Skip Sensitivity Rule**: Automatically applies a $>50\%$ penalty when an artist or song accumulates $\ge 3$ consecutive skips.
- **Dynamic Algotorial Home Shelves**:
  - *Heavy Rotation*: High-affinity tracks blended across fast and slow interest bands.
  - *Forgotten Favorites*: Deep catalog favorites not played in $>30$ days.
  - *Discover Weekly*: Fresh musical discoveries adhering to a strict **~10% familiar anchor ratio** (1 anchor track per 10 recommendations) to ground exploration.

#### 4. 🧭 Multi-Source Autocomplete & Offline Intent Routing (S4, S5)
- **5-Tier Query Autocomplete**: Suggestion chips derived from recent searches, local library, listening history, top artists, and fuzzy matches.
- **Offline Rule Intent Router**: High-speed, zero-LLM classification into `TrackIntent`, `ArtistIntent`, `MoodOrGenreIntent`, `DiscoverIntent`, or `NavigationalIntent`.

#### 5. 🔀 Dynamic Queue Reordering & Player Pre-Buffer Invariant (R5, R6)
- **Player Pre-Buffer Invariant**: The dual-engine pipeline pre-buffers track $N+1$ approximately 15 seconds before track $N$ finishes. Softify guarantees that **Track $N$ and Track $N+1$ are never reordered, mutated, or canceled**. All ranking occurs exclusively on the unbuffered tail ($\ge N+2$).
- **Contextual Epsilon-Greedy Bandit**: Explores novelty arms (`0.0, 0.1, 0.2, 0.3, 0.5`) to prevent recommendation fatigue.
- **KL Divergence Distribution Calibrator**: Calibrates recommendation slate genres to match historical listening distribution, minimizing $D_{\text{KL}}(P \parallel Q)$.

#### 6. 🛡️ Discovery Agency, Diversity & Privacy Controls (R7, R8)
- **Maximal Marginal Relevance (MMR)**: Enforces artist diversity with a hard `maxPerArtist = 2` cap per shelf.
- **30-Day Artist Snoozing**: 1-tap option to temporarily silence any artist from recommendations and suggestions for 30 days.
- **Incognito Taste Mode**: Toggle in Settings to pause all profile learning during shared or party sessions.
- **1-Line Transparent Explanations**: Understand every recommendation (*"Because you listened to The Weeknd"*, *"From your Heavy Rotation"*).
- **Cold-Start Seeding**: Fast onboarding genre picker and instant taste profile seeding from imported Spotify playlists.

#### 7. ⚖️ Radlinski Team-Draft Interleaving & Latency Guardrails (E1, E2)
- **On-Device Team-Draft Interleaving**: Evaluates candidate ranking models locally with a 10% baseline holdback slot to measure true user preference without telemetry.
- **Latency Guardrails**: Rigorous automated latency runner ensuring $p75 < 100\text{ ms}$ over 50 consecutive queries.
- **Golden Query Benchmark Suite**: 54 diverse benchmark queries validating recall, precision, and latency across search scenarios.

#### 8. 🧬 On-Device Semantic Vector Search (E3)
- **128-Dimensional Float32 Embeddings**: Compact vector representations generated via subword character trigram and word hashing.
- **Zero-Network Vector Retrieval**: High-speed cosine similarity computed directly over SQLite `track_embeddings` table with $< 1\text{ MB}$ binary size overhead and zero cloud dependencies.

---

### 📦 Release Assets

- **`Softify-v2.0.0-Universal.apk`**: Universal Android package (arm64-v8a, armeabi-v7a, x86_64) compatible with Android 8.0+ (API 26+).
- **`Softify-iOS-Universal.ipa`**: Sideloadable iOS package (built via automated GitHub Actions CI workflow).

---

> [!IMPORTANT]
> **Disclaimer**: This project is built for educational purposes and personal use. It is not affiliated with, endorsed by, or connected to Spotify, YouTube, or JioSaavn. No copyrighted content is hosted on this app.
