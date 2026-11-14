use std::sync::{Arc, Mutex};
use rusqlite::{params, Connection};
use crate::models::{Playlist, PlayHistory, SoftifyError, Track};
use super::migrations::run_migrations;

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
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
        run_migrations(&conn)?;
        Ok(())
    }

    pub fn insert_or_update_track(&self, track: &Track) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
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
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
        let mut stmt = conn.prepare(
            "SELECT id, source_id, title, artist, album, duration_ms, cover_url, match_confidence, is_liked, is_unavailable
             FROM tracks WHERE id = ?1"
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
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
        let current_state: Option<i64> = conn.query_row(
            "SELECT is_liked FROM tracks WHERE id = ?1",
            params![track_id],
            |r| r.get(0),
        ).optional()?;

        let new_state = match current_state {
            Some(s) => if s == 0 { 1 } else { 0 },
            None => return Err(SoftifyError::NotFound { reason: format!("Track {} not in database", track_id) }),
        };

        conn.execute(
            "UPDATE tracks SET is_liked = ?1 WHERE id = ?2",
            params![new_state, track_id],
        )?;

        Ok(new_state != 0)
    }

    pub fn get_liked_tracks(&self) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
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

    pub fn create_playlist(&self, name: &str, description: Option<&str>) -> Result<Playlist, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
        let id = format!("pl_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
        let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs() as i64;

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
        })
    }

    pub fn delete_playlist(&self, playlist_id: &str) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
        conn.execute("DELETE FROM playlists WHERE id = ?1", params![playlist_id])?;
        Ok(())
    }

    pub fn get_playlists(&self) -> Result<Vec<Playlist>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
        let mut stmt = conn.prepare(
            "SELECT p.id, p.name, p.description, p.is_imported, p.source_url, p.created_at,
                    COUNT(pt.track_id) as track_count
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
            })
        })?;

        let mut playlists = Vec::new();
        for r in rows {
            playlists.push(r?);
        }
        Ok(playlists)
    }

    pub fn add_to_playlist(&self, playlist_id: &str, track_id: &str) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
        
        let track_info: (String, String) = conn.query_row(
            "SELECT title, artist FROM tracks WHERE id = ?1",
            params![track_id],
            |r| Ok((r.get(0)?, r.get(1)?)),
        ).optional()?
        .ok_or_else(|| SoftifyError::NotFound { reason: format!("Track {} not found", track_id) })?;

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

    pub fn remove_from_playlist(&self, playlist_id: &str, track_id: &str) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
        conn.execute(
            "DELETE FROM playlist_tracks WHERE playlist_id = ?1 AND track_id = ?2",
            params![playlist_id, track_id],
        )?;
        Ok(())
    }

    pub fn get_playlist_tracks(&self, playlist_id: &str) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
        let mut stmt = conn.prepare(
            "SELECT t.id, t.source_id, t.title, t.artist, t.album, t.duration_ms, t.cover_url,
                    t.match_confidence, t.is_liked, t.is_unavailable
             FROM playlist_tracks pt
             JOIN tracks t ON pt.track_id = t.id
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

    pub fn record_play_history(&self, track_id: &str, completed_ratio: f64) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
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
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
        let mut stmt = conn.prepare(
            "SELECT ph.id, ph.played_at, ph.completed_ratio,
                    t.id, t.source_id, t.title, t.artist, t.album, t.duration_ms, t.cover_url,
                    t.match_confidence, t.is_liked, t.is_unavailable
             FROM play_histories ph
             JOIN tracks t ON ph.track_id = t.id
             ORDER BY ph.played_at DESC
             LIMIT ?1"
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
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
        conn.execute("DELETE FROM play_histories", [])?;
        Ok(())
    }

    /// Full-Text Search in local tracks using FTS5 virtual table
    pub fn search_local_tracks_fts(&self, fts_query: &str, limit: u32) -> Result<Vec<Track>, SoftifyError> {
        let conn = self.conn.lock().map_err(|e| SoftifyError::Database { reason: e.to_string() })?;
        let mut stmt = conn.prepare(
            "SELECT t.id, t.source_id, t.title, t.artist, t.album, t.duration_ms, t.cover_url,
                    t.match_confidence, t.is_liked, t.is_unavailable
             FROM tracks_fts fts
             JOIN tracks t ON fts.track_id = t.id
             WHERE tracks_fts MATCH ?1
             ORDER BY rank
             LIMIT ?2"
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
}

use rusqlite::OptionalExtension;
