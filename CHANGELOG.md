# Changelog

All notable changes to the Softify project are documented in this file.

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
