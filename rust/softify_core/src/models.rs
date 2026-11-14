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
