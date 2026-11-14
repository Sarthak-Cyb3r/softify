use super::engine::SearchEngine;
use crate::db::repository::DatabaseRepository;
use crate::models::{SearchIntent, Track};

fn sample_track(id: &str, title: &str, artist: &str, album: Option<&str>) -> Track {
    Track {
        id: id.to_string(),
        source_id: format!("src_{}", id),
        title: title.to_string(),
        artist: artist.to_string(),
        album: album.map(|s| s.to_string()),
        duration_ms: 240_000,
        cover_url: Some("https://example.com/cover.jpg".to_string()),
        match_confidence: Some(1.0),
        is_liked: false,
        is_unavailable: false,
    }
}

#[test]
fn test_fts5_prefix_matching() {
    let repo = DatabaseRepository::in_memory().expect("in-memory db");
    let engine = SearchEngine::new(repo.clone());

    let t1 = sample_track("1", "Kesariya", "Arijit Singh", Some("Brahmāstra"));
    let t2 = sample_track("2", "Tum Hi Ho", "Arijit Singh", Some("Aashiqui 2"));
    let t3 = sample_track("3", "Blinding Lights", "The Weeknd", Some("After Hours"));
    let t4 = sample_track("4", "Starboy", "The Weeknd", Some("Starboy"));

    repo.insert_or_update_track(&t1).unwrap();
    repo.insert_or_update_track(&t2).unwrap();
    repo.insert_or_update_track(&t3).unwrap();
    repo.insert_or_update_track(&t4).unwrap();

    // 1. Partial prefix match for artist "arij"
    let results = engine.search_library("arij", 10).unwrap();
    assert_eq!(results.len(), 2);
    let ids: Vec<&str> = results.iter().map(|t| t.id.as_str()).collect();
    assert!(ids.contains(&"1"));
    assert!(ids.contains(&"2"));

    // 2. Partial prefix match for title "blind"
    let results = engine.search_library("blind", 10).unwrap();
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].title, "Blinding Lights");

    // 3. Multi-token match across title and artist "weeknd star"
    let results = engine.search_library("weeknd star", 10).unwrap();
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].title, "Starboy");

    // 4. Diacritics matching: search "brahmastra" matches "Brahmāstra"
    let results = engine.search_library("brahmastra", 10).unwrap();
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].id, "1");
}

#[test]
fn test_playlist_and_history_lifecycle() {
    let repo = DatabaseRepository::in_memory().expect("in-memory db");

    let t1 = sample_track("t1", "Chaleya", "Arijit Singh", None);
    let t2 = sample_track("t2", "Apna Bana Le", "Arijit Singh", None);
    repo.insert_or_update_track(&t1).unwrap();
    repo.insert_or_update_track(&t2).unwrap();

    // 1. Toggle like
    let is_liked = repo.toggle_like("t1").unwrap();
    assert!(is_liked);
    let liked = repo.get_liked_tracks().unwrap();
    assert_eq!(liked.len(), 1);
    assert_eq!(liked[0].id, "t1");

    let is_unliked = repo.toggle_like("t1").unwrap();
    assert!(!is_unliked);
    let liked_after = repo.get_liked_tracks().unwrap();
    assert!(liked_after.is_empty());

    // 2. Playlists
    let pl = repo.create_playlist("Bollywood Chill", Some("Best songs")).unwrap();
    assert_eq!(pl.name, "Bollywood Chill");

    repo.add_to_playlist(&pl.id, "t1").unwrap();
    repo.add_to_playlist(&pl.id, "t2").unwrap();

    let pl_tracks = repo.get_playlist_tracks(&pl.id).unwrap();
    assert_eq!(pl_tracks.len(), 2);
    assert_eq!(pl_tracks[0].id, "t1");
    assert_eq!(pl_tracks[1].id, "t2");

    repo.remove_from_playlist(&pl.id, "t1").unwrap();
    let pl_tracks_after = repo.get_playlist_tracks(&pl.id).unwrap();
    assert_eq!(pl_tracks_after.len(), 1);
    assert_eq!(pl_tracks_after[0].id, "t2");

    repo.delete_playlist(&pl.id).unwrap();
    let playlists = repo.get_playlists().unwrap();
    assert!(playlists.is_empty());

    // 3. Play History
    repo.record_play_history("t2", 0.95).unwrap();
    let history = repo.get_history(10).unwrap();
    assert_eq!(history.len(), 1);
    assert_eq!(history[0].track.id, "t2");
    assert_eq!(history[0].completed_ratio, 0.95);

    repo.clear_history().unwrap();
    let history_cleared = repo.get_history(10).unwrap();
    assert!(history_cleared.is_empty());
}

#[test]
fn test_search_results_processing_and_deduplication() {
    let repo = DatabaseRepository::in_memory().expect("in-memory db");
    let engine = SearchEngine::new(repo.clone());

    let local_t = sample_track("local_1", "Flowers", "Miley Cyrus", None);
    repo.insert_or_update_track(&local_t).unwrap();

    let online_duplicate = sample_track("local_1", "Flowers", "Miley Cyrus", None);
    let online_new = sample_track("yt_99", "Angels Like You", "Miley Cyrus", None);

    let res = engine.process_search_results(
        "songs by Miley Cyrus",
        vec![online_duplicate, online_new],
        10,
    ).unwrap();

    assert_eq!(res.intent, SearchIntent::Artist);
    assert_eq!(res.detected_entity.as_deref(), Some("miley cyrus"));
    assert_eq!(res.local_tracks.len(), 1);
    assert_eq!(res.local_tracks[0].id, "local_1");

    // Online duplicate should be filtered out
    assert_eq!(res.online_tracks.len(), 1);
    assert_eq!(res.online_tracks[0].id, "yt_99");
}
