# Facts 2026-11-17T19:51:00+05:30
HEAD: 25420d594d3af8f94d0d9c227976176a8e17d912
## Git
25420d5 fix(m3b): resolve SearchIntent enum branches and smart playlist ULong signatures
6deb8b4 feat(m3b): implement Metrolist M3 screens, queue manager, and cloud build CI
5859476 docs: update FACTS.md with M3a2 verification facts
22178a2 build: adjust gradle jvmargs for dexing with material icons extended
6c86402 M3a2: remove scalloped, minimal badge, vector icons, lyrics shine & gallery fixes
ac40064 docs: update FACTS.md after M3a build and tests
6128ea1 test(m3a): fix syntax and update gallery screenshot
043ec8b M3a: Material 3 Expressive theme, shapes, components & gallery
964c460 fix: YouTube 403 + retry logic
f79714f fix: Android playback + in-app diagnostics

## Rust tests list
config::tests::test_bundled_default_config_loads: test
config::tests::test_remote_config_fails_fallback_to_bundled_default: test
db::migrations::tests::test_migrations_and_fts5_triggers: test
db::tests::test_incognito_mode_blocks_recent_searches_and_history: test
db::tests::test_playlist_rename: test
db::tests::test_recent_searches_lifecycle: test
db::tests::test_smart_playlists_rules_and_edge_cases: test
downloads::tagger::tests::test_m4a_atom_injection_and_chunk_offset_shift: test
downloads::tagger::tests::test_m4a_atom_stco_and_co64_offset_shift_verification: test
downloads::tests::test_download_recording_and_retrieval: test
importer::spotify::tests::test_fixture_playlist_import_to_n_tracks: test
importer::spotify::tests::test_parse_embed_html: test
importer::spotify::tests::test_parse_spotify_entities: test
lyrics::parser::tests::test_parse_lrc_standard: test
lyrics::tests::test_lyrics_fetch_and_caching: test
lyrics::tests::test_lyrics_lrclib_synced_and_plain_fallback: test
reco::cooccurrence::tests::test_group_plays_into_sentences: test
reco::cooccurrence::tests::test_ppmi_scores_positive: test
reco::diversity::tests::test_mmr_max_per_artist_invariant: test
reco::diversity::tests::test_snooze_artist_30_days: test
reco::explore::tests::test_parse_recorded_explore_fixture: test
reco::ranker::tests::test_artist_skip_penalty_invariant: test
reco::taste::tests::test_incognito_mode_pauses_learning: test
reco::taste::tests::test_taste_decay_math: test
resolvers::tests::test_band_name_and_featured_artist_matching_regression: test
resolvers::tests::test_bitrate_sanity_check: test
resolvers::tests::test_des_decryption_roundtrip: test
resolvers::tests::test_fixture_320_fails_steps_down_to_160: test
resolvers::tests::test_fixture_320_selected_when_available: test
resolvers::tests::test_fixture_saavn_fully_unavailable_triggers_youtube_fallback: test
resolvers::tests::test_normalization_and_phonetic_simplify: test
resolvers::tests::test_real_recorded_encrypted_media_url_decryption: test
resolvers::tests::test_url_rewrite_presets: test
resolvers::tests::test_youtube_fallback_honest_bitrate_marking: test
scanner::local::tests::test_deterministic_track_id: test
scanner::local::tests::test_excluded_folders_and_nomedia: test
search::engine::tests::test_fts5_query_builder: test
search::intent::tests::test_intent_analysis: test
search::normalizer::tests::test_normalizer: test
search::tests::test_fts5_prefix_matching: test
search::tests::test_playlist_and_history_lifecycle: test
search::tests::test_search_results_processing_and_deduplication: test

42 tests, 0 benchmarks

## Rust tests summary
test result: ok. 42 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 1.26s

## Rust clippy
Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.51s (0 warnings)

## NoEmojiTest Verification
SUCCESS: 0 emoji/pictograph violations across all Kotlin source files in composeApp/src.

## GitHub Actions Cloud Build
Workflow: Build Android Debug APK (Cloud) (.github/workflows/build_kmp_android_apk.yml)
Run ID: 44100393153
Conclusion: success
Duration: 7m 29s
Artifact: composeApp-debug-apk (32MB)
Local Path: /home/sarthak/Downloads/composeApp-debug.apk

## Native libraries in APK
10096   lib/arm64-v8a/libandroidx.graphics.path.so
168176  lib/arm64-v8a/libjnidispatch.so
5926096 lib/arm64-v8a/libsoftify_core.so
10760   lib/x86_64/libandroidx.graphics.path.so
118584  lib/x86_64/libjnidispatch.so
6539760 lib/x86_64/libsoftify_core.so
