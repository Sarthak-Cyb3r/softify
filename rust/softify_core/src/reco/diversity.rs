use crate::db::repository::DatabaseRepository;
use crate::models::{SoftifyError, Track};
use std::collections::HashMap;
use std::sync::Arc;

pub const DEFAULT_SNOOZE_DURATION_MS: u64 = 30 * 86400 * 1000; // 30 days

pub struct DiversityController {
    db: Arc<DatabaseRepository>,
}

impl DiversityController {
    pub fn new(db: Arc<DatabaseRepository>) -> Self {
        Self { db }
    }

    /// Maximal Marginal Relevance (MMR) Diversification
    /// Dart:
    /// List<Track> applyMmr(List<Track> ranked, {int maxPerArtist = 2, double lambda = 0.7})
    pub fn apply_mmr(ranked: &[Track], max_per_artist: usize, lambda: f64) -> Vec<Track> {
        if ranked.is_empty() {
            return Vec::new();
        }
        if ranked.len() == 1 {
            return ranked.to_vec();
        }

        let n = ranked.len();
        // Map relevance as normalized rank: Rel(d_i) = 1.0 - (i / n)
        let mut rel_scores: Vec<f64> = Vec::with_capacity(n);
        for i in 0..n {
            rel_scores.push(1.0 - (i as f64 / n as f64));
        }

        let mut selected: Vec<Track> = Vec::new();
        let mut remaining_indices: Vec<usize> = (0..n).collect();
        let mut artist_counts: HashMap<String, usize> = HashMap::new();

        while !remaining_indices.is_empty() {
            let mut best_remaining_pos: Option<usize> = None;
            let mut highest_mmr_score = f64::NEG_INFINITY;

            for (pos, &idx) in remaining_indices.iter().enumerate() {
                let candidate = &ranked[idx];
                let artist_key = candidate.artist.trim().to_lowercase();
                let current_count = *artist_counts.get(&artist_key).unwrap_or(&0);

                // Hard invariant: Skip candidates exceeding maxPerArtist
                if current_count >= max_per_artist {
                    continue;
                }

                let rel = rel_scores[idx];

                // Compute max similarity to already selected tracks
                let mut max_sim = 0.0f64;
                for s in &selected {
                    let sim = Self::compute_similarity(candidate, s);
                    if sim > max_sim {
                        max_sim = sim;
                    }
                }

                // MMR = lambda * Rel(d) - (1 - lambda) * maxSim(d, S)
                let mmr_score = (lambda * rel) - ((1.0 - lambda) * max_sim);

                if mmr_score > highest_mmr_score {
                    highest_mmr_score = mmr_score;
                    best_remaining_pos = Some(pos);
                }
            }

            if let Some(pos) = best_remaining_pos {
                let idx = remaining_indices.remove(pos);
                let best_candidate = ranked[idx].clone();
                let artist_key = best_candidate.artist.trim().to_lowercase();
                *artist_counts.entry(artist_key).or_insert(0) += 1;
                selected.push(best_candidate);
            } else {
                // If all remaining candidates violate maxPerArtist, break
                break;
            }
        }

        selected
    }

    pub fn compute_similarity(a: &Track, b: &Track) -> f64 {
        if a.id == b.id {
            return 1.0;
        }
        if a.artist.trim().eq_ignore_ascii_case(b.artist.trim()) {
            return 1.0;
        }
        if let (Some(alb_a), Some(alb_b)) = (&a.album, &b.album) {
            if alb_a.trim().eq_ignore_ascii_case(alb_b.trim()) {
                return 0.5;
            }
        }
        0.0
    }

    pub fn snooze_artist(&self, artist_id: &str, duration_ms: u64) -> Result<(), SoftifyError> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        let snoozed_until = now + duration_ms as i64;
        self.db.set_artist_snooze(artist_id, snoozed_until)
    }

    pub fn is_snoozed(&self, artist_id: &str) -> Result<bool, SoftifyError> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        self.db.is_artist_snoozed(artist_id, now)
    }

    pub fn get_snoozed_artists(&self) -> Result<Vec<String>, SoftifyError> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        self.db.get_snoozed_artists(now)
    }

    pub fn remove_snooze(&self, artist_id: &str) -> Result<(), SoftifyError> {
        self.db.remove_artist_snooze(artist_id)
    }

    pub fn set_learning_paused(&self, paused: bool) -> Result<(), SoftifyError> {
        self.db
            .set_setting("learning_paused", if paused { "true" } else { "false" })
    }

    pub fn is_learning_paused(&self) -> Result<bool, SoftifyError> {
        let val = self.db.get_setting("learning_paused")?;
        Ok(val.as_deref() == Some("true"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_dummy_track(id: &str, artist: &str) -> Track {
        Track {
            id: id.to_string(),
            source_id: id.to_string(),
            title: format!("Title {}", id),
            artist: artist.to_string(),
            album: None,
            duration_ms: 180000,
            cover_url: None,
            match_confidence: Some(1.0),
            is_liked: false,
            is_unavailable: false,
        }
    }

    #[test]
    fn test_mmr_max_per_artist_invariant() {
        let tracks = vec![
            create_dummy_track("t1", "Artist A"),
            create_dummy_track("t2", "Artist A"),
            create_dummy_track("t3", "Artist A"),
            create_dummy_track("t4", "Artist B"),
            create_dummy_track("t5", "Artist B"),
        ];

        let diversified = DiversityController::apply_mmr(&tracks, 2, 0.7);

        let mut counts = HashMap::new();
        for t in &diversified {
            *counts.entry(t.artist.clone()).or_insert(0) += 1;
        }

        assert_eq!(*counts.get("Artist A").unwrap_or(&0), 2);
        assert_eq!(*counts.get("Artist B").unwrap_or(&0), 2);
        assert_eq!(diversified.len(), 4);
    }

    #[test]
    fn test_snooze_artist_30_days() {
        let db = Arc::new(DatabaseRepository::in_memory().unwrap());
        let controller = DiversityController::new(db.clone());

        let snoozed_before = controller.get_snoozed_artists().unwrap();
        assert!(snoozed_before.is_empty());

        controller
            .snooze_artist("Bad Artist", DEFAULT_SNOOZE_DURATION_MS)
            .unwrap();

        let snoozed_after = controller.get_snoozed_artists().unwrap();
        assert_eq!(snoozed_after.len(), 1);
        assert_eq!(snoozed_after[0], "bad artist");
    }
}
