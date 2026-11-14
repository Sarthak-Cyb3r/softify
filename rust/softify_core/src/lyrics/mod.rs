pub mod parser;
pub mod lrclib;
pub mod engine;

#[cfg(test)]
mod tests {
    use super::engine::LyricsEngine;
    use super::lrclib::LrclibClient;
    use crate::db::repository::DatabaseRepository;
    use crate::models::Track;
    use wiremock::matchers::{method, path, query_param};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    fn dummy_track(id: &str) -> Track {
        Track {
            id: id.to_string(),
            source_id: format!("src_{}", id),
            title: "Kesariya".to_string(),
            artist: "Arijit Singh".to_string(),
            album: Some("Brahmāstra".to_string()),
            duration_ms: 268_000,
            cover_url: None,
            match_confidence: Some(1.0),
            is_liked: false,
            is_unavailable: false,
        }
    }

    #[tokio::test]
    async fn test_lyrics_fetch_and_caching() {
        let mock_server = MockServer::start().await;
        let lrclib_body = r#"{
            "id": 12345,
            "trackName": "Kesariya",
            "artistName": "Arijit Singh",
            "albumName": "Brahmāstra",
            "duration": 268,
            "instrumental": false,
            "plainLyrics": "Kesariya tera ishq hai piya",
            "syncedLyrics": "[00:10.50] Kesariya tera ishq hai piya\n[00:15.20] Rang jaaun jo main haath lagaun"
        }"#;

        Mock::given(method("GET"))
            .and(path("/get"))
            .and(query_param("track_name", "Kesariya"))
            .and(query_param("artist_name", "Arijit Singh"))
            .respond_with(ResponseTemplate::new(200).set_body_string(lrclib_body))
            .mount(&mock_server)
            .await;

        let db = DatabaseRepository::in_memory().unwrap();
        let lrclib = LrclibClient::with_client_and_base_url(reqwest::Client::new(), mock_server.uri());
        let engine = LyricsEngine::with_lrclib(Some(db.clone()), lrclib);

        let track = dummy_track("k1");
        db.insert_or_update_track(&track).unwrap();

        // First call: from mock server and saves to cache
        let lyrics = engine.get_lyrics(&track).await.unwrap();
        assert!(lyrics.is_synced);
        assert_eq!(lyrics.lines.len(), 2);
        assert_eq!(lyrics.lines[0].text, "Kesariya tera ishq hai piya");

        // Verify it was saved to DB cache
        let cached = db.get_cached_lyrics("k1").unwrap();
        assert!(cached.is_some());
        let (synced, plain, is_nf) = cached.unwrap();
        assert!(!is_nf);
        assert!(synced.unwrap().contains("[00:10.50]"));
        assert_eq!(plain.unwrap(), "Kesariya tera ishq hai piya");

        // Second call: served directly from cache (even if mock server is down/not called)
        let cached_lyrics = engine.get_lyrics(&track).await.unwrap();
        assert!(cached_lyrics.is_synced);
        assert_eq!(cached_lyrics.lines[0].text, "Kesariya tera ishq hai piya");
    }

    #[tokio::test]
    async fn test_lyrics_lrclib_synced_and_plain_fallback() {
        let mock_server = MockServer::start().await;
        // Response with only plain lyrics (syncedLyrics is null)
        let lrclib_body = r#"{
            "id": 9999,
            "trackName": "Plain Song",
            "artistName": "Plain Artist",
            "albumName": null,
            "duration": 200,
            "instrumental": false,
            "plainLyrics": "Line one plain\nLine two plain",
            "syncedLyrics": null
        }"#;

        Mock::given(method("GET"))
            .and(path("/get"))
            .and(query_param("track_name", "Plain Song"))
            .and(query_param("artist_name", "Plain Artist"))
            .respond_with(ResponseTemplate::new(200).set_body_string(lrclib_body))
            .mount(&mock_server)
            .await;

        let db = DatabaseRepository::in_memory().unwrap();
        let lrclib = LrclibClient::with_client_and_base_url(reqwest::Client::new(), mock_server.uri());
        let engine = LyricsEngine::with_lrclib(Some(db.clone()), lrclib);

        let mut track = dummy_track("p1");
        track.title = "Plain Song".to_string();
        track.artist = "Plain Artist".to_string();
        db.insert_or_update_track(&track).unwrap();

        let lyrics = engine.get_lyrics(&track).await.unwrap();
        assert!(!lyrics.is_synced, "Must fallback to unsynced/plain");
        assert_eq!(lyrics.plain_text.as_deref(), Some("Line one plain\nLine two plain"));
    }
}
