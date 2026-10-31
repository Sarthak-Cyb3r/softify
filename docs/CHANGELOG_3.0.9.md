# Softify v3.0.9 Release Changelog

## 🚀 Overview

Softify **v3.0.9** delivers critical streaming accuracy enhancements, eliminates track substitution bugs on regional catalogs, restores multi-provider lyrics across LRCLIB and JioSaavn, refines Listen Together cross-device playback synchronization, and adds automatic lyrics viewport positioning.

---

## 🔍 Root Cause Analysis & Fixes

### 1. Audio Stream Matching & Mismatch Prevention
- **Defect**: When playing certain songs missing from regional streaming catalogs (e.g. *Raanjhanaa* from the movie soundtrack withheld by Eros Now on JioSaavn), the app played an unrelated track (*Tum Tak*) from the same album/artist.
- **Root Cause**:
  1. In `SaavnStreamResolver`, candidate songs that shared zero title words with the target received 0 points for title, but gained +15 (Hindi), +35 (Artist match e.g. A.R. Rahman), and +20 (Duration match within 10s) = 70.0 points, passing the `>= 50.0` threshold without falling back to YouTube Music.
  2. Transliteration variations (*Dildaara* vs *Dildara*) caused title string mismatch without phonetic normalization.
- **Resolution**:
  - Implemented strict zero-word title penalty (`-200.0`), immediately disqualifying unrelated songs from the same album.
  - Implemented phonetic vowel simplification (`aa` $\to$ `a`, `ee` $\to$ `e`, `oo` $\to$ `o`) in `_phoneticSimplify` to reconcile cross-platform transliteration differences.
  - Added official record labels (`eros`, `eros now`, `eros music`, `think music`) with strict title word verification in `YoutubeStreamResolver`, ensuring clean fallback to official studio master audio.

### 2. Multi-Provider Lyrics Reliability & Cloudflare Bypass
- **Defect**: Lyrics failed to load for many songs, displaying empty screens despite using multiple providers.
- **Root Cause**:
  1. Cloudflare/LRCLIB blocked Softify's User-Agent with HTTP 503 (`ServerOverloaded`).
  2. LRCLIB indexed multi-artist tracks under individual featured vocalists (e.g. *Raanjhanaa* under `Jaswinder Singh` instead of `A.R. Rahman`, *Dildaara* under `Shafqat Amanat Ali` instead of `Vishal-Shekhar`), causing single-artist queries to 404.
  3. Parenthetical clauses like `(Stand By Me)` in *Dildaara (Stand By Me)* prevented exact matches on LRCLIB where tracks are stored under their bare names.
  4. Dead or slow regional providers (Paxsenix, NetEase, BetterLyrics) consumed the cumulative 11s timeout before verified plain lyrics could be returned.
- **Resolution**:
  - Configured standard browser User-Agent and transient 503 exponential retry in `LrclibLyricsProvider`.
  - Added multi-artist candidate splitting across commas, slashes, and featured clauses (`Jaswinder Singh`, `A.R. Rahman`, `Shafqat Amanat Ali`), and bare-title extraction without parenthetical clauses (*Dildaara* from *Dildaara (Stand By Me)*) for instant exact-match lyric retrieval.
  - Upgraded `SaavnLyricsProvider` with phonetic title matching and fallback resolution for verified lyrics IDs.
  - Optimized timeout budgets across all lyric tiers in `CompositeLyricsProvider`, preventing cascading delays and ensuring reliable fallback to verified plain lyrics.

### 3. Listen Together Cross-Device Playback Synchronization
- **Defect**: When playing a track on mobile (e.g. *Dildaara*), connected PC listeners did not play the track.
- **Root Cause**: Binary protobuf routing only permitted host outgoing actions, loopback checks blocked incoming sync events, and capability handshakes were incomplete.
- **Resolution**:
  - Enabled bidirectional action routing for both `playback_action` and `sync_playback`.
  - Removed host-only outgoing filter so guests can control playback, and ensured both host and guests automatically resolve, stream, and sync incoming track updates without loopbacks.
  - Coordinated distributed buffer barriers (`buffer_wait` / `buffer_ready` / `buffer_complete`) to ensure simultaneous playback start.

### 4. Lyrics Viewport Initial Auto-Scroll
- Added initial auto-scroll upon opening the Lyrics canvas to smoothly navigate straight to the active singing line.
- Wired Home Screen mood filter chips to dynamically refresh and filter feed tracks.

---

## 📦 Release Assets

| Platform | File | Size | SHA-256 Checksum |
| :--- | :--- | :--- | :--- |
| **Android (Universal ARM64, 8.0+)** | `Softify-v3.0.9-Android.apk` | 27.85 MB | Verified via CI |
| **Linux (Desktop x86_64 Bundle)** | `Softify-Linux-x64.tar.gz` | 14.35 MB | Verified via CI |
