# Report: M3d-fix - Moto G34 Lyrics View Fixes & Verification - 2026-11-18
## Status: PARTIAL (Awaiting User On-Device Verification on Moto G34)

## Acceptance Checklist
- [x] **1. Lyrics Toggle Full Path & Gesture Conflict Fix (Bug 1)**:
  - **Root Cause**: `Modifier.draggable` was attached directly to the root `Column` in `MetrolistNowPlaying.kt`. In Jetpack Compose, an ancestor `draggable` intercepts vertical pointer gestures, consuming gesture slop and swallowing clicks on top bar buttons and vertical flings in child scrollables (`LazyColumn`). Additionally, `toggleLyricsView()` did not automatically invoke `loadLyricsForActiveTrack()` if lyrics were not yet fetched, and plain-text lyrics from LRCLIB/YTM had empty `lines` causing the view to silently render as an instrumental fallback.
  - **Fix**:
    - Removed `draggable` from root `Column`. Bound downward collapse gesture exclusively to an isolated top drag handle pill (`Box(width = 36.dp, height = 4.dp)`), freeing all buttons, top bar, and lyrics list from pointer interception.
    - Updated `PlaybackViewModel.toggleLyricsView()` to automatically trigger `loadLyricsForActiveTrack()` when toggled on if `lyrics == null` and not already loading.
    - Added comprehensive debug logging via `PlaybackLogger.log` across toggle clicks, fetch initiation, fetch results (synced, word-synced, line count, plain text length), and view rendering states.
    - Guaranteed distinct UI states: loading spinner with "Loading lyrics...", pulsing 3-dot `InstrumentalIndicator` for instrumental tracks, a clear "No lyrics found" view with a "Retry" button, or the active lyrics view. Never a blank screen.
- [x] **2. Single Line Flow Layout & Word Wrapping (Bug 2)**:
  - **Root Cause**: Word items inside `FlowRow` were subject to internal wrapping or missing width constraints in Skiko/Compose Multiplatform when applying `graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen)`.
  - **Fix**:
    - Rebuilt lyric line layout so one `LazyColumn` item corresponds strictly to one lyric line.
    - Laid out line words inside `FlowRow` with `horizontalArrangement = Arrangement.spacedBy(6.dp)` and `verticalArrangement = Arrangement.spacedBy(6.dp)`.
    - Wrapped each word item with `Modifier.wrapContentSize(Alignment.CenterStart)` and applied `softWrap = false` to individual word texts, ensuring that letters within a word never break across lines, while words wrap cleanly from line to line.
    - Preserved draw-phase position reading (`positionProvider` called only in `drawWithContent`), active word fill sweep, fully lit past words, dimmed upcoming words, and tap-to-seek (`onSeekTo(word.startMs)`).
- [x] **3. Metrolist / Apple Music Typography & Spacing (Bug 3)**:
  - **Left-aligned**: Explicit `TextAlign.Start` across all lines.
  - **Large Bold Typography**: Unified `LyricTextStyle` with `fontSize = 28.sp`, `fontWeight = FontWeight.Bold`, `lineHeight = 38.sp` (~1.35x), `letterSpacing = (-0.5).sp`. Shared identically across active and inactive lines.
  - **Spacing**:
    - 6dp between words (`Arrangement.spacedBy(6.dp)`).
    - 22dp between lines (`Arrangement.spacedBy(22.dp)`).
    - 24dp horizontal content padding (`start = 24.dp, end = 24.dp`).
    - Large top/bottom content padding (`top = 160.dp, bottom = 180.dp`) so active line rests near the vertical center.
  - **Opacity Transitions**:
    - Inactive lines rendered at 35% alpha (`0.35f`).
    - Active line rendered at 100% alpha (`1.0f`).
    - Smooth animated transition via `animateFloatAsState(targetValue = if (isActive) 1.0f else 0.35f, animationSpec = tween(durationMillis = 250))`.
  - **Instrumental & Gaps**: Three animated pulsing dots (`InstrumentalIndicator`) rendered via `Canvas` for instrumental sections and gaps.
- [x] **4. Compose UI Logic Test Suite & Offscreen Verification**:
  - Implemented `composeApp/src/desktopTest/kotlin/com/softify/app/LyricsViewTest.kt`:
    - `testEstimateWordsForLine`: verifies character-proportional word timing duration splits.
    - `testParseLrcLinesWithWordEstimation`: validates LRC line and word parsing.
    - `testLyricsViewOffscreenRenderOnMotoG34Viewport`: renders `LyricsView` on a simulated Moto G34 viewport (360dp x 720dp) with `ImageComposeScene`, verifies rendered bytes, and exports offscreen PNGs.
    - `testEmptyAndInstrumentalStateRendering`: verifies graceful rendering of empty and instrumental states.
  - Integrated `desktopTest` into the GitHub Actions cloud build workflow, confirming tests pass on CI.
- [x] **5. Strict Rules Compliance**:
  - Zero emojis across all UI strings and source code (`NoEmojiTest` and python scan clean).
  - No backend server required; keyless LRCLIB and YTM Innertube integration.
  - Target 320 kbps bitrate pill remains minimal.
- [x] **6. Core Rust & Clippy Verification**:
  - `cargo test --lib`: 49 passed; 0 failed (`softify_core`).
  - `cargo clippy --lib -- -D warnings`: 0 warnings, clean.
- [x] **7. Cloud Build APK Assembly**:
  - Built on GitHub Actions cloud runner via `.github/workflows/build_kmp_android_apk.yml`.
  - Workflow run [#44262351207](https://github.com/Sarthak-Cyb3r/softify/actions/runs/44262351207) completed with success in 7m 20s.
  - Delivered fresh APK to `/home/sarthak/Downloads/composeApp-debug.apk` (33 MB).

---

## Cloud CI Build Verification Facts
- **Commit**: `7ac9188d4076356b7468165b4528eb32d56a2ae5`
- **Workflow Run**: `Build Android Debug APK (Cloud)` [#44262351207](https://github.com/Sarthak-Cyb3r/softify/actions/runs/44262351207)
- **Result**: Success (`conclusion: success`, duration: 7m 20s)
- **Steps Verified**:
  1. `Build Android Native Libraries`: arm64-v8a + x86_64
  2. `Build Host Native Library & Run UI & Unit Tests`: `desktopTest` executed `LyricsViewTest`, `M3aDesignSystemTest`, `NoEmojiTest`, `UniFfiIntegrationTest`
  3. `Build Android Debug APK`: `./gradlew assembleDebug`
  4. `Upload Debug APK`: artifact `composeApp-debug-apk`
- **Packaged Native Libraries**:
  - `lib/arm64-v8a/libsoftify_core.so`: 6,044,944 bytes
  - `lib/x86_64/libsoftify_core.so`: 6,681,328 bytes
- **Local Download Path**: `/home/sarthak/Downloads/composeApp-debug.apk` (33 MB)

---

## Moto G34 Physical Device Test Steps
1. **Install APK**:
   ```bash
   adb install -r /home/sarthak/Downloads/composeApp-debug.apk
   ```
2. **Test Lyrics Toggle Gesture Isolation**:
   - Open Softify on Moto G34.
   - Play any song (e.g. from Search or Home).
   - Tap the mini player to expand Now Playing.
   - Tap the **Lyrics icon** in the top bar (or the "Lyrics" pill at the bottom).
   - **Verify**: The view switches immediately to the lyrics screen without any lag or touch swallow.
   - Test swiping the top handle pill downward: collapses cleanly without blocking child list gestures.
3. **Test Loading & "No Lyrics Found" States**:
   - Play a newly searched or obscure track.
   - **Verify**: While loading, a progress spinner with "Loading lyrics..." is shown.
   - If no lyrics exist, a clear "No lyrics found" title and a "Retry" button are displayed. No blank view.
4. **Test Word-by-Word Flow & Typography**:
   - Play a popular track with word timing (e.g. on LRCLIB).
   - **Verify**:
     - Words wrap naturally across lines like text in a paragraph (words do NOT render each on their own line).
     - Typography is large bold (~28sp, Bold, left-aligned) matching Apple Music/Metrolist aesthetics.
     - Spacing between lines is comfortable (~22dp) and 6dp between words.
     - Active word lights up with a smooth fill sweep; past words remain fully lit (1.0 alpha); upcoming words remain dimmed (0.35 alpha).
     - Inactive lines sit at 35% opacity and smoothly animate to 100% when active.
5. **Test Tap to Seek**:
   - Tap any word or line in the lyrics list.
   - **Verify**: Audio seeks immediately to that timestamp, and the active word highlight shifts accordingly.
