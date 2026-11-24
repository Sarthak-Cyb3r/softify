import { Env, BudgetTier } from './types';

// In-memory counters per Worker isolate (ephemeral, flushed on interval or cron)
let inMemoryRequests = 0;
let inMemoryReads = 0;
let inMemoryWrites = 0;
let inMemoryShed = 0;
let lastFlushMs = 0;

const MAX_DAILY_REQUESTS = 100_000;
const MAX_DAILY_WRITES = 100_000;

export class BudgetGuard {
  static getTodayDateStr(): string {
    return new Date().toISOString().slice(0, 10);
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

  static recordTelemetryShed(): void {
    inMemoryShed++;
  }

  static async getBudgetTier(env: Env): Promise<BudgetTier> {
    // Check if we need to flush in-memory counts to D1
    const now = Date.now();
    if (now - lastFlushMs > 60_000 && (inMemoryRequests > 10 || inMemoryWrites > 5)) {
      await this.flushStats(env).catch(() => {});
    }

    // Query today's aggregate consumption from D1 with fallback to memory
    try {
      const today = this.getTodayDateStr();
      const row = await env.DB.prepare(
        'SELECT request_count, d1_write_count FROM daily_budget_stats WHERE date = ?'
      ).bind(today).first<{ request_count: number; d1_write_count: number }>();

      const totalReqs = (row?.request_count ?? 0) + inMemoryRequests;
      const totalWrites = (row?.d1_write_count ?? 0) + inMemoryWrites;

      const reqRatio = totalReqs / MAX_DAILY_REQUESTS;
      const writeRatio = totalWrites / MAX_DAILY_WRITES;
      const maxRatio = Math.max(reqRatio, writeRatio);

      if (maxRatio >= 0.9) {
        return 'TIER_2_SHED_WRITE';
      } else if (maxRatio >= 0.7) {
        return 'TIER_1_SHED_TELEMETRY';
      }
      return 'TIER_0_NORMAL';
    } catch {
      return 'TIER_0_NORMAL';
    }
  }

  static async flushStats(env: Env): Promise<void> {
    if (inMemoryRequests === 0 && inMemoryWrites === 0 && inMemoryShed === 0) return;

    const today = this.getTodayDateStr();
    const reqs = inMemoryRequests;
    const reads = inMemoryReads;
    const writes = inMemoryWrites;
    const shed = inMemoryShed;

    inMemoryRequests = 0;
    inMemoryReads = 0;
    inMemoryWrites = 0;
    inMemoryShed = 0;
    lastFlushMs = Date.now();

    await env.DB.prepare(`
      INSERT INTO daily_budget_stats (date, request_count, d1_read_count, d1_write_count, telemetry_shed_count, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(date) DO UPDATE SET
        request_count = request_count + excluded.request_count,
        d1_read_count = d1_read_count + excluded.d1_read_count,
        d1_write_count = d1_write_count + excluded.d1_write_count,
        telemetry_shed_count = telemetry_shed_count + excluded.telemetry_shed_count,
        updated_at = excluded.updated_at
    `).bind(today, reqs, reads, writes, shed, Date.now()).run();
  }
}
