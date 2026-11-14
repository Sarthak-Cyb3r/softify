# Softify — Application Screens & Structural Architecture Specification
> **UI/UX Revamp Baseline for Google Stitch**  
> This document specifies the structural anatomy, information architecture, component hierarchy, and platform-specific layout wireframes for every screen in Softify across **Mobile (Android/iOS)** and **Desktop (Linux)**.  
> *Note: Styling tokens, color schemes, and visual ornaments are intentionally omitted to serve as a pure functional blueprint for the Google Stitch redesign.*

---

## 1. Global Application Shell (`AppScaffold`)

### Purpose
The foundational layout container orchestrating persistent navigation, playback docking, global keyboard shortcuts, and responsive breakpoints between desktop and mobile.

### Mobile Layout Structure (`< 800px`)
- **Top Area**: Dynamic viewport displaying the currently active screen.
- **Docked Floating Mini-Player** (visible whenever a track is loaded/playing):
  - Thumbnail artwork (square, left).
  - Track title & artist marquee text (center).
  - Play/Pause toggle button (right).
  - Next track button (right).
  - Tap container trigger -> opens **Full Screen Player**.
  - Swipe horizontal trigger -> skip next/previous track.
- **Slim Bottom Navigation Bar** (anchored at bottom):
  - Fixed tab items with icon + label:
    1. Home
    2. Search
    3. YouTube Stream Resolver
    4. Podcasts
    5. Library
    6. Settings

### Linux / Desktop Layout Structure (`>= 800px`)
- **Two-Column Master Split Layout**:
  - **Left Persistent Sidebar (`desktop_sidebar.dart`)** (fixed width `240px`–`280px`):
    - Brand Header: Softify logo icon + App name title.
    - Quick Search Input Pill (`Ctrl+K` shortcut indicator).
    - Primary Navigation List (Vertical icon + label items with active state pill):
      - Home
      - Search
      - YouTube Resolver
      - Podcasts
      - Library
      - Equalizer / DSP
      - Settings
    - Quick Access Section:
      - "Liked Songs" shortcut button.
      - "Downloaded Tracks" shortcut button.
      - Pinned user playlists list (scrollable).
    - Footer / Utilities:
      - Global shortcut hints (`Space` = Play/Pause, `Ctrl+Right` = Next).
  - **Right Main Content Viewport** (fluid width, vertically scrollable):
    - Displays active page content.
- **Persistent Full-Width Bottom Player Bar (`desktop_player_bar.dart`)** (anchored across full width `80px` height):
  - **Left Column** (`240px` width):
    - Track thumbnail artwork.
    - Track title (auto-scroll ticker on overflow).
    - Artist name (tappable to Artist detail).
    - Favorite / Heart toggle button.
  - **Center Column** (flex grow):
    - Transport Controls Row (centered):
      - Shuffle toggle button.
      - Previous track button.
      - Play / Pause button (prominent).
      - Next track button.
      - Repeat mode toggle button (Off / All / One).
    - Scrubber Row:
      - Current elapsed timestamp (monospace).
      - Interactive seek progress slider with buffered track indicator.
      - Total duration / remaining timestamp (monospace).
  - **Right Column** (`240px` width, trailing):
    - Variable playback speed pill (for podcasts/YouTube).
    - Lyrics toggle button (`L` shortcut indicator).
    - Sleep timer button.
    - Queue drawer button.
    - Volume icon (mute toggle).
    - Volume slider (horizontal).

---

## 2. Home Screen (`HomeScreen`)

### Purpose
Primary discovery and daily listening hub featuring personalized greetings, recently played items, and dynamic algorithmic recommendation shelves.

### Mobile Layout Structure
- **Sticky / Scrolling Header**:
  - Time-contextual greeting ("Good morning", "Good afternoon", "Good evening").
  - Softify brand icon.
  - Action icons row:
    - Wrapped Insights story trigger button.
    - Offline-only mode toggle badge.
- **Recently Played Shelf**:
  - Section header: "Recently Played" + "See All" action.
  - Horizontal scroll carousel with square card items:
    - Cover artwork.
    - Title (1-line truncated).
    - Subtitle / artist name.
    - Tap trigger -> immediate stream playback.
- **Dynamic Content Shelves** (vertical list of shelves):
  - **Heavy Rotation / Quick Picks Shelf**: 2x2 or 2x3 bento grid of compact rectangular cards (artwork left, title + play button right).
  - **Made For You Shelf**: Horizontal card carousel of algorithmic mix playlists.
  - **Recommended Artists Shelf**: Circular artist avatar cards with artist name and follower count.
  - **Daily Fresh Releases Shelf**: Horizontal carousel of recently discovered studio recordings.

### Linux / Desktop Layout Structure
- **Wide Top Header**:
  - Left: Large greeting title + listening summary badge.
  - Right: Quick action pills (Wrapped Insights, Offline toggle, Refresh).
- **Responsive Multi-Column Content Grid** (4 to 6 columns based on window width):
  - Recently Played cards with hover overlay showing a quick "Play" button.
- **Shelves Section**:
  - Grid rows with clear section titles and horizontal/carousel overflow controls.

---

## 3. Search & Discovery Screen (`SearchScreen`)

### Purpose
Instant multi-source music search engine with search history, category filtering, and real-time deduplicated studio recordings.

### Mobile Layout Structure
- **Top Search App Bar**:
  - Search text input field with leading search icon, clear button (`X`), and auto-focus.
- **Filter Chips Bar** (horizontal scrollable pills):
  - "All", "Songs", "Albums", "Artists", "Playlists".
- **Default State** (when query is empty):
  - **Recent Searches Section**: Header with "Clear All" action, chips or list of past queries with remove icon.
  - **Browse Categories / Top Genres Grid**: 2-column card grid of music genres/moods.
- **Active Search Results State**:
  - Instant Deduplicated Results List (vertical list):
    - Track item:
      - Square album artwork thumbnail.
      - Song title (with original studio master badge if matched).
      - Artist & album name subtitle.
      - Song duration.
      - 3-dot overflow options menu button.
      - Tap trigger -> starts playback.

### Linux / Desktop Layout Structure
- **Centered Search Bar**:
  - Prominent search input with keyboard indicator `[Ctrl+K]`.
- **Category Filter Pills**:
  - Aligned below search bar.
- **Tabular Results Layout**:
  - Top Result Hero Card (featured artist or best-match song card with large artwork and play button).
  - Songs Results Table:
    - Columns: `#`, `Title & Artist`, `Album`, `Duration`, `Options Menu`.
  - Albums & Artists Row: Horizontal carousel or card grid below songs table.

---

## 4. Library Screen (`LibraryScreen`)

### Purpose
Centralized personal collection hub managing playlists, liked tracks, offline cached files, local storage music, and cloud backups.

### Mobile Layout Structure
- **Top Header Bar**:
  - Title: "Your Library".
  - Action buttons: Add Playlist (`+`), Search in library, Backup/Export database menu.
- **Category Filter Pills Bar** (horizontal scroll):
  - "Playlists", "Liked Songs", "Downloads", "Local Music", "History".
- **Tab Views / Sections**:
  - **Playlists View**:
    - "Create New Playlist" card (leading item).
    - Custom user playlists (title, track count, mosaic artwork).
    - Imported Spotify playlists.
  - **Liked Songs View**:
    - Big Shuffle Play button at top.
    - Vertical list of all favorited songs.
  - **Downloads / Offline View**:
    - Storage Usage Bar (shows cached MB/GB used).
    - "Open Downloads Folder" action button.
    - List of downloaded offline M4A tracks with offline badge.
  - **Local Music View**:
    - "Scan Device Audio" button.
    - "Open Local Audio Folder" action button.
    - List of scanned MP3/FLAC/WAV audio files on device storage.
  - **History View**:
    - Chronological list of previously played tracks with date/time stamps.

### Linux / Desktop Layout Structure
- **Master Header Bar**:
  - Library title, search field, "Create Playlist" button, and "Backup/Restore" dropdown.
- **Multi-Tab or Filter Segment Control**:
  - Tabs: Playlists, Liked Songs, Downloads, Local Audio, History.
- **Native Desktop Integrations**:
  - Dedicated "Open Downloads Folder" button (launches desktop file manager e.g. Nautilus/Dolphin).
  - Dedicated "Open Local Music Folder" button.
- **Grid / Table Switcher**:
  - Toggle between Grid card view and List table view.

---

## 5. Full Screen Player Screen (`FullScreenPlayerScreen`)

### Purpose
Immersive, distraction-free playback screen with album art, tactile playback controls, high-precision scrubber, and quick access to lyrics, queue, and timer.

### Mobile Layout Structure
- **Top Navigation Bar**:
  - Down chevron icon (collapses screen down to Mini-Player).
  - Track Title & Artist marquee ticker (center).
  - Track options 3-dot overflow menu (right).
- **Center Visual Area**:
  - Dynamic ambient mesh backdrop derived from artwork palette.
  - Concentric Double-Bezel Album Artwork container (square aspect ratio).
  - *Alternative display mode*: Interactive rotating CD disc animation for artist tracks.
  - Tap artwork -> toggles real-time Synced Karaoke Lyrics view.
- **Track Information Row**:
  - Track title (large, 2-line max).
  - Artist name (tappable -> navigates to Artist detail).
  - Heart / Favorite button (toggles liked status).
- **High-Resolution Scrubber Row**:
  - Progress slider with buffered progress track.
  - Elapsed timestamp (left, monospace).
  - Total duration / remaining timestamp (right, monospace).
- **Primary Playback Transport Controls**:
  - Shuffle toggle button.
  - Previous track button.
  - Large Play / Pause morph button.
  - Next track button.
  - Repeat mode toggle button (Off / Repeat All / Repeat One).
- **Bottom Utility Actions Bar**:
  - Speed playback pill (displays `1.0x`, `1.25x`, etc.; visible only on Podcasts/YouTube).
  - Sleep Timer icon button.
  - Synced Lyrics toggle button.
  - Playback Queue icon button.

### Linux / Desktop Structure
- *On Desktop, standard player controls reside in the persistent bottom player bar.*
- When user clicks **"Expand Player" / Fullscreen Mode**:
  - **Split View Layout**:
    - **Left Half**: Oversized album artwork, track title, artist link, favorite button, large scrubber, and full playback controls.
    - **Right Half**: Full-height, auto-scrolling Synchronized Karaoke Lyrics panel.

---

## 6. Synced Karaoke Lyrics View (`LyricsView`)

### Purpose
Live karaoke-style synchronized lyrics viewer powered by LRCLIB, offering real-time highlighting and tap-to-seek audio navigation.

### Mobile & Desktop Shared Structure
- **Header**:
  - Track title & artist subtitle.
  - Lyrics sync status indicator ("Synced" vs "Plain Text").
  - Close / Collapse button.
- **Lyrics Display Area** (vertical scroll view):
  - **Synchronized Mode**:
    - List of timed lyric lines.
    - Active lyric line: elevated scale, bright contrast, smoothly auto-scrolled to center.
    - Inactive / upcoming lines: muted contrast, lower opacity.
    - **Tap-any-line interaction**: Tapping a lyric line seeks audio playback directly to that timestamp.
  - **Plain Text Mode** (when timestamps unavailable):
    - Full scrollable text transcript of lyrics.
  - **No Lyrics Available Mode**:
    - Empty state graphic with message: "Lyrics not available for this track".
- **Footer**:
  - Attribution notice: "Lyrics provided by LRCLIB".

---

## 7. Equalizer & Audio DSP Screen (`EqualizerScreen`)

### Purpose
Hardware audio tuning console providing 10-band parametric frequency adjustment, preset configurations, bass boost, and loudness maximization on Android and Linux.

### Mobile & Linux Shared Structure
- **Top App Bar**:
  - Title: "Equalizer".
  - Master Enable / Bypass toggle switch.
- **A/B Audition Comparison Button**:
  - "Hold to Audition Original Sound" button (temporarily bypasses all EQ/DSP filters while held to hear instant before-and-after difference).
- **Presets Selector Shelf**:
  - Horizontal scrollable pill chips:
    - "Flat", "Bass Booster", "Bass Reducer", "Vocal Booster", "Treble Booster", "Rock", "Pop", "Jazz", "Electronic", "Classical", "Custom".
- **Real-Time Frequency Response Curve Visualizer**:
  - Interactive Bézier curve visualizer rendering the combined dB response line across all 10 frequency points.
- **10-Band Parametric Frequency Sliders**:
  - Frequency bands: **31 Hz, 62 Hz, 125 Hz, 250 Hz, 500 Hz, 1 kHz, 2 kHz, 4 kHz, 8 kHz, 16 kHz**.
  - Each band contains:
    - Gain indicator badge (e.g. `+4.0 dB`, `-2.5 dB`).
    - Vertical slider spanning `-15 dB` to `+15 dB` with center zero detent.
    - Frequency label.
- **Audio Enhancers Section**:
  - **Bass Boost Slider**: Slider from `0%` to `100%` with percentage badge.
  - **Loudness Maximizer Slider**: Slider from `0%` to `100%` with percentage badge.
  - **Loudness Normalization Toggle**: Switch enabling uniform volume leveling across disparate audio sources.

### Desktop Adaptation
- On wide screens, the visualizer sits on top or side-by-side with presets, and the 10 frequency sliders span horizontally in a studio hardware rack layout.

---

## 8. YouTube Stream Resolver Page (`YoutubePage`)

### Purpose
Direct link parser extracting and streaming high-fidelity audio directly from YouTube and YouTube Music URLs without video overhead or advertisements.

### Mobile & Linux Shared Structure
- **Header**:
  - Title: "YouTube Stream Resolver".
  - Subtitle explaining direct URL playback.
- **Input & Action Card**:
  - URL Text Input Field (supports `youtube.com/watch?v=`, `youtu.be/`, `music.youtube.com/`).
  - "Paste from Clipboard" button.
  - "Resolve & Stream" action button.
- **Resolved Media Preview Card** (displayed upon successful resolution):
  - Video thumbnail image.
  - Video title.
  - Channel / Author name.
  - Duration badge.
  - Stream quality metadata (e.g. Opus 160kbps / AAC).
  - Action buttons row:
    - "Play Now".
    - "Add to Queue".
    - "Download for Offline".
- **Playback Speed Controller** (visible during playback):
  - Variable speed selector chips: `0.5x`, `0.75x`, `1.0x`, `1.25x`, `1.5x`, `2.0x`.
- **Recent Resolutions History**:
  - List of previously resolved YouTube tracks with 1-tap replay.

---

## 9. Podcasts Page (`PodcastPage`)

### Purpose
Dedicated podcast player supporting custom RSS feed subscriptions, episode directories, episode notes, and voice-optimized playback controls.

### Mobile & Linux Shared Structure
- **Top Header & Search**:
  - RSS Feed URL input bar / podcast search field.
  - "Subscribe" action button.
- **Subscribed Shows Shelf**:
  - Horizontal carousel of podcast cover art with show titles.
- **Show Detail View**:
  - Podcast cover image.
  - Podcast title & publisher.
  - Show description.
  - Unsubscribe / Share buttons.
- **Episode List View**:
  - Vertical list of episodes:
    - Episode publication date.
    - Episode title.
    - Episode summary / show notes snippet.
    - Duration badge.
    - Play / Stream button.
    - Download for offline button.
- **Voice-Specific Playback Controls** (in player bar):
  - 15-second skip backward button.
  - 30-second skip forward button.
  - Speed modifier selector (`0.5x` to `2.0x`).

---

## 10. Album Detail Screen (`AlbumDetailScreen`)

### Purpose
Comprehensive album presentation screen showcasing album metadata, complete tracklists, release dates, and batch playback controls.

### Mobile Layout Structure
- **Collapsible Hero Header**:
  - Album cover artwork (large, centered).
  - Album title (bold display).
  - Artist name (tappable -> navigates to Artist detail).
  - Metadata row: Release year • Track count • Total duration.
- **Action Bar**:
  - Prominent "Play All" button.
  - "Shuffle" button.
  - Favorite / Save Album toggle icon.
  - Album options 3-dot menu.
- **Tracklist Section**:
  - Indexed track items:
    - Track index number (`1`, `2`, `3`...).
    - Song title.
    - Artist name(s) (if featured).
    - Duration badge.
    - 3-dot options menu.
    - Tap -> plays selected song within album context.

### Linux / Desktop Layout Structure
- **Two-Column Master-Detail Layout**:
  - **Left Sticky Column**: Large album artwork, title, artist link, metadata tags, Play All and Shuffle buttons.
  - **Right Scrollable Column**: Full tracklist formatted as a clean table with columns: `#`, `Title`, `Duration`, `Options`.

---

## 11. Artist Detail & Discography Screens (`ArtistDetailScreen` & `ArtistDiscographyScreen`)

### Purpose
Artist profile hub displaying popular songs, discography categorized by release type (Albums, Singles, EPs), artist bio, and follower metrics.

### Mobile Layout Structure
- **Artist Hero Header**:
  - Full-width artist banner / circular avatar image.
  - Artist name.
  - Monthly listeners counter / verified badge.
  - "Follow" / "Favorite" artist button.
- **Popular Tracks Shelf**:
  - Section header: "Popular Songs".
  - Top 5-10 songs with artwork thumbnail, play count ranking, and duration.
- **Discography Shelves**:
  - "Albums" horizontal carousel.
  - "Singles & EPs" horizontal carousel.
  - "Appears On / Compilations" horizontal carousel.
  - "View All Discography" button -> opens `ArtistDiscographyScreen`.
- **Artist Discography Screen** (`ArtistDiscographyScreen`):
  - Filter tabs: "All", "Albums", "Singles & EPs".
  - 2-column grid of release cards (artwork, release title, year).

### Linux / Desktop Layout Structure
- **Hero Banner Area**: Wide cinematic artist backdrop with overlaid title, listener count, Play Artist button, and Follow toggle.
- **Multi-Section Content**: Popular tracks table followed by responsive card grids for each release category.

---

## 12. Playlist Detail Screen (`PlaylistDetailScreen`)

### Purpose
User playlist management interface supporting custom name/description edits, track reordering, track removal, and batch playback.

### Mobile Layout Structure
- **Playlist Header**:
  - 4-album mosaic artwork container or custom playlist artwork.
  - Playlist title (tappable to edit).
  - Playlist description / creation date.
  - Total tracks count and estimated playback duration.
- **Action Bar**:
  - "Play All" button.
  - "Shuffle" button.
  - "Add Songs" button (`+`).
  - Playlist options menu (Edit, Delete, Export).
- **Interactive Tracklist**:
  - Vertical list of songs.
  - Drag handles for real-time drag-and-drop reordering.
  - Swipe-to-delete track interaction.
  - 3-dot track options menu.

### Linux / Desktop Layout Structure
- **Wide Header Banner**: Playlist mosaic, editable title, description, and action buttons.
- **Tabular Song List**: Columns for `#`, `Title`, `Artist`, `Album`, `Date Added`, `Duration`, `Reorder Drag Handle`, and `Remove`.

---

## 13. Spotify Playlist Importer Screen (`SpotifyImportScreen`)

### Purpose
Seamless migration pipeline allowing users to import public or private Spotify playlists directly into Softify's offline Drift SQLite database.

### Mobile & Linux Shared Structure
- **Top Header**:
  - Title: "Import Spotify Playlist".
  - Explanatory description of the matching pipeline.
- **Input Methods Card**:
  - Public Playlist URL input field + "Paste" button.
  - *Alternative*: "Connect Spotify Account" button (OAuth) for importing personal private playlists.
- **Import Progress & Live Diagnostics Card** (active during processing):
  - Progress indicator bar.
  - Counter: "Extracting tracks (e.g. 24 / 50)...".
  - Live resolution log: Matches found in JioSaavn 320kbps Studio Masters vs YouTube Music fallbacks.
- **Resolution Summary & Confirmation**:
  - Total tracks extracted.
  - Perfect studio master matches count.
  - Fallback matches count.
  - Unmatched tracks list (if any).
  - "Import to Softify Library" primary action button.

---

## 14. Settings Screen (`SettingsScreen`)

### Purpose
Centralized configuration console for streaming quality, audio processing, local cache management, desktop RPC, and legal transparency.

### Mobile Layout Structure (Grouped Vertical Cards)
- **Audio Streaming Quality Card**:
  - Selection chips / radio list:
    - Low (96 kbps)
    - Medium (160 kbps)
    - Studio Master (320 kbps Extreme Quality)
- **Audio Processing & DSP Card**:
  - Link to Equalizer & DSP console.
  - Auto-Mix / Smart Transition toggle (smooth continuous tail blending).
- **Storage, Cache & File Management Card**:
  - Current cache size counter.
  - "Clear Streaming Cache" action button.
  - "Open Saved Songs Folder" action button (opens system file explorer).
- **Desktop Integrations Card** (Linux):
  - Discord Rich Presence toggle switch.
  - Connection status badge ("Connected" / "Disabled").
- **Appearance & Theme Card**:
  - Theme mode selector (AMOLED Pure Black vs Midnight Obsidian).
- **Library & Data Management Card**:
  - Spotify Playlist Importer link.
  - "Export Library Backup" (generates JSON file).
  - "Restore Library Backup" (restores from JSON file).
- **About & Legal Card**:
  - App Version badge (`v2.0.x`).
  - GitHub project repository link.
  - GPL-3.0 License view button.
  - **Mandatory Legal Disclaimer**: Explicit notice stating educational/personal use and non-affiliation with Spotify/YouTube/JioSaavn.

### Linux / Desktop Layout Structure
- **Two-Column Categorized Settings**:
  - Left navigation list: Audio, Storage, Integrations, Appearance, Backup, About.
  - Right content area: Detailed configuration card for the selected category.

---

## 15. Car Mode Screen (`CarModeScreen`)

### Purpose
High-contrast, simplified driver-friendly interface designed for vehicle dashboard mounts with oversized touch targets and minimal distraction.

### Mobile / Tablet Layout Structure
- **Top Bar**:
  - "Exit Car Mode" button (`X`, large touch target).
  - Bluetooth connection indicator.
- **Center Display**:
  - Oversized square Album Artwork.
  - Massive Track Title (high-contrast text).
  - Massive Artist Name.
- **Oversized Controls Row**:
  - Big Previous Track button.
  - Massive Play / Pause toggle button.
  - Big Next Track button.
- **Bottom Action**:
  - Giant Heart / Favorite toggle button.

---

## 16. Queue Bottom Sheet / Modal (`QueueBottomSheet`)

### Purpose
Playback queue inspector displaying current song, upcoming manual queue, and algorithmic automix tails with reordering capabilities.

### Mobile & Linux Shared Structure
- **Sheet Header**:
  - Title: "Play Queue".
  - "Clear Queue" action button.
  - Close button.
- **Now Playing Card**:
  - Thumbnail artwork, track title, artist, live waveform animation.
- **"Up Next" Section**:
  - Vertical list of manually queued songs.
  - Drag handles for position reordering.
  - Swipe or tap `X` to remove from queue.
- **"Automix / Smart Tail" Section**:
  - List of songs queued automatically based on taste profile.
  - Badge: "Continuous Automix".

---

## 17. Sleep Timer Bottom Sheet (`SleepTimerBottomSheet`)

### Purpose
Time-delayed playback shutdown tool offering preset durations, track-boundary stops, and live countdowns.

### Mobile & Linux Shared Structure
- **Sheet Header**:
  - Title: "Sleep Timer".
  - Close button.
- **Preset Duration Chips**:
  - `15 Minutes`, `30 Minutes`, `45 Minutes`, `60 Minutes`, `End of Current Track`.
- **Custom Duration Input**:
  - Numeric minutes input or slider.
- **Active Timer State** (when running):
  - Live countdown display: `MM:SS remaining`.
  - "Turn Off Timer" action button.

---

## 18. Track Options Bottom Sheet / Context Menu (`TrackOptionsBottomSheet`)

### Purpose
Actionable context menu providing full track-level operations across playback, playlists, artist discovery, and downloads.

### Mobile & Linux Shared Structure
- **Track Identity Header**:
  - Album artwork thumbnail.
  - Track title.
  - Artist name.
  - Audio format badge (e.g., `320kbps M4A`).
- **Vertical Action Items List**:
  1. Favorite / Liked toggle (Heart icon).
  2. Add to Playlist (`+` icon).
  3. Play Next (insert at front of queue).
  4. Add to End of Queue.
  5. Go to Album (navigates to `AlbumDetailScreen`).
  6. Go to Artist (navigates to `ArtistDetailScreen`).
  7. Download for Offline Playback.
  8. View Synchronized Lyrics.
  9. Set Sleep Timer.
  10. Share Track Link.

---

## 19. Wrapped & Insights Story Dialog (`WrappedInsightsDialog`)

### Purpose
Interactive multi-slide storytelling review presenting listening statistics, top songs, and favorite artists with shareable story exports.

### Mobile & Linux Shared Structure
- **Story Header**:
  - Progress segments bar (indicating current slide 1 of 5).
  - Close button (`X`).
- **Interactive Story Slides**:
  - **Slide 1 — Total Listening Time**: Large total minutes/hours streamed counter and comparison stats.
  - **Slide 2 — Top Tracks**: Ranked #1 to #5 most-played songs with artwork and play counts.
  - **Slide 3 — Top Artists**: Primary artist spotlight with affinity percentage.
  - **Slide 4 — Listening Habits**: Peak listening hour chart (Morning, Afternoon, Evening, Night Owl).
  - **Slide 5 — Genre & Taste Breakdown**: Primary genres graph and musical taste summary.
- **Interactive Controls**:
  - Tap left half -> previous slide.
  - Tap right half -> next slide.
  - Press and hold -> pause story progression.
- **Footer**:
  - "Share Story Card" action button.

---

## 20. First-Run Terms & Conditions Dialog (`TermsAndConditionsDialog`)

### Purpose
Mandatory initial launch compliance modal ensuring clear user agreement to non-commercial, educational use.

### Mobile & Linux Shared Structure
- **Header**:
  - Softify logo + Title: "Welcome to Softify".
- **Body Content** (scrollable):
  - Non-commercial and personal use terms.
  - Explicit disclaimer of non-affiliation with Spotify, YouTube, or JioSaavn.
  - Notice confirming no copyrighted files are hosted by the application.
- **Action Buttons**:
  - "I Understand & Accept" (primary action button).
  - "Decline & Exit" (closes application).

---

## 21. Onboarding Screen (`OnboardingScreen`)

### Purpose
Initial welcome flow introducing key application pillars (zero ads, 320kbps audio, offline mode) and setting default streaming quality.

### Mobile & Linux Shared Structure
- **Hero Area**:
  - App Logo and punchy tagline.
- **Feature Highlights List**:
  - Feature 1: Pure 320kbps CD-Quality Audio Masters.
  - Feature 2: 100% Ad-Free, Account-Free & Private.
  - Feature 3: Real-Time Synced Karaoke Lyrics.
  - Feature 4: High-Fidelity Offline Downloads.
- **Initial Setup Step**:
  - Streaming audio quality selection chips (`96k`, `160k`, `320k`).
- **Footer**:
  - "Get Started" primary action button.

---

## Summary Matrix: Screen & Platform Breakdown

| # | Screen / Surface | Mobile Layout Type | Linux / Desktop Layout Type | Key Interactive Triggers |
|---|---|---|---|---|
| 1 | **Global Shell (`AppScaffold`)** | Bottom Nav + Mini Player | Left Sidebar + Bottom Player Bar | Navigation, Play/Pause, Seek, Volume, Shortcuts |
| 2 | **Home (`HomeScreen`)** | Single column + Carousels | Multi-column Grid (4-6 cols) | Quick Play, Wrapped, Offline toggle |
| 3 | **Search (`SearchScreen`)** | Top Search Bar + Filter Pills + List | Centered Search (`Ctrl+K`) + Results Table | Search typing, Category filters, Track options |
| 4 | **Library (`LibraryScreen`)** | Filter Chips + Section Lists | Master-Detail Grid / Table | Add Playlist, Open Folders, Backup JSON |
| 5 | **Full Player (`FullScreenPlayerScreen`)** | Full Viewport + Swipes | Persistent Bar or Split Screen | Scrubber, Transport, Lyrics, Timer, Queue |
| 6 | **Lyrics (`LyricsView`)** | Karaoke Sheet + Tap to Seek | Split Right Panel or Modal | Tap line to seek, Scroll |
| 7 | **Equalizer (`EqualizerScreen`)** | Scrollable Sliders + Visualizer | Studio Rack Sliders + Visualizer | 10 band sliders, Presets, A/B Audition |
| 8 | **YouTube (`YoutubePage`)** | Input + Stream Card | Wide Input + Stream Preview Card | Resolve link, Speed pills, Play stream |
| 9 | **Podcasts (`PodcastPage`)** | RSS Input + Feed List | Wide Feed + Episode Notes Table | 15s/30s skip, Speed control, Subscribe |
| 10 | **Album Detail (`AlbumDetailScreen`)** | Collapsible Hero + Tracklist | Sticky Left Hero + Right Songs Table | Play All, Shuffle, Track options |
| 11 | **Artist Detail (`ArtistDetailScreen`)** | Artist Hero + Top Tracks + Shelves | Wide Cinematic Banner + Discography Grid | Follow, Top Songs, Full Discography |
| 12 | **Playlist Detail (`PlaylistDetailScreen`)**| Mosaic Header + Drag Reorder List | Wide Banner + Drag/Drop Table | Edit title, Reorder tracks, Delete |
| 13 | **Spotify Importer (`SpotifyImportScreen`)**| URL Input + Progress + Summary | Wide URL Card + Live Match Log | Match resolution, 1-click import |
| 14 | **Settings (`SettingsScreen`)** | Grouped Accordion / Card List | Two-Column Categorized View | Quality picker, Cache clear, Discord RPC |
| 15 | **Car Mode (`CarModeScreen`)** | Giant Touch Targets + Big Art | N/A (Mobile/Tablet oriented) | Giant Play/Pause, Next, Prev, Exit |
| 16 | **Queue (`QueueBottomSheet`)** | Bottom Sheet with Drag Handles | Popover Panel / Modal | Reorder queue, Clear queue, Automix |
| 17 | **Sleep Timer (`SleepTimerBottomSheet`)** | Duration Pills + Countdown | Popover Panel / Modal | Set timer, Cancel countdown |
| 18 | **Track Options (`TrackOptionsBottomSheet`)**| Bottom Action Sheet | Context Menu / Popover | Add playlist, Download, Album/Artist nav |
| 19 | **Wrapped Insights (`WrappedInsightsDialog`)**| 5-Slide Story Carousel | 5-Slide Modal Carousel | Tap advance, Pause hold, Share card |
| 20 | **Terms Dialog (`TermsAndConditionsDialog`)**| Modal Dialog | Modal Dialog | Accept, Decline |
| 21 | **Onboarding (`OnboardingScreen`)** | Hero Splash + Quality Picker | Centered Hero Setup Card | Select quality, Get Started CTA |
