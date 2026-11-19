/*
 * Metrolist Project (C) 2026 | Licensed under GPL-3.0
 * Adapted for Softify-experimental
 */

use crate::models::SyncedLyrics;
use super::parser::{parse_lrc, parse_ttml};
use std::time::Duration;

#[derive(Clone)]
pub struct UnisonClient {
    client: reqwest::Client,
    base_url: String,
}

impl Default for UnisonClient {
    fn default() -> Self {
        Self::new()
    }
}

impl UnisonClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(5))
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());
        Self {
            client,
            base_url: "https://unison.boidu.dev/lyrics".to_string(),
        }
    }

    pub fn with_client_and_base_url(client: reqwest::Client, base_url: String) -> Self {
        Self { client, base_url }
    }

    pub async fn fetch_lyrics(
        &self,
        title: &str,
        artist: &str,
        _duration_ms: Option<u64>,
    ) -> Option<SyncedLyrics> {
        let resp = self.client.get(&self.base_url)
            .query(&[("song", title), ("artist", artist)])
            .header("Accept", "application/json")
            .send()
            .await
            .ok()?;

        if !resp.status().is_success() {
            return None;
        }

        let body = resp.text().await.ok()?;
        let json: serde_json::Value = serde_json::from_str(&body).ok()?;
        if json.get("success").and_then(|v| v.as_bool()) != Some(true) {
            return None;
        }

        let data = json.get("data")?;
        let lyrics_str = data.get("lyrics")?.as_str()?;
        let format_str = data.get("format").and_then(|v| v.as_str()).unwrap_or("ttml").to_lowercase();

        let mut lyrics = match format_str.as_str() {
            "lrc" => parse_lrc(lyrics_str),
            _ => parse_ttml(lyrics_str),
        };

        if lyrics.is_synced && !lyrics.lines.is_empty() {
            lyrics.provider = "Unison".to_string();
            Some(lyrics)
        } else {
            None
        }
    }
}
