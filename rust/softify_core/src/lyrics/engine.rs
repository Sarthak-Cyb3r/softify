use crate::models::{SoftifyError, SyncedLyrics, Track};
use crate::db::repository::DatabaseRepository;
use super::lrclib::LrclibClient;
use super::parser::parse_lrc;

pub struct LyricsEngine {
    db: Option<DatabaseRepository>,
    lrclib: LrclibClient,
}

impl LyricsEngine {
    pub fn new(db: Option<DatabaseRepository>) -> Self {
        Self {
            db,
            lrclib: LrclibClient::new(),
        }
    }

    #[cfg(test)]
    pub fn with_lrclib(db: Option<DatabaseRepository>, lrclib: LrclibClient) -> Self {
        Self { db, lrclib }
    }

    pub async fn get_lyrics(&self, track: &Track) -> Result<SyncedLyrics, SoftifyError> {
        // 1. Check local DB cache
        if let Some(ref repo) = self.db {
            if let Ok(Some((cached_synced, cached_plain, is_not_found))) = repo.get_cached_lyrics(&track.id) {
                if is_not_found {
                    return Ok(SyncedLyrics {
                        is_synced: false,
                        lines: Vec::new(),
                        plain_text: None,
                    });
                }

                if let Some(lrc) = cached_synced {
                    let parsed = parse_lrc(&lrc);
                    if parsed.is_synced {
                        return Ok(parsed);
                    }
                }

                if let Some(plain) = cached_plain {
                    return Ok(SyncedLyrics {
                        is_synced: false,
                        lines: Vec::new(),
                        plain_text: Some(plain),
                    });
                }
            }
        }

        // 2. Fetch from LRCLIB
        let resp = self.lrclib.fetch_lyrics(&track.title, &track.artist, track.duration_ms).await?;

        match resp {
            Some(data) => {
                if data.instrumental.unwrap_or(false) {
                    if let Some(ref repo) = self.db {
                        let _ = repo.save_cached_lyrics(&track.id, None, None, true);
                    }
                    return Ok(SyncedLyrics {
                        is_synced: false,
                        lines: Vec::new(),
                        plain_text: Some("[Instrumental]".to_string()),
                    });
                }

                let synced_str = data.synced_lyrics.as_deref();
                let plain_str = data.plain_lyrics.as_deref();

                // Save to cache
                if let Some(ref repo) = self.db {
                    let _ = repo.save_cached_lyrics(&track.id, synced_str, plain_str, false);
                }

                if let Some(lrc) = synced_str {
                    let parsed = parse_lrc(lrc);
                    if parsed.is_synced {
                        return Ok(parsed);
                    }
                }

                Ok(SyncedLyrics {
                    is_synced: false,
                    lines: Vec::new(),
                    plain_text: data.plain_lyrics,
                })
            }
            None => {
                // Mark not found in cache
                if let Some(ref repo) = self.db {
                    let _ = repo.save_cached_lyrics(&track.id, None, None, true);
                }
                Ok(SyncedLyrics {
                    is_synced: false,
                    lines: Vec::new(),
                    plain_text: None,
                })
            }
        }
    }
}
