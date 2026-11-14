use crate::models::SearchIntent;
use super::normalizer::normalize_search_text;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QueryIntentAnalysis {
    pub intent: SearchIntent,
    pub entity: Option<String>,
    pub clean_query: String,
}

pub fn analyze_query_intent(query: &str) -> QueryIntentAnalysis {
    let normalized = normalize_search_text(query);
    if normalized.is_empty() {
        return QueryIntentAnalysis {
            intent: SearchIntent::General,
            entity: None,
            clean_query: String::new(),
        };
    }

    // Explicit prefix patterns
    if let Some(rest) = normalized.strip_prefix("artist ") {
        return QueryIntentAnalysis {
            intent: SearchIntent::Artist,
            entity: Some(rest.trim().to_string()),
            clean_query: rest.trim().to_string(),
        };
    }

    if let Some(rest) = normalized.strip_prefix("album ") {
        return QueryIntentAnalysis {
            intent: SearchIntent::Album,
            entity: Some(rest.trim().to_string()),
            clean_query: rest.trim().to_string(),
        };
    }

    if let Some(rest) = normalized.strip_prefix("song ") {
        return QueryIntentAnalysis {
            intent: SearchIntent::Track,
            entity: Some(rest.trim().to_string()),
            clean_query: rest.trim().to_string(),
        };
    }

    if let Some(rest) = normalized.strip_prefix("track ") {
        return QueryIntentAnalysis {
            intent: SearchIntent::Track,
            entity: Some(rest.trim().to_string()),
            clean_query: rest.trim().to_string(),
        };
    }

    // "songs by <artist>" or "by <artist>"
    if let Some(pos) = normalized.find(" by ") {
        let artist_part = &normalized[pos + 4..].trim();
        if !artist_part.is_empty() {
            return QueryIntentAnalysis {
                intent: SearchIntent::Artist,
                entity: Some((*artist_part).to_string()),
                clean_query: (*artist_part).to_string(),
            };
        }
    }

    // Default to General intent with full normalized query
    QueryIntentAnalysis {
        intent: SearchIntent::General,
        entity: None,
        clean_query: normalized,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_intent_analysis() {
        let res1 = analyze_query_intent("songs by Arijit Singh");
        assert_eq!(res1.intent, SearchIntent::Artist);
        assert_eq!(res1.entity.as_deref(), Some("arijit singh"));

        let res2 = analyze_query_intent("artist The Weeknd");
        assert_eq!(res2.intent, SearchIntent::Artist);
        assert_eq!(res2.entity.as_deref(), Some("the weeknd"));

        let res3 = analyze_query_intent("album Brahmastra");
        assert_eq!(res3.intent, SearchIntent::Album);
        assert_eq!(res3.entity.as_deref(), Some("brahmastra"));

        let res4 = analyze_query_intent("Blinding Lights");
        assert_eq!(res4.intent, SearchIntent::General);
        assert_eq!(res4.clean_query, "blinding lights");
    }
}
