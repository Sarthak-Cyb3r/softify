use std::sync::Arc;
use regex::Regex;
use serde_json::Value;
use crate::models::{ImportPlaylistResult, ImportedTrackMatch, Playlist, QualityPreset, SoftifyError, Track};
use crate::db::repository::DatabaseRepository;
use crate::resolvers::hybrid::HybridStreamResolver;

pub const DEFAULT_USER_AGENT: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SpotifyEntityType {
    Playlist,
    Album,
    Track,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SpotifyEntityRef {
    pub id: String,
    pub entity_type: SpotifyEntityType,
}

#[derive(Debug, Clone)]
pub struct RawSpotifyTrack {
    pub title: String,
    pub artist: String,
    pub album: Option<String>,
    pub duration_ms: u64,
    pub cover_url: Option<String>,
}

#[derive(Debug, Clone)]
pub struct RawSpotifyPlaylist {
    pub id: String,
    pub title: String,
    pub description: Option<String>,
    pub cover_url: Option<String>,
    pub tracks: Vec<RawSpotifyTrack>,
}

pub struct SpotifyImporter {
    client: reqwest::Client,
    resolver: Arc<HybridStreamResolver>,
    db: Arc<DatabaseRepository>,
}

impl SpotifyImporter {
    pub fn new(resolver: Arc<HybridStreamResolver>, db: Arc<DatabaseRepository>) -> Self {
        let client = reqwest::Client::builder()
            .user_agent(DEFAULT_USER_AGENT)
            .build()
            .unwrap_or_default();
        Self { client, resolver, db }
    }

    pub fn with_client(
        client: reqwest::Client,
        resolver: Arc<HybridStreamResolver>,
        db: Arc<DatabaseRepository>,
    ) -> Self {
        Self { client, resolver, db }
    }

    pub fn parse_spotify_entity(input: &str) -> Option<SpotifyEntityRef> {
        let clean = input.trim();
        if clean.is_empty() {
            return None;
        }

        // 1. Spotify URI: spotify:(playlist|album|track):([a-zA-Z0-9]+)
        let uri_re = Regex::new(r"spotify:(playlist|album|track):([a-zA-Z0-9]+)").ok()?;
        if let Some(caps) = uri_re.captures(clean) {
            let t_str = caps.get(1)?.as_str();
            let id = caps.get(2)?.as_str().to_string();
            let entity_type = match t_str {
                "album" => SpotifyEntityType::Album,
                "track" => SpotifyEntityType::Track,
                _ => SpotifyEntityType::Playlist,
            };
            return Some(SpotifyEntityRef { id, entity_type });
        }

        // 2. Open Spotify web URL
        let url_re = Regex::new(r"open\.spotify\.com/(?:.+/)?(playlist|album|track)/([a-zA-Z0-9]+)").ok()?;
        if let Some(caps) = url_re.captures(clean) {
            let t_str = caps.get(1)?.as_str();
            let id = caps.get(2)?.as_str().to_string();
            let entity_type = match t_str {
                "album" => SpotifyEntityType::Album,
                "track" => SpotifyEntityType::Track,
                _ => SpotifyEntityType::Playlist,
            };
            return Some(SpotifyEntityRef { id, entity_type });
        }

        // 3. Direct 22-character Spotify base62 ID (default to playlist)
        let id_re = Regex::new(r"^[a-zA-Z0-9]{22}$").ok()?;
        if id_re.is_match(clean) {
            return Some(SpotifyEntityRef {
                id: clean.to_string(),
                entity_type: SpotifyEntityType::Playlist,
            });
        }

        None
    }

    pub async fn fetch_playlist_metadata(&self, entity: &SpotifyEntityRef) -> Result<RawSpotifyPlaylist, SoftifyError> {
        let endpoint_type = match entity.entity_type {
            SpotifyEntityType::Playlist => "playlist",
            SpotifyEntityType::Album => "album",
            SpotifyEntityType::Track => "track",
        };
        let url = format!("https://open.spotify.com/embed/{}/{}", endpoint_type, entity.id);

        let response = self.client.get(&url)
            .send()
            .await
            .map_err(|e| SoftifyError::Import { reason: format!("Failed to request Spotify embed: {}", e) })?;

        if !response.status().is_success() {
            return Err(SoftifyError::Import {
                reason: format!("Spotify embed responded with status {}", response.status()),
            });
        }

        let body = response.text().await
            .map_err(|e| SoftifyError::Import { reason: format!("Failed to read embed response: {}", e) })?;

        Self::parse_embed_html(&entity.id, &body)
    }

    pub fn parse_embed_html(id: &str, html: &str) -> Result<RawSpotifyPlaylist, SoftifyError> {
        let re = Regex::new(r#"<script id="__NEXT_DATA__" type="application/json">([^<]+)</script>"#)
            .map_err(|e| SoftifyError::Import { reason: e.to_string() })?;

        let caps = re.captures(html).ok_or_else(|| SoftifyError::Import {
            reason: "Could not find __NEXT_DATA__ script in Spotify embed HTML".to_string(),
        })?;

        let json_str = caps.get(1).map(|m| m.as_str()).unwrap_or("");
        let parsed: Value = serde_json::from_str(json_str)
            .map_err(|e| SoftifyError::Import { reason: format!("Invalid JSON in Spotify embed: {}", e) })?;

        let entity = parsed.pointer("/props/pageProps/state/data/entity")
            .ok_or_else(|| SoftifyError::Import {
                reason: "Missing /props/pageProps/state/data/entity in Spotify embed data".to_string(),
            })?;

        let title = entity.get("name")
            .or_else(|| entity.get("title"))
            .and_then(|v| v.as_str())
            .unwrap_or("Imported Spotify Playlist")
            .to_string();

        let description = entity.get("subtitle").and_then(|v| v.as_str()).map(|s| s.to_string());

        let cover_url = entity.pointer("/coverArt/sources/0/url")
            .or_else(|| entity.pointer("/visualIdentity/image/0/url"))
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        let mut tracks = Vec::new();
        if let Some(track_list) = entity.get("trackList").and_then(|v| v.as_array()) {
            for t in track_list {
                let track_title = t.get("title").and_then(|v| v.as_str()).unwrap_or("Unknown").to_string();
                let artist = t.get("subtitle").and_then(|v| v.as_str()).unwrap_or("Unknown").to_string();
                let duration_ms = t.get("duration").and_then(|v| v.as_u64()).unwrap_or(0);
                let album = t.pointer("/albumOfTrack/name")
                    .or_else(|| t.pointer("/album/name"))
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string());

                let t_cover = t.pointer("/albumOfTrack/coverArt/sources/0/url")
                    .or_else(|| t.pointer("/coverArt/sources/0/url"))
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string())
                    .or_else(|| cover_url.clone());

                tracks.push(RawSpotifyTrack {
                    title: track_title,
                    artist,
                    album,
                    duration_ms,
                    cover_url: t_cover,
                });
            }
        }

        Ok(RawSpotifyPlaylist {
            id: id.to_string(),
            title,
            description,
            cover_url,
            tracks,
        })
    }

    pub async fn import_playlist(&self, input: &str) -> Result<ImportPlaylistResult, SoftifyError> {
        let entity = Self::parse_spotify_entity(input).ok_or_else(|| SoftifyError::Import {
            reason: format!("Invalid Spotify URL, URI or ID: {}", input),
        })?;

        let raw = self.fetch_playlist_metadata(&entity).await?;

        let playlist_id = format!("sp_{}", raw.id);
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);

        let playlist = Playlist {
            id: playlist_id.clone(),
            name: raw.title.clone(),
            description: raw.description.clone(),
            is_imported: true,
            source_url: Some(input.trim().to_string()),
            track_count: raw.tracks.len() as u32,
            created_at: now,
        };

        // Persist playlist row
        self.db.create_imported_playlist(&playlist)?;

        let mut matches = Vec::new();
        let mut matched_count = 0u32;

        for (pos, raw_t) in raw.tracks.into_iter().enumerate() {
            let track_id = format!("sp_tr_{}_{}", raw.id, pos);
            let track = Track {
                id: track_id.clone(),
                source_id: format!("spotify:{}_{}", raw_t.title, raw_t.artist),
                title: raw_t.title.clone(),
                artist: raw_t.artist.clone(),
                album: raw_t.album.clone(),
                duration_ms: raw_t.duration_ms,
                cover_url: raw_t.cover_url.clone(),
                match_confidence: Some(1.0),
                is_liked: false,
                is_unavailable: false,
            };

            let resolve_res = self.resolver.resolve(&track, QualityPreset::High).await;

            match resolve_res {
                Ok(stream_info) => {
                    let _ = self.db.insert_or_update_track(&track);
                    let _ = self.db.add_track_to_playlist(
                        &playlist_id,
                        (pos + 1) as u32,
                        Some(&track_id),
                        &raw_t.title,
                        &raw_t.artist,
                        "matched",
                    );

                    matched_count += 1;
                    matches.push(ImportedTrackMatch {
                        original_title: raw_t.title,
                        original_artist: raw_t.artist,
                        original_album: raw_t.album,
                        duration_ms: raw_t.duration_ms,
                        cover_url: raw_t.cover_url,
                        resolved_track: Some(track),
                        match_status: "matched".to_string(),
                        bitrate_kbps: stream_info.bitrate_kbps,
                        provider: stream_info.provider,
                    });
                }
                Err(_) => {
                    let _ = self.db.add_track_to_playlist(
                        &playlist_id,
                        (pos + 1) as u32,
                        None,
                        &raw_t.title,
                        &raw_t.artist,
                        "unmatched",
                    );

                    matches.push(ImportedTrackMatch {
                        original_title: raw_t.title,
                        original_artist: raw_t.artist,
                        original_album: raw_t.album,
                        duration_ms: raw_t.duration_ms,
                        cover_url: raw_t.cover_url,
                        resolved_track: None,
                        match_status: "unmatched".to_string(),
                        bitrate_kbps: 0,
                        provider: "none".to_string(),
                    });
                }
            }
        }

        let total_tracks = matches.len() as u32;
        Ok(ImportPlaylistResult {
            playlist,
            tracks: matches,
            total_tracks,
            matched_tracks: matched_count,
            notice: None,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_spotify_entities() {
        let uri = "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M";
        let parsed = SpotifyImporter::parse_spotify_entity(uri).expect("parse URI");
        assert_eq!(parsed.id, "37i9dQZF1DXcBWIGoYBM5M");
        assert_eq!(parsed.entity_type, SpotifyEntityType::Playlist);

        let url = "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=abcd";
        let parsed_url = SpotifyImporter::parse_spotify_entity(url).expect("parse URL");
        assert_eq!(parsed_url.id, "37i9dQZF1DXcBWIGoYBM5M");
        assert_eq!(parsed_url.entity_type, SpotifyEntityType::Playlist);

        let album_url = "https://open.spotify.com/album/4aawyAB9vmqN3uQ7FjRGTy";
        let parsed_album = SpotifyImporter::parse_spotify_entity(album_url).expect("parse album");
        assert_eq!(parsed_album.id, "4aawyAB9vmqN3uQ7FjRGTy");
        assert_eq!(parsed_album.entity_type, SpotifyEntityType::Album);

        let base62 = "37i9dQZF1DXcBWIGoYBM5M";
        let parsed_base62 = SpotifyImporter::parse_spotify_entity(base62).expect("parse base62");
        assert_eq!(parsed_base62.id, "37i9dQZF1DXcBWIGoYBM5M");
        assert_eq!(parsed_base62.entity_type, SpotifyEntityType::Playlist);
    }

    #[test]
    fn test_parse_embed_html() {
        let sample_html = r#"
        <!DOCTYPE html>
        <html>
        <head>
        <script id="__NEXT_DATA__" type="application/json">
        {
          "props": {
            "pageProps": {
              "state": {
                "data": {
                  "entity": {
                    "name": "Today's Top Hits",
                    "subtitle": "Jung Kook is on top of the Hottest 50!",
                    "coverArt": {
                      "sources": [{"url": "https://i.scdn.co/image/ab67706f00000002b55b62b083"}]
                    },
                    "trackList": [
                      {
                        "uri": "spotify:track:12345",
                        "title": "Seven (feat. Latto)",
                        "subtitle": "Jung Kook, Latto",
                        "duration": 184400,
                        "albumOfTrack": {
                          "name": "Seven (feat. Latto)",
                          "coverArt": {
                            "sources": [{"url": "https://i.scdn.co/image/track1"}]
                          }
                        }
                      },
                      {
                        "uri": "spotify:track:67890",
                        "title": "Paint The Town Red",
                        "subtitle": "Doja Cat",
                        "duration": 231000,
                        "albumOfTrack": {
                          "name": "Scarlet",
                          "coverArt": {
                            "sources": [{"url": "https://i.scdn.co/image/track2"}]
                          }
                        }
                      }
                    ]
                  }
                }
              }
            }
          }
        }
        </script>
        </head>
        <body></body>
        </html>
        "#;

        let res = SpotifyImporter::parse_embed_html("test_pl", sample_html).expect("parsed embed html");
        assert_eq!(res.title, "Today's Top Hits");
        assert_eq!(res.tracks.len(), 2);
        assert_eq!(res.tracks[0].title, "Seven (feat. Latto)");
        assert_eq!(res.tracks[0].artist, "Jung Kook, Latto");
        assert_eq!(res.tracks[0].duration_ms, 184400);
        assert_eq!(res.tracks[1].title, "Paint The Town Red");
    }
}
