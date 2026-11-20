pub mod config;
pub mod db;
pub mod downloads;
pub mod importer;
pub mod lyrics;
pub mod models;
pub mod reco;
pub mod resolvers;
pub mod scanner;
pub mod search;

use config::ConfigManager;
use db::repository::DatabaseRepository;
use downloads::manager::DownloadManager;
use importer::spotify::SpotifyImporter;
use lyrics::engine::LyricsEngine;
use models::{
    DownloadItem, DownloadProgressCallback, ImportPlaylistResult, PlayHistory, Playlist,
    ProviderHealth, QualityPreset, RadioResult, ScanProgressCallback, ScanResult, SearchResult,
    Shelf, SoftifyError, StreamInfo, SyncedLyrics, Track,
};
use reco::diversity::DiversityController;
use reco::shelves::ShelfEngine;
use reco::taste::TasteProfileEngine;
use resolvers::hybrid::HybridStreamResolver;
use resolvers::youtube::YoutubeStreamResolver;
use scanner::local::LocalAudioScanner;
use search::engine::SearchEngine;
use std::sync::{Arc, OnceLock};

uniffi::setup_scaffolding!();

static HYBRID_RESOLVER: OnceLock<Arc<HybridStreamResolver>> = OnceLock::new();
static YOUTUBE_RESOLVER: OnceLock<YoutubeStreamResolver> = OnceLock::new();
static DB_REPO: OnceLock<Arc<DatabaseRepository>> = OnceLock::new();
static CONFIG_MGR: OnceLock<ConfigManager> = OnceLock::new();

fn get_hybrid_resolver() -> Arc<HybridStreamResolver> {
    HYBRID_RESOLVER
        .get_or_init(|| Arc::new(HybridStreamResolver::new()))
        .clone()
}

fn get_youtube_resolver() -> &'static YoutubeStreamResolver {
    YOUTUBE_RESOLVER.get_or_init(YoutubeStreamResolver::new)
}

fn get_db_repo() -> Result<Arc<DatabaseRepository>, SoftifyError> {
    DB_REPO
        .get()
        .cloned()
        .ok_or_else(|| SoftifyError::Database {
            reason: "Database not initialized. Call init_database first.".to_string(),
        })
}

fn get_config_mgr() -> &'static ConfigManager {
    CONFIG_MGR.get_or_init(ConfigManager::new)
}

#[uniffi::export]
pub fn init_database(db_path: String) -> Result<(), SoftifyError> {
    if DB_REPO.get().is_some() {
        return Ok(());
    }
    let repo = DatabaseRepository::new(&db_path)?;
    let _ = DB_REPO.set(Arc::new(repo));
    Ok(())
}

/// Fetches remote configuration with 3s timeout or falls back to bundled defaults
#[uniffi::export(async_runtime = "tokio")]
pub async fn refresh_remote_config(url: Option<String>) {
    let target = url
        .as_deref()
        .unwrap_or("https://raw.githubusercontent.com/softify-app/softify-config/main/config.json");
    get_config_mgr().fetch_remote_config(target).await;
}

/// Performs health checks across all resolvers (JioSaavn and YouTube)
#[uniffi::export(async_runtime = "tokio")]
pub async fn check_providers_health() -> Vec<ProviderHealth> {
    get_hybrid_resolver().check_provider_health().await
}

/// Asynchronous search querying YouTube Music (WEB_REMIX). Supports Tokio cancellation.
#[uniffi::export(async_runtime = "tokio")]
pub async fn search_tracks(query: String) -> Result<Vec<Track>, SoftifyError> {
    if query.trim().is_empty() {
        return Ok(Vec::new());
    }
    let resolver = get_youtube_resolver();
    resolver.search(&query).await
}

/// Instant local library search using SQLite FTS5 prefix queries.
#[uniffi::export]
pub fn search_library(query: String, limit: u32) -> Result<Vec<Track>, SoftifyError> {
    let repo = get_db_repo()?;
    let engine = SearchEngine::new((*repo).clone());
    engine.search_library(&query, limit)
}

/// Combined instant search: returns local FTS5 matches immediately + fetched online matches
#[uniffi::export(async_runtime = "tokio")]
pub async fn search_combined(query: String, limit: u32) -> Result<SearchResult, SoftifyError> {
    let repo = get_db_repo()?;
    let engine = SearchEngine::new((*repo).clone());

    let online_tracks = if !query.trim().is_empty() {
        let resolver = get_youtube_resolver();
        resolver.search(&query).await.unwrap_or_default()
    } else {
        Vec::new()
    };

    engine.process_search_results(&query, online_tracks, limit)
}

/// Asynchronous stream resolver following Local -> JioSaavn 320kbps -> YouTube fallback.
/// Performs HTTP HEAD/Range probe quality verification and sanity checks byte rate.
/// Unresolved imported tracks are resolved and matched on demand.
#[uniffi::export(async_runtime = "tokio")]
pub async fn resolve_stream(
    mut track: Track,
    preset: QualityPreset,
) -> Result<StreamInfo, SoftifyError> {
    let repo_opt = get_db_repo().ok();

    // On-demand resolution check for unresolved Spotify tracks
    let mut sp_id_opt = None;
    if track.source_id.starts_with("spotify:") {
        let sp_id = track.source_id.trim_start_matches("spotify:").to_string();
        sp_id_opt = Some(sp_id.clone());
        if let Some(repo) = &repo_opt {
            let cached = repo.get_spotify_match(&sp_id).ok().flatten().or_else(|| {
                repo.get_spotify_match_by_title_artist(&track.title, &track.artist)
                    .ok()
                    .flatten()
            });
            if let Some((vid, cover)) = cached {
                track.source_id = format!("ytm_{vid}");
                if track.cover_url.is_none() {
                    track.cover_url = cover;
                }
            }
        }
    }

    let resolver = get_hybrid_resolver();
    let stream_info = resolver.resolve(&track, preset).await?;

    // If DB is initialized, persist and match unresolved track
    if let Some(repo) = repo_opt {
        if track.id.starts_with("sp_tr_") || sp_id_opt.is_some() {
            let yt = resolver.youtube().clone();
            let repo_clone = repo.clone();
            let track_id = track.id.clone();
            let title = track.title.clone();
            let artist = track.artist.clone();
            tokio::spawn(async move {
                crate::importer::spotify::SpotifyImporter::match_single_track(
                    &repo_clone,
                    &yt,
                    "",
                    &track_id,
                    sp_id_opt.as_deref(),
                    &title,
                    &artist,
                )
                .await;
            });
        } else {
            let _ = repo.insert_or_update_track(&track);
        }
    }

    Ok(stream_info)
}

/// Resolves lyrics from cache or LRCLIB with synced lines and plain fallback
#[uniffi::export(async_runtime = "tokio")]
pub async fn get_lyrics(track: Track) -> Result<SyncedLyrics, SoftifyError> {
    let db_opt = get_db_repo().ok().map(|r| (*r).clone());
    let engine = LyricsEngine::new(db_opt);
    engine.get_lyrics(&track).await
}

/// Downloads highest-quality stream as M4A with iTunes atom tagging and progress notifications
#[uniffi::export(async_runtime = "tokio")]
pub async fn download_track(
    track: Track,
    preset: QualityPreset,
    target_dir: String,
    callback: Box<dyn DownloadProgressCallback>,
) -> Result<DownloadItem, SoftifyError> {
    let db_opt = get_db_repo().ok().map(|r| (*r).clone());
    let manager = DownloadManager::new(get_hybrid_resolver(), db_opt);
    manager
        .download_track(&track, preset, &target_dir, Some(&*callback))
        .await
}

/// Retrieves a setting value by key
#[uniffi::export]
pub fn get_setting(key: String) -> Result<Option<String>, SoftifyError> {
    let repo = get_db_repo()?;
    repo.get_setting(&key)
}

/// Stores a setting key-value pair
#[uniffi::export]
pub fn set_setting(key: String, value: String) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.set_setting(&key, &value)
}

/// Lists all completed downloads
#[uniffi::export]
pub fn get_downloads() -> Result<Vec<DownloadItem>, SoftifyError> {
    let repo = get_db_repo()?;
    let manager = DownloadManager::new(get_hybrid_resolver(), Some((*repo).clone()));
    manager.get_downloads()
}

/// Retrieves a single download item by track_id
#[uniffi::export]
pub fn get_download(track_id: String) -> Result<Option<DownloadItem>, SoftifyError> {
    let repo = get_db_repo()?;
    repo.get_download(&track_id)
}

/// Records or updates download state in database
#[uniffi::export]
#[allow(clippy::too_many_arguments)]
pub fn record_download_state(
    track_id: String,
    relative_path: String,
    container_format: String,
    file_size_bytes: u64,
    bytes_downloaded: u64,
    status: String,
    bitrate_kbps: u32,
    last_error: Option<String>,
) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.record_download(
        &track_id,
        &relative_path,
        &container_format,
        file_size_bytes,
        bytes_downloaded,
        &status,
        bitrate_kbps,
        last_error.as_deref(),
    )
}

/// Updates download status and optional error message
#[uniffi::export]
pub fn update_download_status(
    track_id: String,
    status: String,
    last_error: Option<String>,
) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.update_download_status(&track_id, &status, last_error.as_deref())
}

/// Updates download progress in bytes
#[uniffi::export]
pub fn update_download_progress(
    track_id: String,
    bytes_downloaded: u64,
    file_size_bytes: u64,
    status: String,
) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.update_download_progress(&track_id, bytes_downloaded, file_size_bytes, &status)
}

/// Marks download as failed / needing repair
#[uniffi::export]
pub fn mark_download_repair(track_id: String, error: String) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.mark_download_repair(&track_id, &error)
}

/// Deletes a download from disk and database
#[uniffi::export]
pub fn delete_download(track_id: String) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    let manager = DownloadManager::new(get_hybrid_resolver(), Some((*repo).clone()));
    manager.delete_download(&track_id)
}

/// Deletes all downloads from database
#[uniffi::export]
pub fn delete_all_downloads() -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.delete_all_downloads()
}

/// Tags an audio file (M4A or Opus) with title, artist, album, year and cover art
#[uniffi::export]
pub fn tag_audio_file(
    file_path: String,
    title: String,
    artist: String,
    album: Option<String>,
    year: Option<u32>,
    cover_bytes: Option<Vec<u8>>,
) -> Result<(), SoftifyError> {
    let path = std::path::Path::new(&file_path);
    let meta = downloads::tagger::AudioMetadata {
        title: &title,
        artist: &artist,
        album: album.as_deref(),
        year,
        cover_art_bytes: cover_bytes.as_deref(),
        cover_mime_type: Some("image/jpeg"),
    };
    downloads::tagger::write_tags(path, &meta)
}

/// Persists or updates a track in the local database
#[uniffi::export]
pub fn save_track(track: Track) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.insert_or_update_track(&track)
}

/// Toggles track like status
#[uniffi::export]
pub fn toggle_like(track_id: String) -> Result<bool, SoftifyError> {
    let repo = get_db_repo()?;
    repo.toggle_like(&track_id)
}

/// Returns all liked tracks
#[uniffi::export]
pub fn get_liked_tracks() -> Result<Vec<Track>, SoftifyError> {
    let repo = get_db_repo()?;
    repo.get_liked_tracks()
}

/// Creates a new user playlist
#[uniffi::export]
pub fn create_playlist(
    name: String,
    description: Option<String>,
) -> Result<Playlist, SoftifyError> {
    let repo = get_db_repo()?;
    repo.create_playlist(&name, description.as_deref())
}

/// Renames an existing playlist
#[uniffi::export]
pub fn rename_playlist(playlist_id: String, new_name: String) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.rename_playlist(&playlist_id, &new_name)
}

/// Records a recent search query (skipped if incognito/learning is paused)
#[uniffi::export]
pub fn record_search_query(query: String) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.insert_recent_search(&query)
}

/// Retrieves recent searches ordered by most recent first
#[uniffi::export]
pub fn get_recent_searches(limit: u32) -> Result<Vec<String>, SoftifyError> {
    let repo = get_db_repo()?;
    repo.get_recent_searches(limit)
}

/// Deletes a single recent search query
#[uniffi::export]
pub fn delete_recent_search(query: String) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.delete_recent_search(&query)
}

/// Clears all recent searches
#[uniffi::export]
pub fn clear_recent_searches() -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.clear_recent_searches()
}

/// On Repeat Smart Playlist: tracks played in the past 14 days, ordered by play count desc
#[uniffi::export]
pub fn get_on_repeat_tracks(now_ms: u64, limit: u32) -> Result<Vec<Track>, SoftifyError> {
    let repo = get_db_repo()?;
    repo.get_on_repeat_tracks(now_ms, limit)
}

/// Most Played Smart Playlist: tracks played in the past 30 days, ordered by play count desc
#[uniffi::export]
pub fn get_most_played_tracks(now_ms: u64, limit: u32) -> Result<Vec<Track>, SoftifyError> {
    let repo = get_db_repo()?;
    repo.get_most_played_tracks(now_ms, limit)
}

/// Forgotten Favorites Smart Playlist: liked tracks not played in 60+ days (or never played)
#[uniffi::export]
pub fn get_forgotten_favorites_tracks(now_ms: u64, limit: u32) -> Result<Vec<Track>, SoftifyError> {
    let repo = get_db_repo()?;
    repo.get_forgotten_favorites_tracks(now_ms, limit)
}

/// Asynchronously fetches explore charts / trending shelves for home screen.
/// Uses remote config endpoint, caches in SQLite, falls back to embedded fixture.
#[uniffi::export(async_runtime = "tokio")]
pub async fn home_explore() -> Result<Vec<Shelf>, SoftifyError> {
    let repo = get_db_repo()?;
    let engine = reco::explore::HomeExploreEngine::new(repo);
    engine.get_explore_shelves(get_config_mgr()).await
}

/// Builds dynamic YouTube Music radio queue for a given seed track or continuation token.
/// Re-ranks candidate tracks using local SQLite play history and dedupes against the last 10 played.
#[uniffi::export(async_runtime = "tokio")]
pub async fn get_radio_tracks(
    seed_track_id: String,
    continuation: Option<String>,
) -> Result<RadioResult, SoftifyError> {
    let resolver = get_youtube_resolver();
    let radio_raw = resolver
        .get_radio(&seed_track_id, continuation.as_deref())
        .await?;

    let history = if let Ok(repo) = get_db_repo() {
        repo.get_history(50).unwrap_or_default()
    } else {
        Vec::new()
    };

    let reranked = reco::ranker::rerank_radio_tracks(radio_raw.tracks, &history, 10);
    Ok(RadioResult {
        tracks: reranked,
        continuation: radio_raw.continuation,
    })
}

/// Builds personalized "Quick picks" tracks for Home screen using local history signals:
/// Loved tracks (completed plays >= 0.5, liked), max 2 per artist, backfilled with explore charts.
#[uniffi::export(async_runtime = "tokio")]
pub async fn get_quick_picks(limit: u32) -> Result<Vec<Track>, SoftifyError> {
    let history = if let Ok(repo) = get_db_repo() {
        repo.get_history(100).unwrap_or_default()
    } else {
        Vec::new()
    };

    let fallback_tracks = if let Ok(repo) = get_db_repo() {
        let engine = reco::explore::HomeExploreEngine::new(repo);
        engine
            .get_explore_shelves(get_config_mgr())
            .await
            .unwrap_or_default()
            .into_iter()
            .flat_map(|s| s.tracks)
            .collect()
    } else {
        Vec::new()
    };

    Ok(reco::ranker::build_quick_picks(
        &history,
        &fallback_tracks,
        limit as usize,
    ))
}

/// Deletes a playlist
#[uniffi::export]
pub fn delete_playlist(playlist_id: String) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.delete_playlist(&playlist_id)
}

/// Retrieves all playlists with track counts
#[uniffi::export]
pub fn get_playlists() -> Result<Vec<Playlist>, SoftifyError> {
    let repo = get_db_repo()?;
    repo.get_playlists()
}

/// Adds a track to a playlist
#[uniffi::export]
pub fn add_to_playlist(playlist_id: String, track_id: String) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.add_to_playlist(&playlist_id, &track_id)
}

/// Removes a track from a playlist
#[uniffi::export]
pub fn remove_from_playlist(playlist_id: String, track_id: String) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.remove_from_playlist(&playlist_id, &track_id)
}

/// Gets all tracks in a playlist ordered by position
#[uniffi::export]
pub fn get_playlist_tracks(playlist_id: String) -> Result<Vec<Track>, SoftifyError> {
    let repo = get_db_repo()?;
    repo.get_playlist_tracks(&playlist_id)
}

/// Records play history with completion ratio
#[uniffi::export]
pub fn record_play(track_id: String, completed_ratio: f64) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.record_play_history(&track_id, completed_ratio)
}

/// Retrieves recent play history entries
#[uniffi::export]
pub fn get_history(limit: u32) -> Result<Vec<PlayHistory>, SoftifyError> {
    let repo = get_db_repo()?;
    repo.get_history(limit)
}

/// Clears play history
#[uniffi::export]
pub fn clear_history() -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    repo.clear_history()
}

/// Imports a public Spotify playlist, album, or track without OAuth or API key
#[uniffi::export(async_runtime = "tokio")]
pub async fn import_spotify_playlist(
    url_or_id: String,
) -> Result<ImportPlaylistResult, SoftifyError> {
    let repo = get_db_repo()?;
    let importer = SpotifyImporter::new(get_hybrid_resolver(), repo);
    importer.import_playlist(&url_or_id).await
}

/// Scans local music directories using walkdir, rayon, and lofty
#[uniffi::export]
pub fn scan_local_music(
    directories: Vec<String>,
    callback: Option<Box<dyn ScanProgressCallback>>,
) -> Result<ScanResult, SoftifyError> {
    let repo = get_db_repo()?;
    let scanner = LocalAudioScanner::new(repo);
    scanner.scan_directories(directories, callback)
}

/// Computes personalized recommendation shelves (Jump Back In, Daily Mix, Discover Weekly)
#[uniffi::export]
pub fn get_recommendation_shelves() -> Result<Vec<Shelf>, SoftifyError> {
    let repo = get_db_repo()?;
    let taste = Arc::new(TasteProfileEngine::new(repo.clone()));
    let diversity = Arc::new(DiversityController::new(repo.clone()));
    let engine = ShelfEngine::new(repo, taste, diversity);
    engine.load_shelves()
}

/// Updates taste profile from play event with dual-band decay (4-hour fast, 14-day slow)
#[uniffi::export]
pub fn update_taste_from_play(
    track: Track,
    is_stream: bool,
    is_early_skip: bool,
    is_save: bool,
) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    let diversity = DiversityController::new(repo.clone());
    if diversity.is_learning_paused()? {
        return Ok(());
    }
    let taste = TasteProfileEngine::new(repo);
    taste.update_from_play(&track, is_stream, is_early_skip, is_save)
}

/// Snoozes an artist for specified duration in ms (default 30 days)
#[uniffi::export]
pub fn snooze_artist(artist: String, duration_ms: u64) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    let diversity = DiversityController::new(repo);
    diversity.snooze_artist(&artist, duration_ms)
}

/// Checks if an artist is currently snoozed
#[uniffi::export]
pub fn is_artist_snoozed(artist: String) -> Result<bool, SoftifyError> {
    let repo = get_db_repo()?;
    let diversity = DiversityController::new(repo);
    diversity.is_snoozed(&artist)
}

/// Lists all currently snoozed artists
#[uniffi::export]
pub fn get_snoozed_artists() -> Result<Vec<String>, SoftifyError> {
    let repo = get_db_repo()?;
    let diversity = DiversityController::new(repo);
    diversity.get_snoozed_artists()
}

/// Removes a snooze on an artist
#[uniffi::export]
pub fn remove_artist_snooze(artist: String) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    let diversity = DiversityController::new(repo);
    diversity.remove_snooze(&artist)
}

/// Pauses or resumes recommendation learning (incognito mode)
#[uniffi::export]
pub fn set_learning_paused(paused: bool) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    let diversity = DiversityController::new(repo);
    diversity.set_learning_paused(paused)
}

/// Checks whether recommendation learning is currently paused
#[uniffi::export]
pub fn is_learning_paused() -> Result<bool, SoftifyError> {
    let repo = get_db_repo()?;
    let diversity = DiversityController::new(repo);
    diversity.is_learning_paused()
}

/// Retrieves tracks by artist from local library with online fallback/augmentation
#[uniffi::export(async_runtime = "tokio")]
pub async fn get_artist_tracks(artist: String, limit: u32) -> Result<Vec<Track>, SoftifyError> {
    let mut local = if let Ok(repo) = get_db_repo() {
        repo.get_tracks_by_artist(&artist, limit)
            .unwrap_or_default()
    } else {
        Vec::new()
    };
    if (local.len() as u32) < limit {
        let resolver = get_youtube_resolver();
        let query = format!("{} songs", artist);
        if let Ok(online) = resolver.search(&query).await {
            let mut seen = std::collections::HashSet::new();
            for t in &local {
                seen.insert(t.id.clone());
            }
            for t in online {
                if seen.insert(t.id.clone()) {
                    local.push(t);
                    if (local.len() as u32) >= limit {
                        break;
                    }
                }
            }
        }
    }
    Ok(local)
}

/// Retrieves tracks by album from local library with online fallback/augmentation
#[uniffi::export(async_runtime = "tokio")]
pub async fn get_album_tracks(
    album: String,
    artist: String,
    limit: u32,
) -> Result<Vec<Track>, SoftifyError> {
    let mut local = if let Ok(repo) = get_db_repo() {
        repo.get_tracks_by_album(&album, limit).unwrap_or_default()
    } else {
        Vec::new()
    };
    if local.is_empty() {
        let resolver = get_youtube_resolver();
        let query = format!("{} {} album", artist, album);
        if let Ok(online) = resolver.search(&query).await {
            local = online;
        }
    }
    Ok(local)
}
