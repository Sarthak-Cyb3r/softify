# Facts 2026-11-14T16:32:05+05:30
## Git
332e86b M2d: verification close-out
4349de2 M2: Complete core backend with Spotify importer, local audio scanner, recommendation engine, and desktop/android integration
815e6cf M2b: Remote config, LRCLIB lyrics, M4A download tagger, real fixture test, and Kotlin integration tests
97a26c2 M2: Database schema, FTS5 offline search engine, and library management
d9d5e4a M1: vertical slice with Saavn 320kbps resolver, UniFFI, and Media3 playback
0cf00db fix(linux): set window icon directly from bundled assets with GTK theme fallback
b25ded2 feat(architecture): integrate Rust native core engine with authentic Flutter dual UI, restore v4.0.2 QoL suite, and bump to v4.0.3
d02859b feat(ui): restore and optimize original Softify Flutter UI (v4.0.1 baseline)
6e709f8 feat(ui): complete authentic Metrolist M3 & Apple Music Liquid Glass UI redesign
1011ad2 fix(launcher): robust headful java discovery, icon installation, and wmclass matching
 M docs/agent/FACTS.md
## Diff stat
 .../jniLibs/arm64-v8a/libsoftify_core.so           | Bin 0 -> 12236984 bytes
 .../androidMain/jniLibs/x86_64/libsoftify_core.so  | Bin 0 -> 12052464 bytes
 docs/agent/FACTS.md                                |  71 +-------------------
 docs/agent/KNOWN_ISSUES.md                         |  13 ++++
 docs/agent/quality_30.txt                          |  74 +++++++++++++++++++++
 rust/softify_core/Cargo.lock                       |  42 +++++++++++-
 rust/softify_core/Cargo.toml                       |   1 +
 rust/softify_core/src/bin/quality_verifier.rs      |  19 ++++--
 rust/softify_core/src/config.rs                    |  11 +++
 rust/softify_core/src/downloads/tagger.rs          |  62 +++++++++++++++++
 rust/softify_core/src/importer/spotify.rs          |  10 +++
 rust/softify_core/src/lyrics/mod.rs                |  37 +++++++++++
 rust/softify_core/src/reco/diversity.rs            |  15 +++++
 rust/softify_core/src/reco/taste.rs                |  41 ++++++++++++
 rust/softify_core/src/scanner/local.rs             |  28 ++++++--
 .../softify_core/tests/fixtures/spotify_embed.html |  70 +++++++++++++++++++
 tools/make_report.sh                               |  38 +++++++++--
 17 files changed, 446 insertions(+), 86 deletions(-)
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

36 tests, 0 benchmarks
## Rust tests summary
test search::tests::test_fts5_prefix_matching ... ok
test search::tests::test_playlist_and_history_lifecycle ... ok
test search::tests::test_search_results_processing_and_deduplication ... ok
test resolvers::tests::test_fixture_320_selected_when_available ... ok
test resolvers::tests::test_fixture_320_fails_steps_down_to_160 ... ok

test result: ok. 36 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.19s

## Rust clippy
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 2.12s
## Desktop tests summary
[Incubating] Problems report is available at: file:///home/sarthak/Desktop/Projects/Softify-experimental/build/reports/problems/problems-report.html

Deprecated Gradle features were used in this build, making it incompatible with Gradle 9.0.

You can use '--warning-mode all' to show the individual deprecation warnings and determine if they come from your own scripts or plugins.

For more on this, please refer to https://docs.gradle.org/8.12/userguide/command_line_interface.html#sec:command_line_warnings in the Gradle documentation.

BUILD SUCCESSFUL in 9s
11 actionable tasks: 11 up-to-date
<testsuite name="com.softify.app.UniFfiIntegrationTest" tests="1" skipped="0" failures="0" errors="0" timestamp="2026-11-14T10:59:00" hostname="fedora" time="4.126">
  <testcase name="testAllPublicUniFfiApis[desktop]" classname="com.softify.app.UniFfiIntegrationTest" time="4.126"/>
</testsuite>
## Gradle assembleDebug
[Incubating] Problems report is available at: file:///home/sarthak/Desktop/Projects/Softify-experimental/build/reports/problems/problems-report.html

Deprecated Gradle features were used in this build, making it incompatible with Gradle 9.0.

You can use '--warning-mode all' to show the individual deprecation warnings and determine if they come from your own scripts or plugins.

For more on this, please refer to https://docs.gradle.org/8.12/userguide/command_line_interface.html#sec:command_line_warnings in the Gradle documentation.

BUILD SUCCESSFUL in 2s
40 actionable tasks: 40 up-to-date
## Native libraries in APK
    10096  01-01-1981 01:01   lib/arm64-v8a/libandroidx.graphics.path.so
   168176  01-01-1981 01:01   lib/arm64-v8a/libjnidispatch.so
 12236984  01-01-1981 01:01   lib/arm64-v8a/libsoftify_core.so
     7252  01-01-1981 01:01   lib/armeabi-v7a/libandroidx.graphics.path.so
   122296  01-01-1981 01:01   lib/armeabi-v7a/libjnidispatch.so
   122784  01-01-1981 01:01   lib/armeabi/libjnidispatch.so
   150924  01-01-1981 01:01   lib/mips/libjnidispatch.so
   141904  01-01-1981 01:01   lib/mips64/libjnidispatch.so
     9284  01-01-1981 01:01   lib/x86/libandroidx.graphics.path.so
   120184  01-01-1981 01:01   lib/x86/libjnidispatch.so
    10760  01-01-1981 01:01   lib/x86_64/libandroidx.graphics.path.so
   118584  01-01-1981 01:01   lib/x86_64/libjnidispatch.so
 12052464  01-01-1981 01:01   lib/x86_64/libsoftify_core.so
## Quality verifier 30 tracks reference
Full output saved at docs/agent/quality_30.txt
[RESOLVER] JioSaavn resolved: 'Udaan' -> 320 kbps, codec=aac, requested_quality_met=true
| 30 | Udaan - Amit Trivedi | Indie/Obscure | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | YES | 711 ms |

=== Summary ===
Total tracks resolved: 30/30
Studio Master (320 kbps) achieved: 27/30
Success rate: 100.0%

