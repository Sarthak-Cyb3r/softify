/*
 * Metrolist Project (C) 2026 | Licensed under GPL-3.0
 * Adapted for Softify-experimental
 */

use crate::models::{SoftifyError, SyncedLyrics, Track};
use crate::db::repository::DatabaseRepository;
use super::betterlyrics::BetterLyricsClient;
use super::lrcred::LrcredClient;
use super::unison::UnisonClient;
use super::paxsenix::PaxsenixClient;
use super::youtube_captions::YouTubeCaptionsClient;
use super::lrclib::LrclibClient;
use super::kugou::KuGouClient;
use super::parser::{parse_lrc, parse_lrclib_lyricsfile, parse_ttml};

const NEGATIVE_CACHE_TTL_SECS: i64 = 7 * 86400; // 7 days

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct LyricsProvidersConfig {
    pub enable_betterlyrics: bool,
    pub enable_lrcred: bool,
    pub enable_unison: bool,
    pub enable_paxsenix: bool,
    pub enable_youtube_captions: bool,
    pub enable_lrclib: bool,
    pub enable_kugou: bool,
    pub timeout_secs: u64,
}

impl Default for LyricsProvidersConfig {
    fn default() -> Self {
        Self {
            enable_betterlyrics: true,
            enable_lrcred: true,
            enable_unison: true,
            enable_paxsenix: false, // Default disabled due to live 502 upstream
            enable_youtube_captions: true,
            enable_lrclib: true,
            enable_kugou: true,
            timeout_secs: 5,
        }
    }
}

pub struct LyricsEngine {
    db: Option<DatabaseRepository>,
    config: LyricsProvidersConfig,
    betterlyrics: BetterLyricsClient,
    lrcred: LrcredClient,
    unison: UnisonClient,
    paxsenix: PaxsenixClient,
    youtube_captions: YouTubeCaptionsClient,
    lrclib: LrclibClient,
    kugou: KuGouClient,
}

impl LyricsEngine {
    pub fn new(db: Option<DatabaseRepository>) -> Self {
        Self {
            db,
            config: LyricsProvidersConfig::default(),
            betterlyrics: BetterLyricsClient::new(),
            lrcred: LrcredClient::new(),
            unison: UnisonClient::new(),
            paxsenix: PaxsenixClient::new(),
            youtube_captions: YouTubeCaptionsClient::new(),
            lrclib: LrclibClient::new(),
            kugou: KuGouClient::new(),
        }
    }

    pub fn with_config(db: Option<DatabaseRepository>, config: LyricsProvidersConfig) -> Self {
        Self {
            db,
            config,
            betterlyrics: BetterLyricsClient::new(),
            lrcred: LrcredClient::new(),
            unison: UnisonClient::new(),
            paxsenix: PaxsenixClient::new(),
            youtube_captions: YouTubeCaptionsClient::new(),
            lrclib: LrclibClient::new(),
            kugou: KuGouClient::new(),
        }
    }

    #[cfg(test)]
    pub fn with_lrclib(db: Option<DatabaseRepository>, lrclib: LrclibClient) -> Self {
        let config = LyricsProvidersConfig {
            enable_betterlyrics: false,
            enable_lrcred: false,
            enable_unison: false,
            enable_paxsenix: false,
            enable_youtube_captions: false,
            enable_kugou: false,
            enable_lrclib: true,
            ..Default::default()
        };
        Self {
            db,
            config,
            betterlyrics: BetterLyricsClient::new(),
            lrcred: LrcredClient::new(),
            unison: UnisonClient::new(),
            paxsenix: PaxsenixClient::new(),
            youtube_captions: YouTubeCaptionsClient::new(),
            lrclib,
            kugou: KuGouClient::new(),
        }
    }

    pub async fn get_lyrics(&self, track: &Track) -> Result<SyncedLyrics, SoftifyError> {
        let now_sec = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as i64;

        // 1. Check local DB cache with 7-day TTL check
        if let Some(ref repo) = self.db {
            if let Ok(Some((cached_synced, cached_plain, is_not_found))) = repo.get_cached_lyrics(&track.id) {
                if is_not_found {
                    // Check if negative cache has expired (7-day TTL)
                    let cached_at = repo.get_cached_lyrics_timestamp(&track.id).unwrap_or(0);
                    if now_sec - cached_at < NEGATIVE_CACHE_TTL_SECS {
                        return Ok(SyncedLyrics {
                            is_synced: false,
                            is_word_synced: false,
                            lines: Vec::new(),
                            plain_text: None,
                            provider: "cached".to_string(),
                        });
                    }
                } else {
                    if let Some(lrc) = cached_synced {
                        if lrc.contains("lines:") && lrc.contains("start_ms:") {
                            if let Some(parsed) = parse_lrclib_lyricsfile(&lrc) {
                                return Ok(parsed);
                            }
                        }
                        if lrc.contains("<tt ") || lrc.contains("<tt>") {
                            let parsed = parse_ttml(&lrc);
                            if parsed.is_synced {
                                return Ok(parsed);
                            }
                        }
                        let parsed = parse_lrc(&lrc);
                        if parsed.is_synced {
                            return Ok(parsed);
                        }
                    }

                    if let Some(plain) = cached_plain {
                        return Ok(SyncedLyrics {
                            is_synced: false,
                            is_word_synced: false,
                            lines: Vec::new(),
                            plain_text: Some(plain),
                            provider: "cached".to_string(),
                        });
                    }
                }
            }
        }

        // 2. Multi-provider pipeline in Metrolist priority:
        // First provider with word timing wins. If none, hold best line-timed fallback.
        let mut best_line_synced: Option<SyncedLyrics> = None;

        // Provider 1: BetterLyrics (TTML word-synced)
        if self.config.enable_betterlyrics {
            if let Some(lyrics) = self.betterlyrics.fetch_lyrics(&track.title, &track.artist, Some(track.duration_ms)).await {
                if lyrics.is_word_synced && !lyrics.lines.is_empty() {
                    self.cache_lyrics(&track.id, &lyrics);
                    return Ok(lyrics);
                } else if lyrics.is_synced && best_line_synced.is_none() {
                    best_line_synced = Some(lyrics);
                }
            }
        }

        // Provider 2: lrc.red (TTML word-synced)
        if self.config.enable_lrcred {
            if let Some(lyrics) = self.lrcred.fetch_lyrics(&track.title, &track.artist, Some(track.duration_ms)).await {
                if lyrics.is_word_synced && !lyrics.lines.is_empty() {
                    self.cache_lyrics(&track.id, &lyrics);
                    return Ok(lyrics);
                } else if lyrics.is_synced && best_line_synced.is_none() {
                    best_line_synced = Some(lyrics);
                }
            }
        }

        // Provider 3: Unison (TTML/LRC word-synced)
        if self.config.enable_unison {
            if let Some(lyrics) = self.unison.fetch_lyrics(&track.title, &track.artist, Some(track.duration_ms)).await {
                if lyrics.is_word_synced && !lyrics.lines.is_empty() {
                    self.cache_lyrics(&track.id, &lyrics);
                    return Ok(lyrics);
                } else if lyrics.is_synced && best_line_synced.is_none() {
                    best_line_synced = Some(lyrics);
                }
            }
        }

        // Provider 4: Paxsenix
        if self.config.enable_paxsenix {
            if let Some(lyrics) = self.paxsenix.fetch_lyrics_by_id(&track.source_id).await {
                if lyrics.is_word_synced && !lyrics.lines.is_empty() {
                    self.cache_lyrics(&track.id, &lyrics);
                    return Ok(lyrics);
                } else if lyrics.is_synced && best_line_synced.is_none() {
                    best_line_synced = Some(lyrics);
                }
            }
        }

        // Provider 5: YouTube Captions (json3 word-offsets)
        if self.config.enable_youtube_captions && track.source_id.len() == 11 {
            if let Some(lyrics) = self.youtube_captions.fetch_by_video_id(&track.source_id).await {
                if lyrics.is_word_synced && !lyrics.lines.is_empty() {
                    self.cache_lyrics(&track.id, &lyrics);
                    return Ok(lyrics);
                } else if lyrics.is_synced && best_line_synced.is_none() {
                    best_line_synced = Some(lyrics);
                }
            }
        }

        // Provider 6: LRCLIB (lyricsfile word-synced / synced LRC)
        if self.config.enable_lrclib {
            if let Ok(Some(data)) = self.lrclib.fetch_lyrics(&track.title, &track.artist, track.duration_ms).await {
                if data.instrumental.unwrap_or(false) {
                    if let Some(ref repo) = self.db {
                        let _ = repo.save_cached_lyrics(&track.id, None, None, true);
                    }
                    return Ok(SyncedLyrics {
                        is_synced: false,
                        is_word_synced: false,
                        lines: Vec::new(),
                        plain_text: Some("[Instrumental]".to_string()),
                        provider: "lrclib".to_string(),
                    });
                }

                if data.has_word_sync.unwrap_or(false) {
                    if let Some(ref lf) = data.lyricsfile {
                        if let Some(parsed) = parse_lrclib_lyricsfile(lf) {
                            if let Some(ref repo) = self.db {
                                let _ = repo.save_cached_lyrics(&track.id, Some(lf), data.plain_lyrics.as_deref(), false);
                            }
                            return Ok(parsed);
                        }
                    }
                }

                if let Some(ref lrc) = data.synced_lyrics {
                    let mut parsed = parse_lrc(lrc);
                    if let Some(ref plain) = data.plain_lyrics {
                        parsed.plain_text = Some(plain.clone());
                    }
                    if let Some(ref repo) = self.db {
                        let _ = repo.save_cached_lyrics(&track.id, Some(lrc), data.plain_lyrics.as_deref(), false);
                    }
                    if parsed.is_word_synced {
                        return Ok(parsed);
                    } else if parsed.is_synced && best_line_synced.is_none() {
                        best_line_synced = Some(parsed);
                    }
                } else if best_line_synced.is_none() && data.plain_lyrics.is_some() {
                    let plain = data.plain_lyrics.clone();
                    if let Some(ref repo) = self.db {
                        let _ = repo.save_cached_lyrics(&track.id, None, plain.as_deref(), false);
                    }
                    best_line_synced = Some(SyncedLyrics {
                        is_synced: false,
                        is_word_synced: false,
                        lines: Vec::new(),
                        plain_text: plain,
                        provider: "lrclib".to_string(),
                    });
                }
            }
        }

        // Provider 7: KuGou (line-synced fallback)
        if self.config.enable_kugou && best_line_synced.is_none() {
            if let Some(lyrics) = self.kugou.fetch_lyrics(&track.title, &track.artist, Some(track.duration_ms)).await {
                if lyrics.is_synced {
                    best_line_synced = Some(lyrics);
                }
            }
        }

        // If we found any line-synced lyrics along the chain, cache and return
        if let Some(line_lyrics) = best_line_synced {
            self.cache_lyrics(&track.id, &line_lyrics);
            return Ok(line_lyrics);
        }

        // No lyrics found from any provider: record 7-day negative cache
        if let Some(ref repo) = self.db {
            let _ = repo.save_cached_lyrics(&track.id, None, None, true);
        }

        Ok(SyncedLyrics {
            is_synced: false,
            is_word_synced: false,
            lines: Vec::new(),
            plain_text: None,
            provider: "none".to_string(),
        })
    }

    fn cache_lyrics(&self, track_id: &str, lyrics: &SyncedLyrics) {
        if let Some(ref repo) = self.db {
            let synced_text = if !lyrics.lines.is_empty() {
                let serialized_lines = lyrics.lines.iter().map(|l| {
                    let min = l.start_ms / 60_000;
                    let sec = (l.start_ms % 60_000) / 1000;
                    let ms = (l.start_ms % 1000) / 10;
                    format!("[{:02}:{:02}.{:02}] {}", min, sec, ms, l.text)
                }).collect::<Vec<_>>().join("\n");
                Some(serialized_lines)
            } else {
                None
            };
            let _ = repo.save_cached_lyrics(track_id, synced_text.as_deref(), lyrics.plain_text.as_deref(), false);
        }
    }
}
