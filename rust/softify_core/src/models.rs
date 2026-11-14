#[derive(uniffi::Enum, Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum QualityPreset {
    Low,
    Medium,
    High,
}

impl QualityPreset {
    pub fn target_bitrate_kbps(&self) -> u32 {
        match self {
            QualityPreset::Low => 96,
            QualityPreset::Medium => 160,
            QualityPreset::High => 320,
        }
    }
}

#[derive(uniffi::Record, Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct HeaderPair {
    pub name: String,
    pub value: String,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct StreamInfo {
    pub url: String,
    pub container: String,
    pub bitrate_kbps: u32,
    pub codec: String,
    pub provider: String,
    pub is_requested_quality: bool,
    pub headers: Vec<HeaderPair>,
    pub expires_at: Option<u64>,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct Track {
    pub id: String,
    pub source_id: String,
    pub title: String,
    pub artist: String,
    pub album: Option<String>,
    pub duration_ms: u64,
    pub cover_url: Option<String>,
    pub match_confidence: Option<f64>,
    pub is_liked: bool,
    pub is_unavailable: bool,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct Playlist {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub is_imported: bool,
    pub source_url: Option<String>,
    pub track_count: u32,
    pub created_at: i64,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct PlaylistTrack {
    pub playlist_id: String,
    pub position: u32,
    pub track_id: Option<String>,
    pub original_title: String,
    pub original_artist: String,
    pub match_status: String,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct PlayHistory {
    pub id: i64,
    pub track: Track,
    pub played_at: i64,
    pub completed_ratio: f64,
}

#[derive(uniffi::Enum, Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum SearchIntent {
    General,
    Track,
    Artist,
    Album,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct SearchResult {
    pub local_tracks: Vec<Track>,
    pub online_tracks: Vec<Track>,
    pub intent: SearchIntent,
    pub detected_entity: Option<String>,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct ProviderHealth {
    pub provider: String,
    pub is_healthy: bool,
    pub latency_ms: Option<u64>,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct LyricsLine {
    pub start_ms: u64,
    pub text: String,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct SyncedLyrics {
    pub is_synced: bool,
    pub lines: Vec<LyricsLine>,
    pub plain_text: Option<String>,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct DownloadItem {
    pub track_id: String,
    pub relative_path: String,
    pub container_format: String,
    pub file_size_bytes: u64,
    pub bytes_downloaded: u64,
    pub status: String,
    pub bitrate_kbps: u32,
    pub created_at: i64,
}

#[uniffi::export(callback_interface)]
pub trait DownloadProgressCallback: Send + Sync {
    fn on_progress(&self, track_id: String, bytes_downloaded: u64, total_bytes: u64, status: String);
}

#[derive(uniffi::Error, thiserror::Error, Debug)]
pub enum SoftifyError {
    #[error("Network error: {reason}")]
    Network { reason: String },
    #[error("Not found: {reason}")]
    NotFound { reason: String },
    #[error("Decryption error: {reason}")]
    Decryption { reason: String },
    #[error("Database error: {reason}")]
    Database { reason: String },
    #[error("Quality verification error: {reason}")]
    QualityVerification { reason: String },
    #[error("Provider unavailable: {provider}: {reason}")]
    ProviderUnavailable { provider: String, reason: String },
    #[error("Download error: {reason}")]
    Download { reason: String },
}

impl From<reqwest::Error> for SoftifyError {
    fn from(err: reqwest::Error) -> Self {
        SoftifyError::Network { reason: err.to_string() }
    }
}

impl From<rusqlite::Error> for SoftifyError {
    fn from(err: rusqlite::Error) -> Self {
        SoftifyError::Database { reason: err.to_string() }
    }
}
