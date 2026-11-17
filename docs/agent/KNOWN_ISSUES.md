# Known Issues & Architectural Constraints

## 1. Android 11+ Scoped Storage & Local File Scanning
- **Constraint**: On Android 11+ (API 30+), direct filesystem traversal (`walkdir` across arbitrary `/storage/emulated/0/...` paths) is blocked by Scoped Storage enforcement unless granted `MANAGE_EXTERNAL_STORAGE` (prohibited for general audio apps on Google Play).
- **Current State**: The Rust local scanner (`softify_core::scanner::local`) implements high-performance parallel file walking and tag extraction via `walkdir` + `rayon` + `lofty` for desktop/Linux and app-specific directories.
- **Resolution Plan**: For general user music scanning on Android, an Android-specific bridge must query `MediaStore.Audio.Media.EXTERNAL_CONTENT_URI` or consume Android Storage Access Framework (SAF) tree URIs via JNI/UniFFI file descriptor handles (`ParcelFileDescriptor`), passing opened handles to the metadata parser.

## 2. Spotify Embed API Truncation & Schema Fragility
- **Constraint**: The keyless Spotify scraper consumes open embed HTML (`https://open.spotify.com/embed/playlist/<id>`) by deserializing `__NEXT_DATA__`. Spotify embed pages cap returned track lists at approximately 100 tracks and omit full pagination keys for large playlists.
- **Risk**: Spotify can modify internal Next.js React hydration structures or obfuscate `__NEXT_DATA__` without notice.
- **Resolution Plan**: 
  - For playlists exceeding 100 tracks, provide user feedback stating embed limit.
  - Maintain fallback parsers or allow optional user-provided Spotify Client ID / Client Secret in Settings for official Web API pagination when importing large playlists (> 100 tracks).

## 3. Android Storage Access Framework (SAF) Directory Picker
- **Constraint**: Arbitrary user folder selection for local music directories requires Android `ACTION_OPEN_DOCUMENT_TREE` and persistent URI permission grants (`takePersistableUriPermission`).
- **Status**: The local folder picker in Settings is deferred to M4 alongside the download manager and offline local library scanner. In M3b, the core focuses on streaming, library playlists, and Smart Playlists.
