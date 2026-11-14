pub mod models;
pub mod resolvers;
pub mod db;
pub mod search;

use std::sync::{Arc, OnceLock};
use models::{Playlist, PlayHistory, QualityPreset, SearchResult, SoftifyError, StreamInfo, Track};
use resolvers::hybrid::HybridStreamResolver;
use resolvers::youtube::YoutubeStreamResolver;
use db::repository::DatabaseRepository;
use search::engine::SearchEngine;

uniffi::setup_scaffolding!();

static HYBRID_RESOLVER: OnceLock<HybridStreamResolver> = OnceLock::new();
static YOUTUBE_RESOLVER: OnceLock<YoutubeStreamResolver> = OnceLock::new();
static DB_REPO: OnceLock<Arc<DatabaseRepository>> = OnceLock::new();

fn get_hybrid_resolver() -> &'static HybridStreamResolver {
    HYBRID_RESOLVER.get_or_init(HybridStreamResolver::new)
}

fn get_youtube_resolver() -> &'static YoutubeStreamResolver {
    YOUTUBE_RESOLVER.get_or_init(YoutubeStreamResolver::new)
}

fn get_db_repo() -> Result<Arc<DatabaseRepository>, SoftifyError> {
    DB_REPO.get().cloned().ok_or_else(|| SoftifyError::Database {
        reason: "Database not initialized. Call init_database first.".to_string(),
    })
}

#[uniffi::export]
pub fn init_database(db_path: String) -> Result<(), SoftifyError> {
    let repo = DatabaseRepository::new(&db_path)?;
    let _ = DB_REPO.set(Arc::new(repo));
    Ok(())
}

/// Asynchronous search querying YouTube Music (WEB_REMIX). Supports Tokio cancellation.
#[uniffi::export]
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
#[uniffi::export]
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
#[uniffi::export]
pub async fn resolve_stream(track: Track, preset: QualityPreset) -> Result<StreamInfo, SoftifyError> {
    let resolver = get_hybrid_resolver();
    let stream_info = resolver.resolve(&track, preset).await?;

    // If DB is initialized, persist track
    if let Ok(repo) = get_db_repo() {
        let _ = repo.insert_or_update_track(&track);
    }

    Ok(stream_info)
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
