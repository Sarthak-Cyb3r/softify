use std::sync::Arc;
use std::time::Duration;
use crate::config::ConfigManager;
use crate::db::repository::DatabaseRepository;
use crate::models::{Shelf, SoftifyError, Track};

pub static EXPLORE_FIXTURE_STR: &str = include_str!("../../resources/explore_charts_fixture.json");

pub fn parse_explore_shelves_json(json_str: &str) -> Result<Vec<Shelf>, SoftifyError> {
    serde_json::from_str::<Vec<Shelf>>(json_str).map_err(|e| SoftifyError::Network {
        reason: format!("Failed to parse explore charts payload: {}", e),
    })
}

pub struct HomeExploreEngine {
    repo: Arc<DatabaseRepository>,
    client: reqwest::Client,
}

impl HomeExploreEngine {
    pub fn new(repo: Arc<DatabaseRepository>) -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(5))
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());
        Self { repo, client }
    }

    pub async fn get_explore_shelves(&self, config_mgr: &ConfigManager) -> Result<Vec<Shelf>, SoftifyError> {
        let cfg = config_mgr.get_config();
        let endpoint = cfg.endpoints.get("youtube_browse")
            .map(|s| s.as_str())
            .unwrap_or("https://music.youtube.com/youtubei/v1/browse");

        // Try network fetch from remote endpoint
        let browse_payload = serde_json::json!({
            "context": {
                "client": {
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240801.01.00",
                    "hl": "en",
                    "gl": "IN"
                }
            },
            "browseId": "FEmusic_charts"
        });

        let network_res = self.client.post(endpoint)
            .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36")
            .header("Referer", "https://music.youtube.com/")
            .json(&browse_payload)
            .send()
            .await;

        if let Ok(resp) = network_res {
            if resp.status().is_success() {
                if let Ok(body_json) = resp.json::<serde_json::Value>().await {
                    let parsed_shelves = Self::extract_shelves_from_browse_response(&body_json);
                    if !parsed_shelves.is_empty() {
                        if let Ok(serialized) = serde_json::to_string(&parsed_shelves) {
                            let _ = self.repo.cache_home_explore(&serialized);
                        }
                        return Ok(parsed_shelves);
                    }
                }
            }
        }

        // Network unavailable or failed: check SQLite cache
        if let Ok(Some(cached_json)) = self.repo.get_cached_home_explore() {
            if let Ok(cached_shelves) = parse_explore_shelves_json(&cached_json) {
                if !cached_shelves.is_empty() {
                    return Ok(cached_shelves);
                }
            }
        }

        // Cache empty: fall back to recorded embedded fixture (ensures first install is never empty)
        parse_explore_shelves_json(EXPLORE_FIXTURE_STR)
    }

    fn extract_shelves_from_browse_response(root: &serde_json::Value) -> Vec<Shelf> {
        let mut shelves = Vec::new();
        // Parse tabs -> tabRenderer -> content -> sectionListRenderer -> contents
        let contents = root
            .pointer("/contents/singleColumnBrowseResultsRenderer/tabs/0/tabRenderer/content/sectionListRenderer/contents")
            .and_then(|v| v.as_array());

        if let Some(sections) = contents {
            for (idx, section) in sections.iter().enumerate() {
                let shelf_renderer = section.pointer("/musicCarouselShelfRenderer");
                if let Some(carousel) = shelf_renderer {
                    let title = carousel.pointer("/header/musicCarouselShelfBasicHeaderRenderer/title/runs/0/text")
                        .and_then(|v| v.as_str())
                        .unwrap_or("Charts");
                    let subtitle = carousel.pointer("/header/musicCarouselShelfBasicHeaderRenderer/strapline/runs/0/text")
                        .and_then(|v| v.as_str())
                        .unwrap_or("Popular tracks");

                    let mut tracks = Vec::new();
                    if let Some(items) = carousel.pointer("/contents").and_then(|v| v.as_array()) {
                        for item in items {
                            let two_row = item.pointer("/musicTwoRowItemRenderer")
                                .or_else(|| item.pointer("/musicResponsiveListItemRenderer"));
                            if let Some(row) = two_row {
                                let video_id = row.pointer("/navigationEndpoint/watchEndpoint/videoId")
                                    .and_then(|v| v.as_str());
                                let track_title = row.pointer("/title/runs/0/text")
                                    .and_then(|v| v.as_str());
                                let track_artist = row.pointer("/subtitle/runs/0/text")
                                    .and_then(|v| v.as_str())
                                    .unwrap_or("Various Artists");
                                let cover_url = row.pointer("/thumbnailRenderer/musicThumbnailRenderer/thumbnail/thumbnails/0/url")
                                    .and_then(|v| v.as_str());

                                if let (Some(vid), Some(t_title)) = (video_id, track_title) {
                                    tracks.push(Track {
                                        id: format!("yt_{}", vid),
                                        source_id: vid.to_string(),
                                        title: t_title.to_string(),
                                        artist: track_artist.to_string(),
                                        album: None,
                                        duration_ms: 210_000,
                                        cover_url: cover_url.map(|s| s.to_string()),
                                        match_confidence: Some(1.0),
                                        is_liked: false,
                                        is_unavailable: false,
                                    });
                                }
                            }
                        }
                    }

                    if !tracks.is_empty() {
                        shelves.push(Shelf {
                            id: format!("explore_shelf_{}", idx),
                            title: title.to_string(),
                            subtitle: subtitle.to_string(),
                            rule: "explore_browse".to_string(),
                            tracks,
                        });
                    }
                }
            }
        }

        shelves
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_recorded_explore_fixture() {
        let shelves = parse_explore_shelves_json(EXPLORE_FIXTURE_STR).expect("Fixture must parse cleanly");
        assert_eq!(shelves.len(), 3, "Fixture contains 3 shelves");
        assert_eq!(shelves[0].id, "explore_trending");
        assert_eq!(shelves[1].id, "explore_top_charts");
        assert_eq!(shelves[2].id, "explore_new_releases");

        for shelf in &shelves {
            assert!(!shelf.tracks.is_empty(), "Shelf {} must not be empty", shelf.title);
            for track in &shelf.tracks {
                assert!(!track.title.is_empty());
                assert!(!track.artist.is_empty());
                assert!(track.duration_ms > 0);
            }
        }
    }
}
