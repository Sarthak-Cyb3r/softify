# Facts 2026-11-14T15:08:46+05:30
## Git
d9d5e4a M1: vertical slice with Saavn 320kbps resolver, UniFFI, and Media3 playback
0cf00db fix(linux): set window icon directly from bundled assets with GTK theme fallback
b25ded2 feat(architecture): integrate Rust native core engine with authentic Flutter dual UI, restore v4.0.2 QoL suite, and bump to v4.0.3
d02859b feat(ui): restore and optimize original Softify Flutter UI (v4.0.1 baseline)
6e709f8 feat(ui): complete authentic Metrolist M3 & Apple Music Liquid Glass UI redesign
1011ad2 fix(launcher): robust headful java discovery, icon installation, and wmclass matching
d7b998f fix(installer): update repository discovery and bundle icon detection for v4.0.2
fd67ca4 fix(ci): remove hardcoded local java home path from gradle.properties
5520117 ci: use actions/setup-java gradle cache and gradlew executable
5c966db feat(ui): complete Metrolist M3 & Apple Music Liquid Glass dual UI with GitHub Actions CI/CD
 M composeApp/src/commonMain/kotlin/com/softify/app/ui/App.kt
 M composeApp/src/commonMain/kotlin/com/softify/app/viewmodel/PlaybackViewModel.kt
 M composeApp/src/commonMain/kotlin/uniffi/softify_core/softify_core.kt
 M composeApp/src/desktopMain/kotlin/main.kt
 M docs/agent/FACTS.md
 M rust/softify_core/src/db/mod.rs
 M rust/softify_core/src/db/repository.rs
 M rust/softify_core/src/lib.rs
 M rust/softify_core/src/models.rs
?? rust/softify_core/src/db/migrations.rs
?? rust/softify_core/src/search/
## Diff stat
 .gitignore                                         |    6 +
 build.gradle.kts                                   |    6 +
 composeApp/build.gradle.kts                        |   96 +
 composeApp/src/androidMain/AndroidManifest.xml     |   39 +
 .../kotlin/com/softify/app/MainActivity.kt         |   59 +
 .../com/softify/app/playback/PlaybackService.kt    |  149 ++
 .../commonMain/kotlin/com/softify/app/ui/App.kt    |  536 +++++
 .../softify/app/ui/apple/AppleMusicNowPlaying.kt   |  161 ++
 .../com/softify/app/ui/components/QualityBadge.kt  |   63 +
 .../app/ui/metrolist/MetrolistNowPlaying.kt        |  185 ++
 .../com/softify/app/viewmodel/PlaybackViewModel.kt |  208 ++
 .../kotlin/uniffi/softify_core/softify_core.kt     | 2257 +++++++++++++++++++
 composeApp/src/desktopMain/kotlin/main.kt          |   23 +
 docs/agent/FACTS.md                                |   24 +
 docs/agent/REPORT.md                               |  132 ++
 gradle.properties                                  |    4 +
 gradle/libs.versions.toml                          |   12 +
 gradle/wrapper/gradle-wrapper.jar                  |  Bin 0 -> 43583 bytes
 gradle/wrapper/gradle-wrapper.properties           |    7 +
 gradlew                                            |  251 +++
 gradlew.bat                                        |   94 +
 rust/softify_core/Cargo.lock                       | 2342 ++++++++++++++++++++
 rust/softify_core/Cargo.toml                       |   36 +
 rust/softify_core/src/bin/quality_verifier.rs      |  113 +
 rust/softify_core/src/bin/uniffi_bindgen.rs        |    3 +
 rust/softify_core/src/db/mod.rs                    |    2 +
 rust/softify_core/src/db/repository.rs             |  367 +++
 rust/softify_core/src/lib.rs                       |  171 ++
 rust/softify_core/src/models.rs                    |  119 +
 rust/softify_core/src/resolvers/hybrid.rs          |   69 +
 rust/softify_core/src/resolvers/mod.rs             |    6 +
 rust/softify_core/src/resolvers/saavn.rs           |  547 +++++
 rust/softify_core/src/resolvers/tests.rs           |  325 +++
 rust/softify_core/src/resolvers/youtube.rs         |  405 ++++
 rust/softify_core/tests/fixtures/saavn_search.json |   21 +
 settings.gradle.kts                                |   29 +
 tools/make_report.sh                               |   16 +
 37 files changed, 8883 insertions(+)
## Rust tests
test resolvers::tests::test_normalization_and_phonetic_simplify ... ok
test resolvers::tests::test_fixture_saavn_fully_unavailable_triggers_youtube_fallback ... ok
test resolvers::tests::test_url_rewrite_presets ... ok
test search::engine::tests::test_fts5_query_builder ... ok
test search::intent::tests::test_intent_analysis ... ok
test search::normalizer::tests::test_normalizer ... ok
test resolvers::tests::test_youtube_fallback_honest_bitrate_marking ... ok
test search::tests::test_playlist_and_history_lifecycle ... ok
test search::tests::test_search_results_processing_and_deduplication ... ok
test search::tests::test_fts5_prefix_matching ... ok
test resolvers::tests::test_fixture_320_selected_when_available ... ok
test resolvers::tests::test_fixture_320_fails_steps_down_to_160 ... ok

test result: ok. 15 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.05s

## Rust clippy
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.16s
## Gradle build
Deprecated Gradle features were used in this build, making it incompatible with Gradle 9.0.

You can use '--warning-mode all' to show the individual deprecation warnings and determine if they come from your own scripts or plugins.

For more on this, please refer to https://docs.gradle.org/8.12/userguide/command_line_interface.html#sec:command_line_warnings in the Gradle documentation.

BUILD SUCCESSFUL in 2s
40 actionable tasks: 40 up-to-date
