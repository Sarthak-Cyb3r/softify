/*
 * Metrolist Project (C) 2026 | Licensed under GPL-3.0
 * Adapted for Softify-experimental
 */

use super::parser::parse_ttml;
use crate::models::SyncedLyrics;
use std::time::Duration;

#[derive(Clone)]
pub struct LrcredClient {
    client: reqwest::Client,
    base_url: String,
}

impl Default for LrcredClient {
    fn default() -> Self {
        Self::new()
    }
}

impl LrcredClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(5))
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());
        Self {
            client,
            base_url: "https://lrc.red/api/v1".to_string(),
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
        let query = format!("{} {}", title, artist).trim().to_string();
        if query.is_empty() {
            return None;
        }

        let resp = self
            .client
            .get(&self.base_url)
            .query(&[("q", &query)])
            .send()
            .await
            .ok()?;

        if !resp.status().is_success() {
            return None;
        }

        let body = resp.text().await.ok()?;
        let json: serde_json::Value = serde_json::from_str(&body).ok()?;
        let results = json.get("results")?.as_array()?;

        // Prioritize word-synced entries
        let match_entry = results
            .iter()
            .find(|r| r.get("timing_type").and_then(|v| v.as_str()) == Some("word"))
            .or_else(|| results.first())?;

        let lyrics_url = match_entry.get("lyricsUrl")?.as_str()?;
        let full_lyrics_url = if lyrics_url.starts_with('/') {
            format!("https://lrc.red{}", lyrics_url)
        } else {
            lyrics_url.to_string()
        };

        let ttml_resp = self.client.get(&full_lyrics_url).send().await.ok()?;

        if !ttml_resp.status().is_success() {
            return None;
        }

        let ttml_text = ttml_resp.text().await.ok()?;
        let mut lyrics = parse_ttml(&ttml_text);
        if lyrics.is_synced && !lyrics.lines.is_empty() {
            lyrics.provider = "lrc.red".to_string();
            Some(lyrics)
        } else {
            None
        }
    }
}
