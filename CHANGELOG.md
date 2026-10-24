# Changelog

All notable changes to the Softify project are documented in this file.

## [3.0.1] - 2026-10-24

### 💎 Comprehensive Glassmorphism Overhaul (UI UX Pro MAX Standard)
- **App-Wide Authentic Frosted Glass**: Refactored every major surface, card, and interactive control in Softify to render with authentic, high-depth frosted glassmorphism according to `UI UX Pro MAX` design principles:
  - **Quad-Node Vibrant Aurora Backdrop**: Upgraded `AuroraBackground` with a 4-point dynamic mesh (dominant artwork aura 0.50 alpha, electric cyan 0.38 alpha, aurora violet 0.35 alpha, and radiant rose 0.28 alpha) delivering luminous chromatic backlight across all glass layers.
  - **Backdrop Blur & Dual Bloom Shadows**: Standardized `AppSurface` with hardware-accelerated `BackdropFilter` (sigma 16.0), top-left to bottom-right specular linear gradients (`rgba(255, 255, 255, 0.18)` down to `0.08`), 1px specular hairline borders (`rgba(255, 255, 255, 0.24)`), and ethereal ambient violet/black dual drop shadows.
  - **Default Theme Setting**: Updated initial launch style default to `UiStyle.auroraGlass` so every user experiences the new modern glassmorphism aesthetic out of the box without requiring manual configuration.
- **Screen & Component Coverage**:
  - **Settings Screen**: Converted all 8 preference sections (Profile, Appearance, Playback, Lyrics, Screensaver, Fallbacks, Storage, Security & About) from flat solid tiles to frosted `AppSurface` glass cards.
  - **Full-Screen Player**: Enclosed back/dismiss chevrons, speed selectors, lyrics pills, and skip controls in frosted circular glass capsules with glowing violet playback hubs.
  - **Lyrics Deck**: Upgraded `LyricsView` container with frosted blur (sigma 16.0) over album color gradients.
  - **Search & YouTube / Podcast Link Inputs**: Transformed query text fields into frosted glass pills with cyan focus accents, and upgraded top result, discography, and ready state cards to frosted glass surfaces.
  - **Library & Smart Bento Cards**: Converted Liked Songs, Downloads storage bars, playlist tiles, and library smart cards to frosted glass containers.
  - **Dialogs & Action Sheets**: Converted `AppDialog` and `QueueBottomSheet` to frosted glass surfaces with specular borders.
  - **Buttons & Chips**: Filter chips and `AppPillButton` primary actions now feature smooth cyan-to-violet aurora gradient fills with glowing drop shadows.
- **Performance & 60fps Optimization**:
  - Isolated all blurred surfaces in individual `RepaintBoundary` layers.
  - Preserved list view scrolling performance on large libraries with lightweight specular gradients.
  - Verified low-end device fallback (`shouldReduceEffectsProvider`) seamlessly switches from blur to translucent solid fills on constrained hardware.

## [3.0.0] - 2026-10-23

### 🌌 Major Milestone: Aurora Glass UI Experience (Pre-Release)
- **Selectable Aurora Glass Design System**: Introduced Softify's second selectable visual interface alongside the authentic Spotify "Classic" theme. Features deep midnight backdrop (`#0B0B1A` to `#14122B`), vibrant aurora accents (violet `#7C5CFF`, cyan `#4FD1FF`, rose `#FF7AC6`), 20–28px rounded glass cards, and 1px 18% translucent borders.
- **Dynamic Track-Palette Wallpaper**: `AuroraBackground` extracts and LRU-caches dominant colors directly from currently playing album art, generating dynamic ambient gradients that smoothly transition per track with fallback to aurora violet.
- **Instant Reactive Switching**: Change themes on the fly in **Settings → Appearance** with interactive live preview cards. Switching styles is instantaneous via Riverpod `uiStyleProvider` with zero audio interruption, zero route popping, and full SQLite persistence across app restarts.
- **Strict Performance Guardrails (60fps on Budget Hardware)**:
  - Confined `BackdropFilter` exclusively to static chrome surfaces (`MiniPlayer`, `SlimBottomNavBar`, desktop player/sidebar, modal sheets), completely isolating them inside `RepaintBoundary`.
  - Prohibited heavy Gaussian blurs inside scrollable lists and grids—scrolling rows use optimized zero-blur translucent gradients with hairline borders.
  - Added a 3-way **Reduce effects** selector (**Auto / On / Off**) and automated low-end hardware detection (≤4 CPU cores) that drops blurs in favor of translucent solid fills.
- **Universal Shell Coverage**: Cohesive styling extended across Mobile and Linux Desktop shells, including Home, Search, Your Library, YouTube Link Player, Podcasts, Equalizer, Album, and Playlist details.
- **WCAG AA Compliance**: Silvery lavender secondary text (`#C4C2E2`) and contrast scrims guarantee compliant contrast ratios (>4.5:1 on glass surfaces and >15:1 against deep midnight backgrounds).

## [2.9.9] - 2026-10-23

### 🛠️ Critical Hotfix: Update Checker & Lyrics Real-Time Sync
- **Resolved False Update Notification Loop**: Fixed a hardcoded `kAppVersion` constant (`'2.9.7'`) in `settings_providers.dart` that caused updated devices on v2.9.8 to continuously report an update was available. Version is now synchronized with `pubspec.yaml` to `2.9.9+226`.
- **Eliminated Compounded Lyrics Offset Drift**: Discovered and eliminated a critical bug where latency compensation (`_baseLeadMs`) and user offsets (`_syncOffsetMs`) were compounded up to 3 times across `_ticker`, `positionStreamProvider`, and widget `build()`, jumping lyrics 560ms–840ms ahead of vocal playback. Extrapolation is now calculated strictly once from the audio player reference clock.
- **Removed Deadzone Scroll Suppression**: Removed an 80% viewport deadzone check (`isInAutoScrollZone`) in `_scrollToActiveLine` that was inadvertently locking the scroll view and preventing active lines from auto-scrolling into view as the song played. Lyrics now smoothly center at the golden focal line (`alignment: 0.35`) with post-frame layout retry.
- **Resilient Multi-Format LRC Parsing**: Enhanced `LrclibLyricsProvider.parseLrc` to support single-digit minutes (`[1:05.20]`), colon subsecond separators (`[01:05:20]`), variable fraction lengths (`[01:05.2]`, `[01:05.250]`), multiple timestamp tags per line (`[00:10.00][00:25.00]`), and global header tags (`[offset:+/-ms]`).

## [2.9.8] - 2026-10-23

### 🎵 Reverse-Engineered Spotify Color-Lyrics v2 & Global Fallback
- **Spotify Color-Lyrics v2 Integration**: Reverse-engineered Spotify's internal color-lyrics endpoint with syllable-level word timings and complementary album palette extraction.
- **8-Tier Resilient Lyrics Architecture**: Curated Studio Master (Tier 0) ➔ Spotify Direct ➔ LRCLIB ➔ NetEase Cloud Music ➔ Kugou ➔ JioSaavn ➔ Genius Plain Text Fallback.
- **Performance & Reliability Audit Implementations**: Closed resource leaks, optimized drift query bounds, memoized catalog shelf decoders, and reduced memory footprint.

## [2.9.7] - 2026-10-23

### 🚀 Performance & Instant Track Skipping
- **Eliminated Track Skip Delay**: Resolved the architectural bottleneck where manual track skipping took 3-4 seconds before the next track started playing.
- **In-Flight Request Deduplication**: Implemented `_inFlight` Future join mapping in `HybridStreamResolver`. When skipping to an upcoming track that is already being prefetched in the background, the resolver joins the existing network task rather than firing duplicate 2-3s API queries.
- **Multi-Track Lookahead Pre-Resolution**: Extended queue prefetching into a speculative lookahead window that pre-resolves direct CDN stream URLs for tracks N+1, N+2, and N+3 concurrently into memory cache upon queue load and track changes.
- **Non-Blocking Asynchronous Cutover**: Optimized `playPreloadedNext` in `JustAudioPlayerAdapter` to cut over to the standby player in < 15ms at full volume. Equal-power crossfade attenuation loops now run asynchronously in the background rather than blocking the main player thread.
- **Linux Desktop Standby Pre-Warming**: Added dynamic lazy standby player allocation on Linux Desktop (`_getStandbyPlayer`), giving Linux users the exact same hardware-buffered 0ms instant track transitions as Android and iOS.

### 🎵 Lyrics Engine & Synchronization Overhaul
- **Curated Studio Master Sync ("Maine Khud Ko")**: Added verified, millisecond-accurate synchronized lyrics in `CuratedLyricsProvider` (Tier 0 Gold Standard) for Mustafa Zahid's "Maine Khud Ko" (*Ragini MMS 2*).
- **Hardened Scraper Title Verification**: Fixed a blind duration-matching bug in Kugou, NetEase, and LRCLIB lyrics providers where songs by the same artist with similar durations (e.g. "Gunaah") were incorrectly selected. Added strict token-based title validation (`_isTitleMatch`).
- **GPU & Resource Optimization**:
  - Eliminated GPU-intensive `ShaderMask` layers on scrolling lyrics in favor of lightweight linear opacity gradients.
  - Stripped CPU/GPU-taxing Gaussian blur text shadows from lyric render passes.
  - Deduplicated scroll physics and isolated player state rebuilds from the lyrics list view for smooth 60fps scrolling with minimal resource utilization.

### 🎨 UI & UX Polish
- **Album & Playlist Track Wave Desync Fix**: Resolved a state bug where the animated music wave indicator stayed stuck on the previously played track when tapping a new song in `AlbumDetailScreen`, `PlaylistDetailScreen`, `ArtistDetailScreen`, and `TracksListScreen`. Rows now reactively track `currentTrackProvider` and `isPlayingProvider`.
- **Zero-Badge Clean Design**: Enforced clean, unadorned Spotify Encore interface aesthetics across all screens with zero artificial badges.
- **320 kbps Studio Master Invariant**: Preserved strict 320 kbps bit-exact audio pipeline across JioSaavn and YouTube Explode resolvers.

## [2.9.6] - 2026-10-22
- Curated synced lyrics provider for studio master releases.
- Hardened lyrics scraping title filters.
- Fixed reactive track wave equalizer desynchronization across album and playlist views.

## [2.9.5] - 2026-10-22
- Overhauled lyrics rendering performance: eliminated GPU `ShaderMask` and blurred shadows for ultra-smooth 60fps scrolling and lowest battery/GPU consumption.

## [2.9.4] - 2026-10-21
- Integrated Spotify Kernel reverse-engineered subsystems.
- Removed all badges across UI components.
- Preserved strict 320 kbps bit-exact audio streaming.
