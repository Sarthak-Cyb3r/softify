# Softify: Spotify Kernel Architecture Implementation Task List

## Specification Summary
* **Reference Document**: [softify/SPOTIFY_KERNEL_ARCHITECTURE_RESEARCH.md](file:///home/sarthak/Desktop/Projects/softify/SPOTIFY_KERNEL_ARCHITECTURE_RESEARCH.md)
* **Core Invariant**: **Preserve 320 kbps Studio Master Quality on ALL devices (Linux & Android)**. No downsampling, no re-encoding, and no fallback to low-bitrate streams.
* **Goal**: Implement Spotify's kernel-to-application subsystems into Softify's Flutter/Dart architecture while guaranteeing 320 kbps bit-exact audio delivery.
* **Target Stack**: Flutter (Dart), Riverpod 2.5, `just_audio` / `media_kit`, Drift SQLite, `audio_service`, `background_downloader`.

---

## The 320 kbps Quality Invariant (All Devices)
1. **Source Authority**: JioSaavn Studio CDN Master (`_320.mp4` @ 320,000 bps AAC) is the strict primary stream source. If unflagged in metadata, CDN probing directly validates 320kbps stream availability before any fallback.
2. **Lossless DSP Processing**: EBU R128 loudness normalization, limiter, and crossfade operations must execute in 32-bit floating point PCM inside `media_kit`/FFmpeg without lossy down-conversion or bit-depth truncation.
3. **Byte-for-Byte Chunk Cache**: 128 KB sparse disk caching stores raw 320 kbps chunks verbatim with zero recompression.
4. **Device Integrity**: Linux PipeWire/ALSA and Android AAudio/AudioTrack output sinks are configured for uncompressed 44.1/48kHz 16/24-bit playback.

---

## Development Tasks

### [ ] Task 1: Hardware-Compensated Monotonic Audio Clock
* **Description**: Replace periodic UI position polling with a continuous reference clock tuple $\langle t_{\text{ref}}, P_{\text{ref}}, \text{speed} \rangle$ utilizing `Stopwatch.getTimestamp()` and audio sink latency compensation (compensating Bluetooth A2DP ~120ms delay & PipeWire/Pulse buffer delays) while streaming 320 kbps audio.
* **Acceptance Criteria**:
  * Position interpolation operates smoothly at 60 FPS via `Ticker`.
  * Clock automatically compensates for output device type (Bluetooth vs wired vs internal speaker).
  * 320 kbps audio buffer never underruns during hardware timing queries.
* **Files**:
  * Create `lib/services/audio_clock_service.dart`
  * Modify `lib/providers/player_provider.dart`

### [ ] Task 2: High-Resolution Lyrics & Syllable Interpolation Engine
* **Description**: Bind the monotonic audio clock to the lyric rendering view with smooth bezier bounding-box scrolling and character/syllable level interpolation (`color-lyrics/v2` format).
* **Acceptance Criteria**:
  * Active lyric line auto-centers with smooth physics-based clamping.
  * Word/syllable timing interpolates precisely without desyncing from 320 kbps PCM stream.
  * User manual scrolling pauses auto-scroll for 3 seconds before gentle re-anchoring.
* **Files**:
  * Modify `lib/widgets/lyrics_view.dart`
  * Modify `lib/providers/lyrics_provider.dart`

### [ ] Task 3: 32-Bit Float EBU R128 Loudness Normalizer & Limiter
* **Description**: Implement Spotify-style loudness normalization targeting -14 LUFS with lookahead peak protection, operating in 32-bit floating-point to preserve full 320 kbps dynamic range.
* **Acceptance Criteria**:
  * Audio player scales track volume multiplier dynamically based on track ReplayGain / LUFS metadata without truncating 320 kbps AAC stream quality.
  * Brickwall peak limiter prevents digital clipping when EQ boost or normalization gain exceeds 0 dBFS.
* **Files**:
  * Create `lib/services/loudness_normalizer_service.dart`
  * Modify `lib/services/audio_player_service.dart`

### [ ] Task 4: Dual-Deck S-Curve Crossfade & Automix Engine
* **Description**: Implement dual-deck audio crossfader applying logarithmic/S-curve transitions (`Automix` curve modeling) between consecutive 320 kbps tracks without interrupting decoder throughput.
* **Acceptance Criteria**:
  * Configurable crossfade duration (0s to 12s) in settings.
  * Pre-buffers next 320 kbps track 5-10 seconds before track end to prevent network jitter drops; smoothly crossfades outgoing and incoming decks.
  * Bit-exact 320 kbps playback preserved when crossfade is disabled (gapless mode).
* **Files**:
  * Create `lib/services/automix_service.dart`
  * Modify `lib/services/audio_handler.dart`

### [ ] Task 5: 320 kbps Chunked Sparse Audio Cache Manager with LRU Eviction
* **Description**: Implement high-throughput 128KB chunk-based sparse disk caching storing raw 320 kbps stream chunks byte-for-byte with zero re-encoding and automated LRU quota management (`~/.cache/softify/Storage` on Linux, CacheDir on Android).
* **Acceptance Criteria**:
  * Full 320 kbps AAC audio chunks cache verbatim without lossy compression.
  * Automatic purge triggers when cache footprint exceeds user-selected limit (e.g. 2GB, 5GB, 10GB).
  * Instant offline availability for fully cached 320 kbps tracks.
* **Files**:
  * Create `lib/services/chunk_cache_service.dart`
  * Modify `lib/services/stream_resolver_service.dart`

### [ ] Task 6: SPCO Binary Bank State Serialization
* **Description**: Implement ultra-fast binary serialization (using `SPCO` container format: Magic bytes + GZIP-compressed binary bytes) for local library indexing, offline playlist state, and watch folders.
* **Acceptance Criteria**:
  * Startup load time for 5,000+ track local library reduced from >800ms (SQL queries) to <50ms (memory-mapped binary load).
  * Preserves track metadata (320 kbps bitrates, sample rates, lossless FLAC flags).
* **Files**:
  * Create `lib/services/spco_storage_service.dart`
  * Modify `lib/services/local_library_service.dart`

### [ ] Task 7: 320 kbps Enforcing Stream Resolver & Multi-Mirror Failover
* **Description**: Implement an edge resolver mirroring Spotify's `apresolve` gateway that enforces the 320 kbps invariant. Prioritizes JioSaavn Studio 320 kbps CDN Master, verifies `_320.mp4` availability, and selects highest-fidelity studio mirrors.
* **Acceptance Criteria**:
  * Strict enforcement of 320,000 bps bitrate for Studio Master presets on all platforms.
  * Proactive HTTP HEAD/range probes verify 320 kbps stream availability before player handoff.
  * Quality badge accurately displays `320 KBPS • AAC / MASTER` across all active streams.
* **Files**:
  * Modify `lib/data/resolvers/saavn_stream_resolver.dart`
  * Modify `lib/data/resolvers/hybrid_stream_resolver.dart`

### [ ] Task 8: Local Stream Telemetry & Quality Audit Logger ("RawCoreStream")
* **Description**: Implement an offline-first telemetry logger capturing 20+ dimensions per listen including verified stream bitrate, codec, buffer health, output device category, and listening duration.
* **Acceptance Criteria**:
  * Verifies and records 320 kbps delivery compliance for every track played.
  * Powers real-time stats and local "Softify Wrapped" annual listening recaps with audiophile fidelity breakdown.
* **Files**:
  * Create `lib/services/stream_telemetry_service.dart`
  * Modify `lib/db/database.dart`

### [ ] Task 9: AI DJ Voice Commentary Engine with 320 kbps Ducking (X-DJ)
* **Description**: Build an integrated AI DJ voice announcer using local offline neural TTS or fast Edge-TTS that introduces upcoming track blocks and artist context, ducking the underlying 320 kbps track smoothly.
* **Acceptance Criteria**:
  * Smoothly ducks active 320 kbps deck volume to 20% during TTS announcement, then restores full fidelity without audio pops or re-buffering.
  * Can be toggled on/off with dedicated DJ mode switch.
* **Files**:
  * Create `lib/services/ai_dj_service.dart`
  * Modify `lib/widgets/player_controls.dart`

---

## Quality Requirements
- [ ] **Strict 320 kbps Invariant**: No feature or optimization may reduce the streaming or cached bitrate below 320 kbps AAC (or 1411 kbps FLAC for lossless files).
- [ ] No local Flutter tests on host OS (strictly follow project rules).
- [ ] No long-running background daemon processes.
- [ ] Smooth 60fps rendering without jank on Linux and mobile platforms.

