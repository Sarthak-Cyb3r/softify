import { Env, DeviceContext, SyncBatchRequest, SyncBatchResponse, SyncItem } from './types';
import { BudgetGuard } from './budget';

export function compareHlc(hlcA: string, hlcB: string): number {
  if (hlcA === hlcB) return 0;
  return hlcA > hlcB ? 1 : -1;
}

export async function handleSyncBatch(
  device: DeviceContext,
  body: SyncBatchRequest,
  env: Env
): Promise<{ status: number; data?: SyncBatchResponse; error?: string; retryAfterSec?: number }> {
  const tier = await BudgetGuard.getBudgetTier(env);
  const incoming = body.items || [];

  if (incoming.length > 0 && tier === 'TIER_3_SHED_WRITE') {
    return {
      status: 429,
      error: 'Write budget exhausted for today. Please retry later.',
      retryAfterSec: 3600
    };
  }

  if (incoming.length > 0) {
    const quota = BudgetGuard.checkAndRecordDeviceSyncBatch(device.accountId);
    if (!quota.allowed) {
      return {
        status: 429,
        error: 'Per-device daily sync batch limit reached.',
        retryAfterSec: quota.retryAfterSec
      };
    }
  }

  const now = Date.now();
  const batch = incoming.slice(0, 50);

  if (batch.length > 0) {
    for (const item of batch) {
      const syncId = `${device.accountId}:${item.type}:${item.id}`;
      const isDel = item.deleted ? 1 : 0;
      const ver = item.version || 1;

      BudgetGuard.recordD1Read(1);
      const existing = await env.DB.prepare(
        'SELECT hlc_timestamp FROM library_sync WHERE id = ?'
      ).bind(syncId).first<{ hlc_timestamp: string }>();

      if (!existing || compareHlc(item.hlc, existing.hlc_timestamp) > 0) {
        BudgetGuard.recordD1Write(1);
        await env.DB.prepare(`
          INSERT INTO library_sync (id, device_id, item_type, item_id, payload, hlc_timestamp, is_deleted, version, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            payload = excluded.payload,
            hlc_timestamp = excluded.hlc_timestamp,
            is_deleted = excluded.is_deleted,
            version = excluded.version,
            updated_at = excluded.updated_at
        `).bind(syncId, device.accountId, item.type, item.id, item.payload, item.hlc, isDel, ver, now).run();
      }
    }
  }

  const clientCursor = body.cursor || 0;
  BudgetGuard.recordD1Read(1);
  const rows = await env.DB.prepare(`
    SELECT item_id, item_type, payload, hlc_timestamp, is_deleted, version, updated_at
    FROM library_sync
    WHERE device_id = ? AND updated_at > ?
    ORDER BY updated_at ASC
    LIMIT 100
  `).bind(device.accountId, clientCursor).all<{
    item_id: string;
    item_type: 'playlist' | 'track_like' | 'history_aggregate' | 'setting';
    payload: string;
    hlc_timestamp: string;
    is_deleted: number;
    version: number;
    updated_at: number;
  }>();

  const remoteItems: SyncItem[] = (rows.results || []).map((r) => ({
    id: r.item_id,
    type: r.item_type,
    payload: r.payload,
    hlc: r.hlc_timestamp,
    deleted: r.is_deleted === 1,
    version: r.version
  }));

  const nextCursor = rows.results && rows.results.length > 0
    ? rows.results[rows.results.length - 1].updated_at
    : Math.max(clientCursor, now);

  return {
    status: 200,
    data: {
      cursor: nextCursor,
      items: remoteItems,
      budgetTier: tier,
      serverHlc: `${now}-0000-edge`
    }
  };
}
