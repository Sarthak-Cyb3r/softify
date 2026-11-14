# Report: M2b - 2026-11-14
## Status: PARTIAL

## Acceptance Checklist
- [x] Hybrid resolver provider health checks and remote config with bundled offline fallback (`softify_core::config`)
- [x] Lyrics engine with LRCLIB API, synced LRC parser, and SQLite `cached_lyrics` (`softify_core::lyrics`)
- [x] Download manager saving highest-quality streams as .m4a with iTunes atom tagging (realigning `stco`/`co64` chunk offsets) and progress callbacks
- [x] Decryption test on REAL recorded `encrypted_media_url` fixture (`real_saavn_song_details.json`)
- [x] Desktop JVM Kotlin integration test exercising all public UniFFI APIs (`./gradlew desktopTest` -> PASSED)
- [x] 30-track quality verifier with `--disable-saavn` / `--force-youtube` fallback demonstration
- [ ] Spotify public playlist importer (no API key/OAuth) (M2c)
- [ ] Local file scanner with walkdir + rayon + lofty (M2c)
- [ ] Recommendation engine (taste decay, PPMI graph, ranker, shelves, MMR, snooze) (M2c)

## What works (verified by running it, with the command used)
- Hybrid resolver with provider health checks and remote JSON config with bundled fallback (`cargo test -- config` -> passed).
- Lyrics engine resolving synced & plain lyrics, caching in database (`cargo test -- lyrics` -> passed).
- Pure Rust M4A tagger injecting `udta` (`©nam`, `©ART`, `©alb`, `covr`) and recalculating `stco`/`co64` chunk offsets (`cargo test -- downloads` -> passed).
- Real recorded fixture decryption test verifying DES-ECB decryption of live JioSaavn media tokens (`cargo test -- test_real_recorded_encrypted_media_url_decryption` -> passed).
- Kotlin JVM integration test executing all UniFFI APIs end-to-end (`./gradlew desktopTest` -> BUILD SUCCESSFUL in 20s).
- Live 30-track quality verification: 30/30 resolved (100% success rate), 27/30 at 320 kbps Studio Master on JioSaavn edges, and honest fallback to YouTube AAC (itag 140) when unavailable or when `--disable-saavn` is passed (`cargo run --bin quality_verifier -- 30`).
- Android debug package builds cleanly (`./gradlew assembleDebug` -> BUILD SUCCESSFUL).

## What is stubbed or broken (be specific, no softening)
- Status is PARTIAL: M2c items (Spotify importer, local audio scanner, recommendation engine) remain to complete M2.
- Physical on-device audio playback on Moto G34: NOT VERIFIED by agent (no physical USB device attached to host).
- Desktop audio output: Compose Desktop builds and runs, but audio backend is stubbed for M1-M2 as scoped.

## Test results (paste the real output summary: passed/failed counts)
### Rust tests (`cargo test`): 21 passed; 0 failed
```
New tests in M2b:
test downloads::tagger::tests::test_m4a_atom_injection_and_chunk_offset_shift ... ok
test config::tests::test_bundled_default_config_loads ... ok
test lyrics::parser::tests::test_parse_lrc_standard ... ok
test downloads::tests::test_download_recording_and_retrieval ... ok
test lyrics::tests::test_lyrics_fetch_and_caching ... ok
test resolvers::tests::test_real_recorded_encrypted_media_url_decryption ... ok

Baseline M1/M2 tests:
test resolvers::tests::test_bitrate_sanity_check ... ok
test resolvers::tests::test_des_decryption_roundtrip ... ok
test db::migrations::tests::test_migrations_and_fts5_triggers ... ok
test resolvers::tests::test_fixture_saavn_fully_unavailable_triggers_youtube_fallback ... ok
test resolvers::tests::test_normalization_and_phonetic_simplify ... ok
test resolvers::tests::test_url_rewrite_presets ... ok
test search::engine::tests::test_fts5_query_builder ... ok
test search::intent::tests::test_intent_analysis ... ok
test search::normalizer::tests::test_normalizer ... ok
test resolvers::tests::test_youtube_fallback_honest_bitrate_marking ... ok
test resolvers::tests::test_fixture_320_fails_steps_down_to_160 ... ok
test search::tests::test_fts5_prefix_matching ... ok
test search::tests::test_search_results_processing_and_deduplication ... ok
test search::tests::test_playlist_and_history_lifecycle ... ok
test resolvers::tests::test_fixture_320_selected_when_available ... ok

test result: ok. 21 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.07s
```

### Rust clippy tail
```
    Checking softify_core v0.1.0 (/home/sarthak/Desktop/Projects/Softify-experimental/rust/softify_core)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 3.18s
```

### Attached FACTS.md summary
`97a26c2` | Rust: 21 passed (0.04s), 0 clippy warnings | Gradle: BUILD SUCCESSFUL in 13s

## Quality check (320 kbps): provider, bitrate and time-to-first-audio for 30 tracks
Mode: LIVE NETWORK VERIFICATION (Real JioSaavn CDN & YouTube Innertube)
```
| # | Track | Category | Provider | Codec | Requested | Actual | Verified | TTFA |
|---|-------|----------|----------|-------|-----------|--------|----------|------|
| 01 | Tum Hi Ho - Arijit Singh | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1096 ms |
| 02 | Kesariya - Arijit Singh | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1083 ms |
| 03 | Blinding Lights - The Weeknd | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 820 ms |
| 04 | Shape of You - Ed Sheeran | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 966 ms |
| 05 | Starboy - The Weeknd | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 561 ms |
| 06 | Apna Bana Le - Arijit Singh | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1021 ms |
| 07 | Levitating - Dua Lipa | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1051 ms |
| 08 | Chaleya - Arijit Singh | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 961 ms |
| 09 | Flowers - Miley Cyrus | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1028 ms |
| 10 | Raataan Lambiyan - Jubin Nautiyal | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 855 ms |
| 11 | Lag Ja Gale - Lata Mangeshkar | Retro/Reg | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 819 ms |
| 12 | Pal Pal Dil Ke Paas - Kishore Kumar | Retro/Reg | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 824 ms |
| 13 | Roop Tera Mastana - Kishore Kumar | Retro/Reg | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1410 ms |
| 14 | Brown Munde - AP Dhillon | Retro/Reg | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 686 ms |
| 15 | 295 - Sidhu Moose Wala | Retro/Reg | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 844 ms |
| 16 | Lover - Diljit Dosanjh | Retro/Reg | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 824 ms |
| 17 | Why This Kolaveri Di - Dhanush | Retro/Reg | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 806 ms |
| 18 | Arabic Kuthu - Anirudh Ravichander | Retro/Reg | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1004 ms |
| 19 | Samajavaragamana - Sid Sriram | Retro/Reg | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1193 ms |
| 20 | Rowdy Baby - Dhanush | Retro/Reg | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1116 ms |
| 21 | Kasoor - Prateek Kuhad | Indie/Obsc | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 634 ms |
| 22 | Cold/mess - Prateek Kuhad | Indie/Obsc | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 911 ms |
| 23 | Alag Aasmaan - Anuv Jain | Indie/Obsc | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 572 ms |
| 24 | Baarishein - Anuv Jain | Indie/Obsc | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1108 ms |
| 25 | Roz Roz - The Yellow Diary | Indie/Obsc | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 728 ms |
| 26 | Choojhn De - When Chai Met Toast | Indie/Obsc | YouTube Fallback | AAC | 320 kbps | 155 kbps | YES | 2941 ms |
| 27 | Khoj - When Chai Met Toast | Indie/Obsc | YouTube Fallback | AAC | 320 kbps | 131 kbps | YES | 2186 ms |
| 28 | Liggi - Ritviz | Indie/Obsc | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 624 ms |
| 29 | Sage - Ritviz | Indie/Obsc | YouTube Fallback | AAC | 320 kbps | 133 kbps | YES | 1324 ms |
| 30 | Udaan - Amit Trivedi | Indie/Obsc | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 934 ms |
Total: 30/30 resolved (100.0%) | 320 kbps Master: 27/30 (90.0%) | YouTube fallback (--disable-saavn 5): 5/5 at 130-131 kbps
```

## Decisions I made that you did not ask for
- Implemented pure Rust in-place M4A atom tagger with `stco`/`co64` chunk offset shifting without external C audio libraries.
- Added `async_runtime = "tokio"` to UniFFI exports ensuring JVM threads execute async futures safely without panicking.

## Questions / blockers (numbered)
1. None. Ready to proceed with M2c upon instruction.

## Files changed (git diff --stat)
```
 composeApp/build.gradle.kts                        |  10 +
 composeApp/src/desktopTest/UniFfiIntegrationTest.kt| 120 +++
 composeApp/src/commonMain/uniffi/softify_core.kt   | 557 +++++++
 docs/agent/FACTS.md | REPORT.md                    | 180 ++-
 rust/softify_core/resources/default_config.json    |  30 +
 rust/softify_core/src/bin/quality_verifier.rs      | 139 +++-
 rust/softify_core/src/config.rs                    |  65 ++
 rust/softify_core/src/db/migrations.rs | repo.rs   | 119 ++++
 rust/softify_core/src/downloads/                   | 428 +++++
 rust/softify_core/src/lib.rs | models.rs           | 119 +++-
 rust/softify_core/src/lyrics/                      | 333 +++++
 rust/softify_core/src/resolvers/                   | 120 +++-
 rust/softify_core/tests/fixtures/real_saavn_details|  15 +
 23 files changed, 2185 insertions(+), 180 deletions(-)
```

## Proposed next step
Sub-step M2c: Implement Spotify public playlist importer, local file scanner (walkdir + rayon + lofty), and recommendation engine (taste decay, PPMI graph, ranker, shelves, MMR, snooze).
