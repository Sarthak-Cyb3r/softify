use rusqlite::Connection;
use crate::models::SoftifyError;

pub fn run_migrations(conn: &Connection) -> Result<(), SoftifyError> {
    conn.execute_batch(
        "
        PRAGMA foreign_keys = ON;

        -- 1. Tracks Table
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

        -- 2. Playlists Table
        CREATE TABLE IF NOT EXISTS playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            is_imported INTEGER NOT NULL DEFAULT 0,
            source_url TEXT,
            created_at INTEGER NOT NULL
        );

        -- 3. Playlist Tracks Table
        CREATE TABLE IF NOT EXISTS playlist_tracks (
            playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
            position INTEGER NOT NULL,
            track_id TEXT REFERENCES tracks(id) ON DELETE SET NULL,
            original_title TEXT NOT NULL,
            original_artist TEXT NOT NULL,
            match_status TEXT NOT NULL,
            PRIMARY KEY (playlist_id, position)
        );

        -- 4. Play History Table
        CREATE TABLE IF NOT EXISTS play_histories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
            played_at INTEGER NOT NULL,
            completed_ratio REAL NOT NULL
        );

        -- 5. Downloads Table
        CREATE TABLE IF NOT EXISTS downloads (
            track_id TEXT PRIMARY KEY REFERENCES tracks(id) ON DELETE CASCADE,
            relative_path TEXT NOT NULL,
            container_format TEXT NOT NULL DEFAULT 'm4a',
            file_size_bytes INTEGER NOT NULL DEFAULT 0,
            bytes_downloaded INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            bitrate_kbps INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
        );

        -- 6. Cached Lyrics Table
        CREATE TABLE IF NOT EXISTS cached_lyrics (
            track_id TEXT PRIMARY KEY REFERENCES tracks(id) ON DELETE CASCADE,
            synced_lrc TEXT,
            plain_text TEXT,
            is_not_found INTEGER NOT NULL DEFAULT 0,
            cached_at INTEGER NOT NULL
        );

        -- 7. App Settings Table
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        -- Indices
        CREATE INDEX IF NOT EXISTS idx_tracks_source_id ON tracks(source_id);
        CREATE INDEX IF NOT EXISTS idx_tracks_is_liked ON tracks(is_liked);
        CREATE INDEX IF NOT EXISTS idx_playlist_tracks_track ON playlist_tracks(track_id);
        CREATE INDEX IF NOT EXISTS idx_play_histories_track ON play_histories(track_id);
        CREATE INDEX IF NOT EXISTS idx_play_histories_played_at ON play_histories(played_at DESC);

        -- 8. FTS5 Virtual Table for Instant Search
        CREATE VIRTUAL TABLE IF NOT EXISTS tracks_fts USING fts5(
            track_id UNINDEXED,
            title,
            artist,
            album,
            tokenize = 'unicode61 remove_diacritics 2'
        );

        -- Triggers to synchronize FTS5 index automatically with tracks table
        CREATE TRIGGER IF NOT EXISTS trg_tracks_insert AFTER INSERT ON tracks BEGIN
            INSERT INTO tracks_fts(track_id, title, artist, album)
            VALUES (new.id, new.title, new.artist, coalesce(new.album, ''));
        END;

        CREATE TRIGGER IF NOT EXISTS trg_tracks_update AFTER UPDATE ON tracks BEGIN
            DELETE FROM tracks_fts WHERE track_id = old.id;
            INSERT INTO tracks_fts(track_id, title, artist, album)
            VALUES (new.id, new.title, new.artist, coalesce(new.album, ''));
        END;

        CREATE TRIGGER IF NOT EXISTS trg_tracks_delete AFTER DELETE ON tracks BEGIN
            DELETE FROM tracks_fts WHERE track_id = old.id;
        END;
        "
    )?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_migrations_and_fts5_triggers() {
        let conn = Connection::open_in_memory().expect("open in memory db");
        run_migrations(&conn).expect("migrations run cleanly");

        // Insert track
        conn.execute(
            "INSERT INTO tracks (id, source_id, title, artist, album, duration_ms, cover_url, match_confidence, is_liked, is_unavailable, created_at)
             VALUES ('t1', 's1', 'Kesariya', 'Arijit Singh', 'Brahmastra', 268000, NULL, 1.0, 0, 0, 1000)",
            [],
        ).unwrap();

        // Verify FTS5 index populated via trigger
        let count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM tracks_fts WHERE tracks_fts MATCH '\"arij\"*'",
            [],
            |r| r.get(0),
        ).unwrap();
        assert_eq!(count, 1);

        // Update track
        conn.execute(
            "UPDATE tracks SET title = 'Tum Hi Ho', album = 'Aashiqui 2' WHERE id = 't1'",
            [],
        ).unwrap();

        // Old title should not match, new title should match
        let count_old: i64 = conn.query_row(
            "SELECT COUNT(*) FROM tracks_fts WHERE tracks_fts MATCH '\"kesariya\"*'",
            [],
            |r| r.get(0),
        ).unwrap();
        assert_eq!(count_old, 0);

        let count_new: i64 = conn.query_row(
            "SELECT COUNT(*) FROM tracks_fts WHERE tracks_fts MATCH '\"tum\"*'",
            [],
            |r| r.get(0),
        ).unwrap();
        assert_eq!(count_new, 1);

        // Delete track
        conn.execute("DELETE FROM tracks WHERE id = 't1'", []).unwrap();
        let count_deleted: i64 = conn.query_row(
            "SELECT COUNT(*) FROM tracks_fts WHERE tracks_fts MATCH '\"tum\"*'",
            [],
            |r| r.get(0),
        ).unwrap();
        assert_eq!(count_deleted, 0);
    }
}
