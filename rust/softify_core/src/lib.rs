pub mod models;
pub mod resolvers;
pub mod db;

use std::sync::{Arc, OnceLock};
use models::{QualityPreset, SoftifyError, StreamInfo, Track};
use resolvers::hybrid::HybridStreamResolver;
use resolvers::youtube::YoutubeStreamResolver;
use db::repository::DatabaseRepository;

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

/// Asynchronous stream resolver following Local -> JioSaavn 320kbps -> YouTube fallback.
/// Performs HTTP HEAD/Range probe quality verification and sanity checks byte rate.
#[uniffi::export]
pub async fn resolve_stream(track: Track, preset: QualityPreset) -> Result<StreamInfo, SoftifyError> {
    let resolver = get_hybrid_resolver();
    let stream_info = resolver.resolve(&track, preset).await?;

    // If DB is initialized, persist track
    if let Some(repo) = DB_REPO.get() {
        let _ = repo.insert_or_update_track(&track);
    }

    Ok(stream_info)
}

/// Records play history with completion ratio
#[uniffi::export]
pub fn record_play(track_id: String, completed_ratio: f64) -> Result<(), SoftifyError> {
    if let Some(repo) = DB_REPO.get() {
        repo.record_play_history(&track_id, completed_ratio)?;
    }
    Ok(())
}
