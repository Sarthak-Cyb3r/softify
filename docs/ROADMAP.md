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

## Current Milestone
- **M3c: Player Experience & Detail Screens (Metrolist Material 3 Expressive)**
  - Fullscreen Now Playing screen: large squircle artwork (`SquircleShape(32.dp)`), squiggly progress/seek bar (`SquigglySlider`) with real-time scrub, play/pause/next/previous, repeat (OFF/ALL/ONE) + shuffle, and minimal bitrate pill (`BitrateBadge`).
  - Container-transform spring slide-up animation expanding from `MiniPlayer`, swipe-down gesture or top chevron to collapse.
  - Queue Bottom Sheet: current track highlight, upcoming tracks, reorder (`move`), remove, and visual "Play Next" chip badge distinction.
  - LRCLIB Synced Lyrics: real-time timestamp sync, active line highlight with subtle shine sweep effect (`LyricsView`), tap a line to seek, plain-text fallback, and graceful instrumental state.
  - Artist & Album Detail Screens: hero cover art, play/shuffle all, numbered track rows, reachable from track rows overflow and Now Playing header links.
  - Zero emojis across UI (`NoEmojiTest` compliant), minimal bitrate badge, no scalloped shapes.

## Upcoming Milestones
- **M4: Offline Downloads & Audio Quality Suite**
  - **M4a: Background Download Worker + Progress Notification**
    - Android `WorkManager` background download orchestration.
    - Resumable range chunk downloads with system progress notification.
    - Atomic file rename and Lofty M4A/Opus metadata and cover art tagging.
    - Offline playback resolver prioritizing downloaded local storage over remote CDN.
    - Downloads filter chip enabled in Library screen.
  - **M4b: ReplayGain & Loudness Normalization**
    - EBU R128 loudness scanning and gain adjustment.
  - **M4c: Gapless Playback & Crossfade**
    - Seamless buffer preloading for consecutive tracks.
