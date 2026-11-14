# Facts 2026-11-14T15:57:06+05:30
## Git
815e6cf M2b: Remote config, LRCLIB lyrics, M4A download tagger, real fixture test, and Kotlin integration tests
97a26c2 M2: Database schema, FTS5 offline search engine, and library management
d9d5e4a M1: vertical slice with Saavn 320kbps resolver, UniFFI, and Media3 playback
0cf00db fix(linux): set window icon directly from bundled assets with GTK theme fallback
b25ded2 feat(architecture): integrate Rust native core engine with authentic Flutter dual UI, restore v4.0.2 QoL suite, and bump to v4.0.3
d02859b feat(ui): restore and optimize original Softify Flutter UI (v4.0.1 baseline)
6e709f8 feat(ui): complete authentic Metrolist M3 & Apple Music Liquid Glass UI redesign
1011ad2 fix(launcher): robust headful java discovery, icon installation, and wmclass matching
d7b998f fix(installer): update repository discovery and bundle icon detection for v4.0.2
fd67ca4 fix(ci): remove hardcoded local java home path from gradle.properties
 M composeApp/src/commonMain/kotlin/uniffi/softify_core/softify_core.kt
 M composeApp/src/desktopTest/kotlin/com/softify/app/UniFfiIntegrationTest.kt
 M docs/agent/FACTS.md
 M rust/softify_core/Cargo.lock
 M rust/softify_core/Cargo.toml
 M rust/softify_core/src/db/migrations.rs
 M rust/softify_core/src/db/repository.rs
 M rust/softify_core/src/lib.rs
 M rust/softify_core/src/models.rs
?? rust/softify_core/src/importer/
?? rust/softify_core/src/reco/
?? rust/softify_core/src/scanner/
## Diff stat
 composeApp/build.gradle.kts                        |   10 +
 .../kotlin/uniffi/softify_core/softify_core.kt     | 1408 +++++++++++++++++++-
 .../com/softify/app/UniFfiIntegrationTest.kt       |  145 ++
 docs/agent/FACTS.md                                |   84 +-
 docs/agent/REPORT.md                               |  151 ++-
 rust/softify_core/Cargo.lock                       |  177 +++
 rust/softify_core/Cargo.toml                       |    3 +
 rust/softify_core/resources/default_config.json    |   37 +
 rust/softify_core/src/bin/quality_verifier.rs      |  139 +-
 rust/softify_core/src/config.rs                    |   83 ++
 rust/softify_core/src/db/migrations.rs             |   29 +
 rust/softify_core/src/db/repository.rs             |  545 ++++++++
 rust/softify_core/src/downloads/manager.rs         |  165 +++
 rust/softify_core/src/downloads/mod.rs             |   49 +
 rust/softify_core/src/downloads/tagger.rs          |  270 ++++
 rust/softify_core/src/lib.rs                       |  181 ++-
 rust/softify_core/src/lyrics/engine.rs             |  103 ++
 rust/softify_core/src/lyrics/lrclib.rs             |  104 ++
 rust/softify_core/src/lyrics/mod.rs                |   77 ++
 rust/softify_core/src/lyrics/parser.rs             |   71 +
 rust/softify_core/src/models.rs                    |  100 ++
 rust/softify_core/src/resolvers/hybrid.rs          |  100 +-
 rust/softify_core/src/resolvers/tests.rs           |   16 +
 rust/softify_core/src/resolvers/youtube.rs         |    4 +
 .../tests/fixtures/real_saavn_song_details.json    |   15 +
 25 files changed, 3806 insertions(+), 260 deletions(-)
## Rust tests
test resolvers::tests::test_url_rewrite_presets ... ok
test resolvers::tests::test_normalization_and_phonetic_simplify ... ok
test scanner::local::tests::test_excluded_folders_and_nomedia ... ok
test resolvers::tests::test_youtube_fallback_honest_bitrate_marking ... ok
test search::engine::tests::test_fts5_query_builder ... ok
test search::intent::tests::test_intent_analysis ... ok
test search::normalizer::tests::test_normalizer ... ok
test search::tests::test_fts5_prefix_matching ... ok
test resolvers::tests::test_fixture_320_fails_steps_down_to_160 ... ok
test resolvers::tests::test_fixture_320_selected_when_available ... ok
test search::tests::test_playlist_and_history_lifecycle ... ok
test search::tests::test_search_results_processing_and_deduplication ... ok

test result: ok. 29 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.05s

## Rust clippy
    Checking softify_core v0.1.0 (/home/sarthak/Desktop/Projects/Softify-experimental/rust/softify_core)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 5.19s
## Gradle build
Deprecated Gradle features were used in this build, making it incompatible with Gradle 9.0.

You can use '--warning-mode all' to show the individual deprecation warnings and determine if they come from your own scripts or plugins.

For more on this, please refer to https://docs.gradle.org/8.12/userguide/command_line_interface.html#sec:command_line_warnings in the Gradle documentation.

BUILD SUCCESSFUL in 19s
40 actionable tasks: 40 up-to-date
