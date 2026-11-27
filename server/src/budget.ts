import { Env, BudgetTier } from './types';

let inMemoryRequests = 0;
let inMemoryReads = 0;
let inMemoryWrites = 0;
let inMemoryKvWrites = 0;
let inMemoryDoRequests = 0;
let inMemoryShed = 0;
let lastFlushMs = 0;

export const FREE_QUOTAS = {
  WORKER_REQUESTS_DAILY: 100_000,
  D1_ROWS_READ_DAILY: 5_000_000,
  D1_ROWS_WRITTEN_DAILY: 100_000,
  KV_WRITES_DAILY: 1_000,
  DO_REQUESTS_DAILY: 100_000
} as const;

export const DEVICE_QUOTAS = {
  MAX_REQUESTS_PER_MINUTE: 60,
  MAX_SYNC_BATCHES_PER_DAY: 50
} as const;

export interface BudgetSnapshot {
  workerRequests: number;
  d1RowsRead: number;
  d1RowsWritten: number;
  kvWrites: number;
  doRequests: number;
}

const deviceMinuteBuckets = new Map<string, { windowStartMs: number; count: number }>();
const deviceDailySyncBatches = new Map<string, { dateStr: string; count: number }>();

export function computeTierFromSnapshot(snapshot: BudgetSnapshot): BudgetTier {
  const maxRatio = Math.max(
    snapshot.workerRequests / FREE_QUOTAS.WORKER_REQUESTS_DAILY,
    snapshot.d1RowsRead / FREE_QUOTAS.D1_ROWS_READ_DAILY,
    snapshot.d1RowsWritten / FREE_QUOTAS.D1_ROWS_WRITTEN_DAILY,
    snapshot.kvWrites / FREE_QUOTAS.KV_WRITES_DAILY,
    snapshot.doRequests / FREE_QUOTAS.DO_REQUESTS_DAILY
  );

  if (maxRatio >= 0.9) return 'TIER_3_SHED_WRITE';
  if (maxRatio >= 0.8) return 'TIER_2_SHED_CACHE_REFRESH';
  if (maxRatio >= 0.7) return 'TIER_1_SHED_TELEMETRY';
  return 'TIER_0_NORMAL';
}

export class BudgetGuard {
  static getTodayDateStr(): string {
    return new Date().toISOString().slice(0, 10);
  }

  static resetInMemoryForTest(): void {
    inMemoryRequests = 0;
    inMemoryReads = 0;
    inMemoryWrites = 0;
    inMemoryKvWrites = 0;
    inMemoryDoRequests = 0;
    inMemoryShed = 0;
    lastFlushMs = 0;
    deviceMinuteBuckets.clear();
    deviceDailySyncBatches.clear();
  }

  static recordRequest(): void {
    inMemoryRequests++;
  }

  static recordD1Read(count: number = 1): void {
    inMemoryReads += count;
  }

  static recordD1Write(count: number = 1): void {
    inMemoryWrites += count;
  }

  static recordKvWrite(count: number = 1): void {
    inMemoryKvWrites += count;
  }

  static recordDoRequest(count: number = 1): void {
    inMemoryDoRequests += count;
  }

  static recordTelemetryShed(): void {
    inMemoryShed++;
  }

  static checkAndRecordDeviceRequest(deviceId: string, nowMs: number = Date.now()): { allowed: boolean; retryAfterSec: number } {
    const existing = deviceMinuteBuckets.get(deviceId);
    if (!existing || nowMs - existing.windowStartMs >= 60_000) {
      deviceMinuteBuckets.set(deviceId, { windowStartMs: nowMs, count: 1 });
      return { allowed: true, retryAfterSec: 0 };
    }
    if (existing.count >= DEVICE_QUOTAS.MAX_REQUESTS_PER_MINUTE) {
      const remainingSec = Math.max(1, Math.ceil((60_000 - (nowMs - existing.windowStartMs)) / 1000));
      return { allowed: false, retryAfterSec: remainingSec };
    }
    existing.count++;
    return { allowed: true, retryAfterSec: 0 };
  }

  static checkAndRecordDeviceSyncBatch(deviceId: string, today: string = this.getTodayDateStr()): { allowed: boolean; retryAfterSec: number } {
    const existing = deviceDailySyncBatches.get(deviceId);
    if (!existing || existing.dateStr !== today) {
      deviceDailySyncBatches.set(deviceId, { dateStr: today, count: 1 });
      return { allowed: true, retryAfterSec: 0 };
    }
    if (existing.count >= DEVICE_QUOTAS.MAX_SYNC_BATCHES_PER_DAY) {
      return { allowed: false, retryAfterSec: 3600 };
    }
    existing.count++;
    return { allowed: true, retryAfterSec: 0 };
  }

  static async getBudgetTier(env: Env): Promise<BudgetTier> {
    const now = Date.now();
    if (now - lastFlushMs > 60_000 && (inMemoryRequests > 10 || inMemoryWrites > 5)) {
      await this.flushStats(env).catch(() => {});
    }

    try {
      const today = this.getTodayDateStr();
      const row = await env.DB.prepare(
        'SELECT request_count, d1_read_count, d1_write_count, kv_write_count, do_request_count FROM daily_budget_stats WHERE date = ?'
      ).bind(today).first<{
        request_count: number;
        d1_read_count: number;
        d1_write_count: number;
        kv_write_count?: number;
        do_request_count?: number;
      }>();

      return computeTierFromSnapshot({
        workerRequests: (row?.request_count ?? 0) + inMemoryRequests,
        d1RowsRead: (row?.d1_read_count ?? 0) + inMemoryReads,
        d1RowsWritten: (row?.d1_write_count ?? 0) + inMemoryWrites,
        kvWrites: (row?.kv_write_count ?? 0) + inMemoryKvWrites,
        doRequests: (row?.do_request_count ?? 0) + inMemoryDoRequests
      });
    } catch {
      return 'TIER_0_NORMAL';
    }
  }

  static async flushStats(env: Env): Promise<void> {
    if (
      inMemoryRequests === 0 &&
      inMemoryReads === 0 &&
      inMemoryWrites === 0 &&
      inMemoryKvWrites === 0 &&
      inMemoryDoRequests === 0 &&
      inMemoryShed === 0
    ) {
      return;
    }

    const today = this.getTodayDateStr();
    const reqs = inMemoryRequests;
    const reads = inMemoryReads;
    const writes = inMemoryWrites;
    const kvWrites = inMemoryKvWrites;
    const doReqs = inMemoryDoRequests;
    const shed = inMemoryShed;

    inMemoryRequests = 0;
    inMemoryReads = 0;
    inMemoryWrites = 0;
    inMemoryKvWrites = 0;
    inMemoryDoRequests = 0;
    inMemoryShed = 0;
    lastFlushMs = Date.now();

    await env.DB.prepare(`
      INSERT INTO daily_budget_stats (date, request_count, d1_read_count, d1_write_count, kv_write_count, do_request_count, telemetry_shed_count, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(date) DO UPDATE SET
        request_count = request_count + excluded.request_count,
        d1_read_count = d1_read_count + excluded.d1_read_count,
        d1_write_count = d1_write_count + excluded.d1_write_count,
        kv_write_count = kv_write_count + excluded.kv_write_count,
        do_request_count = do_request_count + excluded.do_request_count,
        telemetry_shed_count = telemetry_shed_count + excluded.telemetry_shed_count,
        updated_at = excluded.updated_at
    `).bind(today, reqs, reads, writes, kvWrites, doReqs, shed, Date.now()).run();
  }
}
