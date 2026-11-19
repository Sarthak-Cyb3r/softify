use crate::db::repository::DatabaseRepository;
use crate::models::{SoftifyError, TasteProfileEntity, Track};
use std::sync::Arc;

/// Dart:
/// static const double fastHalfLifeHours = 4.0;
/// static const double slowHalfLifeDays = 14.0;
/// static const double fastHalfLifeMs = fastHalfLifeHours * 3600 * 1000;
/// static const double slowHalfLifeMs = slowHalfLifeDays * 86400 * 1000;
pub const FAST_HALF_LIFE_HOURS: f64 = 4.0;
pub const SLOW_HALF_LIFE_DAYS: f64 = 14.0;
pub const FAST_HALF_LIFE_MS: f64 = FAST_HALF_LIFE_HOURS * 3600.0 * 1000.0;
pub const SLOW_HALF_LIFE_MS: f64 = SLOW_HALF_LIFE_DAYS * 86400.0 * 1000.0;

pub struct TasteProfileEngine {
    db: Arc<DatabaseRepository>,
}

impl TasteProfileEngine {
    pub fn new(db: Arc<DatabaseRepository>) -> Self {
        Self { db }
    }

    /// Hard isolation: YouTube links and podcasts never enter taste profile.
    pub fn is_excluded_from_taste(track: &Track) -> bool {
        track.id.starts_with("yt_")
            || track.source_id.starts_with("yt_")
            || track.source_id.starts_with("youtube:")
            || track.id.starts_with("podcast_")
            || track.source_id.starts_with("podcast_")
    }

    pub fn update_from_play(
        &self,
        track: &Track,
        is_stream: bool,
        is_early_skip: bool,
        is_save: bool,
    ) -> Result<(), SoftifyError> {
        if Self::is_excluded_from_taste(track) {
            return Ok(());
        }

        // Incognito mode / learning paused check
        if let Ok(Some(val)) = self.db.get_setting("learning_paused") {
            if val == "true" {
                return Ok(());
            }
        }

        let artist = track.artist.trim();
        if artist.is_empty() {
            return Ok(());
        }

        let now_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        self.db.update_taste_profile(
            "artist",
            artist,
            is_stream,
            is_early_skip,
            is_save,
            now_ms,
            FAST_HALF_LIFE_MS,
            SLOW_HALF_LIFE_MS,
        )
    }

    pub fn compute_taste_similarity(&self, track: &Track) -> Result<f64, SoftifyError> {
        let artist = track.artist.trim();
        if artist.is_empty() {
            return Ok(0.0);
        }

        let now_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        let entity = self.db.get_taste_profile("artist", artist)?;
        match entity {
            Some(e) => {
                let dt = (now_ms - e.updated_at) as f64;
                let decayed_fast = e.fast_weight * 2.0f64.powf(-dt / FAST_HALF_LIFE_MS);
                let decayed_slow = e.slow_weight * 2.0f64.powf(-dt / SLOW_HALF_LIFE_MS);

                let blended = (0.4 * decayed_fast) + (0.6 * decayed_slow);
                if blended <= 0.0 {
                    return Ok(0.0);
                }

                // Soft saturation function: x / (x + 2.0)
                let similarity = (blended / (blended + 2.0)).clamp(0.0, 1.0);
                Ok(similarity)
            }
            None => Ok(0.0),
        }
    }

    pub fn get_top_artists(&self, limit: u32) -> Result<Vec<TasteProfileEntity>, SoftifyError> {
        let now_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        self.db.get_top_taste_entities(
            "artist",
            limit,
            now_ms,
            FAST_HALF_LIFE_MS,
            SLOW_HALF_LIFE_MS,
        )
    }

    pub fn apply_decay(&self) -> Result<(), SoftifyError> {
        let now_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        self.db
            .decay_all_taste_profiles(now_ms, FAST_HALF_LIFE_MS, SLOW_HALF_LIFE_MS)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_taste_decay_math() {
        let dt_fast = FAST_HALF_LIFE_MS;
        let decay_fast = 2.0f64.powf(-dt_fast / FAST_HALF_LIFE_MS);
        assert!((decay_fast - 0.5).abs() < 1e-6);

        let dt_slow = SLOW_HALF_LIFE_DAYS * 86400.0 * 1000.0;
        let decay_slow = 2.0f64.powf(-dt_slow / SLOW_HALF_LIFE_MS);
        assert!((decay_slow - 0.5).abs() < 1e-6);

        // Blended saturation check
        let fast: f64 = 2.0;
        let slow: f64 = 2.0;
        let blended: f64 = 0.4 * fast + 0.6 * slow; // 2.0
        let sat: f64 = blended / (blended + 2.0); // 2.0 / 4.0 = 0.5
        assert!((sat - 0.5).abs() < 1e-6);
    }

    #[test]
    fn test_incognito_mode_pauses_learning() {
        let db = Arc::new(DatabaseRepository::in_memory().unwrap());
        let engine = TasteProfileEngine::new(db.clone());

        let track = Track {
            id: "t_test".to_string(),
            source_id: "saavn_1".to_string(),
            title: "Test Song".to_string(),
            artist: "Test Artist".to_string(),
            album: None,
            duration_ms: 180000,
            cover_url: None,
            match_confidence: Some(1.0),
            is_liked: false,
            is_unavailable: false,
        };

        // Enable incognito mode
        db.set_setting("learning_paused", "true").unwrap();
        engine.update_from_play(&track, true, false, false).unwrap();

        // Entity must not exist in DB
        let profile = db.get_taste_profile("artist", "Test Artist").unwrap();
        assert!(profile.is_none());

        // Disable incognito mode
        db.set_setting("learning_paused", "false").unwrap();
        engine.update_from_play(&track, true, false, false).unwrap();

        let profile_after = db.get_taste_profile("artist", "Test Artist").unwrap();
        assert!(profile_after.is_some());
    }
}
