-- Softify D1 Initial Schema (Migration 0001)

CREATE TABLE IF NOT EXISTS devices (
    id TEXT PRIMARY KEY,
    device_id_hash TEXT NOT NULL UNIQUE,
    recovery_hash TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    last_active_at INTEGER NOT NULL,
    revoked_at INTEGER DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON sessions(token_hash);

CREATE TABLE IF NOT EXISTS library_sync (
    id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL,
    item_id TEXT NOT NULL,
    payload TEXT NOT NULL,
    hlc_timestamp TEXT NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    version INTEGER NOT NULL DEFAULT 1,
    updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_library_device_updated ON library_sync(device_id, updated_at);

CREATE TABLE IF NOT EXISTS lyrics_cache (
    id TEXT PRIMARY KEY,
    track_id TEXT NOT NULL,
    provider TEXT NOT NULL,
    raw_payload TEXT NOT NULL,
    format TEXT NOT NULL,
    http_status INTEGER NOT NULL DEFAULT 200,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lyrics_track ON lyrics_cache(track_id);

CREATE TABLE IF NOT EXISTS daily_budget_stats (
    date TEXT PRIMARY KEY,
    request_count INTEGER NOT NULL DEFAULT 0,
    d1_read_count INTEGER NOT NULL DEFAULT 0,
    d1_write_count INTEGER NOT NULL DEFAULT 0,
    telemetry_shed_count INTEGER NOT NULL DEFAULT 0,
    updated_at INTEGER NOT NULL
);
