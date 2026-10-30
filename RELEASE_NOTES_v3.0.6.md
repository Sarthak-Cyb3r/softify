# Softify v3.0.6: Official Stable Release 🚀

Welcome to **Softify v3.0.6**! This release addresses critical playback reliability, lyrics engine concurrency, audio focus coordination during DJ crossfading, Listen Together multi-device synchronization, and CI pipeline fixes.

---

## 🎧 DJ Crossfade & Dual-Engine Audio Focus Architecture

### ExoPlayer Dual-Instance Audio Focus Decoupling
- **Root Cause Resolution**: Resolved an Android-level audio focus collision where ExoPlayer instances (Player A and Player B) in `JustAudioPlayerAdapter` fought for exclusive OS audio focus during crossfade overlap windows, causing ExoPlayer A to immediately pause or mute when ExoPlayer B started.
- **Centralized Session Management**: Disabled internal ExoPlayer audio session activation and interruption handling (`handleAudioSessionActivation: false`, `handleInterruptions: false`) on both primary and secondary players. Audio focus is now centrally managed by `SoftifyAudioHandler`.
- **Generation-Tracked Transitions**: Added `_crossfadeGenerationId` and atomic `_isCrossfading` locks in `SoftifyAudioPlayer` to prevent transition collisions or stranded volume attenuation during rapid track skipping.
- **Standby Isolation**: Guarded standby player prefetching against colliding with active crossfade sequences.

---

## 📱 Android Autoplay & Playback Resilience (Moto g34 5G)

### Low-Latency Buffer & Watchdog Auto-Recovery
- **Eliminated Autoplay Freezes**: Fixed an issue on Motorola (e.g. Moto g34 5G) and budget Android devices where autoplaying continuous tracks would stall with a stuck loading spinner.
- **250ms Initial Buffer Tuning**: Calibrated initial playback buffer thresholds to eliminate unneeded buffering delays before playback begins.
- **10-Second Watchdog Recovery**: Implemented an automated watchdog in `JustAudioPlayerAdapter` that detects stranded loading states and automatically re-triggers buffering or seamless track cutover.
- **Standby Session Safety**: Hardened standby player lifecycle cleanup to prevent audio session leaks.

---

## 📜 Lyrics Engine Concurrency & Screensaver Synchronization

### Non-Blocking Parallel Resolution & Negative Caching
- **Eliminated Permanent Loading State**: Fixed a condition where lyrics remained in an infinite loading state following track transitions in both the standard lyrics screen and Screensaver mode.
- **In-Flight Deduplication**: Implemented `_inFlight` Future memoization in `CompositeLyricsProvider` so overlapping requests for the same track ID join an existing retrieval pipeline rather than spawning duplicate queries.
- **SQLite & In-Memory Negative Caching**: Added persistent negative caching (`isNotFound: true`) to avoid repeated network round-trips for tracks known to lack synchronized lyrics.
- **3-4s Stream Timeout Barriers**: Enforced strict timeout barriers on HTTP response body stream joins across all 7 provider backends (Curated, Spotify, LRCLIB, JioSaavn, NetEase, Kugou, Genius) to prevent zombie socket hangs.
- **Screensaver Viewport Reset**: Added `ValueKey` widget tree isolation and explicit scroll/line key resets in `music_screensaver_screen.dart` and `lyrics_view.dart`, ensuring immediate reactive updates when the active track changes.

---

## 👥 Listen Together & UI Layout Fixes

### Multi-Device Wire Protocol & Mini-Player Clearance
- **Host-to-Guest Playback Synchronization**: Fixed the protocol message dispatch so song updates broadcast by the room host reliably trigger stream resolution and playback on all connected peer devices.
- **Mini-Player Bar Clearance**: Adjusted bottom padding and scroll physics on the Listen Together join sheet, preventing the persistent mini-player bar from occluding the "Join Room" button.

---

## 🛠️ CI/CD Quality Verification & Fleet Administration

### Test Suite & Release Pipelines
- **iOS CI Analyzer Compliance**: Added missing concrete implementations of `@override Duration? get duration` across all test mocks (`test/concurrency_and_isolation_test.dart`, `test/features/equalizer/equalizer_test.dart`, `test/playback_performance_matrix_test.dart`, `test/sleep_timer_test.dart`, `test/softify_audio_handler_test.dart`), unblocking the iOS release pipeline.
- **Analyzer Cleanup**: Removed redundant non-null assertions in `test/listen_together_test.dart`.
- **Fleet Controller & Admin Dashboard**: Synchronized target release version and minimum client requirements to `v3.0.6` in `server/server.js`, `server/public/index.html`, and `lib/presentation/providers/settings_providers.dart`.

---

## 📦 Release Artifacts & Checksums

- **Version**: `3.0.6+234`
- **Git Tag**: `v3.0.6`
- **Target Channels**: Android (APK/AAB), Linux Desktop, iOS, Admin Fleet
