# Report: M3a2 - Design System & Component Fix Pass - 2026-11-14
## Status: PARTIAL

## Acceptance Checklist
- [x] Scalloped shapes and badges completely removed (`ScallopedBadgeShape`, `ScallopedBadge.kt`, tests, and gallery references deleted; `SquircleShape` preserved)
- [x] Minimal, quiet BitrateBadge implemented (single-line rounded pill, no borders/thick colors/ALL CAPS, lowercase "fallback" with amber dot; provider and itags moved to Diagnostics screen only; optional dynamic sample rate; faint inactive state)
- [x] Zero emojis or pictographs across all UI strings/components (replaced with Compose ImageVector icons; 48dp touch targets and content descriptions on all icons; verified by automated `NoEmojiTest`)
- [x] Synced lyrics shine sweep on active line (`LyricsView.kt` and `LyricsPreviewLine.kt` with Brush/graphicsLayer `BlendMode.SrcIn`, interpolated line duration comment, instrumental Canvas pulsing dots, wrapping support, tap-to-seek, and animated centering)
- [x] Component Gallery fixes (horizontally scrollable seed color chips without text wrapping; proper `CircularProgressIndicator` on buffering play pill; play/pause dimmed and non-clickable in disabled dock)
- [x] Generated offscreen gallery screenshots in `docs/agent/screenshots/` (`gallery_overview.png`, `badge_states.png`, `dock_no_emojis.png`, `lyrics_shine_start.png`, `lyrics_shine_middle.png`, `lyrics_shine_end.png`)
- [?] On-device rendering and smoothness on Moto G34 (NOT VERIFIED - awaiting user device test)

## What works (verified by running it, with commands)
- **Unit & UI Tests**: 24 tests passed (`./gradlew desktopTest`), including `NoEmojiTest` scanning all Kotlin source files for emojis/forbidden glyphs and `M3aDesignSystemTest` generating component screenshots.
- **Rust Core**: 37 lib unit tests passed (`cargo test --lib`), 0 clippy warnings (`cargo clippy --lib -- -D warnings`).
- **Offscreen Screenshots**: Captured 6 PNG renders in `docs/agent/screenshots/` displaying minimal badges, emoji-free dock states, and lyrics sweep at start (15%), middle (50%), and end (90%).
- **Diagnostics Screen**: Live JankStats line with dropped frame counter, total frames, jank %, and active stream telemetry (provider, kbps, codec, fallback status).

## Test results
- `./gradlew desktopTest`:
  `<testsuite name="com.softify.app.M3aDesignSystemTest" tests="3" skipped="0" failures="0" errors="0" time="6.849">`
  `<testsuite name="com.softify.app.NoEmojiTest" tests="1" skipped="0" failures="0" errors="0" time="0.064">`
  `<testsuite name="com.softify.app.PlaybackRetryTest" tests="3" skipped="0" failures="0" errors="0" time="0.100">`
  `<testsuite name="com.softify.app.UniFfiIntegrationTest" tests="17" skipped="0" failures="0" errors="0" time="2.828">`
- `cargo test --lib`:
  `37 passed; 0 failed; 0 ignored; finished in 1.20s`
- `cargo clippy --lib -- -D warnings`: 0 warnings

## What is stubbed or broken (be specific, no softening)
- **On-Device Look & Smoothness**: Marked `[?] NOT VERIFIED`. Must be verified by the user on the Moto G34 hardware.
- **M3b Screens**: Home shelves with `home_explore`, Search, Library, Settings remain out of scope for this fix pass.

## What to test on the phone
1. Install updated `/home/sarthak/Downloads/composeApp-debug.apk` on Moto G34.
2. Open Settings -> tap **"Open Component Gallery"** (or reach from Diagnostics).
3. Test in the gallery:
   - **Seed Chips**: Scroll horizontally, verify "Rose" chip does not wrap to "Ro / se".
   - **Minimal Bitrate Badges**: Verify small single-line pill, no thick borders, lowercase "fallback" with amber dot, and faint inactive state.
   - **Floating Dock**: Verify real vector icons (no emojis/pictographs), tap favorite heart for spring pop, verify proper circular progress indicator during buffering, and check play/pause is dimmed and non-clickable in disabled state.
   - **Lyrics View & Sweep Highlight**: Tap Play or drag position slider in section 5 to observe the shine sweep across the active line (test at start 4.3s, middle 6.2s, end 8.1s, and instrumental 1.5s).
4. Open **Diagnostics** screen and inspect the live **JankStats** line while the lyrics sweep is running to verify frame rate.
