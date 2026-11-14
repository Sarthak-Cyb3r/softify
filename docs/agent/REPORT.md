# Report: M2 - 2026-11-14
## Status: DONE

## What works (verified by running it, with the command used)
- SQLite database migrations with pure Rust `rusqlite` creating full Drift parity schema: `tracks`, `playlists`, `playlist_tracks`, `play_histories`, `downloads`, `cached_lyrics`, and `settings` (`cargo test -- db::migrations` -> passed).
- FTS5 virtual table `tracks_fts` with automated SQLite triggers on `INSERT`, `UPDATE`, and `DELETE` keeping FTS5 search index 100% in sync with tracks (`cargo test` -> 15 passed).
- Offline prefix matching search engine and query normalizer handling unicode diacritics and special characters (`cargo test -- search` -> passed).
- Intent router categorizing queries into Artist, Album, Track, and General intents, plus candidate deduplication.
- Database repository CRUD: likes, playlists, track association, play history recording/retrieval.
- UniFFI Kotlin bindings regenerated with new library search, playlists, and history exports.
- KMP Compose UI with Search & Library tabs, instant FTS5 local results, intent badges, and like toggling (`./gradlew compileKotlinDesktop` and `./gradlew assembleDebug` -> BUILD SUCCESSFUL).
- Quality verifier CLI tool: 10/10 tracks verified at 320 kbps Studio Master with Range probes (`cargo run --bin quality_verifier -- 10`).

## What is stubbed or broken (be specific, no softening)
- Physical on-device audio playback on Moto G34: NOT VERIFIED by agent (no physical USB device attached to host).
- Desktop audio output: Compose Desktop compiles and runs, but audio backend is stubbed for M1-M2 as scoped.
- Recommendations engine and lyrics cascade: Scheduled for M3-M5.

## Test results (paste the real output summary: passed/failed counts)
```
running 15 tests
test db::migrations::tests::test_migrations_and_fts5_triggers ... ok
test resolvers::tests::test_bitrate_sanity_check ... ok
test resolvers::tests::test_des_decryption_roundtrip ... ok
test resolvers::tests::test_fixture_saavn_fully_unavailable_triggers_youtube_fallback ... ok
test resolvers::tests::test_normalization_and_phonetic_simplify ... ok
test resolvers::tests::test_url_rewrite_presets ... ok
test resolvers::tests::test_youtube_fallback_honest_bitrate_marking ... ok
test search::engine::tests::test_fts5_query_builder ... ok
test search::intent::tests::test_intent_analysis ... ok
test search::normalizer::tests::test_normalizer ... ok
test search::tests::test_fts5_prefix_matching ... ok
test search::tests::test_playlist_and_history_lifecycle ... ok
test search::tests::test_search_results_processing_and_deduplication ... ok
test resolvers::tests::test_fixture_320_fails_steps_down_to_160 ... ok
test resolvers::tests::test_fixture_320_selected_when_available ... ok

test result: ok. 15 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.04s
```

## Quality check (320 kbps): provider, bitrate and time-to-first-audio for 10 tracks
```
| # | Track | Provider | Codec | Requested | Actual | Verified | TTFA |
|---|-------|----------|-------|-----------|--------|----------|------|
| 01 | Tum Hi Ho - Arijit Singh | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1049 ms |
| 02 | Kesariya - Arijit Singh | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 744 ms |
| 03 | Blinding Lights - The Weeknd | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 633 ms |
| 04 | Shape of You - Ed Sheeran | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 974 ms |
| 05 | Starboy - The Weeknd | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 566 ms |
| 06 | Apna Bana Le - Arijit Singh | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1018 ms |
| 07 | Levitating - Dua Lipa | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1054 ms |
| 08 | Chaleya - Arijit Singh | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 988 ms |
| 09 | Flowers - Miley Cyrus | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1701 ms |
| 10 | Raataan Lambiyan - Jubin Nautiyal | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 996 ms |
```

## Decisions I made that you did not ask for
- Added automatic SQLite triggers (`trg_tracks_insert`, `trg_tracks_update`, `trg_tracks_delete`) directly in the migration DDL so the FTS5 virtual table is kept strictly in sync without requiring application code to manually remember to index each track.
- Reused Desktop home directory `~/.softify/softify.db` to allow local desktop development and testing without affecting Android databases.

## Questions / blockers (numbered)
1. None currently.

## Files changed (git diff --stat)
```
 composeApp/src/commonMain/kotlin/com/softify/app/ui/App.kt        | 473 ++++++++++++-----
 composeApp/src/commonMain/kotlin/com/softify/app/viewmodel/PlaybackViewModel.kt | 119 ++++-
 composeApp/src/commonMain/kotlin/uniffi/softify_core/softify_core.kt | 577 +++++++++++++++++++++
 composeApp/src/desktopMain/kotlin/main.kt                          |  14 +
 docs/agent/FACTS.md                                                |  84 ++-
 docs/agent/REPORT.md                                               | 132 ++---
 rust/softify_core/src/db/migrations.rs                             | 139 +++++
 rust/softify_core/src/db/mod.rs                                    |   1 +
 rust/softify_core/src/db/repository.rs                             | 297 +++++++++--
 rust/softify_core/src/lib.rs                                       | 119 ++++-
 rust/softify_core/src/models.rs                                    |  45 ++
 rust/softify_core/src/search/engine.rs                             |  72 +++
 rust/softify_core/src/search/intent.rs                             |  89 ++++
 rust/softify_core/src/search/mod.rs                                |   5 +
 rust/softify_core/src/search/normalizer.rs                         |  57 ++
 rust/softify_core/src/search/tests.rs                              | 133 +++++
 16 files changed, 1876 insertions(+), 273 deletions(-)
```

## Proposed next step
Milestone 3 (M3): Synchronized Lyrics Engine (port LRCLIB, JioSaavn, Netease, TTML parser, and word-level karaoke synchronization into `softify_core::lyrics` with animated Compose UI).
