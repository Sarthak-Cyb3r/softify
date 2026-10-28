# Softify v3.0.4: Official Stable Release 🚀

Welcome to **Softify v3.0.4**, our largest and most comprehensive release to date! This update brings a complete Metrolist-inspired design overhaul, word-to-word & line-by-line progressive synced lyrics, acoustic music recognition, automatic Spotify playlist sync, major audio DSP & streaming enhancements, and full fleet management controls.

---

## 🎨 Frontend & Design System (Metrolist Precision & M3 Expressive)

### Material You Monet Dynamic Theming
- **Dynamic Artwork Palette Extraction**: Integrated `DynamicThemeNotifier` with LRU cache to dynamically sample seed colors from current album art and generate high-fidelity tonal color schemes (`ColorScheme.fromSeed` with `dynamicSchemeVariant: tonalSpot`).
- **Dark Surface Harmony**: Replaced hardcoded accent surfaces with song-driven dynamic tonal darks and responsive accent tints across all player surfaces, cards, and dialogs.
- **Contrast & Legibility Tuning**: Calibrated text and icon contrast ratios to maintain WCAG AAA readability against dynamic vibrant album art backgrounds.

### M3 Expressive Full-Screen Player
- **Capsule Play/Pause Container**: Redesigned Play/Pause button into a 68dp tall pill container featuring solid white background, high-contrast dark iconography, and responsive press animations.
- **68x68dp Circular Skip Buttons**: Replaced undersized controls with 68x68dp circular Previous and Next skip buttons.
- **44x44dp Squircle Action Buttons**: Redesigned Share and Favorite buttons into modern squircles with 12dp border radius.
- **Horizontal Pill Scrubber**: Clean horizontal progress slider with a vertical pill handle resting on a 4.5dp track.
- **Tight Toolbar Button Spacing**: Reduced spacing between secondary control buttons (Queue, Bedtime/Timer, Shuffle, Lyrics, Repeat) to 2.5dp for tighter, one-handed mobile ergonomics.

### Microphone Lyrics Button Standardization
- Standardized lyrics toggle icon from generic music notes to the universally recognized Spotify-style microphone icon (`Icons.mic_none_rounded` / `Icons.mic_rounded`) across:
  - Mobile Full-Screen Player
  - Desktop Playback Bar
  - Quick Playback Panel
  - Desktop Navigation Sidebar
  - Search Screen action buttons

### Mobile Splash Screen Overhaul
- **Eliminated White Screen Flash**: Fixed the Android 12+ (API 31+) splash screen bug where a small icon appeared on a stark white background.
- **Native Dark Window Style**: Configured pure `#0A0A0A` window background with centered high-resolution launcher icon in `res/values-v31/styles.xml` and `drawable/launch_background.xml`.

### Metrolist UI Precision Clone
- **Floating Concentric MiniPlayer**: Implemented concentric pill MiniPlayer with circular inner artwork, title/artist marquee, play/pause controls, and rounded linear progress bar.
- **SpeedDial Grid**: Added 4-column quick navigation grid items (`MetrolistSpeedDialItem`) on the Home screen.
- **Navigation & Headers**: Integrated `MetrolistNavigationTitle` app bars, dynamic filter chip rows (`AppFilterChip`), and redesigned track rows with duration, explicit badges, and swipe actions.
- **Vinyl TurntableView**: Playful vinyl turntable view with animated spinning record and physical tonearm needle drop/return physics.
- **WavySlider Waveform Scrubber**: Sinusoidal animated waveform scrubber that dances with playback progress.
- **Android Home Screen Turntable Widget**: Native Android AppWidget (`SoftifyTurntableWidgetProvider.kt`) providing a live spinning turntable, track metadata, and direct playback controls from the launcher.

---

## 🎤 Synchronized Lyrics & Karaoke Engine

### Word-to-Word Progressive Karaoke Synchronization
- **Spicetify-Style Progressive Wipe**: Integrated high-speed syllable-level karaoke renderer (`_SpicetifyWordWipe`) that sweeps left-to-right across active words based on millisecond timestamps.
- **Solid Pure White Typography**: Styled active lyrics in solid, vibrant pure white (`Colors.white`) with deep drop shadows for clarity over shifting background colors.

### Line-by-Line & Sub-Line Sequential Animation
- **Smart Multi-Line Splitting**: Wrapped multi-line lyrics on narrow mobile screens now split dynamically into visual sub-lines using `TextPainter.computeLineMetrics` and `getLineBoundary`.
- **Strict Sequential Reveal**: For multi-line wrapped text, sub-line 2 stays dormant until sub-line 1 finishes its progressive wipe. Sub-line 3 waits for sub-line 2, eliminating confusing overlapping animations.

### Rich Syllable, TTML & Multi-Provider Architecture
- **TTML Syllable Parser (`TtmlParser`)**: Full parser for rich Apple Music / Spotify TTML formats, background harmony vocals, and singer turn markers.
- **Duet Karaoke V2**: Dynamic singer-dependent left/right layout alignment for duet tracks.
- **Solo Countdown Lead-In**: Animated countdown dots for instrumental lead-ins and solos before vocals start.
- **Multi-Provider Fallback Registry (`LyricsProviderRegistry`)**: Integrated Paxsenix (`PaxsenixLyricsProvider`), Zemer (`ZemerLyricsProvider`), BetterLyrics (`BetterLyricsProvider`), and LRCLIB (`LrclibLyricsProvider`).
- **Multi-Language Romanization (`RomanizationService`)**: Automatic phonetic romanization for Japanese (Romaji), Korean (Revised Romanization), and Chinese (Pinyin).

---

## ⚙️ Backend & Audio Pipeline Hardening

### Now-Playing Track Synchronization
- **Fixed Stale Track Metadata**: Fixed a bug where switching songs left the player screen showing the previous track's title and artwork. Synchronized `currentTrackStream` and `mediaItem` in `player_providers.dart`.
- **Dynamic Widget Keying**: Keyed album artwork and player widgets with `ValueKey(effectiveTrack.id)` to guarantee instant widget rebuilds and eliminate Hero tag conflicts.

### Client-Side Acoustic Song Recognition (Shazam Engine)
- **Pure Shazam Fingerprint Generator**: Built pure Dart acoustic fingerprinting engine (`SongRecognitionService`, `ShazamSignatureGenerator`) that computes FFT spectrogram peaks and queries Shazam APIs directly without third-party native binaries or heavy dependencies.
- **Interactive Recognition Sheet**: Added `AcousticRecognitionSheet` with live microphone audio waveform visualization, direct match cards, and one-tap playback queuing.

### Spotify Playlist Import & Real-Time Auto-Sync
- **Spotify Logo Badging**: Added vector-painted Spotify circular green badge (`SpotifyLogoBadge`) across imported playlists in library list items, desktop grid cards, and playlist header banners.
- **Automatic Background Sync**: Built `SpotifyPlaylistSyncService` to compare remote Spotify playlists against local library entries upon opening. Automatically discovers newly added songs, resolves high-quality audio streams, and appends them atomically.
- **Manual Sync Button**: Added a dedicated "Sync with Spotify" button in the playlist header with live spinning state indicator and toast notifications.

### Settings Screen Cleanup
- **Pruned Redundant Network Tools**: Removed obsolete Piped fallback latency pinging, manual `sp_dc` cookie inputs, and proxy URL dialogs to reduce clutter and memory overhead.
- **Streamlined Navigation**: Redesigned settings into clean categories focused on audio quality, synced lyrics engine status, storage cache management, and device security.

### DSP Engine & Equalization
- **AutoEQ Headphone Correction**: Integrated `AutoEqService` with database of thousands of parametric EQ compensation profiles for popular headphones and IEMs.
- **Parametric EQ & RBJ Biquad Filters**: Precision audio filtering (`ParametricEq`, `BiquadFilter`) with peaking, low-shelf, high-shelf, bandpass, and notch filter modes.
- **Loudness Normalizer**: Upgraded `LoudnessNormalizerService` with EBU R128 replaygain normalization to prevent sudden volume spikes between tracks.

### Stream Resolver Hardening
- **YouTube InnerTube Engine**: Strengthened cipher extraction and stream signature deciphering (`YoutubeInnertubeService`, `YoutubeStreamResolver`) to prevent audio stall and 403 Forbidden errors.
- **Dead Stream Auto-Recovery**: Automatic fallback to alternative streams if an audio stream fails or times out.

---

## 🌐 Connected Features & Social

### Listen Together Protocol
- **Real-Time Group Listening**: Built `ListenTogetherService` and `ListenTogetherProtocol` supporting shared listening rooms over WebSocket.
- **Buffer Barrier Synchronization**: Microsecond drift compensation and audio clock alignment ensure host and listeners stay perfectly in sync.
- **Dedicated Room Screen**: Added `ListenTogetherScreen` with room creation, shareable invite codes, participant management, and shared queue controls.

### Discord Gateway Rich Presence
- **Native Discord RPC**: Built `DiscordGatewayService` for desktop Linux and Windows. Broadcasts currently playing track title, artist, album art, elapsed time, and total duration directly to Discord status.

### Voice Search Tokenizer & Matcher
- **Hands-Free Query Parsing**: Built `VoiceSearchMatcher` with phonetic soundex and Levenshtein fuzzy distance matching to execute voice commands and play songs instantly.

### Smart Music Alarm
- **Gentle Wake-Up Alarm**: Built `MusicAlarmService` allowing users to wake up to any track or playlist with gradual volume fading.

---

## 🛡️ Fleet Management & Administration Console

### Per-Device Maintenance Downtime Exemptions
- Added granular device targeting in maintenance mode: exempt specific developer, tester, or VIP devices from global maintenance lockdown via `device_control_service.dart`.
- Exempted devices can bypass maintenance screens while the fleet is locked for database updates.

### Commercial Phone Model Resolver
- Built hardware inspection resolver that translates internal hardware board names into real-world consumer branding (e.g. Redmi 13C 5G, Moto G34 5G, vivo X300, Samsung Galaxy F70e 5G, OnePlus, Realme, etc.).

### Admin Web Console Overhaul (`server/`)
- Upgraded web administration dashboard with real-time hardware telemetry, persistent fleet registry, offline notice queuing, device killswitch commands, and system configuration engine.

---

## 📜 Licensing, Quality Assurance & CI/CD

- **Relicensed under GNU GPL-3.0**: Fully committed to open source freedom under the GNU General Public License v3.0 (`LICENSE`).
- **Code of Conduct**: Adopted Contributor Covenant Code of Conduct v2.1 (`CODE_OF_CONDUCT.md`).
- **Cloud CI/CD Releases**: Streamlined GitHub Actions workflows for automated Linux x64 and Android ARM64 builds with noninteractive package pipelines and release asset distribution.
- **Exhaustive Unit & Integration Test Coverage**: Added comprehensive test suites across lyrics rendering, AutoEQ DSP, TTML parsing, Shazam signatures, Spotify sync, and UI style token systems.

---

## 📦 Downloads & Verification

| Asset | Platform / Architecture | Size | Checksum (SHA-256) |
|---|---|---|---|
| **Softify-v3.0.4-Android.apk** | Android 8.0+ (ARM64-v8a) | ~27.8 MB | `5d6288639ea458669387fe75afd0bc7f7f897f2674e792cb00feae9476ecce78` |
| **Softify-Linux-x64.tar.gz** | Linux Desktop (x86_64) | ~14.4 MB | `df587564263ace025e7418d245f1972ff0f24e93010f3c5aeaf1275bbfa6ce43` |
| **SHA256SUMS.txt** | All Platforms | 93 B | Verified |

*Desktop Linux users: Binary installed locally to `~/.local/share/softify/softify` (launcher: `~/.local/bin/softify`).*
