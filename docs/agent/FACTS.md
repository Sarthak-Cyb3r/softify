# Facts 2026-11-14T14:56:19+05:30
## Git
0cf00db fix(linux): set window icon directly from bundled assets with GTK theme fallback
b25ded2 feat(architecture): integrate Rust native core engine with authentic Flutter dual UI, restore v4.0.2 QoL suite, and bump to v4.0.3
d02859b feat(ui): restore and optimize original Softify Flutter UI (v4.0.1 baseline)
6e709f8 feat(ui): complete authentic Metrolist M3 & Apple Music Liquid Glass UI redesign
1011ad2 fix(launcher): robust headful java discovery, icon installation, and wmclass matching
d7b998f fix(installer): update repository discovery and bundle icon detection for v4.0.2
fd67ca4 fix(ci): remove hardcoded local java home path from gradle.properties
5520117 ci: use actions/setup-java gradle cache and gradlew executable
5c966db feat(ui): complete Metrolist M3 & Apple Music Liquid Glass dual UI with GitHub Actions CI/CD
c7b9298 chore: add gradle wrapper and configure .gitignore
?? .gradle/
?? build.gradle.kts
?? composeApp/
?? docs/
?? gradle.properties
?? gradle/
?? gradlew
?? gradlew.bat
?? rust/softify_core/
?? settings.gradle.kts
?? tools/
## Diff stat
 linux/runner/my_application.cc | 9 +++++++++
 1 file changed, 9 insertions(+)
## Rust tests
    Finished `test` profile [unoptimized + debuginfo] target(s) in 2.08s
     Running unittests src/lib.rs (target/debug/build/softify_core/345d157aede12b9c/out/softify_core-345d157aede12b9c)

running 8 tests
test resolvers::tests::test_bitrate_sanity_check ... ok
test resolvers::tests::test_des_decryption_roundtrip ... ok
test resolvers::tests::test_normalization_and_phonetic_simplify ... ok
test resolvers::tests::test_fixture_saavn_fully_unavailable_triggers_youtube_fallback ... ok
test resolvers::tests::test_url_rewrite_presets ... ok
test resolvers::tests::test_youtube_fallback_honest_bitrate_marking ... ok
test resolvers::tests::test_fixture_320_selected_when_available ... ok
test resolvers::tests::test_fixture_320_fails_steps_down_to_160 ... ok

test result: ok. 8 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.07s

## Rust clippy
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.34s
## Gradle build
Deprecated Gradle features were used in this build, making it incompatible with Gradle 9.0.

You can use '--warning-mode all' to show the individual deprecation warnings and determine if they come from your own scripts or plugins.

For more on this, please refer to https://docs.gradle.org/8.12/userguide/command_line_interface.html#sec:command_line_warnings in the Gradle documentation.

BUILD SUCCESSFUL in 6s
40 actionable tasks: 40 up-to-date
