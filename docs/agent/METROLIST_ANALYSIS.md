# Metrolist Reverse Engineering & Architectural Deep-Dive
**Document Target**: `docs/agent/METROLIST_ANALYSIS.md`  
**Analyzed Binary**: `/home/sarthak/Downloads/Metrolist.apk`  
**Matching Source Repository**: `https://github.com/MetrolistGroup/Metrolist` (Release tag: `v14.0.0`, commit `69f7772`)  
**Target Application**: Softify-experimental (`/home/sarthak/Desktop/Projects/Softify-experimental`)  

---

## 1. Executive Summary & Verification

### 1.1 Binary Artifact Identification
Analysis of `/home/sarthak/Downloads/Metrolist.apk` using Android SDK `aapt` (build-tools 34.0.0) yields the exact build metadata:
* **Package Name**: `com.metrolist.music` (with namespace `com.metrolist.android`)
* **Version Code**: `154`
* **Version Name**: `14.0.0`
* **Compile SDK**: `37` (Android 17 preview platform)
* **Min SDK**: `24` (Android 7.0)
* **Target SDK**: `37`

### 1.2 Upstream Source Mapping & Verification
The matching open-source repository was located at `https://github.com/MetrolistGroup/Metrolist`. Inspection of `gradle.properties` line 41 confirms `appVersion=14.0.0`, and `androidApp/build.gradle.kts` line 258 sets `versionCode = 154`.

To guarantee that the public source code exactly represents the shipped binary without proprietary or uncommitted patches, the classes in the APK's DEX files (`classes.dex`, `classes2.dex`, `classes3.dex`) were inspected and compared against the repository bytecode signatures. Core symbol lookups confirmed an exact match:
* `Lcom/metrolist/shared/api/lyrics/KuGouLyricsProvider;`
* `Lcom/metrolist/shared/api/lyrics/BetterLyricsProvider;`
* `Lcom/metrolist/shared/ui/components/lyrics/LyricsSmoothPositionKt;`
* `Lcom/metrolist/shared/ui/components/lyrics/words/AppleKt;`
* `Lcom/metrolist/shared/utils/ArtworkSizingInterceptor;`

Metrolist is structured as a Kotlin Multiplatform (KMP) project consisting of `shared` (Compose Multiplatform core), `androidApp`, `desktopApp`, and `iosApp`.

---

## 2. Codebase Architecture Map

| Subsystem | Package / Directory | Key Classes & Functions |
| :--- | :--- | :--- |
| **Lyrics Models** | `com.metrolist.shared.model` | `Lyrics.kt`: `LyricsEntry`, `WordTimestamp`, `MlxDocument`, `MlxSong`, `MlxMeta`, `LyricsProvider` |
| **Lyrics Interchange Format** | `com.metrolist.shared.api.lyrics` | `MlxParser.kt`: `parse()`, `parseContent()`, `tsToMs()`<br>`MlxBuilder.kt`: `line()`, `appendWords()`, `build()` |
| **Lyrics Providers** | `com.metrolist.shared.api.lyrics` | `BetterLyricsProvider.kt`, `LrcredLyricsProvider.kt`, `UnisonProvider`, `PaxsenixLyricsProvider.kt`, `SimpMusicLyricsProvider.kt`, `YouTubeSubtitleLyricsProvider.kt`, `YouTubeLyricsProvider.kt`, `LrcLibLyricsProvider.kt`, `KuGouLyricsProvider.kt`, `LyricsClient.kt` |
| **Lyrics Storage & Cache** | `com.metrolist.shared.db.entities`<br>`com.metrolist.shared.repository` | `LyricsEntity.kt` (Room table `lyrics`), `LyricsRepository.kt`: negative caching, prefetch, offset resolution |
| **Lyrics Presentation UI** | `com.metrolist.shared.ui.components.lyrics` | `LyricsView.kt`: `rememberLazyListState()`, `syncSnapshotState`, `scrollTargetState`<br>`Lines.kt`: `InlineLyricsLine()`, line scale and alpha transitions |
| **Lyrics Word Animation** | `com.metrolist.shared.ui.components.lyrics.words` | `LyricsAnimationStyle.kt`: `WordLevelLyrics()`<br>`Apple.kt`: `AppleWordAnimation()` (Canvas drawing, layout metrics)<br>`WordAnimationUtils.kt`: `drawWipeText()`, `computeWipe()`, `sampleEmphasisCached()` |
| **Lyrics Frame Clock** | `com.metrolist.shared.ui.components.lyrics` | `LyricsSmoothPosition.kt`: `rememberSmoothLyricsPositionState()`, `LyricsPositionClock`, `smoothLyricsPositions()` |
| **Auto-Scroll Physics** | `com.metrolist.shared.ui.components.lyrics` | `LyricsScrollAnimation.kt`: `LyricsScrollShifter`, `LyPlusSpring`, `LyPlusScrollEasing` |
| **Image Loading Engine** | `com.metrolist.android.utils`<br>`com.metrolist.shared.storage` | `AppImageLoader.kt`: Coil 3 `ImageLoader` configuration, OkHttp dispatcher<br>`ResizableImageDiskCache.kt`: Dynamic disk cache sizing |
| **Artwork URL Processing** | `com.metrolist.shared.utils` | `ArtworkUrl.kt`: `bucketedArtworkUrl()`, `sizedArtworkUrl()`, `videoArtworkFallbackUrl()`<br>`ArtworkSizingInterceptor.kt`: Cross-size cache resolution |
| **Artwork Color Extraction** | `com.metrolist.android.ui.theme` | `PlayerColorExtractor.kt`: `QuantizerCelebi`, HSV saturation boost, 3-stop vertical gradient |

---

## 3. Section A: Word-by-Word Synchronization (Data & Providers)

### 3.1 Provider Priority Chain and Fallback Logic
Metrolist coordinates lyrics resolution through `LyricsClient.kt` (`fetchLyrics()`). In default `AUTO` mode, it prioritizes providers supporting word-level synchronization before falling back to line-synced or unsynced sources.

```
                  ┌──────────────────────────────┐
                  │         User Custom          │ (Local SQLite override)
                  └──────────────┬───────────────┘
                                 │
                  ┌──────────────▼───────────────┐
                  │            Lyprio            │ (Authenticated proxy; skipped if unconfigured)
                  └──────────────┬───────────────┘
                                 │
                  ┌──────────────▼───────────────┐
                  │         BetterLyrics         │ (TTML / Apple Music word-sync)
                  └──────────────┬───────────────┘
                                 │
                  ┌──────────────▼───────────────┐
                  │           lrc.red            │ (ISRC-keyed Apple Music TTML)
                  └──────────────┬───────────────┘
                                 │
                  ┌──────────────▼───────────────┐
                  │            Unison            │ (Crowdsourced TTML / LRC)
                  └──────────────┬───────────────┘
                                 │
                  ┌──────────────▼───────────────┐
                  │            LRCLIB            │ (Synced & plain LRC)
                  └──────────────┬───────────────┘
                                 │
                  ┌──────────────▼───────────────┐
                  │            KuGou             │ (Line-synced LRC fallback)
                  └──────────────┬───────────────┘
                                 │
                  ┌──────────────▼───────────────┐
                  │           Paxsenix           │ (Apple Music Web catalog search + TTML)
                  └──────────────┬───────────────┘
                                 │
                  ┌──────────────▼───────────────┐
                  │       YouTube Subtitle       │ (Caption track json3 with tOffsetMs words)
                  └──────────────┬───────────────┘
                                 │
                  ┌──────────────▼───────────────┐
                  │        YouTube Music         │ (InnerTube Android Music timed lines)
                  └──────────────────────────────┘
```

When evaluating providers in `AUTO` mode, `LyricsClient.kt` iterates through candidate providers in order:
1. It requests the lyrics string and parses it into `List<LyricsEntry>` via `LyricsUtils.parseLyrics()`.
2. If `usableProviderLyrics(parsed)` is true and the candidate contains playback timings (`LyricsUtils.hasPlaybackTiming(parsed)`), **it halts iteration immediately and adopts that result**.
3. If a provider returns unsynced plain lyrics, it holds it as a fallback candidate and continues querying subsequent providers until a timed (word-synced or line-synced) result is found.

---

### 3.2 Provider Specifications

#### 1. BetterLyrics
* **Implementation**: `com.metrolist.shared.api.lyrics.BetterLyricsProvider`
* **Endpoint**: `GET https://lyrics-api.boidu.dev/getLyrics`
* **Query Parameters**:
  * `s`: Track title
  * `a`: Artist name
  * `d`: Track duration in seconds (`duration / 1000`)
  * `al`: Album name (optional; if query fails, retries without album)
* **Headers**: `Accept: application/json`
* **Authentication**: None (Keyless)
* **Response Format**: JSON wrapper containing raw TTML string: `{"ttml": "<tt xmlns=...>"}`
* **Parsing Algorithm**: `parseTtmlToMlx()` parses the XML DOM:
  * Reads `<head><metadata><audio lyricOffset="...">` for global track timing offset.
  * Walks `<body><div><p begin="..." end="...">` to construct lyric lines.
  * Extracts child `<span begin="..." end="...">word</span>` elements to construct individual word tokens.
* **Payload Example (TTML)**:
```xml
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:itunes="http://music.apple.com/lyric-ttml-extensions">
  <head>
    <metadata>
      <audio lyricOffset="0.0"/>
      <Agent type="person" xml:id="v1"/>
    </metadata>
  </head>
  <body>
    <div>
      <p begin="00:14.20" end="00:17.50" agent="v1">
        <span begin="00:14.20" end="00:14.80">Can </span>
        <span begin="00:14.80" end="00:15.30">we </span>
        <span begin="00:15.30" end="00:16.10">still </span>
        <span begin="00:16.10" end="00:16.70">be </span>
        <span begin="00:16.70" end="00:17.50">friends</span>
      </p>
    </div>
  </body>
</tt>
```

#### 2. lrc.red
* **Implementation**: `com.metrolist.shared.api.lyrics.LrcredLyricsProvider`
* **Endpoint**:
  * Search: `GET https://lrc.red/api/v1?q={title}+{artist}`
  * Lyrics Payload: `GET https://lrc.red{lyricsUrl}`
* **Query Parameters**: `q` (encoded track title and artist)
* **Authentication**: None (Keyless)
* **Response Format**: Search returns a JSON array of candidates. The target resource at `lyricsUrl` returns raw Apple Music TTML.
* **Matching**: `findBestMatch()` normalizes track names by stripping bracketed features (`(feat. ...)`, `[Official Video]`) and matches candidate duration within tolerance.
* **Payload Example (Search Response)**:
```json
{
  "results": [
    {
      "id": "1734918231",
      "isrc": "USUG12401234",
      "track_name": "back to friends",
      "artist_name": "sombr",
      "album_name": "back to friends - Single",
      "duration": 199.2,
      "lyricsUrl": "/api/v1/lyrics/1734918231.ttml",
      "timing_type": "word"
    }
  ]
}
```

#### 3. Unison
* **Implementation**: `com.metrolist.shared.api.lyrics.BetterLyricsProvider.kt` (embedded `UnisonProvider`)
* **Endpoint**: `GET https://unison.boidu.dev/lyrics`
* **Query Parameters**:
  * Primary: `v={videoId}`
  * Fallback: `song={title}&artist={artist}&album={album}&duration={sec}`
* **Authentication**: None (Keyless)
* **Response Format**: JSON containing format indicator and string payload:
```json
{
  "success": true,
  "data": {
    "format": "ttml",
    "lyrics": "<tt xmlns=\"http://www.w3.org/ns/ttml\">...</tt>",
    "submitter": { "displayName": "Contributor1", "keyId": "k123" }
  }
}
```

#### 4. Paxsenix (Apple Music Web Scraper)
* **Implementation**: `com.metrolist.shared.api.lyrics.PaxsenixLyricsProvider`
* **Endpoints**:
  * 1. Token acquisition: Scrapes `https://music.apple.com` web scripts using `AppleTokenManager` to obtain the anonymous developer bearer token.
  * 2. Catalog Search: `GET https://amp-api.music.apple.com/v1/catalog/{storefront}/search?term={query}&types=songs&limit=25`
  * 3. Lyrics Fetch: `GET https://lyrics.paxsenix.org/apple-music/lyrics?id={appleSongId}`
* **Headers**: `Authorization: Bearer {token}`, `Origin: https://music.apple.com`, `User-Agent: Metrolist`
* **Authentication**: Anonymous Apple Music web bundle token; proxy keyless.
* **Response Format**: Apple Music TTML / word-timed JSON.

#### 5. YouTube Subtitles (Caption Tracks)
* **Implementation**: `com.metrolist.shared.api.lyrics.YouTubeSubtitleLyricsProvider`
* **Endpoints**: InnerTube `player` response `captions.playerCaptionsTracklistRenderer.captionTracks[].baseUrl`.
* **Parameter Rewrite**: Appends or replaces `fmt=json3` to retrieve raw JSON caption events.
* **Authentication**: Keyless (InnerTube public client).
* **Word Timing Extraction**: Evaluates each segment inside `events[].segs[]`. When `tOffsetMs` is present, it computes `wordStartMs = startMs + tOffsetMs`, allowing word-by-word highlight directly from YouTube without external lyrics services.
* **Payload Example (json3)**:
```json
{
  "events": [
    {
      "tStartMs": 14200,
      "dDurationMs": 3300,
      "segs": [
        { "utf8": "Can " },
        { "utf8": "we ", "tOffsetMs": 600 },
        { "utf8": "still ", "tOffsetMs": 1100 },
        { "utf8": "be ", "tOffsetMs": 1900 },
        { "utf8": "friends", "tOffsetMs": 2500 }
      ]
    }
  ]
}
```

#### 6. SimpMusic
* **Implementation**: `com.metrolist.shared.api.lyrics.SimpMusicLyricsProvider`
* **Endpoint**: `GET https://api-lyrics.simpmusic.org/v1/{videoId}`
* **Authentication**: None (Header `User-Agent: SimpMusicLyrics/1.0`).
* **Format**: Enhanced LRC containing inline `<mm:ss.xx>` tags (`richSyncLyrics`).
* **Payload Example**:
```text
[00:14.20]<00:14.20>Can <00:14.80>we <00:15.30>still <00:16.10>be <00:16.70>friends<00:17.50>
```

#### 7. LRCLIB
* **Implementation**: `com.metrolist.shared.api.lyrics.LrcLibLyricsProvider`
* **Endpoint**: `GET https://lrclib.net/api/search?track_name={title}&artist_name={artist}`
* **Authentication**: None.
* **Format**: Standard line-synced LRC (`syncedLyrics`) or plain text (`plainLyrics`).

#### 8. KuGou
* **Implementation**: `com.metrolist.shared.api.lyrics.KuGouLyricsProvider`
* **Endpoint**:
  * Search: `GET https://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword={query}&duration={durationMs}`
  * Download: `GET https://lyrics.kugou.com/download?fmt=lrc&charset=utf8&client=pc&ver=1&id={id}&accesskey={accessKey}`
* **Format**: Standard Base64-encoded LRC.

---

### 3.3 Internal Canonical Data Model: MLX & Kotlin Entities

Metrolist converts all incoming provider formats (TTML, enhanced LRC, json3, standard LRC) into a unified internal format called **MLX** (`MlxDocument`).

#### Kotlin Data Model (`com.metrolist.shared.model.Lyrics.kt`)
```kotlin
@Serializable
data class WordTimestamp(
    val text: String,
    val startTime: Double,               // Seconds (float/double)
    val endTime: Double,                 // Seconds (float/double)
    val hasTrailingSpace: Boolean = true,
    val isBackground: Boolean = false,
    val isLineTimed: Boolean = false,    // True if inherited from line without word timestamps
)

@Serializable
data class LyricsEntry(
    val time: Long,                      // Milliseconds (line start)
    val text: String,                    // Reconstructed line text with normalized spaces
    val words: List<WordTimestamp>? = null, // Strictly nested words
    val agent: String? = null,           // Vocalist ID (e.g. "v1", "v2")
    val endTime: Long? = null,           // Milliseconds (line end)
    val isBackground: Boolean = false,   // Background vocal line
    val translatedText: String? = null,
    val romanizedText: String? = null,
    val romanizedWords: List<WordTimestamp>? = null,
    val songPart: String? = null,        // e.g. "Chorus", "Verse 1"
    val backgroundText: String? = null,
    val backgroundTranslatedText: String? = null,
    val translationLanguage: String? = null,
    val translationMode: String = "Literal",
) : Comparable<LyricsEntry>
```

#### Structural Rules:
1. **Strict Nesting**: Words are **always** placed inside `LyricsEntry.words`. The parser never emits word tokens as independent lines.
2. **Text Normalization**: `LyricsEntry.text` holds the complete line text. Individual words store their stripped syllable text, and spacing is controlled via `hasTrailingSpace`.
3. **Background Vocals**: Represented either via inline `[bg:<ts>word<ts>]` tags or marked with `isBackground = true`.
4. **Duets / Multiple Agents**: Represented by `agent` IDs linked to `AgentInfo(id, type, name, color)`.
5. **Absence of Word Timings**: When only line timings are provided, `words` is marked with `isLineTimed = true`. **Metrolist never estimates word timings using character count or word count heuristics**. It sets `LyricsTimingKind.LINE_SYNCED` and disables word sweep animations.

---

### 3.4 Caching Architecture
* **Storage**: SQLite via AndroidX Room 3 KMP (`com.metrolist.shared.db.MusicDatabase`), table `lyrics`.
* **Entity**: `LyricsEntity` (`id` = videoId / songId).
* **Positive Cache TTL**: Permanent in SQLite until the user manually triggers a refresh or edits the lyrics.
* **Negative Cache**: When lyrics are missing across all providers, Metrolist records `LyricsEntity.LYRICS_NOT_FOUND` with `missExpiresAt = nowMs() + 7 * 24 * 60 * 60_000L` (7 days). Subsequent track plays bypass network queries until the negative TTL expires.
* **Prefetching**: When the audio player loads a song, `PlayerScreen.kt` calls `PlayerViewModel.prefetchLyrics(nextSong)`, prefetching the upcoming track's lyrics into SQLite before playback begins.

---

## 4. Section B: Lyrics UI, Rendering, and Animation

### 4.1 Composable Hierarchy
```
LyricsView
 └── BoxWithConstraints
      └── LazyColumn (rememberLazyListState)
           └── itemsIndexed(processedItems, key = { itemKeys[index] })
                └── Box (graphicsLayer: translationY from scrollShifter, alpha from itemAlpha)
                     └── InlineLyricsLine
                          └── Box (combinedClickable: onSeek, onLongClick)
                               └── Column (graphicsLayer: scaleX, scaleY)
                                    ├── LyricsBgReveal (background vocals / translation)
                                    └── WordLevelLyrics (Words wrapper)
                                         └── AppleWordAnimation
                                              └── Canvas (lyricsWordCanvasLayout)
                                                   ├── drawText(pastBrush)
                                                   ├── drawText(unlitBrush)
                                                   └── drawText(linearGradientBrush)
```

---

### 4.2 Text Layout & Word Wrapping
Metrolist does **not** lay out words using `FlowRow` or individual `Text()` composables.

In `Apple.kt` (lines 262–286):
1. The composable receives `mainText: String` and measures it in a single pass using `TextMeasurer`:
```kotlin
val textLayoutResult = remember(formattedMainText, lyricStyle, widthPx) {
    textMeasurer.measure(
        text = AnnotatedString(formattedMainText),
        style = lyricStyle,
        softWrap = true,
        constraints = Constraints(minWidth = widthPx, maxWidth = widthPx),
    )
}
```
2. Metrics are extracted from `textLayoutResult`: `lineLefts`, `lineRights`, `lineStarts`, `lineWidths`, `lineBaselines`.
3. Character ranges are mapped to `VisualCluster` instances containing sub-layout bounding boxes.
4. Words wrap naturally as paragraphs governed by Compose's text layout engine, avoiding line breaks between words or container layout thrashing.

---

### 4.3 Word Highlight & Sweep Draw Algorithm

#### Metrolist Implementation (`Apple.kt` & `WordAnimationUtils.kt`)
Softify previously created a new `Path()`, accumulated word rects, and called `drawScope.clipPath(path) { drawText(...) }`. On Android devices with Mali GPUs (such as the Moto G34), allocating paths every frame and using stencil clipping triggers hardware layer allocations and dropped frames.

Metrolist avoids `clipPath` entirely. It draws the text directly using an interpolated **linear gradient shader brush**:

```kotlin
// WordAnimationUtils.kt (lines 1163-1199)
when (wipe.mode) {
    WIPE_PAST -> {
        drawClusterText(vc = vc, topLeft = topLeft, brush = pastBrush, shadow = shadow)
    }
    WIPE_UNLIT -> {
        drawClusterText(vc = vc, topLeft = topLeft, brush = unlitBrush, shadow = shadow)
    }
    else -> {
        // Actively wiping word: single text pass with a narrow transition gradient
        val brush = Brush.linearGradient(
            0.0f to litColor,
            0.1f to litColor,
            0.9f to unlitColor,
            1.0f to unlitColor,
            start = Offset(wipe.bandStart, 0f),
            end = Offset(wipe.bandEnd, 0f),
        )
        drawText(
            textLayoutResult = vc.subLayout,
            topLeft = topLeft,
            brush = brush,
            shadow = shadow,
        )
    }
}
```

* Fully sung words (`WIPE_PAST`): Drawn with `pastBrush` (`Color.White` full opacity).
* Upcoming words (`WIPE_UNLIT`): Drawn with `unlitBrush` (alpha = 0.35f).
* Actively sung word: Drawn with a 4-stop `Brush.linearGradient` spanning the active syllable's bounding box (`wipe.bandStart` to `wipe.bandEnd`), producing a smooth, hardware-accelerated fill sweep without clipping layers.

#### Emphasis & Vocal Bloom (`Apple.kt` lines 85–136, 850–934):
For sustained vowels and held notes:
* Computes an underdamped spring: `emphasisSpring(tSec, responseSec) = 1.0 - (1.0 + i) * exp(-i)`.
* Scales text subtly (`scale = 1f + 0.1f * pulse`).
* Applies slight vertical lift (`lift = -0.05f * fontSizePx * sample.lift`).
* Draws a prewarmed radial bloom glow mask behind the syllable using `drawMaskTinted(blendMode = BlendMode.Lighten)`.

---

### 4.4 Animation Specifications & Physical Parameters

| Dimension | Specification | Easing / Formula | Duration / Values |
| :--- | :--- | :--- | :--- |
| **Inactive Line Opacity** | Alpha dimming | Linear | `0.35f` default (`0.20f` when `isPlusLighter = true`) |
| **Active Line Opacity** | Full focus | Linear | `1.0f` |
| **Line Scale Falloff** | Distance-based scaling | Stepped polynomial | `distance 0`: 1.00<br>`distance 1`: 0.97<br>`distance 2-3`: 0.93<br>`distance 4`: 0.90<br>`distance 5+`: 0.85 |
| **Line Transition Duration** | Staggered spring | Damped | `staggerDurationMs = (750 + staggerDelayMs).toInt()` |
| **Word Sweep Transition** | Syllable wiper | Exact timing / monotonic interpolation | Proportional to `(endTime - startTime)` |
| **Auto-Scroll Curve** | Scroll interpolation | `CubicBezierEasing(0.41f, 0f, 0.12f, 0.99f)` | Calculated dynamically from line distance |
| **Scroll Settling Physics** | Damped harmonic oscillator | `LyPlusSpring(peakMs, zeta = 0.82f)` | `omega0 = omegaD / sqrt(1 - zeta^2)` |

---

### 4.5 Playback Clock & Position Observation

1. **State Hoisting**:
   * The audio service publishes raw positions at ~250–500 ms intervals via `positionFlow: StateFlow<Long>`.
   * `LyricsView` converts this into a smooth 60/120 fps clock via `rememberSmoothLyricsPositionState()`.
2. **Monotonic Frame Interpolation (`LyricsSmoothPosition.kt`)**:
   * Maintains `anchorPositionMs` and `anchorMark = TimeSource.Monotonic.markNow()`.
   * Calculates:
     $$\text{interpolatedPositionMs} = \text{anchorPositionMs} + (\text{elapsedSinceAnchor} \times \text{playbackSpeed})$$
   * Automatically detects seeks when $|\text{newPosition} - \text{expectedPosition}| > 200\text{ ms}$ and snaps the anchor.
3. **Recomposition Isolation**:
   * The interpolated clock returns a `LongState`.
   * Wrapped in a stable lambda: `val stablePositionProvider: () -> Long = remember(lyricsPositionState) { { lyricsPositionState.value } }`.
   * **The clock is never read during the composition phase of line items**.
   * The active line index and scroll targets are calculated via `derivedStateOf(structuralEqualityPolicy())`:
     ```kotlin
     val syncSnapshotState = remember(...) {
         derivedStateOf(structuralEqualityPolicy()) {
             syncEngine.update(currentTimeMs = lyricsPositionState.value, ...)
         }
     }
     ```
     Because `LyricsSyncSnapshot` uses structural equality, the snapshot State only invalidates when a line boundary is crossed, completely stopping recomposition of the LazyColumn while words animate.
4. **Visibility Gating**:
   * Governed by `LocalVisualWorkActive.current`.
   * When the lyrics view is obscured, collapsed into the mini-player, or the screen turns off, `smoothLyricsPositions()` cancels its tick loop.

---

### 4.6 Auto-Scroll & Manual Interaction Debounce

1. **Scroll Architecture**:
   Metrolist does **not** use `LazyListState.animateScrollToItem()`.
   * Standard Compose `animateScrollToItem()` cancels and resets if targets change, causing jitter on variable line timings.
   * Metrolist uses **FLIP-style layout offset shifting** (`LyricsScrollShifter`):
     * Updates LazyList position instantaneously with `lazyListState.scrollBy(delta)`.
     * Applies the inverse visual translation via `Modifier.graphicsLayer { translationY = scrollShifter.translationFor(flip) }`.
     * Decays `translationY` smoothly to 0 using `LyPlusSpring`.
2. **Touch Detection & Debounce**:
   * `isManualScrolling = derivedStateOf { isDragged.value || (lazyListState.isScrollInProgress && !scrollInCode.value) }`.
   * When the user touches or flings the list, `scrollShifter.suppress(LYRICS_SCROLL_LOCK_MS)` locks out auto-scrolling for 400 ms.
   * Auto-scroll resumes automatically after the user releases and the list becomes idle.

---

### 4.7 Tap to Seek
* Registered on each line container using `combinedClickable(role = Role.Button, onClick = seekLine, onLongClick = onLongClick)`.
* Provides a minimum 48dp touch target (`Modifier.heightIn(min = 48.dp)`).
* `onSeek` calculates `lyricsSeekPositionForOffset(entry.time, effectiveOffsetMs)` and dispatches to the player service.
* `pendingSeekLineIndex` provides optimistic UI highlighting before the audio engine confirms the new playback position.

---

## 5. Section C: Cover Art Loading Architecture

### 5.1 Image Engine Configuration (`AppImageLoader.kt`)
* **Library**: Coil 3 (`coil3.ImageLoader`, KMP version).
* **Memory Cache**:
  ```kotlin
  MemoryCache.Builder()
      .maxSizeBytes((Runtime.getRuntime().maxMemory() * 0.25).toLong())
      .build()
  ```
  Allocates exactly 25% of available JVM heap.
* **Disk Cache**: `ResizableImageDiskCache` stored in `context.cacheDir.resolve("coil")`. Capacity is dynamically adjustable via user settings (`Settings.shared.maxImageCacheSize`, default 250 MB).
* **De-duplication**: Uses `DeDupeConcurrentRequestStrategy()`, coalescing concurrent requests for the same URL so only one network call executes.

---

### 5.2 Network Layer & Security
* **Client**: Configured through `sharedOkHttpClient.newBuilder()`.
* **Connection Pooling**: `ConnectionPool(10, 5, TimeUnit.MINUTES)`.
* **Timeouts**: Connect 10s, Read 30s. `retryOnConnectionFailure(true)`.
* **SSRF Protection (`PublicArtworkDns.kt`)**: Implements custom OkHttp `Dns`. Validates that hostnames resolve strictly to public IP addresses, rejecting private/loopback addresses (preventing local network probing).
* **Payload Size Limit**: `ResponseSizeLimitInterceptor` enforces a maximum response size of 12 MB (`MAX_REMOTE_ARTWORK_BYTES`).

---

### 5.3 URL Rewriting & Resolution Bucketing (`ArtworkUrl.kt`)

Metrolist defines discrete sizing buckets to maximize CDN and disk cache hit rates:

| UI Context | Requested Size Range | Bucket Target | Transformed Query |
| :--- | :--- | :--- | :--- |
| **List Rows & Mini-Player** | $\le 256\text{ px}$ | `256` | `=s256` or `=w256-h256` |
| **Home Shelves & Grid Cards** | $257\text{ px} - 544\text{ px}$ | `544` | `=s544` or `=w544-h544` |
| **Now Playing Screen** | $545\text{ px} - 1200\text{ px}$ | `1200` | `=s1200` or `=w1200-h1200` |
| **Fullscreen Artwork / Tablet** | $> 1200\text{ px}$ | `2400` | `=s2400` or `=w2400-h2400` |

#### YouTube CDN Rewriting Rules:
1. **Google User Content (`*.googleusercontent.com`, `*.ggpht.com`)**:
   * Evaluates regex: `=(?:s(\d+)|w(\d+)(?:-[^-?#=]+)*-h\d+)([^?#]*)`.
   * Replaces size with bucket target. If square crop `-s` is present, replaces with `=w$size-h$size`.
2. **YouTube Video Thumbnails (`i.ytimg.com/vi/...`)**:
   * If requested size $> 320\text{ px}$, automatically promotes `mqdefault` (320x180) to `maxresdefault` (1280x720).
   * **404 Fallback Handling (`videoArtworkFallbackUrl`)**: If `maxresdefault` returns 404, Metrolist immediately falls back to `mqdefault`. It deliberately avoids `hqdefault` and `sddefault` because YouTube bakes black 4:3 letterboxing bars into those versions.
3. **Cross-Size Cache Utilization (`ArtworkSizingInterceptor.kt`)**:
   When requesting a 256px thumbnail, the interceptor checks if the 544px or 1200px version is already cached in memory or disk. If so, **it immediately serves the cached higher-resolution image**, avoiding a redundant network request.

---

### 5.4 Prefetching Strategy
1. **List & Playlist Scrolling (`PlaylistScreen.kt`)**:
   * Uses `ArtworkPrefetchWindow` with a lookahead count of 10 (`PLAYLIST_ARTWORK_PREFETCH_COUNT = 10`).
   * Observes `snapshotFlow { listState.layoutInfo.visibleItemsInfo }`.
   * Prefetches thumbnails for the next 10 upcoming items at 128x128.
   * Cancels/disposes prefetch jobs for items that have scrolled behind the view.
2. **Audio Queue Pre-caching**:
   * `AndroidQueueTransitions.kt` schedules next-track audio stream and thumbnail caching via `QueuePreCacheScheduler`.

---

### 5.5 Color Extraction (`PlayerColorExtractor.kt`)
* **Library**: `com.materialkolor.quantize.QuantizerCelebi` (Material Color Utilities Celebi quantizer, KMP native). Metrolist does **not** use AndroidX `Palette`.
* **Performance Optimization**: Downscales the bitmap to at most 10,000 total pixels ($\sim 100 \times 100\text{ px}$) before quantization:
  $$\text{scale} = \min\left(1.0, \sqrt{\frac{10000}{\text{width} \times \text{height}}}\right)$$
  Quantization executes in under 2 ms on `Dispatchers.Default`.
* **Cache**: `LinkedHashMap<String, Map<Int, Int>>` LRU cache of 32 palettes keyed by `artworkColorSourceUrl(url)`.
* **Output Gradient**: Enhances saturation and produces a 3-stop vertical gradient:
  $$\left[\text{primary},\ \text{primary} \times 0.6,\ \text{Color.Black}\right]$$

---

## 6. Section D: Architectural Secrets for Smoothness

1. **`collectLatestWhileVisible` Lifecycle Scoping**:
   Metrolist wraps background flow collections in `collectLatestWhileVisible(LocalVisualWorkActive.current)`. When the player sheet is collapsed, lyrics parsing, timing recalculations, and canvas frame loops are suspended.
2. **Compose Transformation Offloading (`graphicsLayer`)**:
   Animations for line alpha, scale, and scroll translation are applied exclusively inside `Modifier.graphicsLayer { ... }`. Because graphic layer properties alter render node matrices directly, they trigger neither Compose composition nor layout passes.
3. **Prewarmed Text Layout & Alpha Masks**:
   Glyph alpha masks and sub-layout measurements are computed in background launched effects and cached in `ClusterMaskCache`, eliminating frame drops during initial line highlights.
4. **Structural Equality Isolation**:
   By enforcing `derivedStateOf(structuralEqualityPolicy())`, frame-by-frame position changes in `LongState` are prevented from triggering recompositions across the parent LazyColumn.

---

## 7. License Compatibility Analysis

* **Metrolist License**: GNU General Public License v3.0 (GPL-3.0) (`LICENSE` file in root).
* **Softify License**: GNU General Public License v3.0 (GPL-3.0) (`LICENSE` file in root).

### Legal Compatibility Verdict:
**Full GPL-3.0 Compatibility**. Both projects share the identical copyleft license. Algorithms, mathematical models, regex patterns, and architectural code from Metrolist may be adopted into Softify under the terms of GPL-3.0 with attribution to the Metrolist contributors.

### Cross-Platform (KMP) Architecture Boundaries:
Softify is a Kotlin Multiplatform project running on Android and Desktop (JVM), with a Rust core (`softify_core`). While Metrolist is also KMP, certain Android-specific integrations in Metrolist (e.g. `android.graphics.Bitmap`, Android `Context`) must be abstracted:
1. **Lyrics Providers**: Should be implemented in Softify's Rust core (`softify_core/src/lyrics/`) to ensure Desktop and Android share identical provider logic without duplicating Kotlin code.
2. **Lyrics Canvas & UI**: Pure Compose Multiplatform implementation using `TextMeasurer` and `Brush.linearGradient`.
3. **Color Extraction**: Utilize `com.materialkolor:material-kolor` (KMP) rather than Android-only `Palette`.

---

## 8. Prioritized Softify Gap Analysis & Recommendations

### Category 1: Adopt Directly (Clean Algorithms & Standards)

1. **Adopt Four-Stop Linear Gradient Shader for Lyrics Highlight**:
   * *Problem in Softify*: Softify builds a vector `Path` and calls `clipPath()` on every draw frame. This causes high CPU overhead and GPU pipeline stalls on devices like the Moto G34.
   * *Solution*: Adopt Metrolist's `drawWipeText()` pattern: measure the line with `TextMeasurer`, and draw the active word with `Brush.linearGradient(0.0f to lit, 0.1f to lit, 0.9f to unlit, 1.0f to unlit)` across the word's bounds.

2. **Adopt YouTube CDN Sizing Buckets & URL Rewriting**:
   * *Problem in Softify*: Softify requests arbitrary thumbnail dimensions or unoptimized high-res URLs in list rows.
   * *Solution*: Adopt `ArtworkUrl.kt` bucketing: 256px for lists/mini-player, 544px for shelves, 1200px for now playing. Include the `mqdefault` fallback when `maxresdefault` returns 404.

3. **Adopt Negative Caching for Lyrics (7-day TTL)**:
   * *Problem in Softify*: Softify repeatedly queries LRCLIB for tracks that have no lyrics, causing unnecessary network requests.
   * *Solution*: When all providers return empty, store a negative cache marker in SQLite with `miss_expires_at = now + 7 days`.

4. **Adopt Monotonic Clock with Visibility Gating**:
   * *Problem in Softify*: Frame clock loops run continuously when the screen is off or the view is hidden.
   * *Solution*: Gate `withFrameNanos` behind UI visibility (`LocalVisualWorkActive`), freezing ticks during pauses or when collapsed.

---

### Category 2: Re-Implement in Softify Core (Rust & KMP)

5. **Multi-Provider Lyrics Engine in Rust (`softify_core`)**:
   * *Problem in Softify*: Softify relies solely on LRCLIB. If LRCLIB lacks word timings, playback has no synced lyrics.
   * *Action*: Port Metrolist's keyless provider fetchers into Rust:
     * `BetterLyricsProvider`: `https://lyrics-api.boidu.dev/getLyrics` (Apple Music TTML)
     * `LrcredLyricsProvider`: `https://lrc.red/api/v1` (TTML)
     * `YouTubeSubtitleProvider`: InnerTube `fmt=json3` caption tracks with word-level `tOffsetMs`.
     * `KuGouLyricsProvider`: KuGou search and download APIs for line-synced fallbacks.

6. **Eliminate Character-Count Word Timing Estimation**:
   * *Problem in Softify*: When word timings are missing, Softify's `estimateWordsForLine` divides line duration across words by character length. This creates artificial sweeps that desync from the singer.
   * *Action*: Adopt Metrolist's strict rule: if a track is line-timed, set `is_word_synced = false` and highlight the entire line on line boundaries without faking word sweeps.

7. **Implement Artwork Prefetch Window for Scrollable Lists**:
   * *Problem in Softify*: Fast scrolling through library or search rows causes blank image pop-in.
   * *Action*: Implement `ArtworkPrefetchWindow` observing `LazyListState.layoutInfo.visibleItemsInfo` with a 10-item lookahead, enqueuing 128px thumbnails in Coil.

8. **FLIP Spring Scroll for Lyrics Auto-Scroll**:
   * *Problem in Softify*: Softify calls `animateScrollToItem()`, which fights user touches and restarts on every frame update.
   * *Action*: Implement instantaneous list offset shifts (`scrollBy`) combined with spring-interpolated `graphicsLayer { translationY = ... }` and a 400ms suppression lock during user drag gestures.
