/*
 * Metrolist Project (C) 2026 | Licensed under GPL-3.0
 * Adapted for Softify-experimental
 */

use super::parser::parse_ttml;
use crate::models::SyncedLyrics;
use std::time::Duration;

#[derive(Clone)]
pub struct BetterLyricsClient {
    client: reqwest::Client,
    base_url: String,
}

impl Default for BetterLyricsClient {
    fn default() -> Self {
        Self::new()
    }
}

impl BetterLyricsClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(5))
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());
        Self {
            client,
            base_url: "https://lyrics-api.boidu.dev".to_string(),
        }
    }

    pub fn with_client_and_base_url(client: reqwest::Client, base_url: String) -> Self {
        Self { client, base_url }
    }

    pub async fn fetch_lyrics(
        &self,
        title: &str,
        artist: &str,
        duration_ms: Option<u64>,
    ) -> Option<SyncedLyrics> {
        let duration_sec = duration_ms.map(|d| d / 1000).unwrap_or(0);
        let url = format!("{}/getLyrics", self.base_url);

        let mut req = self.client.get(&url).query(&[("s", title), ("a", artist)]);

        let dur_str = duration_sec.to_string();
        if duration_sec > 0 {
            req = req.query(&[("d", &dur_str)]);
        }

        let resp = req.send().await.ok()?;
        if !resp.status().is_success() {
            return None;
        }

        let body = resp.text().await.ok()?;
        let json: serde_json::Value = serde_json::from_str(&body).ok()?;
        let ttml_str = json.get("ttml")?.as_str()?;

        let mut lyrics = parse_ttml(ttml_str);
        if lyrics.is_synced && !lyrics.lines.is_empty() {
            lyrics.provider = "BetterLyrics".to_string();
            Some(lyrics)
        } else {
            None
        }
    }
}
