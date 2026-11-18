use std::time::Duration;
use reqwest::Client;
use serde::Deserialize;
use crate::models::SoftifyError;

const USER_AGENT: &str = "Softify/4.0 (https://github.com/Sarthak-Cyb3r/softify)";

#[derive(Debug, Deserialize)]
pub struct LrclibResponse {
    #[serde(rename = "syncedLyrics")]
    pub synced_lyrics: Option<String>,
    #[serde(rename = "plainLyrics")]
    pub plain_lyrics: Option<String>,
    pub instrumental: Option<bool>,
    pub duration: Option<f64>,
    #[serde(rename = "hasWordSync")]
    pub has_word_sync: Option<bool>,
    pub lyricsfile: Option<String>,
}

pub struct LrclibClient {
    client: Client,
    base_url: String,
}

impl LrclibClient {
    pub fn new() -> Self {
        Self {
            client: Client::builder()
                .timeout(Duration::from_secs(4))
                .build()
                .unwrap_or_else(|_| Client::new()),
            base_url: "https://lrclib.net/api".to_string(),
        }
    }
}

impl Default for LrclibClient {
    fn default() -> Self {
        Self::new()
    }
}

impl LrclibClient {

    #[cfg(test)]
    pub fn with_client_and_base_url(client: Client, base_url: String) -> Self {
        Self { client, base_url }
    }

    pub async fn fetch_lyrics(
        &self,
        title: &str,
        artist: &str,
        duration_ms: u64,
    ) -> Result<Option<LrclibResponse>, SoftifyError> {
        let dur_sec = (duration_ms / 1000).to_string();

        // 1. Try with duration first
        if duration_ms > 0 {
            if let Some(res) = self.execute_get(title, artist, Some(&dur_sec)).await? {
                return Ok(Some(res));
            }
        }

        // 2. Fallback without duration
        self.execute_get(title, artist, None).await
    }

    async fn execute_get(
        &self,
        title: &str,
        artist: &str,
        duration_sec: Option<&str>,
    ) -> Result<Option<LrclibResponse>, SoftifyError> {
        let mut url = format!("{}/get?track_name={}&artist_name={}", self.base_url, urlencoding(title), urlencoding(artist));
        if let Some(dur) = duration_sec {
            url.push_str(&format!("&duration={}", dur));
        }

        let mut req = self.client.get(&url).header("User-Agent", USER_AGENT);
        let mut resp = match req.send().await {
            Ok(r) => r,
            Err(e) => return Err(SoftifyError::Network { reason: e.to_string() }),
        };

        if resp.status().as_u16() == 503 {
            // Transient rate limit backoff
            tokio::time::sleep(Duration::from_millis(500)).await;
            req = self.client.get(&url).header("User-Agent", USER_AGENT);
            if let Ok(r) = req.send().await {
                resp = r;
            }
        }

        if resp.status().is_success() {
            let data: LrclibResponse = resp.json().await.map_err(|e| SoftifyError::Network { reason: e.to_string() })?;
            Ok(Some(data))
        } else {
            Ok(None)
        }
    }
}

fn urlencoding(s: &str) -> String {
    url::form_urlencoded::byte_serialize(s.as_bytes()).collect()
}
