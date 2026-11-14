use std::time::Duration;
use reqwest::Client;
use serde_json::Value;
use crate::models::Track;
use crate::core::cipher::{decrypt_saavn_media_url, normalize_text};

pub struct SaavnResolver {
    client: Client,
}

impl SaavnResolver {
    pub fn new() -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(8))
            .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
            .build()
            .unwrap_or_else(|_| Client::new());
        Self { client }
    }

    pub async fn search_tracks(&self, query: &str) -> Result<Vec<Track>, String> {
        let url = format!(
            "https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=20&p=1&q={}",
            urlencoding::encode(query)
        );

        let resp = self.client.get(&url).send().await.map_err(|e| e.to_string())?;
        let json: Value = resp.json().await.map_err(|e| e.to_string())?;

        let results = json["results"].as_array().ok_or_else(|| "No results array".to_string())?;
        let mut tracks = Vec::new();

        for item in results {
            let id = item["id"].as_str().unwrap_or("").to_string();
            let title = item["title"].as_str().or_else(|| item["song"].as_str()).unwrap_or("").to_string();
            let subtitle = item["subtitle"].as_str().unwrap_or("").to_string();
            let primary_artists = item["more_info"]["artistMap"]["primary_artists"].as_array()
                .map(|arr| {
                    arr.iter().filter_map(|a| a["name"].as_str()).collect::<Vec<_>>().join(", ")
                })
                .unwrap_or_else(|| subtitle.clone());
            let album = item["more_info"]["album"].as_str().map(|s| s.to_string());
            let duration_sec = item["more_info"]["duration"].as_str()
                .and_then(|s| s.parse::<i64>().ok())
                .unwrap_or(0);
            let cover_url = item["image"].as_str().map(|s| s.replace("150x150", "500x500"));

            if !id.is_empty() && !title.is_empty() {
                tracks.push(Track {
                    id: format!("saavn_{}", id),
                    source_id: id,
                    title,
                    artist: primary_artists,
                    album,
                    duration_ms: duration_sec * 1000,
                    cover_url,
                    match_confidence: Some(1.0),
                    is_liked: false,
                    is_unavailable: false,
                });
            }
        }

        Ok(tracks)
    }

    pub async fn resolve_stream_url(&self, song_id: &str) -> Result<String, String> {
        let clean_id = song_id.trim_start_matches("saavn_");
        let url = format!(
            "https://www.jiosaavn.com/api.php?__call=song.getDetails&cc=in&_marker=0%3F_marker%3D0&_format=json&pids={}",
            clean_id
        );

        let resp = self.client.get(&url).send().await.map_err(|e| e.to_string())?;
        let json: Value = resp.json().await.map_err(|e| e.to_string())?;

        let song_obj = &json[clean_id];
        let encrypted_url = song_obj["more_info"]["encrypted_media_url"]
            .as_str()
            .ok_or_else(|| "Missing encrypted_media_url".to_string())?;

        decrypt_saavn_media_url(encrypted_url, 320)
    }

    pub async fn resolve_track(&self, track: &Track) -> Result<String, String> {
        if track.source_id.starts_with("saavn_") || !track.source_id.is_empty() {
            if let Ok(url) = self.resolve_stream_url(&track.source_id).await {
                return Ok(url);
            }
        }

        // Search by query
        let query = format!("{} {}", track.title, track.artist);
        let candidates = self.search_tracks(&query).await?;
        let norm_target_title = normalize_text(&track.title);

        for cand in candidates {
            let norm_cand_title = normalize_text(&cand.title);
            if norm_cand_title.contains(&norm_target_title) || norm_target_title.contains(&norm_cand_title) {
                if let Ok(url) = self.resolve_stream_url(&cand.source_id).await {
                    return Ok(url);
                }
            }
        }

        Err(format!("Could not resolve stream for track {}", track.title))
    }
}
