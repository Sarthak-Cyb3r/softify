/*
 * Metrolist Project (C) 2026 | Licensed under GPL-3.0
 * Adapted for Softify-experimental
 */

use crate::models::SyncedLyrics;
use super::parser::parse_youtube_json3;
use std::time::Duration;

#[derive(Clone)]
pub struct YouTubeCaptionsClient {
    client: reqwest::Client,
}

impl Default for YouTubeCaptionsClient {
    fn default() -> Self {
        Self::new()
    }
}

impl YouTubeCaptionsClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(5))
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());
        Self { client }
    }

    pub fn with_client(client: reqwest::Client) -> Self {
        Self { client }
    }

    pub async fn fetch_caption_track(&self, caption_track_base_url: &str) -> Option<SyncedLyrics> {
        let url = if caption_track_base_url.contains("fmt=") {
            caption_track_base_url.to_string()
        } else if caption_track_base_url.contains('?') {
            format!("{}&fmt=json3", caption_track_base_url)
        } else {
            format!("{}?fmt=json3", caption_track_base_url)
        };

        let resp = self.client.get(&url).send().await.ok()?;
        if !resp.status().is_success() {
            return None;
        }

        let body = resp.text().await.ok()?;
        let lyrics = parse_youtube_json3(&body);
        if lyrics.is_synced && !lyrics.lines.is_empty() {
            Some(lyrics)
        } else {
            None
        }
    }

    pub async fn fetch_by_video_id(&self, video_id: &str) -> Option<SyncedLyrics> {
        let player_url = "https://www.youtube.com/youtubei/v1/player";
        let payload = serde_json::json!({
            "context": {
                "client": {
                    "clientName": "ANDROID_MUSIC",
                    "clientVersion": "6.40.52",
                    "hl": "en",
                    "gl": "US"
                }
            },
            "videoId": video_id
        });

        let resp = self.client.post(player_url)
            .json(&payload)
            .send()
            .await
            .ok()?;

        if !resp.status().is_success() {
            return None;
        }

        let body: serde_json::Value = resp.json().await.ok()?;
        let tracks = body.get("captions")?
            .get("playerCaptionsTracklistRenderer")?
            .get("captionTracks")?
            .as_array()?;

        let track = tracks.iter()
            .find(|t| t.get("vssId").and_then(|v| v.as_str()).map(|s| s.contains(".en")).unwrap_or(false))
            .or_else(|| tracks.first())?;

        let base_url = track.get("baseUrl")?.as_str()?;
        self.fetch_caption_track(base_url).await
    }
}
