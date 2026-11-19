# Third-Party Notices & Attribution

This project incorporates and adapts code from the following third-party open-source projects under the terms of their respective licenses.

---

## Metrolist

- **Project**: Metrolist (Music player for Android and Desktop)
- **Source Repository**: https://github.com/vfsfitvnm/ViMusic / Metrolist
- **Release Tag**: `v14.0.0`
- **License**: GNU General Public License v3.0 (GPL-3.0)
- **Copyright**: (C) 2024-2026 Metrolist Project Contributors

### Adapted Components in Softify

1. **Lyrics Multi-Format Parsers**
   - **Upstream Files**:
     - `shared/src/commonMain/kotlin/com/metrolist/shared/api/lyrics/LyricsUtils.kt`
     - `shared/src/commonMain/kotlin/com/metrolist/shared/api/lyrics/YouTubeSubtitleLyricsProvider.kt`
   - **Softify Implementation**: `rust/softify_core/src/lyrics/parser.rs`
   - **Modifications**: Re-implemented in native Rust for softify_core. Parses TTML (Apple Music XML word/span timing), enhanced LRC word tokens (`<mm:ss.xx>`), YouTube timedtext `json3` format, and LRCLIB YAML payloads. Preserves nested word model (`LyricLine -> Vec<LyricWord>`) and eliminates synthetic character-proportional timing estimation.

2. **Keyless Lyrics Provider Pipeline**
   - **Upstream Files**:
     - `shared/src/commonMain/kotlin/com/metrolist/shared/api/lyrics/BetterLyricsProvider.kt`
     - `shared/src/commonMain/kotlin/com/metrolist/shared/api/lyrics/LrcredLyricsProvider.kt`
     - `shared/src/commonMain/kotlin/com/metrolist/shared/api/lyrics/PaxsenixLyricsProvider.kt`
     - `shared/src/commonMain/kotlin/com/metrolist/shared/api/lyrics/KuGouLyricsProvider.kt`
     - `shared/src/commonMain/kotlin/com/metrolist/shared/api/lyrics/YouTubeLyricsApi.kt`
   - **Softify Implementation**:
     - `rust/softify_core/src/lyrics/betterlyrics.rs`
     - `rust/softify_core/src/lyrics/lrcred.rs`
     - `rust/softify_core/src/lyrics/unison.rs`
     - `rust/softify_core/src/lyrics/paxsenix.rs`
     - `rust/softify_core/src/lyrics/youtube_captions.rs`
     - `rust/softify_core/src/lyrics/kugou.rs`
     - `rust/softify_core/src/lyrics/engine.rs`
   - **Modifications**: Re-implemented in Rust using `reqwest` with 5-second per-provider timeout isolation, per-provider kill switches, SQLite 7-day negative cache TTL, and prioritized word-sync provider ordering.

3. **Shader-Based Lyrics Word Highlight Rendering**
   - **Upstream Files**:
     - `shared/src/commonMain/kotlin/com/metrolist/shared/ui/components/lyrics/words/WordAnimationUtils.kt`
     - `shared/src/commonMain/kotlin/com/metrolist/shared/ui/components/lyrics/words/Simple.kt`
   - **Softify Implementation**: `composeApp/src/commonMain/kotlin/com/softify/app/ui/components/LyricsView.kt`
   - **Modifications**: Replaced per-frame Skia `Path` / `clipPath` stencil clipping with Metrolist's 4-stop horizontal linear gradient shader wipe (`Brush.linearGradient(0f to lit, 0.1f to lit, 0.9f to unlit, 1.0f to unlit)`). Pre-measures full paragraph and word sub-layouts once using `TextMeasurer` when layout settles, achieving zero allocations per animation frame. When `isLineTimed = true`, highlights entire line without word sweep.

4. **FLIP Spring Auto-Scroll & Gesture Lockout**
   - **Upstream Files**:
     - `shared/src/commonMain/kotlin/com/metrolist/shared/ui/components/lyrics/LyricsScrollAnimation.kt`
   - **Softify Implementation**: `composeApp/src/commonMain/kotlin/com/softify/app/ui/components/LyricsView.kt`
   - **Modifications**: Ported FLIP layout shift mechanism: instant list viewport update (`listState.scrollBy(delta)`) combined with inverse visual offset on items via `Modifier.graphicsLayer { translationY = visualOffset }` decaying to 0 with a damped spring (`dampingRatio = 0.85f, stiffness = 200f`). Added 400ms gesture lockout suppressing auto-scroll during user touches or flings.

5. **Cover Art Resolution Bucketing & 404 Fallback Chain**
   - **Upstream Files**:
     - `shared/src/commonMain/kotlin/com/metrolist/shared/utils/ArtworkUrl.kt`
     - `shared/src/commonMain/kotlin/com/metrolist/shared/utils/VideoArtworkFallback.kt`
     - `shared/src/commonMain/kotlin/com/metrolist/shared/utils/ArtworkSizingInterceptor.kt`
   - **Softify Implementation**:
     - `composeApp/src/commonMain/kotlin/com/softify/app/ui/components/CoverArtLoader.kt`
     - `composeApp/src/commonMain/kotlin/com/softify/app/ui/components/AsyncCoverArt.kt`
   - **Modifications**: Adopted discrete sizing buckets (256, 544, 1200, 2400) matching Google CDN and YouTube image servers. Added cross-size cache candidate lookup checking for existing cached resolutions before network dispatch, and implemented the YouTube 404 fallback chain (`maxresdefault.jpg` -> `mqdefault.jpg` -> raw URL).
