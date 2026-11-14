use base64::Engine;
use cipher::{BlockEncrypt, KeyInit, generic_array::GenericArray};
use des::Des;
use wiremock::matchers::{method, path, query_param};
use wiremock::{Mock, MockServer, ResponseTemplate};

use crate::models::{QualityPreset, Track};
use crate::resolvers::saavn::{normalize, phonetic_simplify, SaavnStreamResolver};
use crate::resolvers::youtube::YoutubeStreamResolver;

fn encrypt_test_url(url: &str) -> String {
    let cipher = Des::new_from_slice(b"38346591").unwrap();
    let mut bytes = url.as_bytes().to_vec();
    while bytes.len() % 8 != 0 {
        bytes.push(0);
    }
    for chunk in bytes.chunks_exact_mut(8) {
        let block = GenericArray::from_mut_slice(chunk);
        cipher.encrypt_block(block);
    }
    base64::engine::general_purpose::STANDARD.encode(&bytes)
}

#[test]
fn test_des_decryption_roundtrip() {
    let original = "http://aac.saavn.cdn.jio.com/123/sample_song_320.mp4";
    let encrypted = encrypt_test_url(original);
    let decrypted = SaavnStreamResolver::decrypt_media_url(&encrypted).unwrap();
    assert_eq!(decrypted, "https://aac.saavn.cdn.jio.com/123/sample_song_320.mp4");
}

#[test]
fn test_url_rewrite_presets() {
    let base = "https://aac.saavn.cdn.jio.com/123/song_160.mp4";
    assert_eq!(
        SaavnStreamResolver::rewrite_bitrate_url(base, 320),
        "https://aac.saavn.cdn.jio.com/123/song_320.mp4"
    );
    assert_eq!(
        SaavnStreamResolver::rewrite_bitrate_url(base, 160),
        "https://aac.saavn.cdn.jio.com/123/song_160.mp4"
    );
    assert_eq!(
        SaavnStreamResolver::rewrite_bitrate_url(base, 96),
        "https://aac.saavn.cdn.jio.com/123/song_96.mp4"
    );
}

#[test]
fn test_bitrate_sanity_check() {
    let duration_sec = 200;
    // 320 kbps -> 40 KB/s -> ~8,000,000 bytes
    assert!(SaavnStreamResolver::is_bitrate_sane(8_000_000, duration_sec, 320));
    // 4,000,000 bytes for 200s is ~20 KB/s, which is 160 kbps, not 320 kbps
    assert!(!SaavnStreamResolver::is_bitrate_sane(4_000_000, duration_sec, 320));
    assert!(SaavnStreamResolver::is_bitrate_sane(4_000_000, duration_sec, 160));
    // 2,400,000 bytes for 200s is ~12 KB/s, which is 96 kbps
    assert!(SaavnStreamResolver::is_bitrate_sane(2_400_000, duration_sec, 96));
}

#[test]
fn test_normalization_and_phonetic_simplify() {
    assert_eq!(normalize("Tum Hi Ho (Official Video) [Aashiqui 2]"), "tum hi ho");
    assert_eq!(normalize("Adele - Rolling In The Deep"), "adele rolling in the deep");
    assert_eq!(phonetic_simplify("Saaiyaan"), "saiyan");
}

#[tokio::test]
async fn test_fixture_320_selected_when_available() {
    let server = MockServer::start().await;
    let base_url = server.uri();

    let stream_base = format!("{}/stream/song_320.mp4", base_url);
    let encrypted = encrypt_test_url(&stream_base);

    // Mock search
    let search_json = serde_json::json!({
        "results": [{
            "id": "pid_101",
            "title": "Tum Hi Ho",
            "subtitle": "Arijit Singh - Aashiqui 2",
            "language": "hindi",
            "singers": "Arijit Singh",
            "primary_artists": "Arijit Singh",
            "more_info": {
                "album": "Aashiqui 2",
                "duration": "262",
                "artistMap": {
                    "primary_artists": [{"name": "Arijit Singh"}]
                }
            }
        }]
    });

    Mock::given(method("GET"))
        .and(path("/api.php"))
        .and(query_param("__call", "search.getResults"))
        .respond_with(ResponseTemplate::new(200).set_body_json(&search_json))
        .mount(&server)
        .await;

    // Mock song details
    let details_json = serde_json::json!({
        "songs": [{
            "id": "pid_101",
            "more_info": {
                "encrypted_media_url": encrypted
            }
        }]
    });

    Mock::given(method("GET"))
        .and(path("/api.php"))
        .and(query_param("__call", "song.getDetails"))
        .respond_with(ResponseTemplate::new(200).set_body_json(&details_json))
        .mount(&server)
        .await;

    // Mock stream probe for 320 kbps: 262s duration * 40,000 = 10,480,000 bytes
    Mock::given(method("GET"))
        .and(path("/stream/song_320.mp4"))
        .respond_with(
            ResponseTemplate::new(206)
                .insert_header("Content-Range", "bytes 0-0/10480000")
                .set_body_bytes(vec![0u8]),
        )
        .mount(&server)
        .await;

    let resolver = SaavnStreamResolver::with_client_and_base_url(reqwest::Client::new(), base_url);
    let track = Track {
        id: "test_1".to_string(),
        source_id: "test_1".to_string(),
        title: "Tum Hi Ho".to_string(),
        artist: "Arijit Singh".to_string(),
        album: Some("Aashiqui 2".to_string()),
        duration_ms: 262_000,
        cover_url: None,
        match_confidence: None,
        is_liked: false,
        is_unavailable: false,
    };

    let result = resolver.resolve(&track, QualityPreset::High).await.unwrap();
    assert_eq!(result.bitrate_kbps, 320);
    assert!(result.is_requested_quality);
    assert_eq!(result.codec, "aac");
    assert!(result.url.contains("_320.mp4"));
}

#[tokio::test]
async fn test_fixture_320_fails_steps_down_to_160() {
    let server = MockServer::start().await;
    let base_url = server.uri();

    let stream_base = format!("{}/stream/song_320.mp4", base_url);
    let encrypted = encrypt_test_url(&stream_base);

    // Mock search
    let search_json = serde_json::json!({
        "results": [{
            "id": "pid_102",
            "title": "Kesariya",
            "subtitle": "Arijit Singh - Brahmastra",
            "language": "hindi",
            "singers": "Arijit Singh",
            "primary_artists": "Arijit Singh",
            "more_info": {
                "album": "Brahmastra",
                "duration": "240",
                "artistMap": {
                    "primary_artists": [{"name": "Arijit Singh"}]
                }
            }
        }]
    });

    Mock::given(method("GET"))
        .and(path("/api.php"))
        .and(query_param("__call", "search.getResults"))
        .respond_with(ResponseTemplate::new(200).set_body_json(&search_json))
        .mount(&server)
        .await;

    // Mock song details
    let details_json = serde_json::json!({
        "songs": [{
            "id": "pid_102",
            "more_info": {
                "encrypted_media_url": encrypted
            }
        }]
    });

    Mock::given(method("GET"))
        .and(path("/api.php"))
        .and(query_param("__call", "song.getDetails"))
        .respond_with(ResponseTemplate::new(200).set_body_json(&details_json))
        .mount(&server)
        .await;

    // Mock 320 returns 404 (file missing on CDN edge)
    Mock::given(method("GET"))
        .and(path("/stream/song_320.mp4"))
        .respond_with(ResponseTemplate::new(404))
        .mount(&server)
        .await;

    // Mock 160 returns 206 with correct 160 kbps size (240s * 20,000 = 4,800,000 bytes)
    Mock::given(method("GET"))
        .and(path("/stream/song_160.mp4"))
        .respond_with(
            ResponseTemplate::new(206)
                .insert_header("Content-Range", "bytes 0-0/4800000")
                .set_body_bytes(vec![0u8]),
        )
        .mount(&server)
        .await;

    let resolver = SaavnStreamResolver::with_client_and_base_url(reqwest::Client::new(), base_url);
    let track = Track {
        id: "test_2".to_string(),
        source_id: "test_2".to_string(),
        title: "Kesariya".to_string(),
        artist: "Arijit Singh".to_string(),
        album: Some("Brahmastra".to_string()),
        duration_ms: 240_000,
        cover_url: None,
        match_confidence: None,
        is_liked: false,
        is_unavailable: false,
    };

    // Requested High (320), but 320 failed so stepped down to 160.
    // Invariant: is_requested_quality MUST BE FALSE! Never lie about bitrate.
    let result = resolver.resolve(&track, QualityPreset::High).await.unwrap();
    assert_eq!(result.bitrate_kbps, 160);
    assert!(!result.is_requested_quality); // Downgrade honestly reported!
    assert_eq!(result.codec, "aac");
    assert!(result.url.contains("_160.mp4"));
}

#[tokio::test]
async fn test_fixture_saavn_fully_unavailable_triggers_youtube_fallback() {
    let server = MockServer::start().await;
    let base_url = server.uri();

    // Mock search returns no results
    let search_json = serde_json::json!({ "results": [] });

    Mock::given(method("GET"))
        .and(path("/api.php"))
        .and(query_param("__call", "search.getResults"))
        .respond_with(ResponseTemplate::new(200).set_body_json(&search_json))
        .mount(&server)
        .await;

    let saavn = SaavnStreamResolver::with_client_and_base_url(reqwest::Client::new(), base_url);
    let track = Track {
        id: "rare_indie_track".to_string(),
        source_id: "rare_indie_track".to_string(),
        title: "Some Obscure Track".to_string(),
        artist: "Indie Unknown".to_string(),
        album: None,
        duration_ms: 180_000,
        cover_url: None,
        match_confidence: None,
        is_liked: false,
        is_unavailable: false,
    };

    let saavn_res = saavn.resolve(&track, QualityPreset::High).await;
    assert!(saavn_res.is_err()); // Saavn fails gracefully
}

#[tokio::test]
async fn test_youtube_fallback_honest_bitrate_marking() {
    let server = MockServer::start().await;
    let player_url = format!("{}/youtubei/v1/player", server.uri());
    let music_search_url = format!("{}/youtubei/v1/search", server.uri());

    let player_json = serde_json::json!({
        "playabilityStatus": { "status": "OK" },
        "streamingData": {
            "adaptiveFormats": [
                {
                    "itag": 140,
                    "mimeType": "audio/mp4; codecs=\"mp4a.40.2\"",
                    "bitrate": 128450,
                    "url": "https://rr1---sn-mock.googlevideo.com/videoplayback?itag=140"
                }
            ]
        }
    });

    Mock::given(method("POST"))
        .and(path("/youtubei/v1/player"))
        .respond_with(ResponseTemplate::new(200).set_body_json(&player_json))
        .mount(&server)
        .await;

    let yt = YoutubeStreamResolver::with_client_and_urls(reqwest::Client::new(), player_url, music_search_url);
    let track = Track {
        id: "yt_dQw4w9WgXcQ".to_string(),
        source_id: "dQw4w9WgXcQ".to_string(),
        title: "Never Gonna Give You Up".to_string(),
        artist: "Rick Astley".to_string(),
        album: None,
        duration_ms: 212_000,
        cover_url: None,
        match_confidence: None,
        is_liked: false,
        is_unavailable: false,
    };

    let result = yt.resolve(&track, QualityPreset::High).await.unwrap();
    // YouTube fallback yields ~128 kbps AAC
    assert_eq!(result.bitrate_kbps, 128);
    assert_eq!(result.codec, "aac");
    assert_eq!(result.container, "m4a");
    // Hard requirement: YouTube fallback must mark is_requested_quality as FALSE
    assert!(!result.is_requested_quality);
    assert!(result.provider.contains("youtube_innertube"));
    assert!(!result.headers.is_empty());
}
