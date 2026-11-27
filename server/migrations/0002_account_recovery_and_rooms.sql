-- Softify D1 Migration 0002: Multi-device account linkage & budget quota counters

ALTER TABLE devices ADD COLUMN account_id TEXT;

UPDATE devices SET account_id = id WHERE account_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_devices_account_id ON devices(account_id);
CREATE INDEX IF NOT EXISTS idx_devices_recovery_hash ON devices(recovery_hash);

ALTER TABLE daily_budget_stats ADD COLUMN kv_write_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE daily_budget_stats ADD COLUMN do_request_count INTEGER NOT NULL DEFAULT 0;
