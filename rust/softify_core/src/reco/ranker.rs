use crate::models::{PlayHistory, Track};
use std::collections::{HashMap, HashSet};

/// Dart:
/// static const Map<String, double> defaultWeights = {
///   'bias': -0.2,
///   'taste_sim': 2.5,
///   'cooccurrence': 1.8,
///   'recency': 0.6,
///   'novelty': 0.7,
///   'artist_skip_penalty': -2.0,
/// };
pub fn default_ranker_weights() -> HashMap<String, f64> {
    let mut map = HashMap::new();
    map.insert("bias".to_string(), -0.2);
    map.insert("taste_sim".to_string(), 2.5);
    map.insert("cooccurrence".to_string(), 1.8);
    map.insert("recency".to_string(), 0.6);
    map.insert("novelty".to_string(), 0.7);
    map.insert("artist_skip_penalty".to_string(), -2.0);
    map
}

#[derive(Debug, Clone)]
pub struct RecommendationCandidate {
    pub track_id: String,
    pub features: HashMap<String, f64>,
    pub score: f64,
}

#[derive(Debug, Clone)]
pub struct LogisticRegressionRanker {
    weights: HashMap<String, f64>,
}

impl Default for LogisticRegressionRanker {
    fn default() -> Self {
        Self::new()
    }
}

impl LogisticRegressionRanker {
    pub fn new() -> Self {
        Self {
            weights: default_ranker_weights(),
        }
    }

    pub fn with_weights(weights: HashMap<String, f64>) -> Self {
        Self { weights }
    }

    pub fn weights(&self) -> &HashMap<String, f64> {
        &self.weights
    }

    /// Computes the predicted probability score for a given feature vector.
    /// Enforces hard invariant: 3 consecutive skips (artist_skip_penalty >= 1.0)
    /// penalizes the candidate score by > 50%.
    pub fn compute_score(&self, features: &HashMap<String, f64>) -> f64 {
        let mut z = *self.weights.get("bias").unwrap_or(&0.0);
        for (key, val) in features {
            z += *self.weights.get(key).unwrap_or(&0.0) * val;
        }

        // Sigmoid: 1 / (1 + e^-z) clamped to prevent extreme overflow
        let clamped_z = z.clamp(-20.0, 20.0);
        let mut prob = 1.0 / (1.0 + (-clamped_z).exp());

        // Hard Invariant: 3 consecutive skips of an artist must penalize score by > 50%
        let skip_penalty = *features.get("artist_skip_penalty").unwrap_or(&0.0);
        if skip_penalty >= 1.0 {
            // 0.45 factor ensures at least a 55% penalty (> 50%)
            let penalty_factor = (0.45 / (1.0 + 0.5 * (skip_penalty - 1.0))).clamp(0.05, 0.45);
            prob *= penalty_factor;
        }

        prob
    }

    pub fn rank(&self, candidates: &mut [RecommendationCandidate]) {
        for candidate in candidates.iter_mut() {
            candidate.score = self.compute_score(&candidate.features);
        }

        candidates.sort_by(|a, b| {
            b.score
                .partial_cmp(&a.score)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
    }

    pub fn train_on_device_step(
        &mut self,
        features: &HashMap<String, f64>,
        positive_label: bool,
        learning_rate: f64,
    ) {
        let y = if positive_label { 1.0 } else { 0.0 };

        let mut z = *self.weights.get("bias").unwrap_or(&0.0);
        for (key, val) in features {
            z += *self.weights.get(key).unwrap_or(&0.0) * val;
        }
        let clamped_z = z.clamp(-20.0, 20.0);
        let y_hat = 1.0 / (1.0 + (-clamped_z).exp());

        let error = y_hat - y;

        // Update feature weights
        for (key, val) in features {
            let current = *self.weights.get(key).unwrap_or(&0.0);
            self.weights
                .insert(key.clone(), current - (learning_rate * error * val));
        }

        // Update bias
        let current_bias = *self.weights.get("bias").unwrap_or(&0.0);
        self.weights
            .insert("bias".to_string(), current_bias - (learning_rate * error));
    }
}

/// Re-ranks YouTube Music radio candidate tracks using local SQLite play history:
/// 1. Dedupes against the last N played tracks (default 10).
/// 2. Scores candidates using completed plays (+1.5), skips (-2.0), liked bonus (+2.5),
///    and artist affinity (+0.8 per completed play, -1.0 per skip).
/// 3. Preserves gentle prior from original candidate order.
pub fn rerank_radio_tracks(
    candidates: Vec<Track>,
    history: &[PlayHistory],
    dedupe_last_n: usize,
) -> Vec<Track> {
    if candidates.is_empty() {
        return Vec::new();
    }

    // Step 1: Collect dedup set from last N played tracks
    let mut recent_ids = HashSet::new();
    let mut recent_titles_artists = HashSet::new();
    for entry in history.iter().take(dedupe_last_n) {
        recent_ids.insert(entry.track.id.clone());
        recent_titles_artists.insert((
            entry.track.title.trim().to_lowercase(),
            entry.track.artist.trim().to_lowercase(),
        ));
    }

    // Filter out candidates played in the last N tracks
    let filtered_candidates: Vec<(usize, Track)> = candidates
        .into_iter()
        .enumerate()
        .filter(|(_, t)| {
            if recent_ids.contains(&t.id) {
                return false;
            }
            let key = (
                t.title.trim().to_lowercase(),
                t.artist.trim().to_lowercase(),
            );
            !recent_titles_artists.contains(&key)
        })
        .collect();

    if filtered_candidates.is_empty() {
        return Vec::new();
    }

    // Step 2: Build artist affinity and track history lookup maps
    let mut track_completed_plays: HashMap<String, u32> = HashMap::new();
    let mut track_skips: HashMap<String, u32> = HashMap::new();
    let mut artist_completed_plays: HashMap<String, u32> = HashMap::new();
    let mut artist_skips: HashMap<String, u32> = HashMap::new();

    for entry in history {
        let artist_key = entry.track.artist.trim().to_lowercase();
        if entry.completed_ratio >= 0.7 {
            *track_completed_plays
                .entry(entry.track.id.clone())
                .or_insert(0) += 1;
            *artist_completed_plays.entry(artist_key).or_insert(0) += 1;
        } else if entry.completed_ratio < 0.3 {
            *track_skips.entry(entry.track.id.clone()).or_insert(0) += 1;
            *artist_skips.entry(artist_key).or_insert(0) += 1;
        }
    }

    // Step 3: Compute scores
    let total_candidates = filtered_candidates.len().max(1) as f64;
    let mut scored: Vec<(f64, Track)> = filtered_candidates
        .into_iter()
        .map(|(original_idx, track)| {
            let artist_key = track.artist.trim().to_lowercase();
            let play_count = *track_completed_plays.get(&track.id).unwrap_or(&0);
            let skip_count = *track_skips.get(&track.id).unwrap_or(&0);
            let art_plays = *artist_completed_plays.get(&artist_key).unwrap_or(&0);
            let art_skips = *artist_skips.get(&artist_key).unwrap_or(&0);

            let play_bonus = (play_count as f64 * 1.5).min(6.0);
            let skip_penalty = (skip_count as f64 * 2.0).min(6.0);
            let artist_affinity =
                (art_plays as f64 * 0.8 - art_skips as f64 * 1.0).clamp(-5.0, 5.0);
            let liked_bonus = if track.is_liked { 2.5 } else { 0.0 };

            // Gentle position prior: 5.0 down to 0.0
            let position_prior = 5.0 * (1.0 - (original_idx as f64 / total_candidates));

            let final_score =
                position_prior + play_bonus + artist_affinity + liked_bonus - skip_penalty;
            (final_score, track)
        })
        .collect();

    // Sort descending by score
    scored.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));
    scored.into_iter().map(|(_, track)| track).collect()
}

/// Builds deterministic "Quick picks" row for Home screen using local history signals:
/// - Selects loved tracks (high completion ratio, liked, play count >= 1)
/// - Enforces maximum 2 tracks per artist for diversity
/// - Backfills with fallback tracks if history is sparse
pub fn build_quick_picks(
    history: &[PlayHistory],
    fallback_tracks: &[Track],
    limit: usize,
) -> Vec<Track> {
    let mut track_map: HashMap<String, (Track, f64, i64)> = HashMap::new();
    let mut track_plays: HashMap<String, u32> = HashMap::new();
    let mut track_skips: HashMap<String, u32> = HashMap::new();

    for entry in history {
        if entry.completed_ratio >= 0.5 {
            *track_plays.entry(entry.track.id.clone()).or_insert(0) += 1;
        } else if entry.completed_ratio < 0.3 {
            *track_skips.entry(entry.track.id.clone()).or_insert(0) += 1;
        }

        let record = track_map
            .entry(entry.track.id.clone())
            .or_insert_with(|| (entry.track.clone(), 0.0, entry.played_at));
        if entry.played_at > record.2 {
            record.2 = entry.played_at;
        }
    }

    // Calculate score for each unique track
    for (id, record) in track_map.iter_mut() {
        let plays = *track_plays.get(id).unwrap_or(&0);
        let skips = *track_skips.get(id).unwrap_or(&0);
        let liked_boost = if record.0.is_liked { 3.0 } else { 0.0 };
        record.1 = (plays as f64 * 2.0) + liked_boost - (skips as f64 * 2.5);
    }

    // Filter to positive engagement tracks and sort by score desc, then last played desc
    let mut candidate_list: Vec<(Track, f64, i64)> = track_map
        .into_values()
        .filter(|(_, score, _)| *score > 0.0)
        .collect();

    candidate_list.sort_by(|a, b| {
        b.1.partial_cmp(&a.1)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| b.2.cmp(&a.2))
    });

    let mut result = Vec::new();
    let mut artist_counts: HashMap<String, usize> = HashMap::new();
    let mut seen_ids: HashSet<String> = HashSet::new();

    for (track, _, _) in candidate_list {
        if result.len() >= limit {
            break;
        }
        let artist_key = track.artist.trim().to_lowercase();
        let count = artist_counts.entry(artist_key).or_insert(0);
        if *count < 2 {
            *count += 1;
            seen_ids.insert(track.id.clone());
            result.push(track);
        }
    }

    // Backfill with fallback tracks if needed (e.g. fresh install or sparse history)
    if result.len() < limit {
        for fallback in fallback_tracks {
            if result.len() >= limit {
                break;
            }
            if seen_ids.insert(fallback.id.clone()) {
                let artist_key = fallback.artist.trim().to_lowercase();
                let count = artist_counts.entry(artist_key).or_insert(0);
                if *count < 2 {
                    *count += 1;
                    result.push(fallback.clone());
                }
            }
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dummy_track(id: &str, title: &str, artist: &str, is_liked: bool) -> Track {
        Track {
            id: id.to_string(),
            source_id: id.to_string(),
            title: title.to_string(),
            artist: artist.to_string(),
            album: None,
            duration_ms: 180_000,
            cover_url: None,
            match_confidence: Some(1.0),
            is_liked,
            is_unavailable: false,
        }
    }

    #[test]
    fn test_rerank_radio_tracks_dedupes_last_n() {
        let t1 = dummy_track("t1", "Song 1", "Artist A", false);
        let t2 = dummy_track("t2", "Song 2", "Artist B", false);
        let t3 = dummy_track("t3", "Song 3", "Artist C", false);
        let t4 = dummy_track("t4", "Song 4", "Artist D", false);

        let history = vec![
            PlayHistory {
                id: 1,
                track: t1.clone(),
                played_at: 200,
                completed_ratio: 0.9,
            },
            PlayHistory {
                id: 2,
                track: t2.clone(),
                played_at: 100,
                completed_ratio: 0.8,
            },
        ];

        let candidates = vec![t1, t2, t3.clone(), t4.clone()];
        let reranked = rerank_radio_tracks(candidates, &history, 2);

        // t1 and t2 were played in last 2, must be deduped out
        assert_eq!(reranked.len(), 2);
        assert_eq!(reranked[0].id, "t3");
        assert_eq!(reranked[1].id, "t4");
    }

    #[test]
    fn test_rerank_radio_tracks_scoring_prefers_affinity_and_penalizes_skips() {
        let t_loved = dummy_track("loved", "Loved Track", "Favorite Artist", true);
        let t_skipped = dummy_track("skipped", "Skipped Track", "Skipped Artist", false);

        let history = vec![
            PlayHistory {
                id: 1,
                track: dummy_track("x1", "Hit 1", "Favorite Artist", false),
                played_at: 100,
                completed_ratio: 1.0,
            },
            PlayHistory {
                id: 2,
                track: dummy_track("x2", "Hit 2", "Favorite Artist", false),
                played_at: 90,
                completed_ratio: 1.0,
            },
            PlayHistory {
                id: 3,
                track: dummy_track("s1", "Skip 1", "Skipped Artist", false),
                played_at: 80,
                completed_ratio: 0.1,
            },
            PlayHistory {
                id: 4,
                track: dummy_track("s2", "Skip 2", "Skipped Artist", false),
                played_at: 70,
                completed_ratio: 0.1,
            },
        ];

        // Put t_skipped first in candidates to verify re-ranking overcomes position
        let candidates = vec![t_skipped.clone(), t_loved.clone()];
        let reranked = rerank_radio_tracks(candidates, &history, 0);

        assert_eq!(reranked.len(), 2);
        assert_eq!(
            reranked[0].id, "loved",
            "t_loved must rank first due to artist affinity and like bonus"
        );
        assert_eq!(
            reranked[1].id, "skipped",
            "t_skipped must be penalized for skips"
        );
    }

    #[test]
    fn test_build_quick_picks_artist_diversity() {
        let t1 = dummy_track("a1", "Track 1", "Popular Artist", false);
        let t2 = dummy_track("a2", "Track 2", "Popular Artist", false);
        let t3 = dummy_track("a3", "Track 3", "Popular Artist", false);
        let t4 = dummy_track("b1", "Track 4", "Other Artist", false);

        let history = vec![
            PlayHistory {
                id: 1,
                track: t1.clone(),
                played_at: 100,
                completed_ratio: 1.0,
            },
            PlayHistory {
                id: 2,
                track: t2.clone(),
                played_at: 90,
                completed_ratio: 1.0,
            },
            PlayHistory {
                id: 3,
                track: t3.clone(),
                played_at: 80,
                completed_ratio: 1.0,
            },
            PlayHistory {
                id: 4,
                track: t4.clone(),
                played_at: 70,
                completed_ratio: 1.0,
            },
        ];

        let picks = build_quick_picks(&history, &[], 5);
        let popular_artist_count = picks
            .iter()
            .filter(|t| t.artist == "Popular Artist")
            .count();
        assert!(
            popular_artist_count <= 2,
            "Must enforce <= 2 tracks per artist for diversity, got {}",
            popular_artist_count
        );
        assert_eq!(picks.len(), 3); // 2 from Popular Artist + 1 from Other Artist
    }

    #[test]
    fn test_artist_skip_penalty_invariant() {
        let ranker = LogisticRegressionRanker::new();
        let mut base_features = HashMap::new();
        base_features.insert("taste_sim".to_string(), 0.8);
        base_features.insert("recency".to_string(), 0.5);

        let unpenalized = ranker.compute_score(&base_features);

        let mut penalized_features = base_features.clone();
        penalized_features.insert("artist_skip_penalty".to_string(), 1.0);

        let penalized = ranker.compute_score(&penalized_features);

        // Score must drop by more than 50%
        assert!(
            penalized < unpenalized * 0.5,
            "penalized {} must be < 50% of {}",
            penalized,
            unpenalized
        );
    }
}
