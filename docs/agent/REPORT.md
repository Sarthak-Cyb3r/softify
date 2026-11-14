# Report: M1 - 2026-11-14
## Status: DONE

## What works (verified by running it, with the command used)
- Pure Rust `softify_core` crate with JioSaavn 320kbps resolver, DES-ECB decryption, HTTP probe verification, Content-Length sanity checking, and YouTube VisionOS fallback (`cargo test` -> 8 passed).
- CLI tool `quality_verifier` measuring 10 tracks live (`cargo run --bin quality_verifier -- 10`).
- UniFFI Kotlin bindings generated automatically via `uniffi-bindgen` (`softify_core.kt`).
- Compose Multiplatform shared UI with dual design modes (Metrolist M3 Expressive & Apple Music Liquid Glass), ViewModel, and actual-bitrate QualityBadge (`./gradlew compileKotlinDesktop` -> BUILD SUCCESSFUL).
- Android target with Foreground Service Media3 ExoPlayer, notification channel, and APK packaging (`./gradlew assembleDebug` -> BUILD SUCCESSFUL, generated `composeApp-debug.apk` 14MB).

## What is stubbed or broken (be specific, no softening)
- On-device Moto G34 physical playback: NOT VERIFIED by agent (no connected hardware device attached to host; user acceptance test required).
- Desktop audio output: Compose Desktop window compiles, but audio pipeline is stubbed for M1 as scoped.
- Local audio file scanner, lyrics cascade, and recommendations: Planned for M2-M5.

## Test results (paste the real output summary: passed/failed counts)
```
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
```

## Quality check (320 kbps): provider, bitrate and time-to-first-audio for 10 tracks
```
| # | Track | Provider | Codec | Requested | Actual | Verified | TTFA |
|---|-------|----------|-------|-----------|--------|----------|------|
| 01 | Tum Hi Ho - Arijit Singh | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1114 ms |
| 02 | Kesariya - Arijit Singh | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 789 ms |
| 03 | Blinding Lights - The Weeknd | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 773 ms |
| 04 | Shape of You - Ed Sheeran | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1274 ms |
| 05 | Starboy - The Weeknd | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 728 ms |
| 06 | Apna Bana Le - Arijit Singh | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1544 ms |
| 07 | Levitating - Dua Lipa | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1034 ms |
| 08 | Chaleya - Arijit Singh | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1026 ms |
| 09 | Flowers - Miley Cyrus | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 1289 ms |
| 10 | Raataan Lambiyan - Jubin Nautiyal | JioSaavn Studio | AAC | 320 kbps | 320 kbps | YES | 932 ms |
```

### Exact Duration Guard Parity:
Dart reference (`saavn_stream_resolver.dart`):
```dart
final candDurSec = int.tryParse(moreInfo?['duration']?.toString() ?? '') ?? 0;
if (track.duration > const Duration(seconds: 45)) {
  if (candDurSec <= 0) {
    final targetAlbum = _normalize(track.album ?? '');
    final candAlbum = _normalize((moreInfo?['album'] ?? r['subtitle'] ?? '').toString());
    if (targetAlbum.isEmpty || candAlbum.isEmpty || !candAlbum.contains(targetAlbum)) {
      continue;
    }
  } else {
    final diffSec = (track.duration.inSeconds - candDurSec).abs();
    final maxAllowedDiff = (track.duration.inSeconds * 0.10).clamp(8, 25).toInt();
    if (diffSec > maxAllowedDiff) {
      continue;
    }
  }
}
```
Rust implementation (`saavn.rs`):
```rust
let cand_dur_sec: i64 = more_info.get("duration")
    .and_then(|v| v.as_str().and_then(|s| s.parse::<i64>().ok()).or_else(|| v.as_i64()))
    .unwrap_or(0);
let track_dur_sec = (track.duration_ms / 1000) as i64;
if track.duration_ms > 45_000 {
    if cand_dur_sec <= 0 {
        let target_album = normalize(track.album.as_deref().unwrap_or(""));
        let cand_album = normalize(&raw_cand_album);
        if target_album.is_empty() || cand_album.is_empty() || !cand_album.contains(&target_album) {
            continue;
        }
    } else {
        let diff_sec = (track_dur_sec - cand_dur_sec).abs();
        let max_allowed_diff = ((track_dur_sec as f64 * 0.10).clamp(8.0, 25.0)) as i64;
        if diff_sec > max_allowed_diff {
            continue;
        }
    }
}
```

## Decisions I made that you did not ask for
- Installed standalone portable Temurin JDK 17 to `~/.local/jdk-17` to isolate Gradle builds from host's pre-release Java 25.
- Installed Android SDK Commandline Tools and SDK 34 locally to `~/Android/Sdk` to enable local `./gradlew assembleDebug` builds without needing external cloud CI.

## Questions / blockers (numbered)
1. Please test the compiled APK at `composeApp/build/outputs/apk/debug/composeApp-debug.apk` on your Moto G34 and confirm Media3 foreground playback and audio output.

## Files changed (git diff --stat)
```
 build.gradle.kts                                   |   6 +
 composeApp/build.gradle.kts                        |  80 +++
 composeApp/src/androidMain/AndroidManifest.xml      |  34 +
 composeApp/src/androidMain/kotlin/com/softify/app/MainActivity.kt |  48 ++
 composeApp/src/androidMain/kotlin/com/softify/app/playback/PlaybackService.kt | 120 +++
 composeApp/src/commonMain/kotlin/com/softify/app/ui/App.kt | 316 +++++++++
 composeApp/src/commonMain/kotlin/com/softify/app/ui/apple/AppleMusicNowPlaying.kt | 158 +++++
 composeApp/src/commonMain/kotlin/com/softify/app/ui/components/QualityBadge.kt |  52 ++
 composeApp/src/commonMain/kotlin/com/softify/app/ui/metrolist/MetrolistNowPlaying.kt | 178 +++++
 composeApp/src/commonMain/kotlin/com/softify/app/viewmodel/PlaybackViewModel.kt | 100 +++
 composeApp/src/commonMain/kotlin/uniffi/softify_core/softify_core.kt | 1515 +++++++++++++++++++++++++++++++++++++++
 composeApp/src/desktopMain/kotlin/main.kt          |   9 +
 gradle.properties                                  |   4 +
 gradle/libs.versions.toml                          |  11 +
 local.properties                                   |   1 +
 rust/softify_core/Cargo.toml                       |  38 +
 rust/softify_core/src/bin/quality_verifier.rs      | 104 +++
 rust/softify_core/src/bin/uniffi_bindgen.rs        |   5 +
 rust/softify_core/src/db/mod.rs                    |   1 +
 rust/softify_core/src/db/repository.rs             | 113 +++
 rust/softify_core/src/lib.rs                       |  54 ++
 rust/softify_core/src/models.rs                    |  72 ++
 rust/softify_core/src/resolvers/hybrid.rs          |  55 ++
 rust/softify_core/src/resolvers/mod.rs             |   6 +
 rust/softify_core/src/resolvers/saavn.rs           | 529 ++++++++++++++
 rust/softify_core/src/resolvers/tests.rs           | 266 +++++++
 rust/softify_core/src/resolvers/youtube.rs         | 397 ++++++++++
 settings.gradle.kts                                |  27 +
 tools/make_report.sh                               |  16 +
 29 files changed, 4315 insertions(+)
```

## Proposed next step
Milestone 2 (M2): Database & FTS5 Offline Search Engine (port Drift schema, FTS5 migration, library repository, and instant search queries into `softify_core::db` and `softify_core::search`).
