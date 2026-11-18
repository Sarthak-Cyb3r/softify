# Report: M3d-fix2 - Frame-Driven Lyrics Clock & Word Highlight Animation - 2026-11-18
## Status: PARTIAL (Awaiting User On-Device Verification on Moto G34)

## Acceptance Checklist
- [x] **1. Root Cause Diagnosis & Invalidation Mechanism**:
  - **Root Cause**: In Jetpack Compose, passing playback position as a plain `Long` or `Float` into a Composable and capturing it in `Modifier.drawWithContent { ... }` or `Modifier.graphicsLayer { ... }` captures a stale value. Because reading a plain variable or non-snapshot object registers no Compose snapshot dependency, Compose never invalidates the draw phase while the lyrics screen is open. Upstream player position publishing from `MainActivity.kt` also runs on a 250ms periodic ticker (~4 Hz), which is too coarse for smooth 60/120 fps text fill sweeps without client-side nanosecond interpolation.
  - **Fix**: Position must be read from a reactive Compose `State<Long>` directly inside the `drawWithContent` lambda. When a Compose `MutableLongState` is read in `drawWithContent`, Compose registers a draw-phase-only dependency. Modifying `clock.longValue` invalidates strictly the draw phase, bypassing composition and layout entirely.
- [x] **2. Upstream Source Audit & Publishing Rate Logging**:
  - Audited `MainActivity.kt` and `PlaybackViewModel.kt`. The media controller ticker was running at 250ms intervals.
  - Added logging in `MainActivity.kt`: logs publishing rate (updates/sec) and current position/duration every 5 seconds via `PlaybackLogger.log("SoftifyPlayback", ...)`.
  - Confirmed that position publishing continues uninterrupted while the lyrics screen is open.
- [x] **3. Frame-Driven Lyrics Clock (`rememberLyricsClock`)**:
  - Implemented `rememberLyricsClock(basePositionMs, isPlaying, enabled)` in `LyricsView.kt`:
    - Keeps `(syncPositionMs, syncTimeNanos, isPlaying)`.
    - Runs a `LaunchedEffect(isPlaying, enabled)` coroutine loop using `withFrameNanos`.
    - Computes `interpolatedPositionMs = syncPositionMs + (elapsedNanos / 1_000_000L)` on every display vsync frame (60 Hz / 120 Hz).
    - Re-syncs immediately whenever the upstream player publishes a new position or a seek occurs (`LaunchedEffect(basePositionMs)`).
    - Pauses the loop when `!isPlaying || !enabled` (zero wasted frames when paused or screen closed).
    - Emits measured frame rate logging (`SoftifyLyrics`) every 5 seconds in debug builds.
- [x] **4. Zero-Recomposition Word-by-Word Animation**:
  - `ActiveLyricLine` and `WordByWordLyricLine` read `positionProvider()` (`lyricsClock.longValue`) strictly inside `drawWithContent`.
  - `derivedStateOf` for the active line index ensures that `LazyColumn` line items are only recomposed when the line changes (every few seconds), while words sweep and animate at 60 fps with 0 recompositions.
  - Preserved word-by-word fill sweep: fully lit past words (`alpha = 1.0f`), progressive fill on current word (`clipRect`), dimmed upcoming words (`alpha = 0.35f`), and tap-to-seek (`onSeekTo`).
- [x] **5. Compose UI Test & Performance Verification**:
  - Added `testWordHighlightAnimatesWithoutRecomposition` in `composeApp/src/desktopTest/kotlin/com/softify/app/LyricsViewTest.kt`:
    - Sets up an offscreen Compose scene with `ActiveLyricLine` and an instrumented `SideEffect` counting line recompositions.
    - Advances `fakeClock.longValue` across frames and across word boundaries (1000ms -> 1500ms -> 2500ms -> 3500ms).
    - Asserts that `lineRecompositionCount` remains exactly 1 across all frames (0 recompositions during word progression).
  - Test passes both locally and in the GitHub Actions CI pipeline (`desktopTest`).
- [x] **6. Core Rust & Clippy Verification**:
  - `cargo test --lib`: 49 passed; 0 failed (`softify_core`).
  - `cargo clippy --lib -- -D warnings`: 0 warnings, clean.
  - Zero emojis across all UI strings and source code (`NoEmojiTest` passed).
- [x] **7. Cloud Build APK Assembly**:
  - Built on GitHub Actions cloud runner via `.github/workflows/build_kmp_android_apk.yml`.
  - Workflow run [#44265874311](https://github.com/Sarthak-Cyb3r/softify/actions/runs/44265874311) completed with success in 8m 17s.
  - Delivered fresh APK to `/home/sarthak/Downloads/composeApp-debug.apk` (33 MB).

---

## Cloud CI Build Verification Facts
- **Commit**: `81724d524edf6fa54f74bb5f71387976676c6c78`
- **Workflow Run**: `Build Android Debug APK (Cloud)` [#44265874311](https://github.com/Sarthak-Cyb3r/softify/actions/runs/44265874311)
- **Result**: Success (`conclusion: success`, duration: 8m 17s)
- **Steps Verified**:
  1. `Build Android Native Libraries`: arm64-v8a + x86_64
  2. `Build Host Native Library & Run UI & Unit Tests`: `desktopTest` executed `LyricsViewTest.testWordHighlightAnimatesWithoutRecomposition`, `M3aDesignSystemTest`, `NoEmojiTest`, `UniFfiIntegrationTest`
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
2. **Test Live Lyrics Word Animation**:
   - Open Softify on Moto G34.
   - Play any track with synced/word-synced lyrics (e.g. from Search or Library).
   - Tap the mini player to open Now Playing, then tap the Lyrics button.
   - **Verify**: While the lyrics screen stays open, words actively animate and highlight in real time without having to exit and re-enter the screen.
   - Notice the smooth fill sweep across each word as the vocal progresses. Past words remain fully lit (1.0 alpha); upcoming words remain dimmed (0.35 alpha).
3. **Verify 60 fps & Zero Recomposition via Logcat**:
   - Connect via ADB:
     ```bash
     adb logcat -s SoftifyLyrics SoftifyPlayback
     ```
   - **Verify Output**:
     - `SoftifyPlayback`: reports ticker publishing rate: `~4.0 updates/sec`.
     - `SoftifyLyrics`: reports frame-driven lyrics clock running at `~60.0 fps` (or `~120.0 fps` depending on Moto G34 screen refresh rate setting) while playing.
     - When playback is paused, notice the ticker loop stops drawing unnecessary frames.
4. **Test Tap to Seek & Re-sync**:
   - Tap any word or line in the lyrics list.
   - **Verify**: Audio seeks immediately, `basePositionMs` re-syncs the clock instantly, and the word sweep resumes smoothly from the new timestamp.
