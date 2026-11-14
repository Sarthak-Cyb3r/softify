# Facts 2026-11-14T18:52:30+05:30
HEAD: 043ec8bf68e28516b95fd65c9a00bec66329b013
## Git
043ec8b M3a: Material 3 Expressive theme, shapes, components & gallery
964c460 fix: YouTube 403 + retry logic
f79714f fix: Android playback + in-app diagnostics
0487535 M2e: verification and packaging fixes
b0af156 docs: update M2d REPORT.md and FACTS.md
332e86b M2d: verification close-out
4349de2 M2: Complete core backend with Spotify importer, local audio scanner, recommendation engine, and desktop/android integration
815e6cf M2b: Remote config, LRCLIB lyrics, M4A download tagger, real fixture test, and Kotlin integration tests
97a26c2 M2: Database schema, FTS5 offline search engine, and library management
d9d5e4a M1: vertical slice with Saavn 320kbps resolver, UniFFI, and Media3 playback
 M docs/agent/FACTS.md
## Diff stat
 composeApp/build.gradle.kts                        |  26 ++
 .../kotlin/com/softify/app/MainActivity.kt         |  22 ++
 .../commonMain/kotlin/com/softify/app/ui/App.kt    |  28 +-
 .../com/softify/app/ui/components/BitrateBadge.kt  | 156 ++++++++
 .../app/ui/components/ExpressiveVolumeSlider.kt    |  73 ++++
 .../ui/components/FloatingSegmentedPlayerDock.kt   | 353 ++++++++++++++++++
 .../softify/app/ui/components/LyricsPreviewLine.kt |  70 ++++
 .../softify/app/ui/components/ScallopedBadge.kt    |  72 ++++
 .../softify/app/ui/components/SquigglySlider.kt    | 251 +++++++++++++
 .../app/ui/diagnostics/DiagnosticsScreen.kt        |  21 ++
 .../app/ui/gallery/ComponentGalleryScreen.kt       | 401 +++++++++++++++++++++
 .../kotlin/com/softify/app/ui/theme/HctColor.kt    | 190 ++++++++++
 .../kotlin/com/softify/app/ui/theme/Shapes.kt      |  91 +++++
 .../kotlin/com/softify/app/ui/theme/Theme.kt       |  89 +++++
 .../com/softify/app/viewmodel/PlaybackViewModel.kt |  18 +
 .../kotlin/com/softify/app/M3aDesignSystemTest.kt  |  98 +++++
 docs/agent/FACTS.md                                | 153 +-------
 docs/agent/REPORT.md                               |  95 ++---
 docs/agent/screenshots/gallery_overview.png        | Bin 0 -> 111390 bytes
 docs/design/metrolist/now_playing_reference.jpg    | Bin 0 -> 45797 bytes
 .../design/metrolist/playlist_detail_reference.jpg | Bin 0 -> 62957 bytes
 .../design/metrolist/smart_playlists_reference.png | Bin 0 -> 20466 bytes
 tools/make_report.sh                               |  11 +-
 23 files changed, 2002 insertions(+), 216 deletions(-)
## Rust tests list
config::tests::test_bundled_default_config_loads: test
config::tests::test_remote_config_fails_fallback_to_bundled_default: test
db::migrations::tests::test_migrations_and_fts5_triggers: test
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

37 tests, 0 benchmarks
## Rust tests summary
test search::tests::test_fts5_prefix_matching ... ok
test search::tests::test_playlist_and_history_lifecycle ... ok
test search::tests::test_search_results_processing_and_deduplication ... ok
test resolvers::tests::test_fixture_320_fails_steps_down_to_160 ... ok
test resolvers::tests::test_youtube_fallback_honest_bitrate_marking ... ok

test result: ok. 37 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 2.00s

## Rust clippy
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.52s
## Desktop tests summary
> Get more help at https://help.gradle.org.

Deprecated Gradle features were used in this build, making it incompatible with Gradle 9.0.

You can use '--warning-mode all' to show the individual deprecation warnings and determine if they come from your own scripts or plugins.

For more on this, please refer to https://docs.gradle.org/8.12/userguide/command_line_interface.html#sec:command_line_warnings in the Gradle documentation.

BUILD FAILED in 43s
10 actionable tasks: 1 executed, 9 up-to-date
