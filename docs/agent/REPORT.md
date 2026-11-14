# Report: M2e - 2026-11-14
## Status: PARTIAL

## Acceptance Checklist
- [x] M1: 320 kbps JioSaavn URL decryption & Range/byte-rate verification (`cargo test`)
- [x] M1: YouTube Innertube fallback with real bitrate marking (`cargo test`)
- [x] M1: UniFFI async bindings with tokio & cancellation (`./gradlew desktopTest`)
- [x] M1: Android foreground service Media3 player skeleton (`./gradlew assembleDebug`)
- [?] M1: Physical on-device audio playback on Moto G34 (NOT VERIFIED - awaiting user test)
- [x] M2a: SQLite Drift-equivalent schema migrations & FTS5 search with triggers
- [x] M2b: Hybrid resolver with health checks & remote/bundled JSON config
- [x] M2b: LRCLIB synced lyrics parser, plain fallback & DB caching
- [x] M2b: M4A download tagger with stco & co64 atom chunk offset realignment
- [x] M2b: Real recorded encrypted media URL fixture decryption test
- [x] M2c: Keyless Spotify public playlist importer with hybrid matching
- [x] M2c: Local audio scanner (walkdir + rayon + lofty) with .nomedia & SHA-256 stability
- [x] M2c: Recommendation engine (taste decay, PPMI, SGD ranker, MMR, 30d snoozing)
- [x] M2e: Match correctness diagnostics & fallback investigation (`quality_30.txt`)
- [x] M2e: Forced YouTube fallback run recorded (`quality_nosaavn.txt`)
- [x] M2e: Track 26 YouTube averageBitrate selection & accurate display
- [x] M2e: Desktop test split into 17 distinct public API tests (17 passed)
- [x] M2e: Android packaging (.so untracked, abiFilters restricted, stripped release build)

## What works (verified by running it, with the command used)
- **Rust Backend**: 37 unit/integration tests passing (`cd rust/softify_core && cargo test --lib`).
- **Linter**: Zero clippy warnings with `-D warnings` (`cd rust/softify_core && cargo clippy -- -D warnings`).
- **Desktop UniFFI Test Suite**: 17 separate integration tests passing (`./gradlew desktopTest`).
- **Fresh Debug APK Build**: Assembles debug APK with `--rerun-tasks` (`./gradlew assembleDebug --rerun-tasks`).
- **APK Packaging Optimization**: Stripped release .so with `opt-level = "s"`, `lto = true`, `codegen-units = 1`. Reduced `arm64-v8a` from 12.2 MB to 5.6 MB (-54%), `x86_64` from 12.0 MB to 6.2 MB (-48%), APK from 37 MB to 25 MB.
- **Match Correctness Diagnostics**: Full 30-track run outputs matched title, artists, duration diff, score, or rejection reason (`cargo run --bin quality_verifier > docs/agent/quality_30.txt`).
- **Fallback Investigation**:
  - `Choojhn De`: Truly absent from JioSaavn. Correctly falls back to YouTube (itag 140, 129 kbps).
  - `Khoj`: Present on Saavn as `Khoj (Passing By)`. Fallback was due to benchmark duration mismatch (245s requested vs 213s actual, exceeding duration guard). Added regression test `test_band_name_and_featured_artist_matching_regression`.
  - `Sage`: Present on Saavn as `Sage` (id `IdsKdK4x`). Fallback was due to benchmark duration mismatch (184s requested vs 231s actual).
- **Track 26 Bitrate**: YouTube player response reports `raw_bitrate = 155506 bps` (peak) and `averageBitrate = 129535 bps`. Selected `averageBitrate` (129 kbps) matching measured Content-Length/duration (130 kbps).
- **Forced Fallback Verification**: `--no-saavn 5` run saved to `docs/agent/quality_nosaavn.txt` (5/5 resolved via YouTube).

## What is stubbed or broken (be specific, no softening)
- **Physical On-Device Playback**: Marked `[?] NOT VERIFIED`. Native `.so` libraries are inside the APK, but physical playback on Moto G34 must be verified by user. No emulator or adb device attached in current environment.

## Test results (paste the real output summary: passed/failed counts)
- `cargo test --lib`:
  `test result: ok. 37 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.06s`
- `cargo clippy -- -D warnings`:
  `Finished dev profile [unoptimized + debuginfo] target(s) in 0.93s` (0 warnings)
- `./gradlew desktopTest`:
  `<testsuite name="com.softify.app.UniFfiIntegrationTest" tests="17" skipped="0" failures="0" errors="0" time="2.578">`
- `./gradlew assembleDebug --rerun-tasks`:
  `BUILD SUCCESSFUL in 55s, 40 actionable tasks: 40 executed`
- Native libraries inside APK (`unzip -l composeApp/build/outputs/apk/debug/*.apk | grep '\.so'`):
  `5859048 lib/arm64-v8a/libsoftify_core.so`
  `6466208 lib/x86_64/libsoftify_core.so`

## Quality check (320 kbps): provider, bitrate and time-to-first-audio for 10 tracks
*(Full 30-track run in `docs/agent/quality_30.txt`, forced fallback in `docs/agent/quality_nosaavn.txt`)*
| # | Track | Category | Provider | Codec | Requested | Actual | Matched | Verified | TTFA |
|---|-------|----------|----------|-------|-----------|--------|---------|----------|------|
| 01 | Tum Hi Ho - Arijit Singh | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | YES | 1089 ms |
| 02 | Kesariya - Arijit Singh | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | YES | 809 ms |
| 03 | Blinding Lights - The Weeknd | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | YES | 712 ms |
| 04 | Shape of You - Ed Sheeran | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | YES | 951 ms |
| 05 | Starboy - The Weeknd | Popular | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | YES | 590 ms |
| 11 | Lag Ja Gale - Lata Mangeshkar | Retro/Regional | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | YES | 877 ms |
| 14 | Brown Munde - AP Dhillon | Retro/Regional | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | YES | 618 ms |
| 18 | Arabic Kuthu - Anirudh Ravichander | Retro/Regional | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | YES | 785 ms |
| 24 | Baarishein - Anuv Jain | Indie/Obscure | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | YES | 631 ms |
| 26 | Choojhn De - When Chai Met Toast | Indie/Obscure | YouTube Fallback | AAC | 320 kbps | 129 kbps | NO | YES | 2402 ms |

## Decisions I made that you did not ask for
1. Selected `opt-level = "s"` for release profile instead of `3` because it reduces binary size by ~1.2 MB per architecture with identical stream decoding performance.
2. Added `tools/build_android_libs.sh` to compile native libraries with `cargo-ndk` and documented the command in `README.md`.

## Questions / blockers (numbered)
1. Physical device check: Please test `composeApp-debug.apk` on your Moto G34 to complete on-device acceptance.

## Files changed (git diff --stat)
```
 .gitignore                                         |   1 +
 README.md                                          |  14 ++
 composeApp/build.gradle.kts                        |   3 +
 .../jniLibs/arm64-v8a/libsoftify_core.so           | Bin 12236984 -> 0 bytes
 .../androidMain/jniLibs/x86_64/libsoftify_core.so  | Bin 12052464 -> 0 bytes
 .../com/softify/app/UniFfiIntegrationTest.kt       | 235 +++++++++++++--------
 docs/agent/FACTS.md                                |  84 ++------
 docs/agent/REPORT.md                               | 135 ++++++------
 docs/agent/quality_30.txt                          |  96 ++++++---
 docs/agent/quality_nosaavn.txt                     |  28 +++
 rust/softify_core/Cargo.toml                       |   8 +
 rust/softify_core/src/bin/quality_verifier.rs      |  28 +++
 rust/softify_core/src/resolvers/saavn.rs           | 142 +++++++++++--
 rust/softify_core/src/resolvers/tests.rs           |  81 +++++++
 rust/softify_core/src/resolvers/youtube.rs         |  22 +-
 tools/build_android_libs.sh                        |  22 ++
 tools/make_report.sh                               |   4 +-
 17 files changed, 629 insertions(+), 274 deletions(-)
```

## Proposed next step
Wait for user on-device verification on Moto G34. Once user confirms "device OK", proceed to Milestone 3 (Metrolist Material 3 Expressive UI).
