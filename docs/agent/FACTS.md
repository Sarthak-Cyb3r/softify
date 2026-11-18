# Facts 2026-11-18T19:10:00+05:30
HEAD: pending_commit_m3d_fix4
## Git
pending feat(m3d-fix4): root cause fix for lyrics nesting, startup database race, and resilient album art
f15e7c9 docs: update REPORT.md and FACTS.md for M3d-fix3 completion
64ca6ed fix(coil): resolve CoverArtLoader context and HomeScreen/PlaybackViewModel track references
23295a6 fix(m3d-fix3): single Text paragraph lyrics with TextLayoutResult sweep, Coil 3 image caching, and prefetch
81724d5 fix(lyrics): implement frame-driven withFrameNanos lyrics clock for 60fps word highlight
7ac9188 fix(lyrics): correct PlaybackLogger import package in MetrolistNowPlaying
64b235e fix(m3d): fix lyrics toggle touch interception, multi-word flow layout, and Apple Music typography
4f4b76a docs: update FACTS.md and REPORT.md with M3d cloud build 44244631946
6a571ee fix(lyrics): add ActiveLyricLine overload for single-line preview and previews
7dbe2c6 feat(m3d): implement radio queue with local ranking, lyrics performance, and word-by-word timing
1ab43fc docs: update FACTS.md and REPORT.md for M3c completion
3a25c9a fix(m3c): fix AsyncCoverArt, BitrateBadge, and LyricsLine parameter signatures in M3c screens
4d27d27 feat(m3c): implement full now playing screen, queue bottom sheet, lyrics, and artist/album details
7f9c480 docs: update REPORT.md with successful cloud build 44109297967
566c3c6 fix(viewmodel): import kotlinx.coroutines.delay
79b556b docs: update REPORT.md with M3b 3-bug fix details
862c2f6 fix(m3b): resolve Spotify import concurrency, track artwork fallback, and library vertical text
25420d5 fix(m3b): resolve SearchIntent enum branches and smart playlist ULong signatures
6deb8b4 feat(m3b): implement Metrolist M3 screens, queue manager, and cloud build CI
5859476 docs: update FACTS.md with M3a2 verification facts
22178a2 build: adjust gradle jvmargs for dexing with material icons extended
6c86402 M3a2: remove scalloped, minimal badge, vector icons, lyrics shine & gallery fixes
ac40064 docs: update FACTS.md after M3a build and tests
25: 6128ea1 test(m3a): fix syntax and update gallery screenshot
043ec8b M3a: Material 3 Expressive theme, shapes, components & gallery
964c460 fix: YouTube 403 + retry logic
f79714f fix: Android playback + in-app diagnostics

## Rust tests list
config::tests::test_bundled_default_config_loads: test
config::tests::test_remote_config_fails_fallback_to_bundled_default: test
db::migrations::tests::test_migrations_and_fts5_triggers: test
db::tests::test_get_tracks_by_artist_and_album: test
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
importer::spotify::tests::test_track_does_not_inherit_playlist_cover: test
lyrics::parser::tests::test_estimate_words_character_proportion: test
lyrics::parser::tests::test_parse_enhanced_lrc: test
lyrics::parser::tests::test_parse_lrc_standard: test
lyrics::parser::tests::test_parse_real_sombr_back_to_friends_lyricsfile: test
lyrics::tests::test_lyrics_fetch_and_caching: test
lyrics::tests::test_lyrics_lrclib_synced_and_plain_fallback: test
reco::cooccurrence::tests::test_group_plays_into_sentences: test
reco::cooccurrence::tests::test_ppmi_scores_positive: test
reco::diversity::tests::test_mmr_max_per_artist_invariant: test
reco::diversity::tests::test_snooze_artist_30_days: test
reco::explore::tests::test_parse_recorded_explore_fixture: test
reco::ranker::tests::test_artist_skip_penalty_invariant: test
reco::ranker::tests::test_build_quick_picks_artist_diversity: test
reco::ranker::tests::test_rerank_radio_tracks_dedupes_last_n: test
reco::ranker::tests::test_rerank_radio_tracks_scoring_prefers_affinity_and_penalizes_skips: test
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

50 tests, 0 benchmarks
