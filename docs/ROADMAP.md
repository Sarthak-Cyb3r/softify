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

## Current Milestone
- **M3d: Radio Queue, Local Recommendations, & 60 fps Word-by-Word Lyrics**
  - Radio queue engine: dynamically builds queue from YouTube Music `next`/radio endpoint for any tapped track (search, library, home shelves, or "Start radio").
  - Infinite playback continuation: automatically triggers next batch fetch when upcoming tracks drop below 5 tracks.
  - Local SQLite re-ranking: scores candidate tracks using completed plays (+1.5), skips (-2.0), liked bonus (+2.5), artist affinity (+0.8/-1.0), and dedupes against last 10 played tracks.
  - "Quick picks" shelf on Home: personalized recommendations respecting max 2 tracks per artist diversity invariant.
  - 60 fps lyrics performance: draw-phase-only position reading (`drawWithContent`), `derivedStateOf` active line indexing, stable LazyColumn keys, and debounced smooth auto-scroll.
  - Word-by-word lyrics: LRCLIB `hasWordSync` / enhanced LRC parsing, character-count proportional word duration estimation fallback, word highlight and sweep fill, tap word or line to seek.
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
  - Pure logic unit tests with fakes, MockWebServer HTTP tests, and headless 360dp render verification screenshots.

## Upcoming Milestones
- **M4b: ReplayGain & Loudness Normalization**
  - EBU R128 loudness scanning and gain adjustment.
- **M4c: Gapless Playback & Crossfade**
  - Seamless buffer preloading for consecutive tracks.
