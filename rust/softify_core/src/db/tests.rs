use super::repository::DatabaseRepository;
use crate::models::Track;

fn create_test_track(id: &str, title: &str, artist: &str, is_liked: bool) -> Track {
    Track {
        id: id.to_string(),
        source_id: id.to_string(),
        title: title.to_string(),
        artist: artist.to_string(),
        album: Some("Test Album".to_string()),
        duration_ms: 240_000,
        cover_url: None,
        match_confidence: Some(1.0),
        is_liked,
        is_unavailable: false,
    }
}

#[test]
fn test_recent_searches_lifecycle() {
    let repo = DatabaseRepository::in_memory().unwrap();

    repo.insert_recent_search("Arijit Singh").unwrap();
    repo.insert_recent_search("Karan Aujla").unwrap();
    repo.insert_recent_search("Arijit Singh").unwrap(); // Duplicate updates timestamp

    let recent = repo.get_recent_searches(10).unwrap();
    assert_eq!(recent.len(), 2);
    assert_eq!(recent[0], "Arijit Singh", "Most recently updated search must be first");
    assert_eq!(recent[1], "Karan Aujla");

    repo.delete_recent_search("Karan Aujla").unwrap();
    let recent_after_delete = repo.get_recent_searches(10).unwrap();
    assert_eq!(recent_after_delete, vec!["Arijit Singh"]);

    repo.clear_recent_searches().unwrap();
    let recent_after_clear = repo.get_recent_searches(10).unwrap();
    assert!(recent_after_clear.is_empty());
}

#[test]
fn test_incognito_mode_blocks_recent_searches_and_history() {
    let repo = DatabaseRepository::in_memory().unwrap();
    let track = create_test_track("t_incognito", "Secret Song", "Secret Artist", false);
    repo.insert_or_update_track(&track).unwrap();

    // Normal mode: recordings work
    repo.insert_recent_search("Normal Query").unwrap();
    repo.record_play_history("t_incognito", 0.9).unwrap();

    let searches = repo.get_recent_searches(10).unwrap();
    assert_eq!(searches, vec!["Normal Query"]);
    let history = repo.get_history(10).unwrap();
    assert_eq!(history.len(), 1);

    // Enable incognito (learning_paused = true)
    repo.set_setting("learning_paused", "true").unwrap();

    repo.insert_recent_search("Incognito Query").unwrap();
    repo.record_play_history("t_incognito", 1.0).unwrap();

    // Verifications: incognito queries and plays were not recorded
    let searches_after = repo.get_recent_searches(10).unwrap();
    assert_eq!(searches_after, vec!["Normal Query"]);
    let history_after = repo.get_history(10).unwrap();
    assert_eq!(history_after.len(), 1);

    // Disable incognito: recordings resume
    repo.set_setting("learning_paused", "false").unwrap();
    repo.insert_recent_search("Resumed Query").unwrap();
    let searches_resumed = repo.get_recent_searches(10).unwrap();
    assert_eq!(searches_resumed.len(), 2);
}

#[test]
fn test_smart_playlists_rules_and_edge_cases() {
    let repo = DatabaseRepository::in_memory().unwrap();

    // Setup tracks
    let t1 = create_test_track("t1", "Track 1", "Artist 1", true); // Liked, played 5 days ago (3 times)
    let t2 = create_test_track("t2", "Track 2", "Artist 2", false); // Unliked, played 5 days ago (3 times, ties t1 on count, earlier timestamp)
    let t3 = create_test_track("t3", "Track 3", "Artist 3", true); // Liked, played 20 days ago (past 14 days, inside 30 days)
    let t4 = create_test_track("t4", "Track 4", "Artist 4", true); // Liked, played 75 days ago (older than 60 days)
    let t5 = create_test_track("t5", "Track 5", "Artist 5", true); // Liked, NEVER played
    let t6 = create_test_track("t6", "Track 6", "Artist 6", false); // Unliked, NEVER played

    repo.insert_or_update_track(&t1).unwrap();
    repo.insert_or_update_track(&t2).unwrap();
    repo.insert_or_update_track(&t3).unwrap();
    repo.insert_or_update_track(&t4).unwrap();
    repo.insert_or_update_track(&t5).unwrap();
    repo.insert_or_update_track(&t6).unwrap();

    // Fixed reference time: 2026-11-15T00:00:00Z in ms
    let now_ms = 1_794_700_800_000u64;
    let now_sec = (now_ms / 1000) as i64;

    // Direct manual insertion into play_histories with explicit timestamps to test rules
    let conn = repo.get_connection();
    let c = conn.lock().unwrap();

    // t1: played 5 days ago, 3 plays (latest played: now_sec - 5*86400)
    for i in 0..3 {
        c.execute(
            "INSERT INTO play_histories (track_id, played_at, completed_ratio) VALUES ('t1', ?1, 1.0)",
            rusqlite::params![now_sec - (5 * 86_400) + i],
        ).unwrap();
    }

    // t2: played 5 days ago, 3 plays (latest played: now_sec - 6*86400, older than t1)
    for i in 0..3 {
        c.execute(
            "INSERT INTO play_histories (track_id, played_at, completed_ratio) VALUES ('t2', ?1, 1.0)",
            rusqlite::params![now_sec - (6 * 86_400) + i],
        ).unwrap();
    }

    // t3: played 20 days ago, 5 plays
    for i in 0..5 {
        c.execute(
            "INSERT INTO play_histories (track_id, played_at, completed_ratio) VALUES ('t3', ?1, 1.0)",
            rusqlite::params![now_sec - (20 * 86_400) + i],
        ).unwrap();
    }

    // t4: played 75 days ago, 2 plays
    for i in 0..2 {
        c.execute(
            "INSERT INTO play_histories (track_id, played_at, completed_ratio) VALUES ('t4', ?1, 1.0)",
            rusqlite::params![now_sec - (75 * 86_400) + i],
        ).unwrap();
    }
    drop(c);

    // --- 1. Test On Repeat (Past 14 Days) ---
    // Rule: played within 14 days. t1 (3 plays), t2 (3 plays). t3 (20 days ago) is excluded!
    // Tie-break: t1 last played 5 days ago > t2 last played 6 days ago -> t1 first.
    let on_repeat = repo.get_on_repeat_tracks(now_ms, 10).unwrap();
    assert_eq!(on_repeat.len(), 2, "Only tracks within 14 days qualify for On Repeat");
    assert_eq!(on_repeat[0].id, "t1", "t1 wins tie-break due to more recent play time");
    assert_eq!(on_repeat[1].id, "t2");

    // --- 2. Test Most Played (Past 30 Days) ---
    // Rule: played within 30 days. t3 (5 plays), t1 (3 plays), t2 (3 plays). t4 (75 days ago) is excluded!
    let most_played = repo.get_most_played_tracks(now_ms, 10).unwrap();
    assert_eq!(most_played.len(), 3, "Only tracks within 30 days qualify for Most Played");
    assert_eq!(most_played[0].id, "t3", "t3 has highest play count (5 plays)");
    assert_eq!(most_played[1].id, "t1", "t1 has 3 plays, more recent than t2");
    assert_eq!(most_played[2].id, "t2");

    // --- 3. Test Forgotten Favorites (Liked, Not Played in 60+ Days) ---
    // Candidates among liked tracks (t1, t3, t4, t5):
    // t1: played 5 days ago -> EXCLUDED
    // t3: played 20 days ago -> EXCLUDED
    // t4: played 75 days ago (older than 60 days) -> INCLUDED
    // t5: liked, NEVER played -> INCLUDED (edge case verified)
    // t6: unliked, never played -> EXCLUDED (not liked)
    let forgotten = repo.get_forgotten_favorites_tracks(now_ms, 10).unwrap();
    let forgotten_ids: Vec<String> = forgotten.into_iter().map(|t| t.id).collect();
    assert_eq!(forgotten_ids.len(), 2);
    assert!(forgotten_ids.contains(&"t4".to_string()), "t4 (played 75 days ago) must be included");
    assert!(forgotten_ids.contains(&"t5".to_string()), "t5 (liked, never played) must be included");
    assert!(!forgotten_ids.contains(&"t1".to_string()), "t1 (played 5 days ago) must be excluded");
    assert!(!forgotten_ids.contains(&"t3".to_string()), "t3 (played 20 days ago) must be excluded");
    assert!(!forgotten_ids.contains(&"t6".to_string()), "t6 (not liked) must be excluded");
}

#[test]
fn test_playlist_rename() {
    let repo = DatabaseRepository::in_memory().unwrap();
    let pl = repo.create_playlist("Old Name", Some("Description")).unwrap();
    assert_eq!(pl.name, "Old Name");

    repo.rename_playlist(&pl.id, "New Brand Name").unwrap();
    let all = repo.get_playlists().unwrap();
    assert_eq!(all.len(), 1);
    assert_eq!(all[0].name, "New Brand Name");

    // Non-existent playlist rename must fail
    let err = repo.rename_playlist("non_existent_id", "Fails");
    assert!(err.is_err());
}

#[test]
fn test_get_tracks_by_artist_and_album() {
    let repo = DatabaseRepository::in_memory().unwrap();
    let mut t1 = create_test_track("t_art1", "Song A", "The Beatles", false);
    t1.album = Some("Abbey Road".to_string());
    let mut t2 = create_test_track("t_art2", "Song B", "The Beatles", true);
    t2.album = Some("Let It Be".to_string());
    let mut t3 = create_test_track("t_art3", "Song C", "Queen", false);
    t3.album = Some("A Night at the Opera".to_string());

    repo.insert_or_update_track(&t1).unwrap();
    repo.insert_or_update_track(&t2).unwrap();
    repo.insert_or_update_track(&t3).unwrap();

    let beatles_tracks = repo.get_tracks_by_artist("The Beatles", 10).unwrap();
    assert_eq!(beatles_tracks.len(), 2);
    assert_eq!(beatles_tracks[0].artist, "The Beatles");

    let abbey_road = repo.get_tracks_by_album("Abbey Road", 10).unwrap();
    assert_eq!(abbey_road.len(), 1);
    assert_eq!(abbey_road[0].title, "Song A");

    let empty = repo.get_tracks_by_artist("Unknown Artist", 10).unwrap();
    assert!(empty.is_empty());
}
