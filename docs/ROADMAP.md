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

## Current Milestone
- **M3b: Metrolist Material 3 Expressive Core Screens**
  - Bottom navigation bar: Home, Search, Library.
  - Mini Player docked above navigation bar with lazy queue auto-advance.
  - Home explore shelves from Rust core ("Jump Back In", "Daily Mix", "Trending", "Top Charts").
  - Search with 300ms debounce, instant FTS5 + online results, recent search history, and tap-to-queue-rest.
  - Library with Smart Playlists ("On Repeat", "Most Played", "Forgotten Favorites"), custom playlists, Spotify import, and Liked Songs.
  - Settings screen with quality presets, Incognito mode toggle, and links to Diagnostics and Gallery.
  - Cloud CI APK assembly on GitHub Actions.

## Upcoming Milestones
- **M3c: Full Now Playing Screen & Apple Music Liquid UI**
  - Fullscreen Now Playing with hero cover art, fluid spring controls, and LRCLIB synchronized lyrics.
  - Queue management bottom sheet with drag-and-drop reordering.
  - Dual UI switcher toggle for Apple Music Liquid theme.
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
