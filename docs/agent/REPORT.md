# Report: M5-lyrics-art - Implementation of Metrolist REA Findings

## Summary of Completed Implementation Steps

### 1. Step 1: Lyrics Data Model & Multi-Format Parsers (Commit `8195d78`)
- **Canonical Model Updated**:
  - `LyricsLine` in `rust/softify_core/src/models.rs`: added `is_line_timed: bool` and `is_background: bool`.
  - Nested hierarchy strictly enforced: `LyricLine -> Vec<LyricWord>`. Words live exclusively inside their parent line; zero word tokens emitted as top-level lines.
- **Multi-Format Parsers Implemented in Rust** (`rust/softify_core/src/lyrics/parser.rs`):
  - `parse_ttml`: Apple Music / Paxsenix XML format with `<p begin="..." end="...">` lines and `<span begin="..." end="...">` word timing spans.
  - `parse_lrc`: Enhanced LRC with word-level tags (`<00:01.23>`), as well as standard line-level LRC (`[00:01.23]`). Sets `is_line_timed = true` when word timestamps are absent.
  - `parse_youtube_json3`: YouTube timedtext caption JSON format with `events` and `segs`.
  - `parse_lrclib_lyricsfile`: LRCLIB YAML format with indentation-aware line and word separation.
- **Removed Synthetic Timing**:
  - Completely excised character-proportional estimation (`estimate_words_for_line` in Rust, `estimateWordsForLine` in Kotlin).
  - Line-timed lyrics highlight whole line immediately upon becoming active, without synthetic per-word sweep.
- **Unit Tests with Real Fixtures**:
  - `test_parse_real_sombr_back_to_friends_lyricsfile`: 30 real lines, 192 nested words, 0 word lines.
  - `test_parse_enhanced_lrc_word_timestamps`: verified `<mm:ss.xx>` parsing.
  - `test_parse_ttml_apple_music_format`: verified XML span parsing.
  - `test_parse_youtube_json3_captions`: verified timedtext segs parsing.

---

### 2. Step 2: Multi-Provider Pipeline (Commit `4d6178e`)
- **Keyless Provider Pipeline Implemented in Rust** (`rust/softify_core/src/lyrics/`):
  - `betterlyrics.rs`: `https://lyrics-api.boidu.dev/getLyrics?s=...&a=...&d=...` (verified live HTTP 200, latency ~306ms).
  - `lrcred.rs`: `https://lrc.red/api/v1?q=...` (verified live HTTP 200, latency ~295ms).
  - `unison.rs`: `https://unison.boidu.dev/lyrics?song=...&artist=...` (verified graceful fallback on 404).
  - `paxsenix.rs`: `https://lyrics.paxsenix.org/apple-music/lyrics?id=...` (verified graceful fallback on 502).
  - `youtube_captions.rs`: YouTube subtitle timedtext caption fetcher (`fmt=json3`).
  - `kugou.rs`: KuGou search and Base64 LRC decoder.
  - `lrclib.rs`: LRCLIB fallback client.
- **Engine Coordination & Isolation** (`engine.rs`):
  - Prioritizes word-sync capable providers (BetterLyrics, lrc.red, Unison, Paxsenix, YouTube Captions) over line-synced (LRCLIB, KuGou).
  - 5-second per-provider timeout isolation using `tokio::time::timeout`.
  - Kill switches per provider via `LyricsProvidersConfig`.
  - SQLite negative caching with 7-day TTL: caches 404/not-found responses to prevent redundant network traffic, auto-expiring after 7 days.

---

### 3. Step 3: Shader-Based Word Highlight Rendering (Commit `1be9429`)
- **Metrolist 4-Stop Linear Gradient Shader**:
  - Implemented in `composeApp/src/commonMain/kotlin/com/softify/app/ui/components/LyricsView.kt`.
  - Replaced per-frame Skia `Path` / `clipPath` stencil operations with a 4-stop horizontal linear gradient shader:
    `Brush.linearGradient(0f to litColor, 0.1f to litColor, 0.9f to unlitColor, 1.0f to unlitColor, start = Offset(bandStart, 0f), end = Offset(bandEnd, 0f))`.
  - Fully sung words: drawn in `onSurfaceColor` (lit).
  - Upcoming words: drawn in `aheadColor` (alpha = 0.35f).
  - Currently sung word: 4-stop gradient moves across the word's bounding box driven by the 60 fps lyrics frame clock.
  - Words wrapped across multiple lines: computes separate per-line sub-layouts and rects, smoothly progressing across line breaks.
  - Zero per-frame object allocations: pre-measures full paragraph and word sub-layouts once in `remember(fullString, widthPx)` when layout settles. In the draw lambda, only math and gradient setup are performed.
  - Line-timed lyrics (`isLineTimed = true`): highlights the entire active line immediately with lit color, zero word sweep.

---

### 4. Step 4: FLIP Spring Auto-Scroll & Gesture Lockout (Commit `ac2e3cd`)
- **FLIP Layout Shift Mechanism**:
  - Ported Metrolist's FLIP scroll architecture into `LyricsView.kt`:
  - Instant viewport shift via `listState.scrollBy(delta)`.
  - Inverse visual translation applied to items via `Modifier.graphicsLayer { translationY = visualTranslationY.value }`.
  - Zero initial jump: at frame 0, `offset + translationY = 0`.
  - Decays smoothly to 0 with a damped spring (`dampingRatio = 0.85f, stiffness = 200f`).
- **400ms Gesture Lockout**:
  - Monitors `listState.isScrollInProgress`.
  - When user touches or flings the list, auto-scroll is suppressed and the visual translation resets.
  - Auto-scroll resumes automatically 400ms after user gesture ends, smoothly re-centering the active lyric line in the upper-third (~35%) of the viewport.

---

### 5. Step 5: Discrete Cover Art Bucketing & Fallback Chain (Commit `65a311f`)
- **Discrete Resolution Buckets**:
  - Configured in `CoverArtLoader.kt`: discrete target buckets `256` (thumbnail/list), `544` (shelf/card), `1200` (full/now playing), `2400` (max/fullscreen).
  - Matches Google CDN (`=w...-h...` or `=s...`) and YouTube image server specifications.
- **Cross-Size Cache Candidate Lookup**:
  - Before fetching a 544px image, `CoverArtLoader.findCachedCandidate` checks if a 1200px or 256px version for the same track is already resident in Coil's memory or disk cache.
  - If found, `AsyncCoverArt.kt` immediately displays the cached image scaled, avoiding network delays while the exact resolution loads in background.
- **YouTube 404 Fallback Chain**:
  - `VideoArtworkFallbackInterceptor` (Coil interceptor) and `AsyncCoverArt.kt` fallback chain:
  - If `maxresdefault.jpg` returns 404, immediately falls back to `mqdefault.jpg` (320x180 bar-free frame).
  - If `mqdefault.jpg` fails, falls back to raw provider URL.
  - If all fail, displays solid tonal placeholder (`#242424`).
- **MainActivity JankStats Initialization Fix**:
  - Guarded `JankStats.createAndTrack(window, ...)` with `window.decorView.post { if (window.peekDecorView() != null) { ... } }`.
  - Completely eliminates the `window.peekDecorView() == null` crash at application startup.

---

## Verification & Test Results

1. **Cargo Test & Clippy (Rust Core)**:
   - Command: `cargo test --all` -> 52 passed, 0 failed.
   - Command: `cargo clippy --all-targets -- -D warnings` -> Clean, 0 warnings.
2. **Gradle Multiplatform Tests**:
   - Command: `./gradlew desktopTest` -> 39 passed, 0 failed (34s).
   - `NoEmojiTest` -> Passed (0 emoji characters across entire codebase).
   - `LyricsViewTest`:
     - `testParseLrcLinesStandardNoSyntheticWords` -> Passed.
     - `testLyricsViewOffscreenRenderOnMotoG34Viewport` -> Passed.
     - `testLyricLineParagraphWrappingAt360dpWidth` -> Passed (2 lines, words=3 on line 1).
     - `testWordHighlightAnimatesWithoutRecomposition` -> Passed (exactly 1 recomposition).
   - `CoverArtLoaderTest`:
     - `testThumbnailUrlFormatting` -> Passed (256, 544, 1200, 2400 buckets).
     - `testYouTube404FallbackChain` -> Passed (maxresdefault -> mqdefault).
     - `testCrossSizeCacheCandidates` -> Passed.
     - `testNegativeCacheLifecycle` -> Passed.

---

## Device Verification Steps for Moto G34

1. Install APK from GitHub Actions release build:
   - `adb install -r ~/Downloads/composeApp-debug.apk`
2. Start Softify and verify logcat:
   - `adb logcat -s SoftifyPlayback SoftifyCoverArt | grep -E "Database|JankStats|Art load|Lyrics"`
   - Verify `Database initialized at: /data/user/0/com.softify.app/files/softify.db` occurs before any queries.
   - Verify `JankStats performance tracking initialized` occurs without `peekDecorView` error.
3. Open Now Playing on a track with word-by-word lyrics (e.g. 'back to friends' by sombr):
   - Verify lines wrap as standard multi-word paragraphs at 360dp width.
   - Verify linesCount matches actual song lines (~30 lines, not 222).
   - Verify words highlight smoothly with horizontal gradient wipe driven by 60 fps frame clock.
   - Verify dragging the list locks out auto-scroll, and auto-scroll resumes 400ms after release with smooth FLIP spring decay.
