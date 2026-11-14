use std::collections::HashMap;

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

        candidates.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(std::cmp::Ordering::Equal));
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
            self.weights.insert(key.clone(), current - (learning_rate * error * val));
        }

        // Update bias
        let current_bias = *self.weights.get("bias").unwrap_or(&0.0);
        self.weights.insert("bias".to_string(), current_bias - (learning_rate * error));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
        assert!(penalized < unpenalized * 0.5, "penalized {} must be < 50% of {}", penalized, unpenalized);
    }
}
