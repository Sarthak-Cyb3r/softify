use std::time::Duration;
use reqwest::Client;
use serde_json::{json, Value};

pub struct YouTubeResolver {
    client: Client,
}

impl YouTubeResolver {
    pub fn new() -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(8))
            .user_agent("Mozilla/5.0 (AppleVision; VisionOS/1.2) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/21O555")
            .build()
            .unwrap_or_else(|_| Client::new());
        Self { client }
    }

    pub async fn resolve_stream_url(&self, video_id: &str) -> Result<String, String> {
        let clean_id = video_id.trim_start_matches("yt_");
        let payload = json!({
            "context": {
                "client": {
                    "clientName": "VISIONOS",
                    "clientVersion": "1.2.0.21O555",
                    "osName": "VisionOS",
                    "osVersion": "1.2",
                    "platform": "MOBILE",
                    "hl": "en",
                    "gl": "US"
                }
            },
            "videoId": clean_id,
            "playbackContext": {
                "contentPlaybackContext": {
                    "html5Preference": "HTML5_PREF_WANTS"
                }
            }
        });

        let resp = self.client.post("https://www.youtube.com/youtubei/v1/player")
            .header("X-YouTube-Client-Name", "101")
            .header("X-YouTube-Client-Version", "1.2.0.21O555")
            .json(&payload)
            .send()
            .await
            .map_err(|e| e.to_string())?;

        let json: Value = resp.json().await.map_err(|e| e.to_string())?;

        // Extract streamingData formats
        if let Some(formats) = json["streamingData"]["adaptiveFormats"].as_array() {
            for format in formats {
                let mime = format["mimeType"].as_str().unwrap_or("");
                if mime.starts_with("audio/") {
                    if let Some(url) = format["url"].as_str() {
                        return Ok(url.to_string());
                    }
                }
            }
        }

        // Piped fallback
        let piped_url = format!("https://pipedapi.kavin.rocks/streams/{}", clean_id);
        if let Ok(piped_resp) = self.client.get(&piped_url).send().await {
            if let Ok(piped_json) = piped_resp.json::<Value>().await {
                if let Some(audio_streams) = piped_json["audioStreams"].as_array() {
                    if let Some(best) = audio_streams.first() {
                        if let Some(url) = best["url"].as_str() {
                            return Ok(url.to_string());
                        }
                    }
                }
            }
        }

        Err(format!("Could not extract playable stream URL for YouTube video {}", clean_id))
    }
}
