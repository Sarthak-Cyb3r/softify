# Report: M3b - Metrolist Material 3 Expressive Screens - 2026-11-17
## Status: PARTIAL

## Acceptance Checklist
- [x] **Rust Core Extensions**: Migrated database with `recent_searches` and `home_explore_cache` tables; added `home_explore` with network + cached SQLite + bundled fixture fallbacks; added Smart Playlists (`get_on_repeat_tracks`, `get_most_played_tracks`, `get_forgotten_favorites_tracks`) with deterministic cutoff rules; playlist rename support; Incognito mode enforcement (`learning_paused` blocks searches, history, and taste updates). 42 unit tests passed.
- [x] **Kotlin Queue Architecture**: Implemented `QueueManager.kt` as single source of truth for queue state, lazy stream resolution with TTL/expiration check, lookahead pre-resolution of upcoming track, play next vs add to queue, repeat modes (OFF, ALL, ONE), skip controls, and auto-advance on track completion. Unit tested in `QueueManagerTest.kt`.
- [x] **Mini Player**: Docked above bottom navigation across all screens; features squircle cover art, bold title, muted artist, minimal `BitrateBadge` (single-line pill, lowercase "fallback" with amber dot), thin squiggly line synced to playback progress, play/pause and next controls with >=48dp touch targets, and tap notification ("Now Playing full screen arrives in M3c").
- [x] **Home Screen**: Header with "320 kbps Studio Fidelity", personalized recommendation shelves with fallback to charts/trending explore shelves, horizontal card rows with squircle artwork, track overflow options (Play next, Add to queue, Add to playlist, Like), and real loading/empty/error states with retry.
- [x] **Search Screen**: Search input with 300ms debounce, instant local FTS5 matches merged with online results, classification intent badge (Artist, Album, Track), recent search history with individual delete and clear-all, and tapping a search result plays immediately while queuing the rest.
- [x] **Library Screen**: Smart playlist cards ("On Repeat", "Most Played", "Forgotten Favorites"), filter chips for Playlists, Liked Songs, and History (Downloads chip intentionally hidden per instructions), playlist creation dialog, rename dialog, delete confirmation, and keyless Spotify playlist import dialog.
- [x] **Playlist Detail Screen**: Dynamic gradient header, track count, total calculated duration, Play and Shuffle controls, numbered track rows, active playback indicator, and track removal.
- [x] **Settings Screen**: Audio quality stream presets (High 320k, Med 160k, Low 96k), UI design system picker, Incognito mode toggle, history and search clearing, system info diagnostics, and entry points to Diagnostics and Component Gallery.
- [x] **Design Constraints & Cleanliness**: Zero emojis or pictographs across all Kotlin code and UI strings; validated by `NoEmojiTest`.
- [x] **Cloud Build Pipeline**: Created `.github/workflows/build_kmp_android_apk.yml`; built on GitHub Actions runner (run #44100393153, 7m 29s); verified arm64-v8a and x86_64 `libsoftify_core.so` native libraries; APK downloaded to `/home/sarthak/Downloads/composeApp-debug.apk` (32MB).
- [x] **Documentation Updates**: Added "M4a: download worker + progress notification" to `docs/ROADMAP.md`; documented Android SAF directory picker in `docs/agent/KNOWN_ISSUES.md`.
- [?] **On-Device Verification on Moto G34 (Android 15)**: (NOT VERIFIED - awaiting user device test).

## What Works (Verified)
- **Rust Core**: 42 lib unit tests passed (`cargo test --lib`), 0 clippy warnings (`cargo clippy --lib -- -D warnings`).
- **NoEmojiTest**: 0 forbidden emojis or pictographs across all Kotlin files in `composeApp/src`.
- **Cloud Build**: GitHub Actions workflow completed with exit code 0; universal APK assembled and verified.
- **Native Libraries**: `lib/arm64-v8a/libsoftify_core.so` (5,926,096 bytes) and `lib/x86_64/libsoftify_core.so` (6,539,760 bytes) packaged inside APK.

## Test Results
- `cargo test --lib`:
  `42 passed; 0 failed; 0 ignored; finished in 1.26s`
- `cargo clippy -- -D warnings`: 0 warnings
- GitHub Actions Run `#44100393153`:
  `✓ Build Android Debug APK with Rust Core in 7m29s (ID 134098528815) - conclusion: success`
- APK native library inspection (`unzip -l composeApp-debug.apk | grep '\.so'`):
  - `lib/arm64-v8a/libsoftify_core.so`
  - `lib/x86_64/libsoftify_core.so`
  - `lib/arm64-v8a/libjnidispatch.so`
  - `lib/x86_64/libjnidispatch.so`

## What is Stubbed or Deferred (By Approved Plan)
- **Full Now Playing Screen & Apple Music Liquid UI**: Deferred to M3c (mini player tap shows informative snackbar; Apple Music chip disabled with M3c label).
- **Offline Download Manager**: Background download worker and notification deferred to M4a (`docs/ROADMAP.md`). Downloads chip in Library screen is hidden.
- **Android SAF Local Storage Picker**: Local directory picker deferred to M4 (`docs/agent/KNOWN_ISSUES.md`).
- **On-Device Look & Feel**: Status is `PARTIAL` pending physical device verification on Moto G34 (Android 15).

## What to Test on the Moto G34
1. Install `/home/sarthak/Downloads/composeApp-debug.apk`.
2. **Bottom Navigation**: Tap Home, Search, and Library. Verify bottom navigation bar transitions and back stack behavior (pressing back on Search or Library returns to Home).
3. **Home Screen**:
   - Verify recommendation shelves ("Jump Back In", "Daily Mix", "Trending", "Top Charts").
   - Scroll horizontally across track cards.
   - Tap 3-dots overflow menu on a card: verify "Play next", "Add to queue", "Add to playlist", "Like".
4. **Search Screen**:
   - Type a query (e.g. "Arijit"). Verify 300ms debouncing and search intent badge.
   - Tap a track: verify it plays immediately and queues the remaining results in the mini player.
   - Clear query: verify Recent Searches list appears with query text, individual delete buttons, and "Clear all".
5. **Mini Player & Queue**:
   - Verify docked mini player displays squircle cover art, title, artist, minimal `BitrateBadge` (e.g. "320 kbps AAC"), and animated squiggly progress line.
   - Tap Play/Pause and Next buttons; verify smooth playback transition.
   - Let a track end: verify `QueueManager` auto-advances to the next queued track.
   - Tap the mini player card: verify snackbar displays "Now Playing full screen arrives in M3c".
6. **Library Screen**:
   - Verify Smart Playlist cards ("On Repeat", "Most Played", "Forgotten Favorites"). Tap one to inspect tracks.
   - Tap "New Playlist" button: create a playlist, tap overflow to rename or delete.
   - Tap Spotify import icon: enter a playlist URL or ID and test keyless import.
7. **Settings Screen**:
   - Switch stream quality preset between High (320k), Med (160k), Low (96k).
   - Toggle Incognito Mode: verify snackbar confirmation and that searches/history are paused.
   - Tap "Diagnostics": verify live playback logs, host, bitrate, and JankStats.
   - Tap "Component Gallery": verify M3a components remain intact.
