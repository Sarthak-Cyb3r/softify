# Report: M3a - Design System & Component Gallery - 2026-11-14
## Status: PARTIAL

## Acceptance Checklist
- [x] Reference screenshots reviewed and organized in `docs/design/metrolist/`
- [x] Gradle ABI check: `verifyNativeLibsExist` task fails if `libsoftify_core.so` is missing for `arm64-v8a` or `x86_64`, printing expected path and `tools/build_android_libs.sh`
- [x] JankStats telemetry integrated for debug builds, tracking jank percentage, frame duration, and logging to Diagnostics
- [x] Pure Kotlin Multiplatform HCT & Cam16 dynamic color engine (`HctColor.kt`), extracting seed colors with fallback to `#6750A4`
- [x] Custom shapes: parametric `ScallopedBadgeShape` (trochoid/rosette bezier curve) and `SquircleShape` (continuous curvature)
- [x] Stateless, state-hoisted Compose components with `@Preview`:
  - `SquigglySlider`: sine wave with smoothstep playhead dampening, frame-clock phase animation, flat line on pause/unplayed, spring-stretched pill thumb during scrub
  - `FloatingSegmentedPlayerDock`: center capsule with elapsed/total countdown timers and transport controls; auxiliary pills for speed, sleep timer, EQ, and spring-pop favorite heart; secondary utility dock
  - `BitrateBadge`: real data only (provider, kbps, codec, fallback indicator; sample rate rendered only if read from player format, never hardcoded)
  - `ScallopedBadge`: multi-lobe rosette container for badges and avatars
  - `LyricsPreviewLine` & `ExpressiveVolumeSlider`
- [x] Debug Component Gallery screen (`ComponentGalleryScreen.kt`) showcasing every component across all required states: idle, playing, paused, buffering, dragging, disabled, long text, and fallback
- [x] Component Gallery screenshots captured offscreen and saved to `docs/agent/screenshots/gallery_overview.png`
- [?] On-device rendering and JankStats on Moto G34 (NOT VERIFIED - awaiting user device test)

## What works (verified by running it, with commands)
- **Design System & Component Tests**: 24 tests passed (`./gradlew desktopTest`), including 4 new unit tests in `M3aDesignSystemTest` verifying HCT color roundtrips, fallback seed handling, rosette bezier curves, squircle bounds, and offscreen screenshot rendering.
- **Rust Backend**: 37 lib tests passed (`cargo test --lib`), 0 clippy warnings (`cargo clippy --lib -- -D warnings`).
- **Gradle ABI Enforcement**: `verifyNativeLibsExist` task executed as a dependency of APK packaging.
- **Android Debug APK Assembly**: Built fresh with `--rerun-tasks` (`./gradlew assembleDebug --rerun-tasks`, 41/41 tasks executed).
- **Gallery Screenshots Generated**: Full offscreen Skia render saved to `docs/agent/screenshots/gallery_overview.png` (109 KB).
- **Debug APK Copied**: Fresh 26MB APK copied to `/home/sarthak/Downloads/composeApp-debug.apk`.

## Test results
- `./gradlew desktopTest`:
  `<testsuite name="com.softify.app.UniFfiIntegrationTest" tests="17" skipped="0" failures="0" errors="0" time="3.238">`
  `<testsuite name="com.softify.app.PlaybackRetryTest" tests="3" skipped="0" failures="0" errors="0" time="0.196">`
  `<testsuite name="com.softify.app.M3aDesignSystemTest" tests="4" skipped="0" failures="0" errors="0" time="1.842">`
- `./gradlew assembleDebug --rerun-tasks`:
  `BUILD SUCCESSFUL in 2m 27s, 41 actionable tasks: 41 executed`
- Native libraries in APK (`unzip -l composeApp-debug.apk | grep '\.so'`):
  `5859048 lib/arm64-v8a/libsoftify_core.so`
  `6466208 lib/x86_64/libsoftify_core.so`

## What is stubbed or broken (be specific, no softening)
- **On-Device JankStats & Rendering**: Marked `[?] NOT VERIFIED`. No physical device or emulator on build machine; Moto G34 test required to verify frame rate and JankStats metrics on real hardware.
- **Screens**: M3b screens (Home shelves, Search, Library, Settings) not implemented yet per milestone staging rules.

## What to test on the phone
1. Install updated `/home/sarthak/Downloads/composeApp-debug.apk` on Moto G34.
2. Open Settings (top right gear) or Diagnostics screen and tap **"🎨 Open M3 Expressive Component Gallery"**.
3. In the gallery:
   - Tap color seed chips (Indigo, Emerald, Amber, Rose) and observe smooth animated theme transitions.
   - Interact with the **Squiggly Waveform Slider**: drag the pill thumb and observe spring stretching, playing sine wave animation, paused flat line, and buffering pulse.
   - Interact with the **Floating Segmented Player Dock**: tap play/pause, prev/next, cycle speed, sleep timer, EQ, and tap the favorite heart to verify spring pop.
   - Verify the **Bitrate Badges**: check Studio Master vs YouTube Fallback warning badges.
4. Open **Diagnostics** screen and verify the live **JankStats** line showing dropped frame count, total frames, jank percentage, and max frame latency.
