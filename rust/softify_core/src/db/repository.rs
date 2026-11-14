use std::sync::{Arc, Mutex};
use rusqlite::{params, Connection};
use crate::models::{SoftifyError, Track};

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

    #[cfg(test)]
    pub fn in_memory() -> Result<Self, SoftifyError> {
        let conn = Connection::open_in_memory()?;
        let repo = Self {
            conn: Arc::new(Mutex::new(conn)),
        };
        repo.init_tables()?;
        Ok(repo)
    }

    pub fn init_tables(&self) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().unwrap();
        conn.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS tracks (
                id TEXT PRIMARY KEY,
                source_id TEXT UNIQUE NOT NULL,
                title TEXT NOT NULL,
                artist TEXT NOT NULL,
                album TEXT,
                duration_ms INTEGER NOT NULL,
                cover_url TEXT,
                match_confidence REAL,
                is_liked INTEGER NOT NULL DEFAULT 0,
                is_unavailable INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS play_histories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
                played_at INTEGER NOT NULL,
                completed_ratio REAL NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_tracks_source_id ON tracks(source_id);
            CREATE INDEX IF NOT EXISTS idx_play_histories_track ON play_histories(track_id);
            "
        )?;
        Ok(())
    }

    pub fn insert_or_update_track(&self, track: &Track) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().unwrap();
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
        let conn = self.conn.lock().unwrap();
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

    pub fn record_play_history(&self, track_id: &str, completed_ratio: f64) -> Result<(), SoftifyError> {
        let conn = self.conn.lock().unwrap();
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
}
