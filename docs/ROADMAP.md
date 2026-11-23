# Softify Milestone Roadmap

## Completed Milestones
- **M1: Audio Core & Multi-Source Resolvers**
  - High-fidelity stream resolution (Saavn 320 kbps AAC primary, YouTube 128 kbps Opus/AAC fallback).
  - DES media URL decryption, phonetic simplification, Honest Bitrate Marking.
  - UniFFI bridge between Rust core (`softify_core`) and Kotlin Multiplatform.
- **M2: Audio Engine Stabilization & Playback Lifecycle**
  - Android 15 ExoPlayer integration via Media3 `MediaSessionService`.
  - Bounded 1 MB chunk streaming for YouTube googlevideo URLs (HTTP 403 prevention).
  - Background playback, persistent notification, and in-app diagnostics.
- **M3a / M3a2: Design System Foundation (Metrolist Material 3 Expressive)**
  - Dynamic HCT color palette extraction.
  - Squircle containers and card shapes (scalloped shapes completely purged).
  - Minimal quiet `BitrateBadge` (rounded pill, lowercase "fallback", amber indicator).
  - Full emoji/pictograph ban enforced by unit test (`NoEmojiTest`).
  - Synced sweep lyrics rendering engine (`LyricsView`).
  - Isolated Component Gallery for visual inspection.

- **M3b: Metrolist Material 3 Expressive Core Screens**
  - Bottom navigation bar: Home, Search, Library.
  - Mini Player docked above navigation bar with lazy queue auto-advance.
  - Home explore shelves from Rust core ("Jump Back In", "Daily Mix", "Trending", "Top Charts").
  - Search with 300ms debounce, instant FTS5 + online results, recent search history, and tap-to-queue-rest.
  - Library with Smart Playlists ("On Repeat", "Most Played", "Forgotten Favorites"), custom playlists, Spotify import, and Liked Songs.
  - Settings screen with quality presets, Incognito mode toggle, and links to Diagnostics and Gallery.
  - Cloud CI APK assembly on GitHub Actions.

- **M3c: Player Experience & Detail Screens (Metrolist Material 3 Expressive)**
  - Fullscreen Now Playing screen: large squircle artwork (`SquircleShape(32.dp)`), squiggly progress/seek bar (`SquigglySlider`) with real-time scrub, play/pause/next/previous, repeat (OFF/ALL/ONE) + shuffle, and minimal bitrate pill (`BitrateBadge`).
  - Container-transform spring slide-up animation expanding from `MiniPlayer`, swipe-down gesture or top chevron to collapse.
  - Queue Bottom Sheet: current track highlight, upcoming tracks, reorder (`move`), remove, and visual "Play Next" chip badge distinction.
  - LRCLIB Synced Lyrics: real-time timestamp sync, active line highlight with subtle shine sweep effect (`LyricsView`), tap a line to seek, plain-text fallback, and graceful instrumental state.
  - Artist & Album Detail Screens: hero cover art, play/shuffle all, numbered track rows, reachable from track rows overflow and Now Playing header links.
  - Zero emojis across UI (`NoEmojiTest` compliant), minimal bitrate badge, no scalloped shapes.

- **M3d: Radio Queue, Local Recommendations, & 60 fps Synced Lyrics**
  - Radio queue engine: dynamically builds queue from YouTube Music `next`/radio endpoint for any tapped track (search, library, home shelves, or "Start radio").
  - Infinite playback continuation: automatically triggers next batch fetch when upcoming tracks drop below 5 tracks.
  - Local SQLite re-ranking: scores candidate tracks using completed plays (+1.5), skips (-2.0), liked bonus (+2.5), artist affinity (+0.8/-1.0), and dedupes against last 10 played tracks.
  - "Quick picks" shelf on Home: personalized recommendations respecting max 2 tracks per artist diversity invariant.
  - 60 fps lyrics performance: draw-phase-only position reading (`drawWithContent`), `derivedStateOf` active line indexing, stable LazyColumn keys, and debounced smooth auto-scroll.
  - Synced lyrics rendering: real-time timestamp sync, active line highlight, tap word or line to seek.
  - Zero emojis across UI (`NoEmojiTest` compliant), minimal bitrate badge, squircle design system.

- **M4: Offline Downloads, Storage Access Framework, & Offline Playback**
  - Settings download storage card with SAF tree URI picker (`ACTION_OPEN_DOCUMENT_TREE`), persistable URI permissions, and default app external storage fallback.
  - WorkManager `CoroutineWorker` (`DownloadWorker`) with foreground service notification (`dataSync`), max concurrent queue (1-3), pause/resume/cancel/retry with exponential backoff, Wi-Fi only mode.
  - Resumable streaming directly to `.part` file with 64 KB buffer, HTTP Range (206) support, size verification, and atomic rename.
  - Automatic stream URL re-resolution on HTTP 403 / 410.
  - Native stream preservation (AAC/M4A up to 320 kbps, Opus up to 160 kbps, no transcoding/upscaling) and honest bitrate recording.
  - Lossless metadata tagging (title, artist, album, year, embedded cover art) via Rust `lofty` with 0 byte APK growth.
  - Offline lyrics caching in SQLite for offline display.
  - Playback engine offline-first resolution with automatic missing file reconciliation and streaming fallback.
  - Material 3 Expressive Downloads screen: live storage capacity visualizer, active queue cards, completed tracks, single & bulk deletion, health alerts for revoked permissions or storage shortage (<50 MB).
  - Track rows & Now Playing download indicators (circular progress spinner, vector checkmark badge), "Download all" on Playlist and Album detail screens.
  - Unhidden Downloads filter chip in Library screen.

- **M4-Fix: Real-Device Bug Fixes (Home Covers, Prefetch, Offline SAF, Mid-Stream 403, LRC Burst)**
  - Home cover art fix: YouTube Music responsive list item browse parsing, removal of dead Saavn 404 CDN URLs, and SQLite `COALESCE` with `i.ytimg.com` thumbnail fallbacks.
  - Prefetch throttling: bounded queue prefetch to next 5 tracks, OkHttp connection bounds, and prefetch cancellation on track skip.
  - SAF offline playback: `DefaultDataSource.Factory` wrapping in ExoPlayer for `content://` and `file://` playback, and cache staging file tagging before moving to SAF storage.
  - Mid-stream 403 recovery: `BoundedHttpDataSource` error propagation and automatic silent stream re-resolution from `lastPlaybackPositionMs`.
  - LRC burst rejection: multi-tag parsing, centisecond fraction normalization, and corrupt tight-burst timestamp rejection falling back cleanly to unsynced plain text.

- **M5: Lyrics & Art Pipeline (from Metrolist REA Analysis)**
  - Canonical nested lyrics data model (`LyricLine -> Vec<LyricWord>`) eliminating synthetic character-proportional word timing.
  - Multi-provider keyless lyrics pipeline in Rust core: BetterLyrics (Apple Music TTML), lrc.red, Unison, Paxsenix, YouTube Captions (json3), KuGou, and LRCLIB with 7-day negative caching.
  - 4-stop linear gradient shader word highlight rendering in Compose with smooth inter-word transitions.
  - Coil 3 image pipeline with 250 MB disk cache, negative cache suppression for 404s, and bucketed cover resolution.

- **M5-Fix: Real Data Parsers, Layout Measurement, & Headless Verification**
  - Real TTML and LRCLIB response test fixtures with preserved whitespace and span word segmentation.
  - Finite `maxWidth` TextMeasurer layout avoiding word truncation, overlapping lines, and scale layout shifts.
  - 60 fps frame clock with debounced smooth scrolling.
  - Fully headless cloud CI test verification.

## In Progress Milestones
- **M4b: ReplayGain & Loudness Normalization**
  - Priority loudness extraction: ReplayGain tags in local files, YouTube player response `loudnessDb` / `perceptualLoudnessDb`, and unnormalized fallback.
  - SQLite loudness metadata storage and migration.
  - Configurable target level (default -14 LUFS), attenuate-only mode by default, and optional `LoudnessEnhancer` boost with peak limiting.
  - Smooth 100-200 ms volume transitions composed with sleep timer / crossfade multipliers.
  - Real-time loudness diagnostics in in-app Diagnostics screen.

- **M4c: Gapless Playback & Dual-Player Crossfade**
  - ExoPlayer timeline pre-buffering for gapless playback of consecutive tracks with queue-synchronous pre-resolution.
  - Dual-player forwarding architecture (`CrossfadePlayerManager`) for equal-power crossfade (0-12s configurable slider).
  - Album track preservation (disabling crossfade on consecutive album tracks), manual skip fade (300ms), and mid-fade pause/resume synchronization.
  - Crossfade state machine and diagnostics telemetry.

## Upcoming Milestones
- **M6: Core Ergonomics & Release Hardening**
  - Session restore across app restarts.
  - Sleep timer with smooth volume fade-out.
  - Search UX improvements and filter chips.
  - Library backup and restore (JSON / OPML).
  - In-app log viewer and diagnostics export.
  - R8 full release build optimization with ProGuard rules.
- **Updater & Signing Automation**
  - In-app update checker against GitHub Releases.
  - Production release keystore signing workflow.
- **Remote Configuration & Backend Sync**
  - Dynamic provider endpoints and killswitches.
  - Optional multi-device listen together sync backend.
