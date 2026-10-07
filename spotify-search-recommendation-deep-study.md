# Spotify's Search & Recommendation Engine — A Deep Multi-Division Study

**Compiled from four divisions: Engineering · Research · Specialized · Testing**
*Date: Oct 2026. Primary sources: engineering.atspotify.com, research.atspotify.com, arXiv, ACM/SIGIR/RecSys/KDD/WSDM papers, spotify/* GitHub, patents, newsroom. All claims carry inline citations; unverified items are collected per division at the end.*

---

## Executive Summary

Spotify runs two deeply intertwined systems — **Search** and **Recommendation** — that are converging into a single agentic/LLM-based query-understanding stack as of 2025–26.

- **Search** is *instant search* (results on every keystroke): Elasticsearch for lexical recall + **Vespa** ANN for dense/semantic recall, fused by a learned-to-rank re-ranker (LambdaLoss/NDCG on success logs). A 2025 "Parallel Fusion Router" LLM rewrites/expands/facets queries at ~450 ms p75 and routes broad intents to the AI DJ sub-agent.
- **Recommendation** is a four-era evolution: latent-factor CF → content-based audio CNNs → "playlist-as-sentence" word2vec embeddings → deep/generative stacks (two-tower retrieval + multi-objective rankers, transformers on ~40B interactions, Semantic-ID LLM generation, diffusion slate models, RL/bandits for long-term engagement).
- **Training** runs on ~1T events/day through Scio/Beam → Jukebox feature store → weekly Kubeflow retrains → Salem/Hendrix serving, with feature logging for train/serve parity and near-real-time user-embedding refresh (~50 ms reads).
- **Validation** is deliberately skeptical of offline metrics: NDCG is only trusted after correlating with online listen volume; ~42% of shipped experiments are later rolled back on guardrail regressions no offline eval caught. Gold standard = impression-to-stream (≥30 s), guarded by non-inferiority metrics in a four-role metric framework.

---

## PART I — SEARCH (Engineering Division)

### 1. End-to-end query flow

Spotify's core search is **instant search** — results refresh on every keystroke, so parse/retrieve/rank must fit an interactive budget ([NIS, 2021](https://research.atspotify.com/2021/08/neural-instant-search-for-music-and-podcasts)). Behavior drives the design: **80–85% of clicks land on the top result** and users type ~6 characters before acting ([Chandar et al. 2019](https://pchandar.github.io/files/papers/Chandar2019.pdf)).

**Query understanding layers:**
1. **Neural Instant Search (NIS, KDD 2021)** — character-level embeddings to match partial prefixes ("lana d…"), multi-task intent-type ID (music vs podcast), per-item embedding lookup.
2. **Complete-query classifier** — DistilBERT decides whether a logged prefix is a complete query (F1 ≈ 0.85 on 500 hand-labeled queries; [SIGIR 2023](https://dl.acm.org/doi/pdf/10.1145/3539618.3591827)).
3. **LLM routing (2025→)** — a **Parallel Fusion Router (PFR)**: a small post-trained LLM infers intent and emits *structured, parameterized tool calls*, e.g. `{"route":"personalized_recs","genre":"indie rock","max_weeks_from_release":4}` — replacing stacks of dedicated classifiers ([RecSys 2025 Industry](https://research.atspotify.com/2025/9/you-say-search-i-say-recs-a-scalable-agentic-approach-to-query-understanding)).

**Rewriting/expansion:** beyond native LLM rewriting, **Aligned Query Expansion (AQE)** uses DPO + rejection-sampling fine-tuning so an LLM emits expansions that rank well *in Spotify's own engine*, cutting generation time ~70% ([AQE, 2025](https://research.atspotify.com/2025/7/optimizing-query-expansions-via-llm-preference-alignment)).

**Spelling correction:** never published as a dedicated system — only fuzzy matching, normalization, manual aliases, and spell-correction of mined suggestions are confirmed.

### 2. Indexing

Seven public entity types: `album, artist, playlist, track, show, episode, audiobook`, with field filters (`album:`, `artist:`, `year:`, `isrc:`, `tag:new`, `tag:hipster`) ([Search API docs](https://developer.spotify.com/documentation/web-api/reference/search)). Internally: "billions of items" catalog (SIGIR 2023).

Three indexed layers:
- **Metadata/text** → Elasticsearch corpus (titles, descriptions, genres, dates, popularity).
- **Semantic vectors** → episode docs (title + description + parent show) encoded offline into dense vectors ([NLS blog 2022](https://engineering.atspotify.com/2022/03/introducing-natural-language-search-for-podcast-episodes)).
- **Behavioral graphs** → query–item interaction and reformulation edges embedded via node2vec for suggestions ([2023](https://research.atspotify.com/2023/10/graph-learning-for-exploratory-query-suggestions-in-an-instant-search-system)).

**History:** original search was a raw **Lucene** service (~30M docs / ~7 GB RAM, per-entity in-memory indexes queried in parallel; [Twente thesis](https://essay.utwente.nl/fileshare/file/61936/Sharding_Spotify_Search.pdf)) → Elasticsearch (lexical) + **Vespa** (ANN with first-phase ranking) today.

### 3. Retrieval & ranking

**Multi-source recall, never a single engine:** Elasticsearch (sparse) + Vespa (dense) + other sources → feature builder → **final-stage re-ranker** merges them; (query, episode) cosine similarity is just one feature ([2022 blog](https://engineering.atspotify.com/2022/03/introducing-natural-language-search-for-podcast-episodes)).

**The re-ranker** ([BCS 2022 talk](https://www.bcs.org/media/10476/ss22-bottens-spotify.pdf)): a **learn-to-rank model on search-success logs, LambdaLoss optimizing NDCG**, with all features logged at serving time to prevent skew. Documented features:
- item popularity
- user has searched this item before
- **edit distance between prefix query and matched title**
- **item↔user taste-vector similarity**
- user's recent search behavior

Shared network layer with a primary head and a reranking head; success signals differ by content type (music vs podcast).

**Semantic search (2022→):** siamese bi-encoder fine-tuned from **multilingual Universal Sentence Encoder CMLM**, in-batch negatives, trained on 4 pair sources: successful log pairs, reformulation pairs, **synthetic BART queries fine-tuned on MS MARCO**, curated pairs. Episode vectors offline; query vectors online on **Vertex AI T4 GPUs (6× cheaper than CPU)** + vector cache; Vespa returns **top 30**.

**ANN evolution:** `annoy` (2013, mmap random-projection forests) → hnswlib (~10× faster) → **Voyager** (2023, HNSW; ">10× Annoy at equal recall, up to 50% more accuracy at same speed") ([Voyager post](https://engineering.atspotify.com/2023/10/introducing-voyager-spotifys-new-nearest-neighbor-search-library)). Vespa is the documented search ANN engine; no evidence of FAISS/Milvus.

### 4. Autocomplete & suggestions

Hybrid **Query Recommendation** with 5 candidate sources ([RecSys 2024](https://dl.acm.org/doi/10.1145/3640457.3688035)):
1. catalog item titles (co-occurrence hypothesis testing against prefix logs),
2. complete queries mined from logs (spell-corrected, deduped),
3. user's own recent searches/personal items,
4. metadata expansion rules ("[artist] + covers"),
5. **LLM-generated synthetic queries**.

A **point-wise ranker trained on downstream success** (stream/save/add after click) orders them — **removing it cuts suggested-query clicks 20%**.

**Graph learning:** heterogeneous graph → node2vec → nearest metadata as suggestions ("chess → game theory"). Offline beat a transformer similarity baseline **+22%**; in a millions-user A/B: coverage **+1.42%**, suggestion clicks **+1.21%**, exploratory-query clicks **+9.37%**, no latency impact ([2023](https://research.atspotify.com/2023/10/graph-learning-for-exploratory-query-suggestions-in-an-instant-search-system)).

**Results:** hybrid QR → exploratory queries **+9%**, max query length **+30%**, avg query length **+10%**. **AudioBoost** (cold-start audiobooks): LLM synthetic queries indexed into both QAC and retrieval → **+1.22% clicks, +1.82% exploratory completions**.

### 5. Semantic → agentic → generative search (2022–2026)

| Year | System | Result |
|---|---|---|
| 2022 | Natural Language (semantic) podcast search | Engagement lift in A/B |
| 2024 | Playlist semantic search (LLM metadata enrichment + LLM-as-judge) | Recall@1 **+17–32%** |
| 2024 | Generative retrieval joining search+recsys | **+16% R@30** vs task-specific models |
| 2025 | **Text2Tracks** (LLM emits semantic IDs built on CF embeddings) | **+127% Hits@10** |
| 2025 | **PFR agentic router** | LLM-judge **+115%** ("artists similar to X"), +91% new-release; **+3%** online success; **~450 ms p75**; distilled small router = **−60% latency, −99% cost, +3% quality** |
| 2025–26 | Product surfaces | AI DJ voice/text requests (60+ markets), Spotify in ChatGPT (145 countries), "Talk to Spotify" conversational assistant beta (Jul 2026) |

### 6. Infrastructure & org

- 2021 re-org: **Core Search** (user satisfaction) + **Search Platform** (developer happiness + SLOs); search headcount **+500% 2016→2020** ([Rethinking Spotify Search](https://engineering.atspotify.com/2021/04/rethinking-spotify-search)).
- Stack: GCP, Elasticsearch + Vespa + Vertex AI GPUs + Redis/vector caches, gRPC/protobuf microservices.
- Surfaces: Search tab, Home, Now Playing contextual search, "Hey Spotify" voice, Car Thing, Android Auto, ChatGPT.

---

## PART II — RECOMMENDATION (Research Division)

### 7. Era timeline

| Era | Years | Key system | Key source |
|---|---|---|---|
| Vector CF / PLSA | ~2008–13 | Related Artists, Radio | [Bernhardsson retrospective](https://www.quora.com/How-did-Spotify-get-so-good-at-machine-learning-Was-machine-learning-important-from-the-start-or-did-they-catch-up-over-time) |
| Implicit MF + ANN | 2011– | Taste profiles, ALS/WMF | Hu/Koren/Volinsky as taught in [Spotify decks](https://hpac.cs.umu.se/teaching/sem-mus-16/presentations/Pruefer.pdf) |
| Annoy | 2013– | All NN retrieval | [erikbern.com](https://erikbern.com/2013/04/12/annoy.html) |
| Audio deep learning | 2013–16 | Content cold-start | [van den Oord NIPS 2013](https://proceedings.neurips.cc/paper_files/paper/5004-deep-content-based-music-recommendation.pdf) |
| Playlist-as-sentence | 2014–18 | Discover Weekly, word2vec item vectors | [Quora](https://www.quora.com/How-did-Spotify-get-so-good-at-machine-learning-Was-machine-learning-important-from-the-start-or-did-they-catch-up-over-time), [InfoQ Home arch](https://www.infoq.com/presentations/evolution-spotify-arch/) |
| Product-scale personalization | 2015– | Discover Weekly, Release Radar, Fresh Finds | [DW post](https://engineering.atspotify.com/2015/11/what-made-discover-weekly-one-of-our-most-successful-feature-launches-to-date) |
| Two-stage deep recsys | 2020– | Home candidate gen + ranking | [Home Part I](https://engineering.atspotify.com/2021/11/the-rise-and-lessons-learned-of-ml-models-to-personalize-content-on-home-part-i) |
| Slow/fast user modeling | 2022 | FS-VAE | [WSDM 2022](https://research.atspotify.com/2022/02/modeling-users-according-to-their-slow-and-fast-moving-interests) |
| Multi-objective slates | 2022 | Mostra (set transformer + submodular beam) | [WWW 2022](https://research.atspotify.com/2022/04/mostra-balancing-multiple-objectives-for-music-recommendation) |
| Long-term RL | 2022–23 | Podcast Q-learning, Impatient Bandits | [arXiv 2302.03561](http://arxiv.org/pdf/2302.03561v2), [KDD 2023](https://research.atspotify.com/publications/impatient-bandits-optimizing-for-the-long-term-without-delay) |
| Unified user vectors | 2025 | Generalized user representations (autoencoder + NRT) | [2025](https://research.atspotify.com/2025/9/generalized-user-representations-for-large-scale-recommendations) |
| LLM / agentic era | 2024–26 | AI DJ, Semantic IDs, GLIDE, diffusion slates | [Narratives](https://research.atspotify.com/2024/12/contextualized-recommendations-through-personalized-narratives-using-llms), [Prompt-to-Slate](https://research.atspotify.com/2025/9/prompt-to-slate-diffusion-models-for-prompt-conditioned-slate-generation) |

### 8. The classic hybrid era (2008–2015)

- **Matrix factorization over implicit feedback** (confidence-weighted, c = 1 + α·r, ALS) was the backbone; play counts aren't ratings, so confidence weighting mattered.
- **ANN over ~40-dim vectors** instead of pairwise scoring — the reason `annoy` exists ("millions of tracks in 40-dimensional space… 5M×40×4B ≈ 800MB — too big to duplicate per process" → mmap shared index).
- **Multi-source blending** at the retrieval/ranking boundary (dense + lexical → reranker), also on Home (many models per shelf + heuristics + editorial slots).
- **Echo Nest (2014)** contributed taste clusters, acoustic analysis, artist/song graphs, and web-NLP signals — though Bernhardsson claims "very little of Echo Nest's tech actually made it into the product" (single-source, disputed).

### 9. Content-based audio models

The foundational paper — **van den Oord, Dieleman & Schrauwen, NIPS 2013**: CNN on 128-bin log-mel spectrograms of 3-second clips **regressing the latent factors of weighted MF**, then using predicted factors for recommendation (382K songs / 1M users). Beat bag-of-MFCC words (AUC ~0.77 vs ~0.65).

Inside Spotify (Dieleman's account): 7–8 layer 1-D convnets, global temporal pooling, predicting 40 `vector_exp` factors on the 1M most popular tracks, unit-normalized to strip popularity confounds. Uses: an extra pipeline signal + **filtering outliers** (intros/outros/covers/remixes) that CF wrongly surfaces.

### 10. "Playlist as sentence" NLP era

The defining paradigm: **a playlist is a sentence, tracks are words.** "As soon as word2vec came out we switched immediately — in production weeks later"; Discover Weekly was "entirely powered by collaborative filtering, in particular a few extensions to word2vec." Operationally corroborated: Home replaced batch datasets with a live **Word2Vec service** in 2017 ([InfoQ](https://www.infoq.com/presentations/evolution-spotify-arch/)).

**Discover Weekly recipe (2015):** taste profile × ~2B user playlists → "neighbouring songs" (what others playlist alongside your favorites) → novelty filter with **~1-in-10 deliberately familiar tracks** retained (a bug that proved to build trust). Formal account: Jacobson et al., *Music Personalization at Spotify* (RecSys 2016).

### 11. Modern deep architectures

- **Two-stage Home:** candidate generation (user/item embedding → ANN over ~100M catalog → 100–200 candidates) → learned ranker (NDCG/MRR).
- **Generalized user representations (2025):** one autoencoder-compressed vector for retrieval/ranking/search/generation; batch inference for coverage + near-real-time refresh on activity events → **+2.9% discoveries, +13% item-to-stream**.
- **FS-VAE (WSDM 2022):** slow (aggregate) vs fast (sequential LSTM) user state for next-track prediction.
- **Mostra (WWW 2022):** Set Transformer + submodular counterfactual beam search balancing Satisfaction/Discovery/Exposure/Boost over millions of radio sessions.
- **Sequence models:** SPDD (KDD 2026) trains **SASRec on ~40B interactions, 62M users, 42M tracks** for playlist ranking; earlier WSDM Cup 2019 skip-prediction on the ~150M-session MSSD.
- **Generative/LLM:**
  - **Semantic IDs** tokenize the catalog; domain-adapted LLM "speaks Spotify" with beam search → up to **1.96×** episode recommendation gains ([2025](https://research.atspotify.com/2025/11/teaching-large-language-models-to-speak-spotify-how-semantic-ids-enable)).
  - **GLIDE** (KDD 2026): instruction-following generative podcast recommender → **+5.4% non-habitual streaming, +14.3% new-show discovery**.
  - **DMSG / Prompt-to-Slate** (RecSys 2025): diffusion over slate embeddings from text prompts; 1M-user A/B showed freshness gains but **−5.6% listening time, +3% skips** vs personalized control (a published negative result).
  - **SPDD** (KDD 2026): inference-time primal-dual decoding gives multi-objective control without retraining (+5.44% auxiliary stream-share, no consumption loss).

### 12. RL & exploration — Spotify's strongest research line

- **Explore, Exploit, Explain** (RecSys 2018): bandits learning which *explanations* users respond to, on live traffic.
- **Home MAB + counterfactual training** (2020): logistic regression → boosted trees → DNNs under a bandit framework, with off-policy evaluation replacing some A/B tests.
- **Long-term podcast RL** (arXiv 2302.03561): Q-function over item-level listening habits; treatment A/B lifted **60-day show minutes +81%**; now serves hundreds of millions of users.
- **Impatient Bandits** (KDD 2023): Bayesian filter over progressively-revealed daily engagement + Thompson sampling, solving 60-day delayed-reward cold start.
- **ICEE** (ICLR 2024): in-context exploration-exploitation via return-conditioned decision transformers — adapts within a session without gradient updates.
- **Calibration bandit on Home** (deployed Mar 2025): ε-greedy contextual bandit choosing content-type *distribution* (music/podcasts/audiobooks), slate built greedily with KL-divergence penalty.

### 13. Product pipelines — what differentiates each surface

| Surface | Cadence | Mechanism | Distinguishing feature |
|---|---|---|---|
| Discover Weekly | Weekly (Mon) | CF playlist co-occurrence × taste profile | Novelty-first; ~10% familiar tracks kept deliberately |
| Release Radar | Weekly (Fri) | Followed/affiliated artists + CF fill; **waveform/audio analysis** for fresh tracks | Cold-start-heavy — audio analysis because new tracks lack history |
| Daily Mix | Daily, up to 6 | Taste-segment clustering; familiar-first | Explicitly less adventurous than DW |
| Radio / Autoplay | Continuous | Vector+acoustic similarity, session-aware reranking | Session-level transition learning |
| Home | Event-driven | Multi-model candidates per shelf + ranker in streaming pipelines | Batch (2016) → services (2017) → streaming+services (2018+) |
| Fresh Finds | Weekly (Wed) | Web/blog buzz + anonymous tastemaker cohorts → ~1,000 candidates → editors | Engineered long-tail pathway (65M+ artist discoveries in 2024) |
| AI DJ / AI Playlists | Real-time | LLM intent → tool orchestration → retrieval/rank → narration; **RLHF+DPO preference flywheel** | Preference optimization, not pointwise scoring |

### 14. How models are trained

**Signals:** streams, completion %, early skips (~30 s threshold), saves/library adds, playlist adds, repeats, artist follows, search/profile activity, session context (time, device, source). Negatives are first-class (skip labels strength 1–3 in MSSD; contrastive losses push skipped tracks away). **Which signal you pick materially changes podcast recommendations** — subscribe-vs-play vs play-count optimizes different things; Spotify uses **calibration (λ≈0.5)** to improve precision@10 on both ([2022](https://research.atspotify.com/2022/05/choice-of-implicit-signal-matters-accounting-for-user-aspirations-in-podcast-recommendations)).

**Objectives:** pointwise cross-entropy on completion; MSE regression onto CF factor space (audio models); next-item NLL (sequence models); NDCG@k as the offline gate; multi-objective scalarization (Generalized Gini, submodular, KL-constrained, primal-dual) for slates; long-horizon Q-targets for podcasts.

**Infrastructure (the full training chain):**
```
Client events → Pub/Sub (schema-driven, auto-provisioned) 
  → ~1T events/day, 38k+ pipelines on BigQuery/Flink/Dataflow (Scio/Beam)
  → Jukebox feature store (TFTransform; point-in-time joins → Bigtable online, ~50ms reads)
  → weekly Kubeflow/TFX retrain with auto-promotion on eval threshold
  → Ray (GKE) for research-scale PyTorch/TF/GNN training
  → Salem (TF Serving) / Hendrix ML platform → online inference
  → feature logging from serving path → train/serve parity loop
```
Key lessons learned the hard way: a **train/serve transform mismatch went undetected 4 months** on Home — fixed by logging already-transformed features + daily TFDV distribution checks (Chebyshev distance) ([Home Part II](https://engineering.atspotify.com/2021/11/the-rise-and-lessons-learned-of-ml-models-to-personalize-content-on-home-part-ii)). A Shortcuts model wasn't retrained, so a content type introduced post-training was **never recommended** — textbook covariate shift.

**Frameworks:** Luigi (still used) → Scio/Beam → TFX + Kubeflow ("Paved Road") → Flyte + managed Ray → Salem serving, consolidated as **Hendrix**.

### 15. Fairness, diversity, filter bubbles

- Recommendation-driven listening is **less diverse than organic listening**, yet higher consumption diversity strongly predicts conversion & retention — while rankers disproportionately help "specialists" ([WWWC 2020](https://dl.acm.org/doi/fullHtml/10.1145/3366423.3380281)).
- Field experiment: personalized podcast recs **+28.9% streams but −11.5% individual diversity** — the engagement–diversity trade-off, measured openly.
- Diversification methods compared (WSDM 2021): interleaving, submodularity, linear interpolation, **RL reward modeling** — RL won on popularity-diversification trade-off; interpolation gave more operational control.
- Supplier fairness: counterfactual estimation of group fairness over artist-popularity bins; ~20% fairness weight costs little satisfaction.
- Levers: Mostra creator-centric reranking, calibration bandits, DMSG stochastic generation, Fresh Finds long-tail pathway.

### 16. 2024–26: the LLM era

- **AI DJ** (2023→, ~90M users): domain-adapted **Llama** for commentary/explanations; fine-tuned smaller Llamas matched larger ones at lower latency; explanations drove up to ~**4× engagement** on recommendations ([Meta × Spotify](https://ai.meta.com/blog/spotify-personalized-recommendations-built-with-llama/)).
- **AI Playlist / Prompted Playlists:** agentic LLM emits a DSL plan → calls search/filter tools → synthesizes; **reward model + DPO preference flywheel** → **+4% listening time, −70% erroneous tool calls**.
- **Search–recs convergence:** one LLM router routes exploratory queries between search and recs at ~450 ms p75.
- Catalog hygiene shapes eligibility: 75M+ spammy tracks removed in 12 months (Sept 2025), role-level AI credits, behavioral spam de-ranking.

---

## PART III — SPECIALIZED TOPICS (Specialized Division)

### 17. Open-source artifacts

| Repo | Purpose | Recsys/search role |
|---|---|---|
| [spotify/annoy](https://github.com/spotify/annoy) | mmap ANN (random-projection forests) | Early embedding-similarity backbone (superseded by Voyager) |
| [spotify/voyager](https://github.com/spotify/voyager) | Current HNSW ANN (Python/Java) | Powers personalization, recommendation **and search** |
| [spotify/luigi](https://github.com/spotify/luigi) | Batch DAG orchestration | README: powers "recommendations, toplists, A/B test analysis" |
| [backstage/backstage](https://github.com/backstage/backstage) (created by Spotify) | Developer portal, CNCF | Catalogs services, data pipelines, ML models |
| [spotify/echoprint-codegen](https://github.com/spotify/echoprint-codegen) | Audio fingerprinting (Echo Nest lineage, archived 2022) | Content identification |
| [spotify/pedalboard](https://github.com/spotify/pedalboard) | Python audio I/O + VST3 | ML data augmentation; powers AI DJ / voice translation |
| [spotify/scio](https://github.com/spotify/scio) | Scala Beam/Dataflow API | Default batch+stream recsys data framework |
| [spotify/klio](https://github.com/spotify/klio) | Audio processing on Beam | Large-scale audio feature preprocessing |
| `spotify/confidence-*` | Experimentation SDKs | Backs the Confidence A/B platform |

*(Verified: `spotify/chroma` and `spotify/Dermology` do not exist — 404/zero hits.)*

### 18. Echo Nest lineage (Mar 6, 2014)

Acquired for a reported ~$100M (some sources say €50M; officially undisclosed). Brought **taste profiles**, **acoustic analysis + artist/song graphs** ("music intelligence" powering radio on 400+ platforms), a 7,000-developer API ecosystem, and Echoprint. Integration built Spotify's "personalization, retrieval and knowledge graph team… one of the biggest at Spotify" and enabled Fresh Finds / Discover Weekly / Release Radar / Daily Mix ([Whitman exit post](https://variogram.com/2016/11/16/leaving-spotify-the-echo-nest)). Echo Nest API sunset May 31, 2016; its IP lives on in patents like **US 9,613,118 B2 "Cross media recommendation."**

### 19. Data & serving infrastructure

- **~1 trillion events/day**, **38,000+ scheduled pipelines**; schema-driven client SDKs → Kubernetes operators auto-provision Pub/Sub queues, **anonymization pipelines**, streaming jobs; each output a registered endpoint with lineage/ACLs/quality checks ([Data Platform Part II](https://engineering.atspotify.com/2024/05/data-platform-explained-part-ii)).
- **Session definition:** listening interrupted by no more than **60 s**; key implicit signals = skips and context-switches ([MSSD, arXiv 1901.09851](https://arxiv.org/pdf/1901.09851)).
- **Jukebox** feature store: point-in-time joins, online Bigtable serving, feature registry, automated backfills, streaming ingestion.
- **Serving evolution:** Scio+Zoltar batch → hand-rolled online recommender → **Salem** (TF Serving-based) with feature logging, push-based model versions, CI/CD. Today's ML platform: **Hendrix**, managed **Ray on GKE**.
- **Home scale:** 50M+ DAU; MAB balancing exploration/exploitation (RecSys'19).
- **Latency philosophy:** publishes methodology not SLOs — ELS load balancer optimizes expected client latency at **p75/p99** (p99 = 47 ms metadata-proxy example), models an **800 ms penalty** for cross-globe retries.
- **Experimentation:** ABBA → Experimentation Platform (2015–23) → **Confidence** (2023+, commercialized). Deliberately **separate stacks** for personalization vs experimentation; explicitly **against Bayesian A/B**.

### 20. Editorial × ML — "Algotorial"

Spotify's official model ([Humans + Machines](https://engineering.atspotify.com/2023/4/humans-machines-a-look-behind-spotifys-algotorial-playlists)): editors define user need, select **candidate pools rather than final orderings**, see per-track performance, co-design branding; **ML ranks the pool per listener**. RapCaviar / Today's Top Hits stay human-owned; Discover Weekly / Daily Mix / Time Capsule are algorithmic. Levers: Spotify for Artists submissions, **Global Curation Groups**, and **Discovery Mode** — a *disclosed* merchandising signal ("our system will add that signal to the algorithms"). Critical scholarship (Bonini & Gandini, Prey 2020, Pelly's *Mood Machine* 2025) documents major-label dominance differences between editorial and algotorial shelves.

### 21. Podcast & audiobook recs

- **Episode vs show divergence:** two strong but conflicting signals; calibration (λ≈0.5) improves precision@10 on both simultaneously.
- **Transcripts:** Spotify Podcasts Dataset — ~100K episodes, 47–50K hours of ASR transcripts with diarization ([arXiv 2004.04270](https://arxiv.org/pdf/2004.04270)); language/reading-grade/sentiment correlate with stream rate.
- **GLIDE:** production LLM recommender with 4-token Semantic IDs, session-aware episode-level generation under real latency constraints.
- **Cold start:** podcasts recommended from **music taste** for 200K+ shows → up to **+50% consumption** offline and online.
- **Audiobooks:** GNN personalization (WWW'24) + **LLM-generated "descriptive shelves"** ("Uplifting Women's Fiction", ~2,500 titles) — discovery up, engagement mixed → moved to subfeed.

### 22. Globalization

85 markets/36 languages added in 2021 → ~180 markets. Recsys handles it via market segmentation (core/mature/emerging/scaled) driving editorial strategy; a **"local artists" Home shelf** (locality = statistically surprising localized listenership, scored genre-affinity × locality) beat non-local controls on follows; macro research shows rising local-content preference 2014–2019 shaped by language and proximity.

### 23. Ethics, privacy, regulation

- **GDPR:** Swedish IMY (June 2023) found Spotify infringed Art. 12(1)/15(1)(a)–(d)/15(2) on how access copies were delivered, while finding the layered "Download your data" design generally transparency-compliant.
- **Recommendations explained:** the public [Understanding Recommendations](https://www.spotify.com/us/safetyandprivacy/understanding-recommendations) page demystifies inputs and lists steering controls (genre prompts to DJ/DW, hide/snooze 30-day, Smart Shuffle opt-out, autoplay off, explicit filter, Home filters). No per-item "because you listened to X" attribution UI.
- **DSA:** Spotify publishes transparency reports but pre-adoption comments lobbied for flexibility on recommender transparency and the non-personalized opt-out; DSA Art. 27 requires explaining main ranking parameters and offering parameter modification.

### 24. Patents (Spotify AB)

| Patent | Gist |
|---|---|
| **US 10,891,948 B2** | *Taste attributes from audio signals* — voice + background noise → speech recognition → content metadata (emotion/gender/age/accent) + environmental metadata → media preferences. Controversial "monitor your speech" patent. |
| **US 11,003,710 B2** | Context signals (motion/location/biometric/co-present devices/time) → context profiles → activity prediction → auto-surfacing playlists. |
| **US 9,613,118 B2** | *Cross media recommendation* (Echo Nest lineage) — transfer an evaluation taste profile across domains via taste-profile/media vector models. |
| **US 12,694,051** (2026) | Text prompt → model emits **structured queries** against item vector space → playlist (search↔generation fusion). |
| **US 12,688,396** (2026) | **RL ranker** conditioned on previously recommended items, learning a sampling policy balancing relevance and diversity. |
| **App. 19/352,890** (2026, pending) | **Multi-task LM jointly returning search results and recommendations** — the patent version of the search–recs convergence. |

### 25. Academic context — RecSys Challenge 2018

Million Playlist Dataset: 1M playlists (~2M tracks, 49M occurrences); organizers from Spotify (Chen, Lamere), JKU (Schedl), UMass (Zamani). 113 teams/1,228 runs (main track). Metrics: **R-precision** (0.25 credit for right-artist/wrong-track), **NDCG**, and a bespoke **"Clicks"** metric = refreshes of the 10-item Recommended Songs list before first held-out track appears — product-grounded by design.

**Winner (team vl6, U Toronto): two-stage** — WRMF matrix-factorization retrieval + **XGBoost** LTR reranking; won both tracks. Top-10 patterns: two-stage + pairwise LTR, with candidates from item-CF, playlist NN, **LSTMs**, autoencoders. A naive "500 most popular tracks" baseline looked OK on NDCG (0.099) but was catastrophic on Clicks (13.2 vs 1.78) — proving user-centric metrics catch popularity collapse that accuracy metrics miss.

---

## PART IV — TESTING & EVALUATION (Testing Division)

### 26. Offline metrics — and Spotify's skepticism

| Metric | Where used | Spotify's trust |
|---|---|---|
| NDCG@k | Home/Shortcuts offline gate (TFMA in Kubeflow) | **Conditional** — trusted only after correlating with online listen volume |
| Recall@k / MRR, NDCG@7 | Dense retrieval; 7 = results visible without scrolling | Moderate — retrieval stage only, not a ship signal |
| Impression-to-stream (≥30 s) | Playlist rec A/B gold standard | **Gold standard** |
| Capped/normalized importance sampling (VIS/VCIS/VNCIS) | Offline prediction of A/B outcomes | **High when debiased** — preserves online ordering (WSDM'19) |
| Raw offline metrics on logged data | General | **Low** — position/popularity/selection bias; 42% of shipped experiments later rolled back on metrics no offline eval flagged |
| Search success (stream/follow/add) | Search reranker A/B frontline | High — user-level, action-anchored |
| Guardrail non-inferiority | Every experiment | **Very high** — hard ship gate |
| LLM-judge scores | Pre-screening search & recsys candidates | Rising but must be re-calibrated against A/B outcomes |
| Diversity/fairness/Gini retrievability | New-user models, AIA audits | Diagnostic, not decisive |
| ANN recall@k vs QPS | Annoy/Voyager tuning | High — engineering trade-off |
| Win rate vs Learning rate (EwL) | Org-level health | 12% win / 64% learning reframes "failed" tests |

**The two poles of Spotify's published position:** Ben Carterette's NTCIR-15 keynote: "there is a lot we still don't know about the ability of offline experiments to predict online outcomes." Versus Gruson et al. (WSDM 2019): "properly-conducted offline experiments do correlate well to A/B test results" — *but only with debiasing* (capped importance sampling vs impression-to-stream gold standard across 12 runs). In practice teams built **recommendation dashboards to eyeball outputs** because metrics couldn't explain failures.

### 27. Online experimentation

- **Platform:** rebuilt 2019–20 (replacing ABBA): Remote Configuration + Metrics Catalog + Experiment Planner in Backstage. **Bucket Reuse over 1M buckets** with a "salt machine" reshuffling users without stopping experiments (difference-in-means validity proven under reuse).
- **Power:** mandatory relative **MDE** in power calculations; sample-size calculator pulls historical control mean/variance.
- **Four metric roles:** *success* (superiority), *guardrail* (non-inferiority with margin), *deterioration* (inferiority), *quality* (SRM, pre-exposure). **Ship iff** ≥1 success improves significantly, all guardrails non-inferior, no deterioration, no quality failure. FPR not corrected for guardrails, but power beta-corrected for guardrail count.
- **Scale:** ~300+ teams, tens of thousands of experiments/year; **520 experiments on mobile Home in one year across 58 teams**; learning rate ~64% vs win rate ~12% under Experiments-with-Learning.
- **Novelty/long-term:** quarterly **cumulative holdbacks** (cohort shielded all quarter, then tested once vs the combined shipped experience); randomized recommendation-withhold holdbacks also serve as counterfactual training data (cut impressions 7% with no consumption loss). 60-day reward windows (Impatient Bandits).
- **Peeking problem 2.0:** sequential tests inflate FPR on longitudinal metrics — published with a fix.
- **Interleaving:** semi-random interleaving used to collect warm-up training data for the suggestion ranker; no confirmed production interleaving ranker comparison. Switchback methodology documented in Confidence curriculum, but no published Spotify feed-surface case.

### 28. Search-specific evaluation

- **Click-bias correction:** position-bias IPS with monotonic propensity curves (randomized experiments where available, else click models). Carterette & Chandar propose *minimally invasive* online perturbation (change 1–2 rank positions, ~2% of ~1M log lines) to curate propensity-labelled collections — deliberately safer than interleaving a bad ranker.
- **Human judgments:** **Human-Judged Multilingual dataset** — 265 SERPs × 5 languages × 3-level graded relevance. LLM-judge alignment (Spearman/Kendall) improved **+91% on disagreement cases** when grounded; matched the live A/B winner better than ungrounded judges. Companion study: train/test splits label only ~7% of top-100 items vs ~57% under pooling (system-rank Kendall τ = 0.26) — while **LLM-judge system rankings reach τ ≈ 0.92**.
- **Head/tail slicing:** 34.7% of eval queries unseen in training; 97.8% of sessions long-tail — cold-start slices analyzed separately, never averaged away.
- **The evaluation funnel doctrine:** "evals *verify* (pre-screen), experiments *validate* (business outcome)"; judges re-run **on A/B data** to calibrate judge-vs-outcome gaps. ~**42% of launched experiments are rolled back** to prevent secondary-metric regressions no offline eval flagged.

### 29. Quality guardrails

- **Algorithmic Impact Assessments:** internal audits of **100+ personalization/recommendation systems** in under a year → roadmaps, safety mechanisms, data-usage reductions.
- **Retrievability bias:** Gini over per-entity retrievability; click-trained dense retrievers are **more biased than BM25**; synthetic broad queries cut Gini ~10% while lifting R@100.
- **Fairness:** relevance-optimal sets are ~2× less fair than average (counterfactual estimation, no A/B needed); ~20% fairness weight costs little satisfaction.
- **Cold-start stress:** music-based podcast cold-start models → up to **+50% consumption**, with explicit analysis of bias from using music data as input.
- **Robustness:** dual-sample feature-dropout training validated by *removing* the behavioral feature at eval time and slicing head/tail/cold-start — a deliberate mis-specification stress test.
- **Localization:** HJM spans 5 languages; Wrapped load tests deliberately use payloads from many countries/languages to stress obscure paths.

### 30. System & performance testing

- **ANN recall-vs-latency:** `annoy` exposes `n_trees` (build accuracy) and `search_k` (runtime accuracy-vs-speed, latency ~linear in `search_k`); docs point to **ann-benchmarks** for recall@k/QPS curves. **Voyager** benchmarked vs Annoy: **>10× speed at equal recall, up to +50% accuracy at equal speed, ~4× less memory**.
- **Load testing:** internal **Moshpit** (Backstage plugin) — HTTP/gRPC protobuf payloads with ramp-up/duration/target RPS; 2022 Wrapped load tests ran tens of thousands of RPS across US/EU/Asia, with employee cache-busting removed to preserve realism.
- **Resilience:** the "Arrow" daemon — circuit breaking, health monitoring, fast-fail for weak dependencies + Nginx ingress rate limiting. **No published chaos-engineering program for the search cluster.**
- **Latency:** only numeric search figure = LLM router **p75 ≈ 450 ms** in production. No published search SLO.

### 31. Observability & postmortems

- CI/CD gates: Kubeflow checks eval score > threshold before auto-push; feature logging closes the train/serve loop; weekly retrains.
- Known drift failure: Shortcuts' stale model never recommended a post-training content type (covariate shift); model-serving version skew during rollouts (10-min polling, mixed revisions).
- Continuous experiment-health monitoring (SRM, pre-exposure, crashes).
- **Case studies:** Discover Weekly's "familiarity bug" — fixing the bug made *all success metrics decline*, so it was deliberately reverted into a feature (metrics caught the harm of the *fix*); OPS-6000 (2013) Discovery rollout dependency storm; 81% wrong TTR timestamps found in an incident-review study (synthetic tests cut recovery ~10×); 2025 Envoy filter-reordering outage (3 h 27 m global crash loop); 2026 retrospectives now ask whether AI-authored code contributed to incidents.

---

## CONVERGENCES: WHAT THE FOUR DIVISIONS TOGETHER REVEAL

1. **Search and recs are becoming one system.** The PFR LLM router routes exploratory queries to recs sub-agents; a pending patent (19/352,890) claims a *multi-task LM returning both search results and recommendations*; generative retrieval already beats task-specific models (+16% R@30).
2. **Hybridization is a hard rule, never "replace the old thing."** Elasticsearch + Vespa + graph + editorial + heuristics all feed one re-ranker; Home runs many models per shelf. Even the newest LLM layers sit *on top of* the retrieval stack rather than replacing it.
3. **Train/serve parity is the recurring production failure.** The 4-month feature-transform skew, the Shortcuts stale-model bug, the "log already-transformed features" fix — all four divisions found instances of the same lesson.
4. **The offline/online gap is the central methodological tension.** Spotify simultaneously publishes that offline *can* correlate (with debiasing) and that 42% of shipped experiments get rolled back on unflagged metrics. Their answer: gold-standard online metrics (impression-to-stream), four-role guardrails, quarterly holdbacks, and LLM judges that must be re-calibrated on A/B data.
5. **Negative results are published.** DMSG's −5.6% listening time, the engagement–diversity trade-off (−11.5% diversity for +28.9% streams), the Clicks-vs-NDCG divergence in RecSys Challenge — Spotify publishes where things failed, which is rare.
6. **Cold-start is solved differently per vertical:** audio CNNs for new *tracks*, music-taste transfer for new *podcasts*, LLM synthetic queries for *audiobooks*, local-listenership statistics for new *markets*.
7. **Exploration graduated from bandits to RL to LLM preference optimization:** MAB → counterfactual off-policy → long-horizon Q-learning (+81% 60-day minutes) → Impatient Bandits → ICEE in-context → DPO preference flywheels for AI DJ/playlists.
8. **Latency discipline made distillation mandatory:** teacher LLM → small router = −99% cost/−60% latency/+3% quality; T4 GPU 6× cheaper than CPU; Voyager 10× Annoy; AQE −70% generation time.

---

## CONSOLIDATED "UNVERIFIED" REGISTER

Treat as unconfirmed unless primary evidence is found:

1. Spell-correction internals (no primary source).
2. Numeric search latency SLOs (only router p75 ≈450 ms exists); "sub-50 ms" third-party claims are not Spotify-sourced.
3. Whether podcast transcripts are full-text searchable; whether legacy audio features are in the search index.
4. FAISS/Milvus at Spotify — no evidence; Vespa is the documented search ANN engine.
5. "TorchFire" — does not exist in Spotify literature (likely conflation with TorchRec or Jukebox). "Music Conversations" — not located.
6. BPR specifically at Spotify; exact current Discover Weekly algorithm (word2vec account is a 2017 insider retrospective).
7. Echo Nest tech "never shipped" — single-source (Bernhardsson), contradicted elsewhere.
8. Retrain cadences — "weekly" documented for Home only.
9. Production interleaving ranker comparisons; switchback feed tests; search-cluster chaos testing.
10. RecSys Challenge techniques → production transfer (only the Clicks metric's product grounding is documented); participation numbers conflict across sources (791/410/1,497 vs 1,791 registrants).
11. "Emma Home" observability, embedding-drift thresholds — secondary talk summaries only.
12. Per-surface latency SLOs; experiment stats (~12% win rate, 520 experiments/year) — third-party dev.to summaries.
13. Echo Nest deal price (€50M vs ~$100M vs undisclosed); two 2026 patents' full claims (Justia 403).
14. `spotify/chroma`, `spotify/Dermology` — do not exist.
15. Implicit-signal weight constants (e.g. "save = 2.5×") circulating online — illustrative fabrications, not Spotify disclosures.
16. Discover Weekly bug specifics — third-party case-study blog, not a Spotify engineering post.
