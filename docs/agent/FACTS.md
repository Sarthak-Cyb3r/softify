# Facts 2026-11-14T17:37:21+05:30
## Git
0487535 M2e: verification and packaging fixes
b0af156 docs: update M2d REPORT.md and FACTS.md
332e86b M2d: verification close-out
4349de2 M2: Complete core backend with Spotify importer, local audio scanner, recommendation engine, and desktop/android integration
815e6cf M2b: Remote config, LRCLIB lyrics, M4A download tagger, real fixture test, and Kotlin integration tests
97a26c2 M2: Database schema, FTS5 offline search engine, and library management
d9d5e4a M1: vertical slice with Saavn 320kbps resolver, UniFFI, and Media3 playback
0cf00db fix(linux): set window icon directly from bundled assets with GTK theme fallback
b25ded2 feat(architecture): integrate Rust native core engine with authentic Flutter dual UI, restore v4.0.2 QoL suite, and bump to v4.0.3
d02859b feat(ui): restore and optimize original Softify Flutter UI (v4.0.1 baseline)
 M composeApp/src/androidMain/AndroidManifest.xml
 M composeApp/src/androidMain/kotlin/com/softify/app/MainActivity.kt
 M composeApp/src/androidMain/kotlin/com/softify/app/playback/PlaybackService.kt
 M composeApp/src/commonMain/kotlin/com/softify/app/ui/App.kt
 M composeApp/src/commonMain/kotlin/com/softify/app/ui/apple/AppleMusicNowPlaying.kt
 M composeApp/src/commonMain/kotlin/com/softify/app/ui/metrolist/MetrolistNowPlaying.kt
 M composeApp/src/commonMain/kotlin/com/softify/app/viewmodel/PlaybackViewModel.kt
 M docs/agent/FACTS.md
?? composeApp/src/commonMain/kotlin/com/softify/app/ui/diagnostics/
?? composeApp/src/commonMain/kotlin/com/softify/app/util/
## Diff stat
 .gitignore                                         |   1 +
 README.md                                          |  14 ++
 composeApp/build.gradle.kts                        |   3 +
 composeApp/src/androidMain/AndroidManifest.xml     |   1 +
 .../jniLibs/arm64-v8a/libsoftify_core.so           | Bin 12236984 -> 0 bytes
 .../androidMain/jniLibs/x86_64/libsoftify_core.so  | Bin 12052464 -> 0 bytes
 .../kotlin/com/softify/app/MainActivity.kt         | 183 +++++++++++++++-
 .../com/softify/app/playback/PlaybackService.kt    | 244 +++++++++++++++++++--
 .../commonMain/kotlin/com/softify/app/ui/App.kt    |  90 +++++---
 .../softify/app/ui/apple/AppleMusicNowPlaying.kt   |  25 ++-
 .../app/ui/metrolist/MetrolistNowPlaying.kt        |  27 ++-
 .../com/softify/app/viewmodel/PlaybackViewModel.kt | 144 +++++++++++-
 .../com/softify/app/UniFfiIntegrationTest.kt       | 235 ++++++++++++--------
 docs/agent/FACTS.md                                | 132 +----------
 docs/agent/REPORT.md                               | 117 +++++-----
 docs/agent/quality_30.txt                          |  96 +++++---
 docs/agent/quality_nosaavn.txt                     |  28 +++
 rust/softify_core/Cargo.toml                       |   8 +
 rust/softify_core/src/bin/quality_verifier.rs      |  28 +++
 rust/softify_core/src/resolvers/saavn.rs           | 142 ++++++++++--
 rust/softify_core/src/resolvers/tests.rs           |  81 +++++++
 rust/softify_core/src/resolvers/youtube.rs         |  22 +-
 tools/build_android_libs.sh                        |  46 ++++
 tools/make_report.sh                               |   4 +-
 24 files changed, 1267 insertions(+), 404 deletions(-)
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
test resolvers::tests::test_youtube_fallback_honest_bitrate_marking ... ok
test resolvers::tests::test_fixture_320_selected_when_available ... ok
test search::tests::test_search_results_processing_and_deduplication ... ok
test search::tests::test_playlist_and_history_lifecycle ... ok
test search::tests::test_fts5_prefix_matching ... ok

test result: ok. 37 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.20s

## Rust clippy
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.23s
## Desktop tests summary
[Incubating] Problems report is available at: file:///home/sarthak/Desktop/Projects/Softify-experimental/build/reports/problems/problems-report.html

Deprecated Gradle features were used in this build, making it incompatible with Gradle 9.0.

You can use '--warning-mode all' to show the individual deprecation warnings and determine if they come from your own scripts or plugins.

For more on this, please refer to https://docs.gradle.org/8.12/userguide/command_line_interface.html#sec:command_line_warnings in the Gradle documentation.

BUILD SUCCESSFUL in 17s
11 actionable tasks: 11 up-to-date
<testsuite name="com.softify.app.UniFfiIntegrationTest" tests="17" skipped="0" failures="0" errors="0" timestamp="2026-11-14T12:05:16" hostname="fedora" time="2.567">
  <testcase name="test01_initDatabase[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.022"/>
  <testcase name="test02_saveTrackAndSearchLibrary[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.007"/>
  <testcase name="test03_searchCombined[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="1.121"/>
  <testcase name="test04_toggleLikeAndGetLikedTracks[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.003"/>
  <testcase name="test05_createAndGetPlaylists[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.005"/>
  <testcase name="test06_addAndRemoveFromPlaylist[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.007"/>
  <testcase name="test07_deletePlaylist[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.003"/>
  <testcase name="test08_recordAndGetHistory[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.003"/>
  <testcase name="test09_clearHistory[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.002"/>
  <testcase name="test10_refreshRemoteConfig[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.384"/>
  <testcase name="test11_checkProvidersHealth[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.532"/>
  <testcase name="test12_getLyrics[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.46"/>
  <testcase name="test13_downloadsApiAndDeletion[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.002"/>
  <testcase name="test14_tasteProfileAndRecommendationShelves[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.004"/>
  <testcase name="test15_artistSnoozingLifecycle[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.003"/>
  <testcase name="test16_incognitoMode[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.003"/>
  <testcase name="test17_localMusicScanner[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="0.004"/>
</testsuite>
## Gradle assembleDebug
[Incubating] Problems report is available at: file:///home/sarthak/Desktop/Projects/Softify-experimental/build/reports/problems/problems-report.html

Deprecated Gradle features were used in this build, making it incompatible with Gradle 9.0.

You can use '--warning-mode all' to show the individual deprecation warnings and determine if they come from your own scripts or plugins.

For more on this, please refer to https://docs.gradle.org/8.12/userguide/command_line_interface.html#sec:command_line_warnings in the Gradle documentation.

BUILD SUCCESSFUL in 1m 3s
40 actionable tasks: 40 executed
## Native libraries in APK
    10096  01-01-1981 01:01   lib/arm64-v8a/libandroidx.graphics.path.so
   168176  01-01-1981 01:01   lib/arm64-v8a/libjnidispatch.so
  5859048  01-01-1981 01:01   lib/arm64-v8a/libsoftify_core.so
    10760  01-01-1981 01:01   lib/x86_64/libandroidx.graphics.path.so
   118584  01-01-1981 01:01   lib/x86_64/libjnidispatch.so
  6466208  01-01-1981 01:01   lib/x86_64/libsoftify_core.so
## Quality verifier 30 tracks reference
Full output saved at docs/agent/quality_30.txt
[RESOLVER] JioSaavn resolved: 'Udaan' -> 320 kbps, codec=aac, requested_quality_met=true
| 30 | Udaan - Amit Trivedi | Indie/Obscure | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | YES | 840 ms |

=== Summary ===
Total tracks resolved: 30/30
Studio Master (320 kbps) achieved: 27/30
Success rate: 100.0%

