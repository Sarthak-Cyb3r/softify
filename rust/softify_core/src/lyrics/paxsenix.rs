/*
 * Metrolist Project (C) 2026 | Licensed under GPL-3.0
 * Adapted for Softify-experimental
 */

use super::parser::parse_ttml;
use crate::models::SyncedLyrics;
use std::time::Duration;

#[derive(Clone)]
pub struct PaxsenixClient {
    client: reqwest::Client,
    base_url: String,
}

impl Default for PaxsenixClient {
    fn default() -> Self {
        Self::new()
    }
}

impl PaxsenixClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(5))
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());
        Self {
            client,
            base_url: "https://lyrics.paxsenix.org/apple-music/lyrics".to_string(),
        }
    }

    pub fn with_client_and_base_url(client: reqwest::Client, base_url: String) -> Self {
        Self { client, base_url }
    }

    pub async fn fetch_lyrics_by_id(&self, apple_music_id: &str) -> Option<SyncedLyrics> {
        let resp = self
            .client
            .get(&self.base_url)
            .query(&[("id", apple_music_id)])
            .header("User-Agent", "Softify/1.0")
            .send()
            .await
            .ok()?;

        if !resp.status().is_success() {
            return None;
        }

        let body = resp.text().await.ok()?;
        let json: serde_json::Value = serde_json::from_str(&body).ok()?;
        let ttml_str = json.get("ttml")?.as_str()?;

        let mut lyrics = parse_ttml(ttml_str);
        if lyrics.is_synced && !lyrics.lines.is_empty() {
            lyrics.provider = "Paxsenix".to_string();
            Some(lyrics)
        } else {
            None
        }
    }
}
