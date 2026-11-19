/*
 * Metrolist Project (C) 2026 | Licensed under GPL-3.0
 * Adapted for Softify-experimental
 */

use crate::models::SyncedLyrics;
use super::parser::parse_lrc;
use base64::Engine;
use std::time::Duration;

#[derive(Clone)]
pub struct KuGouClient {
    client: reqwest::Client,
    base_url: String,
}

impl Default for KuGouClient {
    fn default() -> Self {
        Self::new()
    }
}

impl KuGouClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(5))
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());
        Self {
            client,
            base_url: "https://lyrics.kugou.com".to_string(),
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

        let search_url = format!("{}/search", self.base_url);
        let resp = self.client.get(&search_url)
            .query(&[
                ("ver", "1"),
                ("man", "yes"),
                ("client", "pc"),
                ("keyword", &query),
            ])
            .send()
            .await
            .ok()?;

        if !resp.status().is_success() {
            return None;
        }

        let body: serde_json::Value = resp.json().await.ok()?;
        let candidates = body.get("candidates")?.as_array()?;
        let first = candidates.first()?;

        let id = first.get("id")?.as_u64()?;
        let access_key = first.get("accesskey")?.as_str()?;

        let download_url = format!("{}/download", self.base_url);
        let id_str = id.to_string();
        let dl_resp = self.client.get(&download_url)
            .query(&[
                ("fmt", "lrc"),
                ("charset", "utf8"),
                ("client", "pc"),
                ("ver", "1"),
                ("id", &id_str),
                ("accesskey", access_key),
            ])
            .send()
            .await
            .ok()?;

        if !dl_resp.status().is_success() {
            return None;
        }

        let dl_body: serde_json::Value = dl_resp.json().await.ok()?;
        let b64_content = dl_body.get("content")?.as_str()?;
        let lrc_bytes = base64::engine::general_purpose::STANDARD.decode(b64_content).ok()?;
        let lrc_text = String::from_utf8(lrc_bytes).ok()?;

        let mut lyrics = parse_lrc(&lrc_text);
        if lyrics.is_synced && !lyrics.lines.is_empty() {
            lyrics.provider = "KuGou".to_string();
            Some(lyrics)
        } else {
            None
        }
    }
}
