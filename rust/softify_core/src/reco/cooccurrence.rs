use crate::db::repository::DatabaseRepository;
use crate::models::SoftifyError;
use std::collections::HashMap;
use std::sync::Arc;

#[derive(Debug, Clone, PartialEq)]
pub struct CooccurrencePairScore {
    pub track_a: String,
    pub track_b: String,
    pub score: f64,
}

#[derive(Debug, Clone)]
pub struct PlaySessionItem {
    pub track_id: String,
    pub played_at_ms: i64,
    pub duration_ms: i64,
}

pub struct CooccurrenceGraphBuilder {
    db: Arc<DatabaseRepository>,
}

impl CooccurrenceGraphBuilder {
    pub fn new(db: Arc<DatabaseRepository>) -> Self {
        Self { db }
    }

    /// Groups historical track plays into continuous listening sessions (sentences).
    /// Two consecutive plays belong to the same session if the gap between track completion
    /// and the next track start is <= max_gap_ms (default 60,000 ms).
    pub fn group_plays_into_sentences(
        plays: &[PlaySessionItem],
        max_gap_ms: i64,
    ) -> Vec<Vec<String>> {
        if plays.is_empty() {
            return Vec::new();
        }

        let mut sorted = plays.to_vec();
        sorted.sort_by_key(|p| p.played_at_ms);

        let mut sentences = Vec::new();
        let mut current_sentence = vec![sorted[0].track_id.clone()];
        let mut prev_end_ms = sorted[0].played_at_ms + sorted[0].duration_ms;

        for item in sorted.iter().skip(1) {
            let gap = item.played_at_ms - prev_end_ms;
            if gap <= max_gap_ms {
                current_sentence.push(item.track_id.clone());
            } else {
                if current_sentence.len() >= 2 {
                    sentences.push(current_sentence);
                }
                current_sentence = vec![item.track_id.clone()];
            }
            prev_end_ms = item.played_at_ms + item.duration_ms;
        }

        if current_sentence.len() >= 2 {
            sentences.push(current_sentence);
        }

        sentences
    }

    /// Calculates Positive Pointwise Mutual Information (PPMI) co-occurrence scores.
    pub fn compute_ppmi_scores(
        sentences: &[Vec<String>],
        window_size: usize,
    ) -> Vec<CooccurrencePairScore> {
        if sentences.is_empty() {
            return Vec::new();
        }

        let mut pair_counts: HashMap<(String, String), usize> = HashMap::new();
        let mut unigram_counts: HashMap<String, usize> = HashMap::new();
        let mut total_pairs = 0usize;

        for sentence in sentences {
            let len = sentence.len();
            for i in 0..len {
                let u = &sentence[i];
                let max_j = std::cmp::min(len, i + window_size + 1);

                for v in sentence.iter().take(max_j).skip(i + 1) {
                    if u == v {
                        continue; // Skip self co-occurrence
                    }

                    *pair_counts.entry((u.clone(), v.clone())).or_insert(0) += 1;
                    *pair_counts.entry((v.clone(), u.clone())).or_insert(0) += 1;

                    *unigram_counts.entry(u.clone()).or_insert(0) += 1;
                    *unigram_counts.entry(v.clone()).or_insert(0) += 1;

                    total_pairs += 2;
                }
            }
        }

        if total_pairs == 0 {
            return Vec::new();
        }

        let mut results = Vec::new();

        for ((u, v), c_uv) in pair_counts {
            let c_u = *unigram_counts.get(&u).unwrap_or(&1);
            let c_v = *unigram_counts.get(&v).unwrap_or(&1);

            // PMI = ln( (C(u,v) * N) / (C(u) * C(v)) )
            let numerator = (c_uv * total_pairs) as f64;
            let denominator = (c_u * c_v) as f64;

            let pmi = (numerator / denominator).ln();
            let ppmi = f64::max(0.0, pmi);

            if ppmi > 0.0 {
                results.push(CooccurrencePairScore {
                    track_a: u,
                    track_b: v,
                    score: ppmi,
                });
            }
        }

        results
    }

    pub fn rebuild_graph_from_history(&self) -> Result<usize, SoftifyError> {
        let plays = self.db.get_play_sessions_history()?;
        let sentences = Self::group_plays_into_sentences(&plays, 60_000);
        let scores = Self::compute_ppmi_scores(&sentences, 3);
        let count = scores.len();

        let now_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        self.db.batch_save_cooccurrences(&scores, now_ms)?;
        Ok(count)
    }

    pub fn get_cooccurrence_score(
        &self,
        track_a: &str,
        track_b: &str,
    ) -> Result<f64, SoftifyError> {
        self.db.get_cooccurrence_score(track_a, track_b)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_group_plays_into_sentences() {
        let plays = vec![
            PlaySessionItem {
                track_id: "t1".into(),
                played_at_ms: 1000,
                duration_ms: 10000,
            },
            PlaySessionItem {
                track_id: "t2".into(),
                played_at_ms: 12000,
                duration_ms: 10000,
            },
            // Gap = 30000 - 22000 = 8000 <= 60000 -> same sentence
            PlaySessionItem {
                track_id: "t3".into(),
                played_at_ms: 30000,
                duration_ms: 10000,
            },
            // Gap = 150000 - 40000 = 110000 > 60000 -> new sentence
            PlaySessionItem {
                track_id: "t4".into(),
                played_at_ms: 150000,
                duration_ms: 10000,
            },
            PlaySessionItem {
                track_id: "t5".into(),
                played_at_ms: 155000,
                duration_ms: 10000,
            },
        ];

        let sentences = CooccurrenceGraphBuilder::group_plays_into_sentences(&plays, 60000);
        assert_eq!(sentences.len(), 2);
        assert_eq!(sentences[0], vec!["t1", "t2", "t3"]);
        assert_eq!(sentences[1], vec!["t4", "t5"]);
    }

    #[test]
    fn test_ppmi_scores_positive() {
        let sentences = vec![
            vec!["t1".into(), "t2".into(), "t3".into()],
            vec!["t1".into(), "t2".into()],
        ];

        let scores = CooccurrenceGraphBuilder::compute_ppmi_scores(&sentences, 3);
        assert!(!scores.is_empty());
        for s in &scores {
            assert!(s.score >= 0.0);
        }
    }
}
