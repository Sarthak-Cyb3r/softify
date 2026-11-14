pub mod models;
pub mod resolvers;
pub mod db;
pub mod search;
pub mod config;
pub mod lyrics;
pub mod downloads;

use std::sync::{Arc, OnceLock};
use models::{
    DownloadItem, DownloadProgressCallback, Playlist, PlayHistory, ProviderHealth, QualityPreset,
    SearchResult, SoftifyError, StreamInfo, SyncedLyrics, Track,
};
use resolvers::hybrid::HybridStreamResolver;
use resolvers::youtube::YoutubeStreamResolver;
use db::repository::DatabaseRepository;
use search::engine::SearchEngine;
use config::ConfigManager;
use lyrics::engine::LyricsEngine;
use downloads::manager::DownloadManager;

uniffi::setup_scaffolding!();

static HYBRID_RESOLVER: OnceLock<Arc<HybridStreamResolver>> = OnceLock::new();
static YOUTUBE_RESOLVER: OnceLock<YoutubeStreamResolver> = OnceLock::new();
static DB_REPO: OnceLock<Arc<DatabaseRepository>> = OnceLock::new();
static CONFIG_MGR: OnceLock<ConfigManager> = OnceLock::new();

fn get_hybrid_resolver() -> Arc<HybridStreamResolver> {
    HYBRID_RESOLVER.get_or_init(|| Arc::new(HybridStreamResolver::new())).clone()
}

fn get_youtube_resolver() -> &'static YoutubeStreamResolver {
    YOUTUBE_RESOLVER.get_or_init(YoutubeStreamResolver::new)
}

fn get_db_repo() -> Result<Arc<DatabaseRepository>, SoftifyError> {
    DB_REPO.get().cloned().ok_or_else(|| SoftifyError::Database {
        reason: "Database not initialized. Call init_database first.".to_string(),
    })
}

fn get_config_mgr() -> &'static ConfigManager {
    CONFIG_MGR.get_or_init(ConfigManager::new)
}

#[uniffi::export]
pub fn init_database(db_path: String) -> Result<(), SoftifyError> {
    let repo = DatabaseRepository::new(&db_path)?;
    let _ = DB_REPO.set(Arc::new(repo));
    Ok(())
}

/// Fetches remote configuration with 3s timeout or falls back to bundled defaults
#[uniffi::export(async_runtime = "tokio")]
pub async fn refresh_remote_config(url: Option<String>) {
    let target = url.as_deref().unwrap_or("https://raw.githubusercontent.com/softify-app/softify-config/main/config.json");
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
#[uniffi::export(async_runtime = "tokio")]
pub async fn resolve_stream(track: Track, preset: QualityPreset) -> Result<StreamInfo, SoftifyError> {
    let resolver = get_hybrid_resolver();
    let stream_info = resolver.resolve(&track, preset).await?;

    // If DB is initialized, persist track
    if let Ok(repo) = get_db_repo() {
        let _ = repo.insert_or_update_track(&track);
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
    manager.download_track(&track, preset, &target_dir, Some(&*callback)).await
}

/// Lists all completed downloads
#[uniffi::export]
pub fn get_downloads() -> Result<Vec<DownloadItem>, SoftifyError> {
    let repo = get_db_repo()?;
    let manager = DownloadManager::new(get_hybrid_resolver(), Some((*repo).clone()));
    manager.get_downloads()
}

/// Deletes a download from disk and database
#[uniffi::export]
pub fn delete_download(track_id: String) -> Result<(), SoftifyError> {
    let repo = get_db_repo()?;
    let manager = DownloadManager::new(get_hybrid_resolver(), Some((*repo).clone()));
    manager.delete_download(&track_id)
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
pub fn create_playlist(name: String, description: Option<String>) -> Result<Playlist, SoftifyError> {
    let repo = get_db_repo()?;
    repo.create_playlist(&name, description.as_deref())
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
