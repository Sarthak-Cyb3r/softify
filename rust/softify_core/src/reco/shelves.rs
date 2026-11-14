use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use crate::db::repository::DatabaseRepository;
use crate::models::{Shelf, SoftifyError, Track};
use super::diversity::DiversityController;
use super::taste::TasteProfileEngine;

pub struct ShelfEngine {
    db: Arc<DatabaseRepository>,
    taste: Arc<TasteProfileEngine>,
    diversity: Arc<DiversityController>,
}

impl ShelfEngine {
    pub fn new(
        db: Arc<DatabaseRepository>,
        taste: Arc<TasteProfileEngine>,
        diversity: Arc<DiversityController>,
    ) -> Self {
        Self { db, taste, diversity }
    }

    pub fn load_shelves(&self) -> Result<Vec<Shelf>, SoftifyError> {
        let mut shelves = Vec::new();

        // 1. Jump Back In Shelf
        if let Ok(jump_back_in) = self.build_jump_back_in_shelf(15) {
            if !jump_back_in.tracks.is_empty() {
                shelves.push(jump_back_in);
            }
        }

        // 2. Daily Mix Shelf
        if let Ok(daily_mix) = self.build_daily_mix_shelf(20) {
            if !daily_mix.tracks.is_empty() {
                shelves.push(daily_mix);
            }
        }

        // 3. Discover Weekly Shelf
        if let Ok(discover_weekly) = self.build_discover_weekly_shelf(20) {
            if !discover_weekly.tracks.is_empty() {
                shelves.push(discover_weekly);
            }
        }

        Ok(shelves)
    }

    pub fn build_jump_back_in_shelf(&self, limit: usize) -> Result<Shelf, SoftifyError> {
        let history = self.db.get_recent_history(100)?;
        let snoozed = self.diversity.get_snoozed_artists().unwrap_or_default();
        let snoozed_set: HashSet<String> = snoozed.iter().map(|s| s.to_lowercase()).collect();

        let mut track_counts: HashMap<String, usize> = HashMap::new();
        let mut latest_played: HashMap<String, i64> = HashMap::new();
        let mut track_map: HashMap<String, Track> = HashMap::new();

        for h in history {
            if snoozed_set.contains(&h.track.artist.trim().to_lowercase()) {
                continue;
            }
            *track_counts.entry(h.track.id.clone()).or_insert(0) += 1;
            let current_latest = latest_played.entry(h.track.id.clone()).or_insert(h.played_at);
            if h.played_at > *current_latest {
                *current_latest = h.played_at;
            }
            track_map.insert(h.track.id.clone(), h.track);
        }

        let now_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        let mut candidates: Vec<Track> = track_map.into_values().collect();
        candidates.sort_by(|a, b| {
            let count_a = *track_counts.get(&a.id).unwrap_or(&1) as f64;
            let count_b = *track_counts.get(&b.id).unwrap_or(&1) as f64;
            let recency_a = 1.0 / (1.0 + (now_ms - *latest_played.get(&a.id).unwrap_or(&0)) as f64 / 86400000.0);
            let recency_b = 1.0 / (1.0 + (now_ms - *latest_played.get(&b.id).unwrap_or(&0)) as f64 / 86400000.0);
            let score_a = count_a * 2.0 + recency_a;
            let score_b = count_b * 2.0 + recency_b;
            score_b.partial_cmp(&score_a).unwrap_or(std::cmp::Ordering::Equal)
        });

        let mut tracks: Vec<Track> = candidates.into_iter().take(limit).collect();

        // Fallback: If history is empty, populate from latest tracks in library
        if tracks.is_empty() {
            let all_tracks = self.db.get_all_tracks(limit as u32)?;
            tracks = all_tracks.into_iter()
                .filter(|t| !snoozed_set.contains(&t.artist.trim().to_lowercase()))
                .collect();
        }

        Ok(Shelf {
            id: "jump_back_in".to_string(),
            title: "Jump Back In".to_string(),
            subtitle: "Recently and frequently played".to_string(),
            rule: "frequency_recency".to_string(),
            tracks,
        })
    }

    pub fn build_daily_mix_shelf(&self, limit: usize) -> Result<Shelf, SoftifyError> {
        let top_artists = self.taste.get_top_artists(5).unwrap_or_default();
        let snoozed = self.diversity.get_snoozed_artists().unwrap_or_default();
        let snoozed_set: HashSet<String> = snoozed.iter().map(|s| s.to_lowercase()).collect();

        let mut candidates = Vec::new();
        let artist_names: Vec<String> = top_artists.iter()
            .map(|a| a.entity_id.clone())
            .filter(|a| !snoozed_set.contains(&a.to_lowercase()))
            .collect();

        if !artist_names.is_empty() {
            for artist in &artist_names {
                let artist_tracks = self.db.get_tracks_by_artist(artist, 5)?;
                candidates.extend(artist_tracks);
            }
        }

        // Fallback if not enough tracks
        if candidates.len() < limit {
            let fallback_tracks = self.db.get_all_tracks(limit as u32)?;
            for t in fallback_tracks {
                if !snoozed_set.contains(&t.artist.trim().to_lowercase()) && !candidates.iter().any(|c| c.id == t.id) {
                    candidates.push(t);
                }
            }
        }

        // Apply MMR diversification
        let diversified = DiversityController::apply_mmr(&candidates, 2, 0.7);
        let final_tracks = diversified.into_iter().take(limit).collect();

        Ok(Shelf {
            id: "daily_mix".to_string(),
            title: "Daily Mix".to_string(),
            subtitle: "Familiar favorites blended for your taste".to_string(),
            rule: "kmeans_clusters".to_string(),
            tracks: final_tracks,
        })
    }

    pub fn build_discover_weekly_shelf(&self, limit: usize) -> Result<Shelf, SoftifyError> {
        let snoozed = self.diversity.get_snoozed_artists().unwrap_or_default();
        let snoozed_set: HashSet<String> = snoozed.iter().map(|s| s.to_lowercase()).collect();

        // Get unplayed or least played tracks
        let candidates = self.db.get_unplayed_tracks(limit as u32 * 2)?;
        let filtered: Vec<Track> = candidates.into_iter()
            .filter(|t| !snoozed_set.contains(&t.artist.trim().to_lowercase()))
            .collect();

        let diversified = DiversityController::apply_mmr(&filtered, 2, 0.8);
        let final_tracks = diversified.into_iter().take(limit).collect();

        Ok(Shelf {
            id: "discover_weekly".to_string(),
            title: "Discover Weekly".to_string(),
            subtitle: "Fresh discoveries tailored to your music profile".to_string(),
            rule: "novelty_with_familiar_anchor".to_string(),
            tracks: final_tracks,
        })
    }
}
