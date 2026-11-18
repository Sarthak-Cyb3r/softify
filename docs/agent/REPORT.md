# Report: M3c - Player Experience & Detail Screens (Metrolist Material 3 Expressive) - 2026-11-18
## Status: PARTIAL (Awaiting User On-Device Verification on Moto G34)

## Acceptance Checklist
- [x] **1. Fullscreen Now Playing Screen**:
  - Replaced legacy text glyphs with clean Compose vector icons (`Icons.Filled.*`).
  - Hero squircle artwork using `SquircleShape(32.dp)` with fallback placeholder.
  - Interactive squiggly seek slider (`SquigglySlider`) synchronized to real playback time with elapsed and remaining timestamps (`mm:ss`).
  - Transport controls: Previous, Play/Pause (64dp elevated container), Next, Shuffle toggle, and Repeat mode cycle (`OFF` -> `ALL` -> `ONE`).
  - Minimal Bitrate Badge: single-line quiet pill showing real runtime bitrate (e.g., `320 kbps AAC` or `129 kbps AAC fallback` with amber indicator).
  - Fluid container-transform / spring slide-and-fade animation transitioning from the docked `MiniPlayer`.
  - Swipe-down vertical drag gesture or header collapse chevron to return to previous screen.
- [x] **2. Queue Management Bottom Sheet**:
  - Modal bottom sheet (`QueueBottomSheet.kt`) with squircle styling (`SquircleShape(24.dp)`).
  - Displays "Now Playing" hero item with dynamic waveform/play indicator.
  - Displays "Up Next" tracks list with clear visual distinction for tracks queued via "Play Next" (`Play Next` chip badge).
  - Interactive item reordering (`move(fromIndex, toIndex)`) and removal (`removeQueueItem(index)`).
  - Tap any queued track to immediately jump and play.
- [x] **3. LRCLIB Synchronized Lyrics Engine**:
  - Integrated LRCLIB synced lyrics via Rust core UniFFI `get_lyrics` export.
  - Synchronized line rendering with automatic scroll to active line.
  - Active line highlighted with animated subtle sweep shine gradient effect (`LyricsView.kt`).
  - Tap any lyric line to seek directly to that timestamp in the track.
  - Plain-text fallback and graceful instrumental/"No lyrics found" empty states.
- [x] **4. Artist & Album Detail Screens**:
  - Created `ArtistDetailScreen.kt` and `AlbumDetailScreen.kt` with Material 3 Expressive layout.
  - Reachable from track row 3-dots overflow menus ("Go to artist", "Go to album") and from clickable artist/album text in Now Playing.
  - Prominent hero cover art / artist avatar, Play All and Shuffle All buttons, numbered track rows with duration formatting.
  - Integrated into app navigation back stack with instant back navigation.
- [x] **5. Strict Design & Purity Constraints**:
  - Zero emojis or pictographic glyphs anywhere in UI strings or Kotlin sources (`NoEmojiTest` compliant).
  - No scalloped shapes; all cards and containers utilize `SquircleShape`.
  - Minimal quiet bitrate badge with honest quality indicators.
  - Zero hardcoded mock data; all data flows from UniFFI Rust core and SQLite.
- [x] **6. Core Tests & Verification**:
  - `cargo test --lib`: 44 passed; 0 failed (`softify_core`).
  - `cargo clippy --lib -- -D warnings`: 0 warnings.
  - Desktop unit tests: `QueueManagerTest.kt` passes test cases for queue ordering, `move`, `jumpTo`, `playNext` tracking, and stream caching.
- [x] **7. Cloud CI APK Assembly**:
  - Executed on GitHub Actions runner (Run ID: `44236908017`, 7m 21s).
  - Packaged native libraries `libsoftify_core.so` (arm64-v8a: 5,979,912 bytes; x86_64: 6,605,216 bytes).
  - APK delivered to `/home/sarthak/Downloads/composeApp-debug.apk` (33 MB).

---

## Cloud CI Build Verification Facts
- **Commit**: `3a25c9a5d9c6b7983b969e6e00e793b7aba1b130`
- **Workflow Run**: `Build Android Debug APK (Cloud)` [#44236908017](https://github.com/Sarthak-Cyb3r/softify/actions/runs/44236908017)
- **Result**: Success (`conclusion: success`, duration: 7m 21s)
- **Output Artifact**: `composeApp-debug-apk` (24.56 MB zip, 33 MB unpacked APK)
- **Local APK Path**: `/home/sarthak/Downloads/composeApp-debug.apk`
- **Native ABI Verification**:
  ```text
  lib/arm64-v8a/libsoftify_core.so (5,979,912 bytes)
  lib/x86_64/libsoftify_core.so   (6,605,216 bytes)
  lib/arm64-v8a/libjnidispatch.so
  lib/x86_64/libjnidispatch.so
  ```

---

## On-Device Verification Steps for Moto G34 (Android 15)

1. **Install the APK**:
   ```bash
   adb install -r /home/sarthak/Downloads/composeApp-debug.apk
   ```

2. **Test Mini Player -> Full Now Playing Expansion**:
   - Open Softify on the phone.
   - Tap any track from Home shelves or Search results to start playback.
   - Observe the docked `MiniPlayer` above the bottom bar with squircle art and minimal bitrate pill.
   - Tap the `MiniPlayer` card.
   - **Verify**: The screen expands smoothly with a spring container-transform animation into the full Now Playing screen.

3. **Test Now Playing Controls & Progress Scrub**:
   - Verify large squircle artwork (`SquircleShape(32.dp)`).
   - Drag the squiggly slider back and forth: observe smooth seek response and updated elapsed/remaining timestamps.
   - Toggle Repeat mode: cycles `OFF` -> `ALL` -> `ONE`.
   - Toggle Shuffle mode: verifies shuffle state.
   - Verify minimal bitrate badge: shows `320 kbps AAC` or `fallback` without bulky borders or emojis.

4. **Test LRCLIB Synced Lyrics View**:
   - In Now Playing, tap the lyrics icon button in the top action bar.
   - **Verify**: Smoothly toggles into the synced lyrics view.
   - **Verify**: The active singing line is highlighted with a subtle sweep shine effect.
   - Tap any future lyric line: playback jumps to that timestamp and lyrics continue smoothly.

5. **Test Queue Bottom Sheet**:
   - In Now Playing, tap the queue icon in the top action bar.
   - **Verify**: The modal bottom sheet slides up showing "Now Playing" and "Up Next".
   - Notice the "Play Next" badge on tracks added via Play Next.
   - Tap the up/down arrows to reorder items; tap the close icon to remove an item.
   - Tap any track to play it immediately.

6. **Test Artist and Album Navigation**:
   - In Now Playing, tap the artist name: opens `ArtistDetailScreen` with avatar and track list.
   - In Now Playing, tap the album name: opens `AlbumDetailScreen` with album art and track list.
   - Tap the top-left back arrow: returns to Now Playing.
   - Swipe down on the Now Playing screen: collapses smoothly back to the previous screen with the docked `MiniPlayer`.
