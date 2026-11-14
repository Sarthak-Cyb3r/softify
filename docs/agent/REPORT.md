# Report: Android Playback YouTube 403 & Retry Logic Fix - 2026-11-14
## Status: PARTIAL

## Acceptance Checklist
- [x] BUG 1 - YouTube 403 investigation & fix:
  - "Probe last YouTube URL" button added in Diagnostics screen running OkHttp 6-case matrix (open-ended vs bounded ranges, with/without Referer, client UA).
  - VisionOS InnerTube client context with dynamic `visitorData` prioritized, producing unthrottled direct itag 140 URLs.
  - `BoundedHttpDataSource` implemented in Media3 wrapping `DefaultHttpDataSource` to transparently serve 1 MB bounded chunks for `googlevideo.com`.
  - InnerTube client User-Agent explicitly set on `DefaultHttpDataSource.Factory.setUserAgent`.
  - Android client fallback stripped of browser `Referer` header.
- [x] BUG 2 - Session-bound auto-retry engine:
  - `PlaybackRetryManager` implemented with generation session IDs.
  - Max 2 retries with backoff (500ms, 1000ms), logging `"retry n/2"` with failure reason.
  - Stale retries immediately cancelled when user selects another track, pauses, or stops.
  - Deterministic Kotlin unit test suite in `PlaybackRetryTest.kt` verifying backoff, exhaustion, and cancellation.
- [x] Android hygiene & packaging:
  - Removed `android:usesCleartextTraffic="true"` from `AndroidManifest.xml`.
  - `PlaybackService.onStartCommand` gracefully ignores `intent?.action == null`.
  - Redundant service startup skipped when `PlaybackService.instance != null`.
- [x] Quality verifier updated:
  - YouTube streams verified via 1 MB bounded range GET with body bytes verification.
  - Added `Playable Probe` column.
  - 5-track `--no-saavn` run saved to `docs/agent/quality_nosaavn.txt` (100% playable 1.00MB).
  - 30-track benchmark saved to `docs/agent/quality_30.txt` (30/30 resolved, 27/30 320 kbps, 3/30 YouTube 129 kbps).
- [?] Physical playback on Moto G34 (NOT VERIFIED - awaiting user phone test).

## What works (verified by running it, with the command used)
- **Rust Backend**: 37 lib tests passed (`cargo test --lib`), 0 clippy warnings (`cargo clippy --lib -- -D warnings`).
- **Desktop Tests**: 20 tests passed (`./gradlew desktopTest`): 17 UniFFI tests + 3 PlaybackRetry tests.
- **Android Debug APK**: Fresh build with `--rerun-tasks` (`./gradlew assembleDebug --rerun-tasks`, 40/40 executed).
- **YouTube Playable Probes**: 1 MB real body byte downloads confirmed (`YES (1.00MB)`).
- **APK Copied**: Copied fresh 25MB debug APK to `/home/sarthak/Downloads/composeApp-debug.apk`.

## YouTube Probe Matrix (OkHttp from Android Diagnostics)
The Diagnostics screen now includes a dedicated "🔬 Probe last YouTube URL" button executing:
1. `GET Range: bytes=0-1` with ExoPlayer headers
2. `GET Range: bytes=0-` with ExoPlayer headers
3. `GET Range: bytes=0-1048575` with ExoPlayer headers
4. `GET Range: bytes=0-1` without Referer, with Client UA
5. `GET Range: bytes=0-` without Referer, with Client UA
6. `GET Range: bytes=0-1048575` without Referer, with Client UA
Results are formatted into a live table in the Diagnostics console and can be copied or shared.

## Quality Check: YouTube Fallback Tracks (--no-saavn 5)
*(Full run recorded in `docs/agent/quality_nosaavn.txt`)*
| # | Track | Category | Provider | Codec | Requested | Actual | Matched | Playable Probe | Verified | TTFA |
|---|-------|----------|----------|-------|-----------|--------|---------|----------------|----------|------|
| 01 | Tum Hi Ho - Arijit Singh | Popular | YouTube Fallback | AAC | 320 kbps | 129 kbps | NO | YES (1.00MB) | YES | 2676 ms |
| 02 | Kesariya - Arijit Singh | Popular | YouTube Fallback | AAC | 320 kbps | 129 kbps | NO | YES (1.00MB) | YES | 1467 ms |
| 03 | Blinding Lights - The Weeknd | Popular | YouTube Fallback | AAC | 320 kbps | 129 kbps | NO | YES (1.00MB) | YES | 1731 ms |
| 04 | Shape of You - Ed Sheeran | Popular | YouTube Fallback | AAC | 320 kbps | 129 kbps | NO | YES (1.00MB) | YES | 1248 ms |
| 05 | Starboy - The Weeknd | Popular | YouTube Fallback | AAC | 320 kbps | 129 kbps | NO | YES (1.00MB) | YES | 1674 ms |

## What is stubbed or broken (be specific, no softening)
- **Physical Device Playback**: Marked `[?] NOT VERIFIED`. No adb device connected; physical audio playback on Moto G34 must be verified by user.

## Test results
- `./gradlew desktopTest`:
  `<testsuite name="com.softify.app.UniFfiIntegrationTest" tests="17" skipped="0" failures="0" errors="0" time="3.519">`
  `<testsuite name="com.softify.app.PlaybackRetryTest" tests="3" skipped="0" failures="0" errors="0" time="0.33">`
- `./gradlew assembleDebug --rerun-tasks`:
  `BUILD SUCCESSFUL in 1m 32s, 40 actionable tasks: 40 executed`
- Native libraries in APK (`unzip -l composeApp-debug.apk | grep '\.so'`):
  `5859048 lib/arm64-v8a/libsoftify_core.so`
  `6466208 lib/x86_64/libsoftify_core.so`

## Questions / blockers
1. Install `/home/sarthak/Downloads/composeApp-debug.apk` on your Moto G34.
2. Search and play a YouTube fallback track (e.g. "back to friends" by sombr / Rove).
3. If any issue arises, open Diagnostics, tap "🔬 Probe last YouTube URL", and tap "Copy log" or "Share log".
