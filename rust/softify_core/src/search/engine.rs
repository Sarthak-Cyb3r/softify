use super::intent::analyze_query_intent;
use super::normalizer::normalize_search_text;
use crate::db::repository::DatabaseRepository;
use crate::models::{SearchResult, SoftifyError, Track};

pub struct SearchEngine {
    db: DatabaseRepository,
}

impl SearchEngine {
    pub fn new(db: DatabaseRepository) -> Self {
        Self { db }
    }

    /// Formats a search query into an FTS5 match expression with prefix tokens
    pub fn build_fts5_query(query: &str) -> String {
        let normalized = normalize_search_text(query);
        let tokens: Vec<&str> = normalized.split_whitespace().collect();
        if tokens.is_empty() {
            return String::new();
        }

        tokens
            .into_iter()
            .map(|t| format!("\"{}\"*", t.replace('"', "\"\"")))
            .collect::<Vec<String>>()
            .join(" ")
    }

    /// Pure offline search over local library using FTS5
    pub fn search_library(&self, query: &str, limit: u32) -> Result<Vec<Track>, SoftifyError> {
        let fts_query = Self::build_fts5_query(query);
        if fts_query.is_empty() {
            return Ok(Vec::new());
        }

        self.db.search_local_tracks_fts(&fts_query, limit)
    }

    /// Combined search: analyzes intent, performs local FTS5 search instantly,
    /// and incorporates online results with deduplication
    pub fn process_search_results(
        &self,
        query: &str,
        online_tracks: Vec<Track>,
        limit: u32,
    ) -> Result<SearchResult, SoftifyError> {
        let intent_info = analyze_query_intent(query);
        let local_tracks = self.search_library(&intent_info.clean_query, limit)?;

        // Deduplicate online tracks against local tracks
        let local_ids: std::collections::HashSet<String> =
            local_tracks.iter().map(|t| t.id.clone()).collect();
        let local_source_ids: std::collections::HashSet<String> =
            local_tracks.iter().map(|t| t.source_id.clone()).collect();

        let filtered_online: Vec<Track> = online_tracks
            .into_iter()
            .filter(|t| !local_ids.contains(&t.id) && !local_source_ids.contains(&t.source_id))
            .take(limit as usize)
            .collect();

        Ok(SearchResult {
            local_tracks,
            online_tracks: filtered_online,
            intent: intent_info.intent,
            detected_entity: intent_info.entity,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fts5_query_builder() {
        assert_eq!(
            SearchEngine::build_fts5_query("Arijit Singh"),
            "\"arijit\"* \"singh\"*"
        );
        assert_eq!(SearchEngine::build_fts5_query("Kesariya"), "\"kesariya\"*");
        assert_eq!(SearchEngine::build_fts5_query("   "), "");
    }
}
