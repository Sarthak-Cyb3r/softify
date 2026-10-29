# Softify v3.0.5: Official Stable Release 🚀

Welcome to **Softify v3.0.5**! This release delivers critical improvements across the audio engine, backend infrastructure, and user interface. It introduces an adaptive launcher icon architecture for modern Android devices, equal-power DJ Crossfade restoration, a persistent Listen Together room database with a high-speed admin fleet dashboard, Spotify playlist sync deduplication, UI decluttering, and a completely responsive redesign of the Screensaver mode.

---

## 🎨 Android Launcher Icons, Branding & Splash

### Adaptive Launcher Icon System (Android 8.0+ / Moto g34 5G Fix)
- **Eliminated White Background Box**: Fixed the display bug on Motorola (Moto g34 5G), Google Pixel, and other Android 12+ launchers where the app icon was enclosed in an awkward white square box.
- **Adaptive Icon XML Architecture**: Implemented `res/mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml` pairing a pure `#000000` background (`@color/ic_launcher_background` in `res/values/colors.xml`) with high-resolution vector and raster foreground layers.
- **Multi-Density Icon Assets**: Generated and integrated calibrated foreground and rounded launcher icons (`ic_launcher_foreground.png` and `ic_launcher_round.png`) across all density buckets: `mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, and `xxxhdpi`.
- **Rounded Squircle Branding Assets**: Updated `assets/logo/logo.png`, `assets/logo/logo.jpg`, and the web administration logo `server/public/logo.png` with smooth rounded squircle corners.
- **Android 12+ Splash Theme Hardening**: Configured `android:windowSplashScreenIconBackgroundColor` to `@color/ic_launcher_background` in `res/values-v31/styles.xml` to prevent any white screen flashes during cold launches.

---

## 🎧 DJ Crossfade & Audio Engine Hardening

### Restored & Responsive DJ Crossfade Transitions
- **Startup Settings Restoration**: Fixed an issue where the user's configured crossfade duration was not being applied upon app restart. Now automatically queried from the Drift database (`crossfade_duration`) and injected directly into `SoftifyAudioHandler` on application boot in `lib/main.dart`.
- **Dynamic Stream Duration Resolution**: Dynamically queries `_player.duration ?? currentTrack?.duration` to guarantee millisecond-level precision when calculating transition cutover points.
- **Speculative Buffer Pre-Warming**: Increased pre-fetch lead time to `max(25, _crossfadeSeconds + 10)` seconds to ensure the upcoming audio stream is fully buffered and ready before the crossfade begins.
- **Relaxed Player State Gate**: Updated `JustAudioPlayerAdapter` crossfade activation criteria from requiring strict `ProcessingState.ready` to `processingState != ProcessingState.idle`, preventing YouTube audio streams from dropping back to hard cutovers.
- **YouTube Audio Stream Support**: Removed the `supportsSpeedPlayback` check that inadvertently blocked crossfading on streams sourced from YouTube InnerTube.
- **Intelligent Spoken Word Bypass**: Podcasts and spoken-word audio tracks (prefixed with `podcast_`) automatically bypass crossfading with a 0ms cutover to preserve dialogue clarity.

---

## 🌐 Listen Together Backend & High-Performance Admin Fleet

### Persistent Room Database Ledger
- **File-Backed Persistence**: Integrated `server/data/rooms.json` database store with automatic directory creation and debounced asynchronous cloud synchronization (`scheduleCloudSync()`) to GitHub Gists.
- **Comprehensive Room Telemetry**: Tracks room code, host user ID, host username, host device model, client IP, active user count, peak user count, total songs played, and a complete chronological song history ledger with timestamps.
- **Client REST Lifecycle Endpoints**:
  - `POST /api/rooms/create`: Host creates or re-registers a room with device metadata.
  - `POST /api/rooms/join`: Participant joins room; updates active participant list and peak user stats.
  - `POST /api/rooms/leave`: Participant departs room; updates active user count.
  - `POST /api/rooms/song-played`: Appends full song details (title, artist, album, duration, sourceId) to the room ledger.
  - `POST /api/rooms/heartbeat`: Keeps room alive and synchronizes active user counts and playback position.
  - `POST /api/rooms/close`: Cleanly closes room when host leaves.
  - `GET /api/rooms/active`: Fetches currently open public/shared rooms.
  - `GET /api/rooms/:roomCode`: Queries individual room details and playback status.

### Ultra-Fast Admin Dashboard (<5ms Responses)
- **In-Memory Cache TTL**: Added a 60-second in-memory cache TTL for store lookups, reducing admin API endpoint latency from >1.5s down to <5ms.
- **New Admin Fleet Rooms Tab**: Added a dedicated "Listen Together Rooms" view in `server/public/index.html` featuring:
  - Live summary KPI cards: Total Rooms, Currently Active, Peak Concurrent Users, Total Songs Played.
  - Real-time search by room code or host name.
  - Status filters (`All`, `Active`, `Closed`).
  - Detailed modal viewer displaying participant logs and song playback history.
  - Admin remote room termination (`POST /api/admin/rooms/:roomCode/close`).
  - Admin permanent room purge (`DELETE /api/admin/rooms/:roomCode`).
- **Client App Service Sync**: Updated `ListenTogetherService` and `ListenTogetherProtocol` to communicate with the backend room ledger in the background without affecting audio sync accuracy.

---

## 🔄 Spotify Playlist Import & Auto-Sync Deduplication

### Intelligent Track Signature Matching
- **Duplicate Track Rejection**: Fixed an issue where auto-updating Spotify playlists continually added duplicate songs even when no new tracks had been added to the Spotify playlist.
- **Fuzzy Signature Comparison**: Normalizes song titles and artist names (stripping punctuation, casing, remaster tags, and featured artist suffixes) to detect duplicates before fetching audio streams.
- **Database-Level Stream Protection**: Added `playlistHasTrackBySourceId` method to `ILibraryRepository` and `DriftLibraryRepository` to prevent identical YouTube audio sources from being inserted into the same playlist multiple times.
- **Metadata Fidelity**: Preserves original Spotify track titles, artist credits, album names, and artwork while attaching the resolved audio stream.

---

## 🧹 UI Decluttering & Redundant Control Pruning

### Streamlined Single-Control Ergonomics
- **Playlist Detail Screen**: Removed duplicate top AppBar action buttons that duplicated primary header controls (Sync with Spotify, Play All, and Duplicate Playlist). Header buttons and the unified three-dot menu now serve as single points of control.
- **Album Detail Screen**: Removed duplicate floating play buttons and cleaned up redundant action bars.
- **Full-Screen Player Screen**: Tightened layout padding and removed redundant secondary action triggers.
- **Library Screen**: Consolidated playlist and library creation controls into a single clear action path.
- **Desktop Sidebar**: Cleaned up navigation items and removed duplicate action shortcuts.

### Music Identifier & Quick Panel Removal
- **Removed Fake Music Identifier**: Cleaned up non-functional placeholder "Identify Music" floating action button and search bar microphone trigger from `search_screen.dart` and `app_scaffold.dart`.
- **Removed Top Quick Playback Panel**: Deleted top-edge swipe-down trigger handle and `lib/presentation/widgets/quick_playback_panel.dart` to avoid accidental gesture triggers during system navigation and notification shade pulls.

---

## 🌌 Screensaver Mode Responsive Redesign

### Complete Visual & Ergonomic Alignment
- **Fixed Mobile Layout Breakage**: Eliminated `RenderFlex` overflow errors caused by rigid side-by-side splits on vertical mobile screens.
- **Adaptive Responsive Layout**:
  - **Mobile Portrait**: Dynamically transitions into an elegant centered vertical deck with auto-scaled artwork (140dp–260dp), compact typography, centered playback transport controls, and scaled lyric heights.
  - **Landscape & Desktop**: Preserves expansive 40/60 split deck with giant synchronized lyrics and left-docked album artwork and playback controls.
- **Auto-Hiding HUD**: Header clock, battery/status bar, and exit controls smoothly fade out after 4 seconds of inactivity and re-appear on any tap.
- **Ambient Dynamic Glow**: Enhanced backdrop blur and dynamic seed color extraction to cast soft ambient light around album art and lyrics.
- **Studio Master Fallback**: Designed a sleek, non-intrusive pill indicator when playing instrumental or studio master audio without available lyrics.

---

## 📦 Versioning & Build Details

- **Version**: `3.0.5+233`
- **Minimum Android Version**: Android 8.0 (API Level 26)
- **Target Platform**: Android ARM64 (`android-arm64`), Linux x64
- **Release Verification**: Fully passes static AST syntax analysis, Drift database generation, and automated test suite.
