use crate::models::{HeaderPair, QualityPreset, RadioResult, SoftifyError, StreamInfo, Track};
use serde_json::{json, Value};

const VISIONOS_UA: &str =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15";
const ANDROID_UA: &str = "com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip";
const WEB_REMIX_UA: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

#[derive(Clone)]
pub struct YoutubeStreamResolver {
    client: reqwest::Client,
    player_url: String,
    music_search_url: String,
}

impl YoutubeStreamResolver {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(10))
            .build()
            .unwrap_or_default();
        Self {
            client,
            player_url: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false".to_string(),
            music_search_url: "https://music.youtube.com/youtubei/v1/search?prettyPrint=false"
                .to_string(),
        }
    }

    #[cfg(test)]
    pub fn with_client_and_urls(
        client: reqwest::Client,
        player_url: String,
        music_search_url: String,
    ) -> Self {
        Self {
            client,
            player_url,
            music_search_url,
        }
    }

    pub fn client(&self) -> &reqwest::Client {
        &self.client
    }

    /// Searches YouTube Music for songs matching query
    pub async fn search(&self, query: &str) -> Result<Vec<Track>, SoftifyError> {
        let payload = json!({
            "context": {
                "client": {
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240422.01.00",
                    "hl": "en",
                    "gl": "US"
                }
            },
            "query": query,
            "params": "EgWKAQIIAWoQEAMQBBAJEAoQBRAREBAQFQ%3D%3D"
        });

        let res = self
            .client
            .post(&self.music_search_url)
            .header("User-Agent", WEB_REMIX_UA)
            .header("Referer", "https://music.youtube.com/")
            .header("Content-Type", "application/json")
            .json(&payload)
            .send()
            .await
            .map_err(|e| SoftifyError::Network {
                reason: format!("YouTube Music search request failed: {e}"),
            })?;

        if !res.status().is_success() {
            return Ok(Vec::new());
        }

        let body: Value = res.json().await.map_err(|e| SoftifyError::Network {
            reason: format!("YouTube Music JSON decode failed: {e}"),
        })?;

        let mut tracks = Vec::new();
        let mut seen = std::collections::HashSet::new();

        self.extract_music_items(&body, &mut tracks, &mut seen);
        Ok(tracks)
    }

    /// Fetches YouTube Music radio queue for a given video ID or continuation token
    pub async fn get_radio(
        &self,
        video_id: &str,
        continuation: Option<&str>,
    ) -> Result<RadioResult, SoftifyError> {
        let (payload, url) = if let Some(token) = continuation {
            (
                json!({
                    "context": {
                        "client": {
                            "clientName": "WEB_REMIX",
                            "clientVersion": "1.20240422.01.00",
                            "hl": "en",
                            "gl": "US"
                        }
                    },
                    "continuation": token
                }),
                "https://music.youtube.com/youtubei/v1/next",
            )
        } else {
            let clean_vid = video_id.trim_start_matches("ytm_");
            (
                json!({
                    "context": {
                        "client": {
                            "clientName": "WEB_REMIX",
                            "clientVersion": "1.20240422.01.00",
                            "hl": "en",
                            "gl": "US"
                        }
                    },
                    "videoId": clean_vid,
                    "playlistId": format!("RDAMVM{}", clean_vid),
                    "isAudioOnly": true
                }),
                "https://music.youtube.com/youtubei/v1/next",
            )
        };

        let res = self
            .client
            .post(url)
            .header("User-Agent", WEB_REMIX_UA)
            .header("Referer", "https://music.youtube.com/")
            .header("Content-Type", "application/json")
            .json(&payload)
            .send()
            .await
            .map_err(|e| SoftifyError::Network {
                reason: format!("YouTube radio request failed: {e}"),
            })?;

        if !res.status().is_success() {
            return Err(SoftifyError::Network {
                reason: format!("YouTube radio endpoint returned HTTP {}", res.status()),
            });
        }

        let body: Value = res.json().await.map_err(|e| SoftifyError::Network {
            reason: format!("YouTube radio JSON decode failed: {e}"),
        })?;

        Self::parse_radio_response(&body, continuation.is_some())
    }

    pub fn parse_radio_response(
        body: &Value,
        is_continuation: bool,
    ) -> Result<RadioResult, SoftifyError> {
        let (contents_ptr, continuations_ptr) = if is_continuation {
            (
                "/continuationContents/playlistPanelContinuation/contents",
                "/continuationContents/playlistPanelContinuation/continuations",
            )
        } else {
            (
                "/contents/singleColumnMusicWatchNextResultsRenderer/tabbedRenderer/watchNextTabbedResultsRenderer/tabs/0/tabRenderer/content/musicQueueRenderer/content/playlistPanelRenderer/contents",
                "/contents/singleColumnMusicWatchNextResultsRenderer/tabbedRenderer/watchNextTabbedResultsRenderer/tabs/0/tabRenderer/content/musicQueueRenderer/content/playlistPanelRenderer/continuations",
            )
        };

        let mut tracks = Vec::new();
        let mut seen = std::collections::HashSet::new();

        if let Some(items) = body.pointer(contents_ptr).and_then(|v| v.as_array()) {
            for item in items {
                if let Some(renderer) = item.get("playlistPanelVideoRenderer") {
                    if let Some(track) = Self::parse_playlist_panel_video_renderer(renderer) {
                        if seen.insert(track.id.clone()) {
                            tracks.push(track);
                        }
                    }
                }
            }
        }

        let mut next_token = None;
        if let Some(conts) = body.pointer(continuations_ptr).and_then(|v| v.as_array()) {
            for cont in conts {
                if let Some(token) = cont
                    .pointer("/nextRadioContinuationData/continuation")
                    .or_else(|| cont.pointer("/nextContinuationData/continuation"))
                    .and_then(|v| v.as_str())
                {
                    next_token = Some(token.to_string());
                    break;
                }
            }
        }

        Ok(RadioResult {
            tracks,
            continuation: next_token,
        })
    }

    fn parse_playlist_panel_video_renderer(renderer: &Value) -> Option<Track> {
        let vid = renderer.get("videoId").and_then(|v| v.as_str())?;
        let title = renderer
            .pointer("/title/runs/0/text")
            .and_then(|v| v.as_str())?;
        let artist = renderer
            .pointer("/longBylineText/runs/0/text")
            .or_else(|| renderer.pointer("/shortBylineText/runs/0/text"))
            .and_then(|v| v.as_str())
            .unwrap_or("Unknown Artist");

        let album = renderer
            .pointer("/longBylineText/runs/2/text")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        let duration_ms = renderer
            .pointer("/lengthText/runs/0/text")
            .and_then(|v| v.as_str())
            .map(parse_colon_duration)
            .unwrap_or(0);

        let cover_url = renderer
            .pointer("/thumbnail/thumbnails")
            .and_then(|v| v.as_array())
            .and_then(|arr| arr.last())
            .and_then(|t| t.get("url"))
            .and_then(|u| u.as_str())
            .map(|s| s.to_string());

        let id = format!("ytm_{}", vid);
        Some(Track {
            id: id.clone(),
            source_id: id,
            title: title.to_string(),
            artist: artist.to_string(),
            album,
            duration_ms,
            cover_url,
            match_confidence: Some(1.0),
            is_liked: false,
            is_unavailable: false,
        })
    }

    fn extract_music_items(
        &self,
        node: &Value,
        tracks: &mut Vec<Track>,
        seen: &mut std::collections::HashSet<String>,
    ) {
        if tracks.len() >= 25 {
            return;
        }

        if let Value::Object(map) = node {
            if let Some(item) = map.get("musicResponsiveListItemRenderer") {
                if let Some(vid) = self.extract_video_id(item) {
                    if seen.insert(vid.clone()) {
                        let (title, artist, album, duration_ms, cover_url) =
                            self.parse_item_fields(item, &vid);
                        tracks.push(Track {
                            id: format!("ytm_{vid}"),
                            source_id: format!("ytm_{vid}"),
                            title,
                            artist,
                            album,
                            duration_ms,
                            cover_url: Some(cover_url),
                            match_confidence: Some(1.0),
                            is_liked: false,
                            is_unavailable: false,
                        });
                    }
                }
            } else {
                for (_, val) in map {
                    self.extract_music_items(val, tracks, seen);
                }
            }
        } else if let Value::Array(arr) = node {
            for val in arr {
                self.extract_music_items(val, tracks, seen);
            }
        }
    }

    fn extract_video_id(&self, item: &Value) -> Option<String> {
        if let Some(vid) = item
            .get("playlistItemData")
            .and_then(|p| p.get("videoId"))
            .and_then(|v| v.as_str())
        {
            return Some(vid.to_string());
        }
        if let Some(overlay) = item
            .get("overlay")
            .and_then(|o| o.get("musicItemThumbnailOverlayRenderer"))
        {
            if let Some(watch) = overlay
                .get("content")
                .and_then(|c| c.get("musicPlayButtonRenderer"))
                .and_then(|p| p.get("playNavigationEndpoint"))
                .and_then(|e| e.get("watchEndpoint"))
                .and_then(|w| w.get("videoId"))
                .and_then(|v| v.as_str())
            {
                return Some(watch.to_string());
            }
        }
        if let Some(cols) = item.get("flexColumns").and_then(|c| c.as_array()) {
            for col in cols {
                if let Some(runs) = col
                    .get("musicResponsiveListItemFlexColumnRenderer")
                    .and_then(|f| f.get("text"))
                    .and_then(|t| t.get("runs"))
                    .and_then(|r| r.as_array())
                {
                    for r in runs {
                        if let Some(vid) = r
                            .get("navigationEndpoint")
                            .and_then(|e| e.get("watchEndpoint"))
                            .and_then(|w| w.get("videoId"))
                            .and_then(|v| v.as_str())
                        {
                            return Some(vid.to_string());
                        }
                    }
                }
            }
        }
        None
    }

    fn parse_item_fields(
        &self,
        item: &Value,
        video_id: &str,
    ) -> (String, String, Option<String>, u64, String) {
        let mut title = String::new();
        let mut artist = String::new();
        let mut album = None;
        let mut duration_ms = 0;

        if let Some(cols) = item.get("flexColumns").and_then(|c| c.as_array()) {
            if let Some(first_col) = cols.first() {
                if let Some(runs) = first_col
                    .get("musicResponsiveListItemFlexColumnRenderer")
                    .and_then(|f| f.get("text"))
                    .and_then(|t| t.get("runs"))
                    .and_then(|r| r.as_array())
                {
                    title = runs
                        .iter()
                        .filter_map(|r| r.get("text").and_then(|v| v.as_str()))
                        .collect::<Vec<_>>()
                        .join("");
                }
            }
            if cols.len() > 1 {
                if let Some(runs) = cols[1]
                    .get("musicResponsiveListItemFlexColumnRenderer")
                    .and_then(|f| f.get("text"))
                    .and_then(|t| t.get("runs"))
                    .and_then(|r| r.as_array())
                {
                    let texts: Vec<&str> = runs
                        .iter()
                        .filter_map(|r| r.get("text").and_then(|v| v.as_str()))
                        .collect();
                    if !texts.is_empty() {
                        artist = texts[0].to_string();
                    }
                    if texts.len() > 2 {
                        album = Some(texts[2].to_string());
                    }
                    if let Some(last) = texts.last() {
                        if last.contains(':') {
                            duration_ms = parse_colon_duration(last);
                        }
                    }
                }
            }
        }

        let cover_url = Self::extract_highest_res_thumbnail(item, video_id);
        (title, artist, album, duration_ms, cover_url)
    }

    pub fn extract_highest_res_thumbnail(item: &Value, video_id: &str) -> String {
        let thumbs = item
            .pointer("/thumbnail/musicThumbnailRenderer/thumbnail/thumbnails")
            .or_else(|| item.pointer("/musicThumbnailRenderer/thumbnail/thumbnails"))
            .and_then(|v| v.as_array());

        if let Some(arr) = thumbs {
            let best = arr
                .iter()
                .filter_map(|t| {
                    let u = t.get("url")?.as_str()?;
                    let w = t.get("width").and_then(|v| v.as_u64()).unwrap_or(0);
                    Some((w, u))
                })
                .max_by_key(|(w, _)| *w);

            if let Some((_, u)) = best {
                if u.contains("=w") {
                    if let Ok(re) = regex::Regex::new(r"=w\d+-h\d+[^?&]*") {
                        return re.replace(u, "=w544-h544-l90-rj").to_string();
                    }
                }
                return u.to_string();
            }
        }
        format!("https://i.ytimg.com/vi/{video_id}/hqdefault.jpg")
    }

    /// Resolves YouTube stream using VisionOS client context (unthrottled, no signature ciphers / n transform)
    pub async fn resolve(
        &self,
        track: &Track,
        _preset: QualityPreset,
    ) -> Result<StreamInfo, SoftifyError> {
        let raw_id = track
            .source_id
            .trim_start_matches("ytm_")
            .trim_start_matches("yt_")
            .trim();

        let video_id = if raw_id.len() == 11
            && raw_id
                .chars()
                .all(|c| c.is_alphanumeric() || c == '_' || c == '-')
        {
            raw_id.to_string()
        } else {
            // Find track via YouTube Music search
            let query = format!("{} {}", track.title, track.artist);
            let search_results = self.search(&query).await?;
            let best = search_results
                .into_iter()
                .next()
                .ok_or_else(|| SoftifyError::NotFound {
                    reason: format!("No YouTube match found for '{}'", track.title),
                })?;
            best.source_id.trim_start_matches("ytm_").to_string()
        };

        // 1. Try VisionOS client context
        if let Ok(info) = self.query_innertube_player(&video_id, "VISIONOS").await {
            return Ok(info);
        }

        // 2. Fallback to Android client context
        if let Ok(info) = self.query_innertube_player(&video_id, "ANDROID").await {
            return Ok(info);
        }

        Err(SoftifyError::NotFound {
            reason: format!("Failed to resolve playable YouTube stream for video {video_id}"),
        })
    }

    async fn fetch_visitor_data(&self) -> Option<String> {
        let res = self
            .client
            .get("https://www.youtube.com/")
            .header("User-Agent", WEB_REMIX_UA)
            .send()
            .await
            .ok()?;
        let html = res.text().await.ok()?;
        let re = regex::Regex::new(r#""VISITOR_DATA":"([^"]+)""#).ok()?;
        re.captures(&html)
            .and_then(|c| c.get(1))
            .map(|m| m.as_str().to_string())
    }

    async fn query_innertube_player(
        &self,
        video_id: &str,
        client_name: &str,
    ) -> Result<StreamInfo, SoftifyError> {
        let visitor_data = if client_name == "VISIONOS" {
            self.fetch_visitor_data().await
        } else {
            None
        };

        let (client_context, user_agent, extra_headers) = if client_name == "VISIONOS" {
            let mut ctx = json!({
                "clientName": "VISIONOS",
                "clientVersion": "1.02",
                "deviceMake": "Apple",
                "deviceModel": "RealityDevice17,1",
                "osName": "visionOS",
                "osVersion": "26.5.23O471",
                "hl": "en",
                "gl": "US"
            });
            let mut headers = vec![
                ("X-YouTube-Client-Name", "101".to_string()),
                ("X-YouTube-Client-Version", "1.02".to_string()),
                ("Origin", "https://www.youtube.com".to_string()),
            ];
            if let Some(ref vis) = visitor_data {
                if let Some(obj) = ctx.as_object_mut() {
                    obj.insert("visitorData".to_string(), json!(vis));
                }
                headers.push(("X-Goog-Visitor-Id", vis.clone()));
            }
            (ctx, VISIONOS_UA, headers)
        } else {
            (
                json!({
                    "clientName": "ANDROID",
                    "clientVersion": "20.10.38",
                    "osName": "Android",
                    "osVersion": "11",
                    "hl": "en",
                    "timeZone": "UTC",
                    "utcOffsetMinutes": 0
                }),
                ANDROID_UA,
                vec![],
            )
        };

        let payload = json!({
            "context": {
                "client": client_context
            },
            "videoId": video_id
        });

        let mut req = self
            .client
            .post(&self.player_url)
            .header("Content-Type", "application/json")
            .header("User-Agent", user_agent);

        for (k, v) in extra_headers {
            req = req.header(k, v);
        }

        let res = req
            .json(&payload)
            .send()
            .await
            .map_err(|e| SoftifyError::Network {
                reason: format!("Innertube player call failed: {e}"),
            })?;

        if !res.status().is_success() {
            return Err(SoftifyError::Network {
                reason: format!("Innertube returned HTTP {}", res.status()),
            });
        }

        let data: Value = res.json().await.map_err(|e| SoftifyError::Network {
            reason: format!("Failed to parse player JSON: {e}"),
        })?;

        let status = data
            .get("playabilityStatus")
            .and_then(|p| p.get("status"))
            .and_then(|s| s.as_str())
            .unwrap_or("");

        if status != "OK" {
            return Err(SoftifyError::NotFound {
                reason: format!("Player status not playable: {status}"),
            });
        }

        let streaming_data = data
            .get("streamingData")
            .ok_or_else(|| SoftifyError::NotFound {
                reason: "No streamingData in player response".to_string(),
            })?;

        let adaptive_formats = streaming_data
            .get("adaptiveFormats")
            .and_then(|f| f.as_array())
            .cloned()
            .unwrap_or_default();

        // Audio streams with direct unthrottled URL
        let mut audio_formats: Vec<&Value> = adaptive_formats
            .iter()
            .filter(|f| {
                let mime = f.get("mimeType").and_then(|m| m.as_str()).unwrap_or("");
                let url = f.get("url").and_then(|u| u.as_str()).unwrap_or("");
                mime.starts_with("audio/") && !url.is_empty()
            })
            .collect();

        if audio_formats.is_empty() {
            // Check formats (muxed)
            if let Some(formats) = streaming_data.get("formats").and_then(|f| f.as_array()) {
                audio_formats = formats
                    .iter()
                    .filter(|f| {
                        f.get("url")
                            .and_then(|u| u.as_str())
                            .map(|s| !s.is_empty())
                            .unwrap_or(false)
                    })
                    .collect();
            }
        }

        if audio_formats.is_empty() {
            return Err(SoftifyError::NotFound {
                reason: "No direct playable audio streams found".to_string(),
            });
        }

        // Prioritize m4a/aac (itag 140)
        audio_formats.sort_by_key(|f| {
            let mime = f.get("mimeType").and_then(|m| m.as_str()).unwrap_or("");
            let itag = f.get("itag").and_then(|i| i.as_u64()).unwrap_or(0);
            if itag == 140 {
                0
            } else if mime.contains("mp4") {
                1
            } else if itag == 251 {
                2
            } else {
                3
            }
        });

        let chosen = audio_formats[0];
        let stream_url = chosen
            .get("url")
            .and_then(|u| u.as_str())
            .unwrap_or("")
            .to_string();
        let mime = chosen
            .get("mimeType")
            .and_then(|m| m.as_str())
            .unwrap_or("");
        let raw_bitrate = chosen
            .get("bitrate")
            .and_then(|b| b.as_u64())
            .unwrap_or(128_000);
        let avg_bitrate = chosen.get("averageBitrate").and_then(|b| b.as_u64());
        let content_length = chosen
            .get("contentLength")
            .and_then(|c| c.as_str())
            .and_then(|s| s.parse::<u64>().ok());
        let approx_duration_ms = chosen
            .get("approxDurationMs")
            .and_then(|d| d.as_str())
            .and_then(|s| s.parse::<u64>().ok());
        let calc_kbps = match (content_length, approx_duration_ms) {
            (Some(cl), Some(dur_ms)) if dur_ms > 0 => {
                Some(((cl as f64 * 8.0) / (dur_ms as f64)).round() as u32)
            }
            _ => None,
        };

        // Prefer averageBitrate as it reflects continuous playback rate matching Content-Length/duration
        let bitrate_kbps = if let Some(avg) = avg_bitrate {
            (avg / 1000) as u32
        } else if let Some(calc) = calc_kbps {
            calc
        } else {
            (raw_bitrate / 1000) as u32
        };

        eprintln!(
            "[YOUTUBE BITRATE] video_id={}: raw_bitrate={} bps, averageBitrate={:?} bps, measured Content-Length/duration={:?} kbps -> selected {} kbps",
            video_id, raw_bitrate, avg_bitrate, calc_kbps, bitrate_kbps
        );
        let itag = chosen.get("itag").and_then(|i| i.as_u64()).unwrap_or(0);

        let (container, codec) = if mime.contains("mp4") {
            ("m4a".to_string(), "aac".to_string())
        } else {
            ("webm".to_string(), "opus".to_string())
        };

        let expires_at = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() + 4 * 3600)
            .ok();

        let loudness_db = data
            .get("playerConfig")
            .and_then(|pc| pc.get("audioConfig"))
            .and_then(|ac| ac.get("loudnessDb").or_else(|| ac.get("perceptualLoudnessDb")))
            .and_then(|v| v.as_f64())
            .or_else(|| chosen.get("loudnessDb").and_then(|v| v.as_f64()));

        let mut headers = if client_name == "ANDROID" {
            vec![HeaderPair {
                name: "User-Agent".to_string(),
                value: user_agent.to_string(),
            }]
        } else {
            vec![
                HeaderPair {
                    name: "User-Agent".to_string(),
                    value: user_agent.to_string(),
                },
                HeaderPair {
                    name: "Referer".to_string(),
                    value: "https://www.youtube.com/".to_string(),
                },
                HeaderPair {
                    name: "Origin".to_string(),
                    value: "https://www.youtube.com".to_string(),
                },
            ]
        };

        if let Some(ldb) = loudness_db {
            headers.push(HeaderPair {
                name: "X-Loudness-Db".to_string(),
                value: format!("{:.2}", ldb),
            });
            headers.push(HeaderPair {
                name: "X-Loudness-Source".to_string(),
                value: "YOUTUBE".to_string(),
            });
        }

        Ok(StreamInfo {
            url: stream_url,
            container,
            bitrate_kbps,
            codec,
            provider: format!(
                "youtube_innertube_{} (itag {itag})",
                client_name.to_lowercase()
            ),
            is_requested_quality: false, // YouTube never yields true 320 kbps studio master
            headers,
            expires_at,
        })
    }
}

impl Default for YoutubeStreamResolver {
    fn default() -> Self {
        Self::new()
    }
}

fn parse_colon_duration(s: &str) -> u64 {
    let parts: Vec<&str> = s.split(':').collect();
    if parts.len() == 2 {
        let mins = parts[0].parse::<u64>().unwrap_or(0);
        let secs = parts[1].parse::<u64>().unwrap_or(0);
        (mins * 60 + secs) * 1000
    } else if parts.len() == 3 {
        let hrs = parts[0].parse::<u64>().unwrap_or(0);
        let mins = parts[1].parse::<u64>().unwrap_or(0);
        let secs = parts[2].parse::<u64>().unwrap_or(0);
        (hrs * 3600 + mins * 60 + secs) * 1000
    } else {
        0
    }
}
