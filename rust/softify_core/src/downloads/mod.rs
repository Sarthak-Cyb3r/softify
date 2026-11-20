pub mod manager;
pub mod tagger;

#[cfg(test)]
mod tests {
    use super::manager::DownloadManager;
    use crate::db::repository::DatabaseRepository;
    use crate::models::Track;
    use crate::resolvers::hybrid::HybridStreamResolver;
    use std::sync::Arc;

    fn sample_track(id: &str) -> Track {
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
    async fn test_download_recording_and_retrieval() {
        let db = DatabaseRepository::in_memory().unwrap();
        let track = sample_track("t1");
        db.insert_or_update_track(&track).unwrap();

        let resolver = Arc::new(HybridStreamResolver::new());
        let manager = DownloadManager::new(resolver, Some(db.clone()));

        // Test DB download records directly
        db.record_download(
            "t1",
            "/downloads/t1.m4a",
            "m4a",
            10_000_000,
            10_000_000,
            "completed",
            320,
            None,
        )
        .unwrap();

        let downloads = manager.get_downloads().unwrap();
        assert_eq!(downloads.len(), 1);
        assert_eq!(downloads[0].track_id, "t1");
        assert_eq!(downloads[0].bitrate_kbps, 320);
        assert_eq!(downloads[0].status, "completed");

        manager.delete_download("t1").unwrap();
        let after_delete = manager.get_downloads().unwrap();
        assert!(after_delete.is_empty());
    }
}
