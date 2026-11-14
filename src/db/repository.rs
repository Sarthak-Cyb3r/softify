use rusqlite::{Connection, Result};
use std::path::PathBuf;
use crate::models::Track;

pub struct Database {
    db_path: PathBuf,
}

impl Database {
    pub fn new() -> Self {
        let mut path = dirs::document_dir().unwrap_or_else(|| PathBuf::from("."));
        path.push("softify.sqlite");
        if !path.exists() {
            let local_path = PathBuf::from("softify.sqlite");
            if local_path.exists() {
                path = local_path;
            }
        }
        Self { db_path: path }
    }

    fn connect(&self) -> Result<Connection> {
        Connection::open(&self.db_path)
    }

    pub fn get_all_tracks(&self) -> Result<Vec<Track>> {
        let conn = self.connect()?;
        let mut stmt = conn.prepare(
            "SELECT id, source_id, title, artist, album, duration_ms, cover_url, match_confidence, is_liked, is_unavailable 
             FROM tracks ORDER BY id DESC LIMIT 500"
        )?;

        let track_iter = stmt.query_map([], |row| {
            Ok(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get(5)?,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            })
        })?;

        let mut tracks = Vec::new();
        for track in track_iter {
            if let Ok(t) = track {
                tracks.push(t);
            }
        }
        Ok(tracks)
    }

    pub fn get_liked_tracks(&self) -> Result<Vec<Track>> {
        let conn = self.connect()?;
        let mut stmt = conn.prepare(
            "SELECT id, source_id, title, artist, album, duration_ms, cover_url, match_confidence, is_liked, is_unavailable 
             FROM tracks WHERE is_liked = 1 ORDER BY id DESC LIMIT 500"
        )?;

        let track_iter = stmt.query_map([], |row| {
            Ok(Track {
                id: row.get(0)?,
                source_id: row.get(1)?,
                title: row.get(2)?,
                artist: row.get(3)?,
                album: row.get(4)?,
                duration_ms: row.get(5)?,
                cover_url: row.get(6)?,
                match_confidence: row.get(7)?,
                is_liked: row.get::<_, i64>(8)? != 0,
                is_unavailable: row.get::<_, i64>(9)? != 0,
            })
        })?;

        let mut tracks = Vec::new();
        for track in track_iter {
            if let Ok(t) = track {
                tracks.push(t);
            }
        }
        Ok(tracks)
    }
}
