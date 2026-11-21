use super::migrations::run_migrations;
use crate::models::{PlayHistory, Playlist, SoftifyError, Track};
use rusqlite::{params, Connection};
use std::sync::{Arc, Mutex};

#[derive(Clone)]
pub struct DatabaseRepository {
    conn: Arc<Mutex<Connection>>,
}

impl DatabaseRepository {
    pub fn new(path: &str) -> Result<Self, SoftifyError> {
        let conn = Connection::open(path)?;
        let repo = Self {
            conn: Arc::new(Mutex::new(conn)),
        };
        repo.init_tables()?;
        Ok(repo)
    }

    pub fn in_memory() -> Result<Self, SoftifyError> {
        let conn = Connection::open_in_memory()?;
        let repo = Self {
            conn: Arc::new(Mutex::new(conn)),
        };
        repo.init_tables()?;
        Ok(repo)
    }

    pub fn init_tables(&self) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        run_migrations(&conn)?;
        Ok(())
    }

    pub fn get_connection(&self) -> Arc<Mutex<Connection>> {
        self.conn.clone()
    }

    pub fn insert_or_update_track(&self, track: &Track) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);

        conn.execute(
            "INSERT INTO tracks (id, source_id, title, artist, album, duration_ms, cover_url, match_confidence, is_liked, is_unavailable, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
             ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                artist = excluded.artist,
                album = excluded.album,
                duration_ms = excluded.duration_ms,
                cover_url = excluded.cover_url,
                match_confidence = excluded.match_confidence",
            params![
                track.id,
                track.source_id,
                track.title,
                track.artist,
                track.album,
                track.duration_ms as i64,
                track.cover_url,
                track.match_confidence,
                if track.is_liked { 1 } else { 0 },
                if track.is_unavailable { 1 } else { 0 },
                now,
            ],
        )?;
        Ok(())
    }

    pub fn get_track_by_id(&self, id: &str) -> Result<Option<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT t.id, t.source_id, t.title, t.artist, t.album, t.duration_ms,
                    COALESCE(NULLIF(t.cover_url, ''), sm.cover_url,
                        CASE
                            WHEN t.id LIKE 'yt_%' THEN 'https://i.ytimg.com/vi/' || SUBSTR(t.id, 4) || '/mqdefault.jpg'
                            WHEN t.source_id LIKE 'yt_%' THEN 'https://i.ytimg.com/vi/' || SUBSTR(t.source_id, 4) || '/mqdefault.jpg'
                            WHEN t.source_id LIKE 'ytm_%' THEN 'https://i.ytimg.com/vi/' || SUBSTR(t.source_id, 5) || '/mqdefault.jpg'
                            WHEN LENGTH(t.source_id) = 11 THEN 'https://i.ytimg.com/vi/' || t.source_id || '/mqdefault.jpg'
                            ELSE NULL
                        END
                    ) as cover_url,
                    t.match_confidence, t.is_liked, t.is_unavailable
             FROM tracks t
             LEFT JOIN spotify_matches sm ON sm.spotify_id = REPLACE(t.source_id, 'spotify:', '')
             WHERE t.id = ?1"
        )?;

        let mut rows = stmt.query(params![id])?;
        if let Some(row) = rows.next()? {
            Ok(Some(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            }))
        } else {
            Ok(None)
        }
    }

    pub fn toggle_like(&self, track_id: &str) -> Result<bool, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let current_state: Option<i64> = conn
            .query_row(
                "SELECT is_liked FROM tracks WHERE id = ?1",
                params![track_id],
                |r| r.get(0),
            )
            .optional()?;

        let new_state = match current_state {
            Some(s) => {
                if s == 0 {
                    1
                } else {
                    0
                }
            }
            None => {
                return Err(SoftifyError::NotFound {
                    reason: format!("Track {} not in database", track_id),
                })
            }
        };

        conn.execute(
            "UPDATE tracks SET is_liked = ?1 WHERE id = ?2",
            params![new_state, track_id],
        )?;

        Ok(new_state != 0)
    }

    pub fn get_liked_tracks(&self) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT id, source_id, title, artist, album, duration_ms, cover_url, match_confidence, is_liked, is_unavailable
             FROM tracks WHERE is_liked = 1 ORDER BY created_at DESC"
        )?;

        let rows = stmt.query_map([], |row| {
            Ok(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            })
        })?;

        let mut tracks = Vec::new();
        for r in rows {
            tracks.push(r?);
        }
        Ok(tracks)
    }

    pub fn create_playlist(
        &self,
        name: &str,
        description: Option<&str>,
    ) -> Result<Playlist, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let id = format!(
            "pl_{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis()
        );
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;

        conn.execute(
            "INSERT INTO playlists (id, name, description, is_imported, source_url, created_at)
             VALUES (?1, ?2, ?3, 0, NULL, ?4)",
            params![id, name, description, now],
        )?;

        Ok(Playlist {
            id,
            name: name.to_string(),
            description: description.map(|s| s.to_string()),
            is_imported: false,
            source_url: None,
            track_count: 0,
            created_at: now,
            matched_count: 0,
        })
    }

    pub fn delete_playlist(&self, playlist_id: &str) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute("DELETE FROM playlists WHERE id = ?1", params![playlist_id])?;
        Ok(())
    }

    pub fn get_playlists(&self) -> Result<Vec<Playlist>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT p.id, p.name, p.description, p.is_imported, p.source_url, p.created_at,
                    COUNT(pt.position) as track_count,
                    COALESCE(SUM(CASE WHEN pt.match_status = 'matched' THEN 1 ELSE 0 END), 0) as matched_count
             FROM playlists p
             LEFT JOIN playlist_tracks pt ON p.id = pt.playlist_id
             GROUP BY p.id
             ORDER BY p.created_at DESC"
        )?;

        let rows = stmt.query_map([], |row| {
            Ok(Playlist {
                id: row.get(0)?,
                name: row.get(1)?,
                description: row.get(2)?,
                is_imported: row.get::<_, i64>(3)? != 0,
                source_url: row.get(4)?,
                created_at: row.get(5)?,
                track_count: row.get::<_, i64>(6)? as u32,
                matched_count: row.get::<_, i64>(7)? as u32,
            })
        })?;

        let mut playlists = Vec::new();
        for r in rows {
            playlists.push(r?);
        }
        Ok(playlists)
    }

    pub fn add_to_playlist(&self, playlist_id: &str, track_id: &str) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;

        let track_info: (String, String) = conn
            .query_row(
                "SELECT title, artist FROM tracks WHERE id = ?1",
                params![track_id],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()?
            .ok_or_else(|| SoftifyError::NotFound {
                reason: format!("Track {} not found", track_id),
            })?;

        let next_pos: i64 = conn.query_row(
            "SELECT COALESCE(MAX(position), -1) + 1 FROM playlist_tracks WHERE playlist_id = ?1",
            params![playlist_id],
            |r| r.get(0),
        )?;

        conn.execute(
            "INSERT INTO playlist_tracks (playlist_id, position, track_id, original_title, original_artist, match_status)
             VALUES (?1, ?2, ?3, ?4, ?5, 'matched')",
            params![playlist_id, next_pos, track_id, track_info.0, track_info.1],
        )?;

        Ok(())
    }

    pub fn remove_from_playlist(
        &self,
        playlist_id: &str,
        track_id: &str,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute(
            "DELETE FROM playlist_tracks WHERE playlist_id = ?1 AND track_id = ?2",
            params![playlist_id, track_id],
        )?;
        Ok(())
    }

    pub fn get_playlist_tracks(&self, playlist_id: &str) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT t.id, t.source_id, t.title, t.artist, t.album, t.duration_ms,
                    COALESCE(NULLIF(t.cover_url, ''), sm.cover_url,
                        CASE
                            WHEN t.id LIKE 'yt_%' THEN 'https://i.ytimg.com/vi/' || SUBSTR(t.id, 4) || '/mqdefault.jpg'
                            WHEN t.source_id LIKE 'yt_%' THEN 'https://i.ytimg.com/vi/' || SUBSTR(t.source_id, 4) || '/mqdefault.jpg'
                            WHEN t.source_id LIKE 'ytm_%' THEN 'https://i.ytimg.com/vi/' || SUBSTR(t.source_id, 5) || '/mqdefault.jpg'
                            WHEN LENGTH(t.source_id) = 11 THEN 'https://i.ytimg.com/vi/' || t.source_id || '/mqdefault.jpg'
                            ELSE NULL
                        END
                    ) as cover_url,
                    t.match_confidence, t.is_liked, t.is_unavailable
             FROM playlist_tracks pt
             JOIN tracks t ON pt.track_id = t.id
             LEFT JOIN spotify_matches sm ON sm.spotify_id = REPLACE(t.source_id, 'spotify:', '')
             WHERE pt.playlist_id = ?1
             ORDER BY pt.position ASC"
        )?;

        let rows = stmt.query_map(params![playlist_id], |row| {
            Ok(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            })
        })?;

        let mut tracks = Vec::new();
        for r in rows {
            tracks.push(r?);
        }
        Ok(tracks)
    }

    pub fn record_play_history(
        &self,
        track_id: &str,
        completed_ratio: f64,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;

        // Incognito check: if learning is paused, do not record listening history
        let is_paused: Result<String, rusqlite::Error> = conn.query_row(
            "SELECT value FROM settings WHERE key = 'learning_paused'",
            [],
            |r| r.get(0),
        );
        if let Ok(val) = is_paused {
            if val == "true" {
                return Ok(());
            }
        }

        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);

        conn.execute(
            "INSERT INTO play_histories (track_id, played_at, completed_ratio)
             VALUES (?1, ?2, ?3)",
            params![track_id, now, completed_ratio],
        )?;
        Ok(())
    }

    pub fn get_history(&self, limit: u32) -> Result<Vec<PlayHistory>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT ph.id, ph.played_at, ph.completed_ratio,
                    t.id, t.source_id, t.title, t.artist, t.album, t.duration_ms,
                    COALESCE(NULLIF(t.cover_url, ''), sm.cover_url,
                        CASE
                            WHEN t.id LIKE 'yt_%' THEN 'https://i.ytimg.com/vi/' || SUBSTR(t.id, 4) || '/mqdefault.jpg'
                            WHEN t.source_id LIKE 'yt_%' THEN 'https://i.ytimg.com/vi/' || SUBSTR(t.source_id, 4) || '/mqdefault.jpg'
                            WHEN t.source_id LIKE 'ytm_%' THEN 'https://i.ytimg.com/vi/' || SUBSTR(t.source_id, 5) || '/mqdefault.jpg'
                            WHEN LENGTH(t.source_id) = 11 THEN 'https://i.ytimg.com/vi/' || t.source_id || '/mqdefault.jpg'
                            ELSE NULL
                        END
                    ) as cover_url,
                    t.match_confidence, t.is_liked, t.is_unavailable
             FROM play_histories ph
             JOIN tracks t ON ph.track_id = t.id
             LEFT JOIN spotify_matches sm ON sm.spotify_id = REPLACE(t.source_id, 'spotify:', '')
             ORDER BY ph.played_at DESC
             LIMIT ?1",
        )?;

        let rows = stmt.query_map(params![limit], |row| {
            Ok(PlayHistory {
                id: row.get(0)?,
                played_at: row.get(1)?,
                completed_ratio: row.get(2)?,
                track: Track {
                    id: row.get(3)?,
                    source_id: row.get(4)?,
                    title: row.get(5)?,
                    artist: row.get(6)?,
                    album: row.get(7)?,
                    duration_ms: row.get::<_, i64>(8)? as u64,
                    cover_url: row.get(9)?,
                    match_confidence: row.get(10)?,
                    is_liked: row.get::<_, i64>(11)? != 0,
                    is_unavailable: row.get::<_, i64>(12)? != 0,
                },
            })
        })?;

        let mut history = Vec::new();
        for r in rows {
            history.push(r?);
        }
        Ok(history)
    }

    pub fn clear_history(&self) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute("DELETE FROM play_histories", [])?;
        Ok(())
    }

    /// Full-Text Search in local tracks using FTS5 virtual table
    pub fn search_local_tracks_fts(
        &self,
        fts_query: &str,
        limit: u32,
    ) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT t.id, t.source_id, t.title, t.artist, t.album, t.duration_ms, t.cover_url,
                    t.match_confidence, t.is_liked, t.is_unavailable
             FROM tracks_fts fts
             JOIN tracks t ON fts.track_id = t.id
             WHERE tracks_fts MATCH ?1
             ORDER BY rank
             LIMIT ?2",
        )?;

        let rows = stmt.query_map(params![fts_query, limit], |row| {
            Ok(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            })
        })?;

        let mut tracks = Vec::new();
        for r in rows {
            tracks.push(r?);
        }
        Ok(tracks)
    }

    #[allow(clippy::type_complexity)]
    pub fn get_cached_lyrics(
        &self,
        track_id: &str,
    ) -> Result<Option<(Option<String>, Option<String>, bool)>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT synced_lrc, plain_text, is_not_found FROM cached_lyrics WHERE track_id = ?1",
        )?;

        let mut rows = stmt.query(params![track_id])?;
        if let Some(row) = rows.next()? {
            Ok(Some((row.get(0)?, row.get(1)?, row.get::<_, i64>(2)? != 0)))
        } else {
            Ok(None)
        }
    }

    pub fn get_cached_lyrics_timestamp(&self, track_id: &str) -> Result<i64, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare("SELECT cached_at FROM cached_lyrics WHERE track_id = ?1")?;
        let mut rows = stmt.query(params![track_id])?;
        if let Some(row) = rows.next()? {
            Ok(row.get(0)?)
        } else {
            Ok(0)
        }
    }

    pub fn save_cached_lyrics(
        &self,
        track_id: &str,
        synced_lrc: Option<&str>,
        plain_text: Option<&str>,
        is_not_found: bool,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;

        // Ensure track exists in tracks table to satisfy foreign key constraint
        let _ = conn.execute(
            "INSERT OR IGNORE INTO tracks (id, source_id, title, artist, duration_ms, created_at)
             VALUES (?1, ?1, ?1, 'Unknown', 0, ?2)",
            params![track_id, now],
        );

        conn.execute(
            "INSERT INTO cached_lyrics (track_id, synced_lrc, plain_text, is_not_found, cached_at)
             VALUES (?1, ?2, ?3, ?4, ?5)
             ON CONFLICT(track_id) DO UPDATE SET
                synced_lrc = excluded.synced_lrc,
                plain_text = excluded.plain_text,
                is_not_found = excluded.is_not_found,
                cached_at = excluded.cached_at",
            params![
                track_id,
                synced_lrc,
                plain_text,
                if is_not_found { 1 } else { 0 },
                now
            ],
        )?;

        Ok(())
    }

    #[allow(clippy::too_many_arguments)]
    pub fn record_download(
        &self,
        track_id: &str,
        relative_path: &str,
        container_format: &str,
        file_size_bytes: u64,
        bytes_downloaded: u64,
        status: &str,
        bitrate_kbps: u32,
        last_error: Option<&str>,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;

        // Ensure track exists in tracks table to satisfy foreign key constraint
        let _ = conn.execute(
            "INSERT OR IGNORE INTO tracks (id, source_id, title, artist, duration_ms, created_at)
             VALUES (?1, ?1, ?1, 'Unknown', 0, ?2)",
            params![track_id, now],
        );

        conn.execute(
            "INSERT INTO downloads (track_id, relative_path, container_format, file_size_bytes, bytes_downloaded, status, bitrate_kbps, created_at, last_error)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
             ON CONFLICT(track_id) DO UPDATE SET
                relative_path = excluded.relative_path,
                container_format = excluded.container_format,
                file_size_bytes = excluded.file_size_bytes,
                bytes_downloaded = excluded.bytes_downloaded,
                status = excluded.status,
                bitrate_kbps = excluded.bitrate_kbps,
                last_error = excluded.last_error",
            params![
                track_id,
                relative_path,
                container_format,
                file_size_bytes as i64,
                bytes_downloaded as i64,
                status,
                bitrate_kbps as i64,
                now,
                last_error
            ],
        )?;

        Ok(())
    }

    pub fn get_downloads(&self) -> Result<Vec<crate::models::DownloadItem>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT track_id, relative_path, container_format, file_size_bytes, bytes_downloaded, status, bitrate_kbps, created_at, last_error
             FROM downloads
             ORDER BY created_at DESC"
        )?;

        let rows = stmt.query_map([], |row| {
            Ok(crate::models::DownloadItem {
                track_id: row.get(0)?,
                relative_path: row.get(1)?,
                container_format: row.get(2)?,
                file_size_bytes: row.get::<_, i64>(3)? as u64,
                bytes_downloaded: row.get::<_, i64>(4)? as u64,
                status: row.get(5)?,
                bitrate_kbps: row.get::<_, i64>(6)? as u32,
                created_at: row.get(7)?,
                last_error: row.get(8)?,
            })
        })?;

        let mut items = Vec::new();
        for r in rows {
            items.push(r?);
        }
        Ok(items)
    }

    pub fn get_download(
        &self,
        track_id: &str,
    ) -> Result<Option<crate::models::DownloadItem>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT track_id, relative_path, container_format, file_size_bytes, bytes_downloaded, status, bitrate_kbps, created_at, last_error
             FROM downloads
             WHERE track_id = ?1"
        )?;

        let mut rows = stmt.query(params![track_id])?;
        if let Some(row) = rows.next()? {
            Ok(Some(crate::models::DownloadItem {
                track_id: row.get(0)?,
                relative_path: row.get(1)?,
                container_format: row.get(2)?,
                file_size_bytes: row.get::<_, i64>(3)? as u64,
                bytes_downloaded: row.get::<_, i64>(4)? as u64,
                status: row.get(5)?,
                bitrate_kbps: row.get::<_, i64>(6)? as u32,
                created_at: row.get(7)?,
                last_error: row.get(8)?,
            }))
        } else {
            Ok(None)
        }
    }

    pub fn update_download_status(
        &self,
        track_id: &str,
        status: &str,
        last_error: Option<&str>,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute(
            "UPDATE downloads SET status = ?1, last_error = ?2 WHERE track_id = ?3",
            params![status, last_error, track_id],
        )?;
        Ok(())
    }

    pub fn update_download_progress(
        &self,
        track_id: &str,
        bytes_downloaded: u64,
        file_size_bytes: u64,
        status: &str,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute(
            "UPDATE downloads SET bytes_downloaded = ?1, file_size_bytes = ?2, status = ?3 WHERE track_id = ?4",
            params![bytes_downloaded as i64, file_size_bytes as i64, status, track_id],
        )?;
        Ok(())
    }

    pub fn mark_download_repair(&self, track_id: &str, error: &str) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute(
            "UPDATE downloads SET status = 'failed', last_error = ?1 WHERE track_id = ?2",
            params![error, track_id],
        )?;
        Ok(())
    }

    pub fn delete_download(&self, track_id: &str) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute(
            "DELETE FROM downloads WHERE track_id = ?1",
            params![track_id],
        )?;
        Ok(())
    }

    pub fn delete_all_downloads(&self) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute("DELETE FROM downloads", [])?;
        Ok(())
    }

    pub fn create_imported_playlist(&self, playlist: &Playlist) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute(
            "INSERT INTO playlists (id, name, description, is_imported, source_url, created_at)
             VALUES (?1, ?2, ?3, 1, ?4, ?5)
             ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                description = excluded.description,
                source_url = excluded.source_url",
            params![
                playlist.id,
                playlist.name,
                playlist.description,
                playlist.source_url,
                playlist.created_at,
            ],
        )?;
        Ok(())
    }

    pub fn add_track_to_playlist(
        &self,
        playlist_id: &str,
        position: u32,
        track_id: Option<&str>,
        original_title: &str,
        original_artist: &str,
        match_status: &str,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute(
            "INSERT INTO playlist_tracks (playlist_id, position, track_id, original_title, original_artist, match_status)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)
             ON CONFLICT(playlist_id, position) DO UPDATE SET
                track_id = excluded.track_id,
                original_title = excluded.original_title,
                original_artist = excluded.original_artist,
                match_status = excluded.match_status",
            params![playlist_id, position as i64, track_id, original_title, original_artist, match_status],
        )?;
        Ok(())
    }

    pub fn get_spotify_match(
        &self,
        spotify_id: &str,
    ) -> Result<Option<(String, Option<String>)>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt =
            conn.prepare("SELECT video_id, cover_url FROM spotify_matches WHERE spotify_id = ?1")?;
        let mut rows = stmt.query(params![spotify_id])?;
        if let Some(row) = rows.next()? {
            let vid: String = row.get(0)?;
            let cover: Option<String> = row.get(1)?;
            Ok(Some((vid, cover)))
        } else {
            Ok(None)
        }
    }

    pub fn get_spotify_match_by_title_artist(
        &self,
        title: &str,
        artist: &str,
    ) -> Result<Option<(String, Option<String>)>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare("SELECT video_id, cover_url FROM spotify_matches WHERE title = ?1 AND artist = ?2 LIMIT 1")?;
        let mut rows = stmt.query(params![title, artist])?;
        if let Some(row) = rows.next()? {
            let vid: String = row.get(0)?;
            let cover: Option<String> = row.get(1)?;
            Ok(Some((vid, cover)))
        } else {
            Ok(None)
        }
    }

    pub fn insert_spotify_match(
        &self,
        spotify_id: &str,
        video_id: &str,
        title: &str,
        artist: &str,
        cover_url: Option<&str>,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as i64;
        conn.execute(
            "INSERT INTO spotify_matches (spotify_id, video_id, title, artist, cover_url, matched_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)
             ON CONFLICT(spotify_id) DO UPDATE SET
                video_id = excluded.video_id,
                cover_url = COALESCE(excluded.cover_url, spotify_matches.cover_url),
                matched_at = excluded.matched_at",
            params![spotify_id, video_id, title, artist, cover_url, now],
        )?;
        Ok(())
    }

    pub fn update_imported_track_match(
        &self,
        track_id: &str,
        video_id: &str,
        cover_url: Option<&str>,
        match_status: &str,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let ytm_source_id = format!("ytm_{video_id}");
        conn.execute(
            "UPDATE tracks 
             SET source_id = ?1,
                 cover_url = COALESCE(?2, cover_url),
                 match_confidence = 1.0
             WHERE id = ?3",
            params![ytm_source_id, cover_url, track_id],
        )?;
        conn.execute(
            "UPDATE playlist_tracks 
             SET match_status = ?1 
             WHERE track_id = ?2",
            params![match_status, track_id],
        )?;
        Ok(())
    }

    pub fn set_track_match_status(
        &self,
        playlist_id: &str,
        track_id: &str,
        match_status: &str,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute(
            "UPDATE playlist_tracks SET match_status = ?1 WHERE playlist_id = ?2 AND track_id = ?3",
            params![match_status, playlist_id, track_id],
        )?;
        Ok(())
    }

    pub fn get_playlist_match_counts(&self, playlist_id: &str) -> Result<(u32, u32), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT 
                COALESCE(SUM(CASE WHEN match_status = 'matched' THEN 1 ELSE 0 END), 0),
                COUNT(*)
             FROM playlist_tracks
             WHERE playlist_id = ?1",
        )?;
        let row = stmt.query_row(params![playlist_id], |r| {
            let matched: i64 = r.get(0)?;
            let total: i64 = r.get(1)?;
            Ok((matched as u32, total as u32))
        })?;
        Ok(row)
    }

    pub fn get_recent_history(&self, limit: u32) -> Result<Vec<PlayHistory>, SoftifyError> {
        self.get_history(limit)
    }

    pub fn get_play_sessions_history(
        &self,
    ) -> Result<Vec<crate::reco::cooccurrence::PlaySessionItem>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT ph.track_id, ph.played_at, t.duration_ms
             FROM play_histories ph
             JOIN tracks t ON ph.track_id = t.id
             ORDER BY ph.played_at ASC",
        )?;

        let rows = stmt.query_map([], |row| {
            Ok(crate::reco::cooccurrence::PlaySessionItem {
                track_id: row.get(0)?,
                played_at_ms: row.get::<_, i64>(1)? * 1000,
                duration_ms: row.get::<_, i64>(2)?,
            })
        })?;

        let mut items = Vec::new();
        for r in rows {
            items.push(r?);
        }
        Ok(items)
    }

    #[allow(clippy::too_many_arguments)]
    pub fn update_taste_profile(
        &self,
        entity_type: &str,
        entity_id: &str,
        is_stream: bool,
        is_early_skip: bool,
        is_save: bool,
        now_ms: i64,
        fast_half_life_ms: f64,
        slow_half_life_ms: f64,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let existing: Option<(i64, f64, f64, i64)> = conn.query_row(
            "SELECT id, fast_weight, slow_weight, updated_at FROM taste_profiles WHERE entity_type = ?1 AND entity_id = ?2",
            params![entity_type, entity_id],
            |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)),
        ).optional()?;

        let mut current_fast = 0.0;
        let mut current_slow = 0.0;

        if let Some((_, fast, slow, updated_at)) = existing {
            let dt = (now_ms - updated_at) as f64;
            current_fast = fast * 2.0f64.powf(-dt / fast_half_life_ms);
            current_slow = slow * 2.0f64.powf(-dt / slow_half_life_ms);
        }

        if is_stream {
            current_fast += 1.0;
            current_slow += 1.0;
        }
        if is_save {
            current_fast += 2.0;
            current_slow += 2.0;
        }
        if is_early_skip {
            current_fast = f64::max(0.0, current_fast - 1.5);
            current_slow = f64::max(0.0, current_slow - 0.5);
        }

        conn.execute(
            "INSERT INTO taste_profiles (entity_type, entity_id, fast_weight, slow_weight, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5)
             ON CONFLICT(entity_type, entity_id) DO UPDATE SET
                fast_weight = excluded.fast_weight,
                slow_weight = excluded.slow_weight,
                updated_at = excluded.updated_at",
            params![entity_type, entity_id, current_fast, current_slow, now_ms],
        )?;

        Ok(())
    }

    pub fn get_taste_profile(
        &self,
        entity_type: &str,
        entity_id: &str,
    ) -> Result<Option<crate::models::TasteProfileEntity>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT id, entity_type, entity_id, fast_weight, slow_weight, updated_at
             FROM taste_profiles WHERE entity_type = ?1 AND entity_id = ?2",
        )?;

        let mut rows = stmt.query(params![entity_type, entity_id])?;
        if let Some(row) = rows.next()? {
            let fast: f64 = row.get(3)?;
            let slow: f64 = row.get(4)?;
            let blended = 0.4 * fast + 0.6 * slow;
            Ok(Some(crate::models::TasteProfileEntity {
                id: row.get(0)?,
                entity_type: row.get(1)?,
                entity_id: row.get(2)?,
                fast_weight: fast,
                slow_weight: slow,
                blended_affinity: blended,
                updated_at: row.get(5)?,
            }))
        } else {
            Ok(None)
        }
    }

    pub fn get_top_taste_entities(
        &self,
        entity_type: &str,
        limit: u32,
        now_ms: i64,
        fast_half_life_ms: f64,
        slow_half_life_ms: f64,
    ) -> Result<Vec<crate::models::TasteProfileEntity>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT id, entity_type, entity_id, fast_weight, slow_weight, updated_at
             FROM taste_profiles WHERE entity_type = ?1",
        )?;

        let rows = stmt.query_map(params![entity_type], |row| {
            let id: i64 = row.get(0)?;
            let e_type: String = row.get(1)?;
            let e_id: String = row.get(2)?;
            let fast: f64 = row.get(3)?;
            let slow: f64 = row.get(4)?;
            let updated_at: i64 = row.get(5)?;

            let dt = (now_ms - updated_at) as f64;
            let decayed_fast = fast * 2.0f64.powf(-dt / fast_half_life_ms);
            let decayed_slow = slow * 2.0f64.powf(-dt / slow_half_life_ms);
            let blended = 0.4 * decayed_fast + 0.6 * decayed_slow;

            Ok(crate::models::TasteProfileEntity {
                id,
                entity_type: e_type,
                entity_id: e_id,
                fast_weight: decayed_fast,
                slow_weight: decayed_slow,
                blended_affinity: blended,
                updated_at: now_ms,
            })
        })?;

        let mut entities = Vec::new();
        for r in rows {
            entities.push(r?);
        }

        entities.sort_by(|a, b| {
            b.blended_affinity
                .partial_cmp(&a.blended_affinity)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        entities.truncate(limit as usize);
        Ok(entities)
    }

    pub fn decay_all_taste_profiles(
        &self,
        now_ms: i64,
        fast_half_life_ms: f64,
        slow_half_life_ms: f64,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt =
            conn.prepare("SELECT id, fast_weight, slow_weight, updated_at FROM taste_profiles")?;
        let rows = stmt.query_map([], |row| {
            Ok((
                row.get::<_, i64>(0)?,
                row.get::<_, f64>(1)?,
                row.get::<_, f64>(2)?,
                row.get::<_, i64>(3)?,
            ))
        })?;

        let mut updates = Vec::new();
        for r in rows {
            let (id, fast, slow, updated_at) = r?;
            let dt = (now_ms - updated_at) as f64;
            if dt > 60_000.0 {
                let decayed_fast = fast * 2.0f64.powf(-dt / fast_half_life_ms);
                let decayed_slow = slow * 2.0f64.powf(-dt / slow_half_life_ms);
                updates.push((id, decayed_fast, decayed_slow));
            }
        }

        for (id, fast, slow) in updates {
            conn.execute(
                "UPDATE taste_profiles SET fast_weight = ?1, slow_weight = ?2, updated_at = ?3 WHERE id = ?4",
                params![fast, slow, now_ms, id],
            )?;
        }

        Ok(())
    }

    pub fn batch_save_cooccurrences(
        &self,
        scores: &[crate::reco::cooccurrence::CooccurrencePairScore],
        now_ms: i64,
    ) -> Result<(), SoftifyError> {
        let mut conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let tx = conn.transaction()?;

        for s in scores {
            tx.execute(
                "INSERT INTO cooccurrences (track_a, track_b, score, updated_at)
                 VALUES (?1, ?2, ?3, ?4)
                 ON CONFLICT(track_a, track_b) DO UPDATE SET
                    score = excluded.score,
                    updated_at = excluded.updated_at",
                params![s.track_a, s.track_b, s.score, now_ms],
            )?;
        }

        tx.commit()?;
        Ok(())
    }

    pub fn get_cooccurrence_score(
        &self,
        track_a: &str,
        track_b: &str,
    ) -> Result<f64, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let score: Option<f64> = conn
            .query_row(
                "SELECT score FROM cooccurrences WHERE track_a = ?1 AND track_b = ?2",
                params![track_a, track_b],
                |r| r.get(0),
            )
            .optional()?;

        Ok(score.unwrap_or(0.0))
    }

    pub fn set_artist_snooze(
        &self,
        artist_id: &str,
        snoozed_until: i64,
    ) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute(
            "INSERT INTO artist_snoozes (artist_id, snoozed_until)
             VALUES (?1, ?2)
             ON CONFLICT(artist_id) DO UPDATE SET snoozed_until = excluded.snoozed_until",
            params![artist_id.trim().to_lowercase(), snoozed_until],
        )?;
        Ok(())
    }

    pub fn is_artist_snoozed(&self, artist_id: &str, now_ms: i64) -> Result<bool, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let until: Option<i64> = conn
            .query_row(
                "SELECT snoozed_until FROM artist_snoozes WHERE artist_id = ?1",
                params![artist_id.trim().to_lowercase()],
                |r| r.get(0),
            )
            .optional()?;

        match until {
            Some(u) => Ok(u > now_ms),
            None => Ok(false),
        }
    }

    pub fn get_snoozed_artists(&self, now_ms: i64) -> Result<Vec<String>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt =
            conn.prepare("SELECT artist_id FROM artist_snoozes WHERE snoozed_until > ?1")?;
        let rows = stmt.query_map(params![now_ms], |r| r.get(0))?;

        let mut artists = Vec::new();
        for a in rows {
            artists.push(a?);
        }
        Ok(artists)
    }

    pub fn remove_artist_snooze(&self, artist_id: &str) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute(
            "DELETE FROM artist_snoozes WHERE artist_id = ?1",
            params![artist_id.trim().to_lowercase()],
        )?;
        Ok(())
    }

    pub fn set_setting(&self, key: &str, value: &str) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute(
            "INSERT INTO settings (key, value) VALUES (?1, ?2)
             ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            params![key, value],
        )?;
        Ok(())
    }

    pub fn get_setting(&self, key: &str) -> Result<Option<String>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let val: Option<String> = conn
            .query_row(
                "SELECT value FROM settings WHERE key = ?1",
                params![key],
                |r| r.get(0),
            )
            .optional()?;
        Ok(val)
    }

    pub fn get_all_tracks(&self, limit: u32) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT id, source_id, title, artist, album, duration_ms, cover_url, match_confidence, is_liked, is_unavailable
             FROM tracks ORDER BY created_at DESC LIMIT ?1"
        )?;

        let rows = stmt.query_map(params![limit], |row| {
            Ok(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            })
        })?;

        let mut tracks = Vec::new();
        for r in rows {
            tracks.push(r?);
        }
        Ok(tracks)
    }

    pub fn get_tracks_by_artist(
        &self,
        artist: &str,
        limit: u32,
    ) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT id, source_id, title, artist, album, duration_ms, cover_url, match_confidence, is_liked, is_unavailable
             FROM tracks WHERE LOWER(artist) = LOWER(?1) ORDER BY created_at DESC LIMIT ?2"
        )?;

        let rows = stmt.query_map(params![artist, limit], |row| {
            Ok(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            })
        })?;

        let mut tracks = Vec::new();
        for r in rows {
            tracks.push(r?);
        }
        Ok(tracks)
    }

    pub fn get_tracks_by_album(&self, album: &str, limit: u32) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT id, source_id, title, artist, album, duration_ms, cover_url, match_confidence, is_liked, is_unavailable
             FROM tracks WHERE LOWER(album) = LOWER(?1) ORDER BY created_at DESC LIMIT ?2"
        )?;

        let rows = stmt.query_map(params![album, limit], |row| {
            Ok(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            })
        })?;

        let mut tracks = Vec::new();
        for r in rows {
            tracks.push(r?);
        }
        Ok(tracks)
    }

    pub fn get_unplayed_tracks(&self, limit: u32) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt = conn.prepare(
            "SELECT t.id, t.source_id, t.title, t.artist, t.album, t.duration_ms, t.cover_url,
                    t.match_confidence, t.is_liked, t.is_unavailable
             FROM tracks t
             LEFT JOIN play_histories ph ON t.id = ph.track_id
             WHERE ph.id IS NULL
             ORDER BY t.created_at DESC LIMIT ?1",
        )?;

        let rows = stmt.query_map(params![limit], |row| {
            Ok(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            })
        })?;

        let mut tracks = Vec::new();
        for r in rows {
            tracks.push(r?);
        }
        Ok(tracks)
    }

    // --- Recent Searches ---

    pub fn insert_recent_search(&self, query: &str) -> Result<(), SoftifyError> {
        let trimmed = query.trim();
        if trimmed.is_empty() {
            return Ok(());
        }
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;

        // Incognito check: if learning is paused, do not record recent searches
        let is_paused: Result<String, rusqlite::Error> = conn.query_row(
            "SELECT value FROM settings WHERE key = 'learning_paused'",
            [],
            |r| r.get(0),
        );
        if let Ok(val) = is_paused {
            if val == "true" {
                return Ok(());
            }
        }

        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        conn.execute(
            "INSERT INTO recent_searches (query, searched_at)
             VALUES (?1, ?2)
             ON CONFLICT(query) DO UPDATE SET searched_at = excluded.searched_at",
            params![trimmed, now],
        )?;
        Ok(())
    }

    pub fn get_recent_searches(&self, limit: u32) -> Result<Vec<String>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let mut stmt =
            conn.prepare("SELECT query FROM recent_searches ORDER BY searched_at DESC LIMIT ?1")?;
        let rows = stmt.query_map(params![limit as i64], |row| row.get(0))?;
        let mut results = Vec::new();
        for r in rows {
            results.push(r?);
        }
        Ok(results)
    }

    pub fn delete_recent_search(&self, query: &str) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute(
            "DELETE FROM recent_searches WHERE query = ?1",
            params![query.trim()],
        )?;
        Ok(())
    }

    pub fn clear_recent_searches(&self) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        conn.execute("DELETE FROM recent_searches", [])?;
        Ok(())
    }

    // --- Smart Playlists ---

    /// On Repeat Smart Playlist:
    /// Returns tracks played >= 1 time in the past 14 days (now_ms - 14 * 86_400_000),
    /// ordered by play count descending, with ties broken by most recent play time.
    pub fn get_on_repeat_tracks(
        &self,
        now_ms: u64,
        limit: u32,
    ) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let now_sec = (now_ms / 1000) as i64;
        let cutoff_sec = now_sec - (14 * 86_400);

        let mut stmt = conn.prepare(
            "SELECT t.id, t.source_id, t.title, t.artist, t.album, t.duration_ms, t.cover_url, t.match_confidence, t.is_liked, t.is_unavailable,
                    COUNT(ph.id) AS play_count, MAX(ph.played_at) AS last_played
             FROM play_histories ph
             JOIN tracks t ON ph.track_id = t.id
             WHERE ph.played_at >= ?1
             GROUP BY t.id
             ORDER BY play_count DESC, last_played DESC
             LIMIT ?2"
        )?;

        let rows = stmt.query_map(params![cutoff_sec, limit as i64], |row| {
            Ok(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            })
        })?;

        let mut tracks = Vec::new();
        for r in rows {
            tracks.push(r?);
        }
        Ok(tracks)
    }

    /// Most Played Smart Playlist:
    /// Returns tracks played in the past 30 days (now_ms - 30 * 86_400_000),
    /// ordered by total play count descending, with ties broken by most recent play time.
    pub fn get_most_played_tracks(
        &self,
        now_ms: u64,
        limit: u32,
    ) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let now_sec = (now_ms / 1000) as i64;
        let cutoff_sec = now_sec - (30 * 86_400);

        let mut stmt = conn.prepare(
            "SELECT t.id, t.source_id, t.title, t.artist, t.album, t.duration_ms, t.cover_url, t.match_confidence, t.is_liked, t.is_unavailable,
                    COUNT(ph.id) AS play_count, MAX(ph.played_at) AS last_played
             FROM play_histories ph
             JOIN tracks t ON ph.track_id = t.id
             WHERE ph.played_at >= ?1
             GROUP BY t.id
             ORDER BY play_count DESC, last_played DESC
             LIMIT ?2"
        )?;

        let rows = stmt.query_map(params![cutoff_sec, limit as i64], |row| {
            Ok(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            })
        })?;

        let mut tracks = Vec::new();
        for r in rows {
            tracks.push(r?);
        }
        Ok(tracks)
    }

    /// Forgotten Favorites Smart Playlist:
    /// Returns liked tracks (`is_liked = 1`) that have not been played in the past 60 days
    /// (or have never been played at all), ordered by creation date descending.
    pub fn get_forgotten_favorites_tracks(
        &self,
        now_ms: u64,
        limit: u32,
    ) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let now_sec = (now_ms / 1000) as i64;
        let cutoff_sec = now_sec - (60 * 86_400);

        let mut stmt = conn.prepare(
            "SELECT t.id, t.source_id, t.title, t.artist, t.album, t.duration_ms, t.cover_url, t.match_confidence, t.is_liked, t.is_unavailable
             FROM tracks t
             WHERE t.is_liked = 1
               AND t.id NOT IN (
                   SELECT ph.track_id
                   FROM play_histories ph
                   WHERE ph.played_at >= ?1
               )
             ORDER BY t.created_at DESC
             LIMIT ?2"
        )?;

        let rows = stmt.query_map(params![cutoff_sec, limit as i64], |row| {
            Ok(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            })
        })?;

        let mut tracks = Vec::new();
        for r in rows {
            tracks.push(r?);
        }
        Ok(tracks)
    }

    // --- Playlist Rename ---

    pub fn rename_playlist(&self, playlist_id: &str, new_name: &str) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let rows_affected = conn.execute(
            "UPDATE playlists SET name = ?1 WHERE id = ?2",
            params![new_name.trim(), playlist_id],
        )?;
        if rows_affected == 0 {
            return Err(SoftifyError::NotFound {
                reason: format!("Playlist {} not found", playlist_id),
            });
        }
        Ok(())
    }

    // --- Home Explore Cache ---

    pub fn cache_home_explore(&self, json_payload: &str) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);

        conn.execute(
            "INSERT INTO home_explore_cache (id, json_payload, cached_at)
             VALUES ('primary_explore', ?1, ?2)
             ON CONFLICT(id) DO UPDATE SET json_payload = excluded.json_payload, cached_at = excluded.cached_at",
            params![json_payload, now],
        )?;
        Ok(())
    }

    pub fn get_cached_home_explore(&self) -> Result<Option<String>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database {
            reason: e.to_string(),
        })?;
        let res: Result<String, rusqlite::Error> = conn.query_row(
            "SELECT json_payload FROM home_explore_cache WHERE id = 'primary_explore'",
            [],
            |r| r.get(0),
        );
        match res {
            Ok(json) => Ok(Some(json)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(SoftifyError::from(e)),
        }
    }
}

use rusqlite::OptionalExtension;
