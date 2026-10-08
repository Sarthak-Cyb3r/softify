# Changelog

All notable changes to the Softify project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.5] - 2026-10-08

### Added
- **YouTube Audio-Only Tab**:
  - Dedicated "YouTube" tab in the bottom navigation bar (`/youtube`).
  - Comprehensive link parser supporting all YouTube URL formats (`watch?v=`, `youtu.be/`, `/shorts/`, `/embed/`, `/live/`, `music.youtube.com`, timestamps `t=90s`, `1m30s`, and playlist links).
  - Direct InnerTube mobile player endpoint integration (`/youtubei/v1/player`) to bypass web-scraping bot-checks and 429 rate-limiting.
  - Automatic clipboard detection chip ("Play copied link?") on tab focus.
  - Android Share Intent support (`ACTION_SEND text/plain`) for sharing links directly from the YouTube app on cold and warm starts.
  - Drift SQLite persistence for recently played links with swipe-to-delete and clear-all actions.
  - Lazy playlist loading with 1-tap "Play all" queue integration.
- **Studio Hardware DSP Equalizer**:
  - 5-band hardware-accelerated equalizer in Settings (`Playback & Streaming`).
  - Powered by `AndroidEqualizer` and `AndroidLoudnessEnhancer` with dual-engine gapless playback sync.
  - 14 tuned acoustic presets (Flat, Bass Booster, Rock, Pop, Electronic, Hip Hop, Jazz, Classical, Acoustic, Vocal Booster, etc.).
  - Real-time Catmull-Rom Bézier spline curve visualizer with smooth gradient glow.
  - Sub-bass boost and hardware loudness enhancer controls.
  - "Hold to Audition" A/B bypass comparison button.
  - Drift SQLite key-value persistence for custom band configurations.
- **Linux Terminal Updater**:
  - Seamless 1-line update command preserving all user data and downloads:
    `curl -fsSL https://raw.githubusercontent.com/Sarthak-Cyb3r/softify/main/install.sh | bash`

### Fixed
- **Scraping Rate-Limit Errors**: Eliminated `RequestLimitExceededException` crashes by routing stream resolution and metadata through mobile InnerTube and oEmbed endpoints.
- **Desktop Sidebar Layout**: Compacted sidebar margins to prevent RenderFlex overflow on small displays.

---

## [2.0.4] - 2026-10-06

### Added
- Phase 8 JioSaavn 320kbps Studio Master integration.
- Intelligent search deduplication engine collapsing compilation and remix duplicates.
- High-fidelity offline downloading with embedded M4A iTunes atom metadata and album artwork.
- In-app OTA updater for Android.

---

## [2.0.0] - 2026-10-04

### Added
- Complete 17-feature search and recommendation roadmap (Sprints 1–9).
- Sub-100ms instant search with on-device SQLite FTS5 full-text indexing.
- Dual-band taste decay profile learning and PPMI session co-occurrence graph.
- Pointwise logistic regression ranker and algotorial home shelves with familiar anchor ratio.
- Epsilon-greedy multi-armed bandit with KL divergence calibration.
- 128-dimensional on-device zero-network semantic vector search.
