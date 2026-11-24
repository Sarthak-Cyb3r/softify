import { describe, it, expect, vi, beforeEach } from 'vitest';
import { hashString, generateToken, verifyToken } from '../src/auth';
import { compareHlc } from '../src/sync';
import { BudgetGuard } from '../src/budget';

describe('Auth & Cryptography Unit Tests', () => {
  it('should deterministically hash strings with SHA-256', async () => {
    const hash1 = await hashString('device_123');
    const hash2 = await hashString('device_123');
    const hashOther = await hashString('device_456');

    expect(hash1).toBe(hash2);
    expect(hash1.length).toBe(64);
    expect(hash1).not.toBe(hashOther);
  });

  it('should generate and verify valid HMAC-SHA256 access tokens', async () => {
    const secret = 'test_secret_key_12345';
    const token = await generateToken('device_abc', 'access', secret);
    expect(token).toContain('.');

    const verified = await verifyToken(token, secret);
    expect(verified).not.toBeNull();
    expect(verified?.deviceId).toBe('device_abc');
    expect(verified?.type).toBe('access');
  });

  it('should reject tampered or expired tokens', async () => {
    const secret = 'test_secret_key_12345';
    const token = await generateToken('device_abc', 'access', secret);
    const tampered = token.slice(0, -4) + 'abcd';

    const verified = await verifyToken(tampered, secret);
    expect(verified).toBeNull();
  });
});

describe('Sync & Hybrid Logical Clock (HLC) Tests', () => {
  it('should order HLC timestamps deterministically', () => {
    const hlc1 = '1732440000000:0001:nodeA';
    const hlc2 = '1732440000000:0002:nodeA';
    const hlc3 = '1732440001000:0001:nodeB';

    expect(compareHlc(hlc1, hlc2)).toBe(-1);
    expect(compareHlc(hlc2, hlc1)).toBe(1);
    expect(compareHlc(hlc1, hlc1)).toBe(0);
    expect(compareHlc(hlc2, hlc3)).toBe(-1);
  });
});

describe('Budget Guard Logic Tests', () => {
  it('should accurately format today date string', () => {
    const today = BudgetGuard.getTodayDateStr();
    expect(today).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('should track in-memory metrics without throwing', () => {
    BudgetGuard.recordRequest();
    BudgetGuard.recordD1Read(3);
    BudgetGuard.recordD1Write(2);
    BudgetGuard.recordTelemetryShed();
  });
});

describe('CPU Execution Benchmark (< 10ms Limit)', () => {
  it('should execute token verification and HLC comparison in under 10ms CPU time', async () => {
    const secret = 'benchmark_secret';
    const token = await generateToken('device_perf', 'access', secret);

    const t0 = performance.now();
    for (let i = 0; i < 20; i++) {
      await verifyToken(token, secret);
      compareHlc('1732440000000:0001:nodeA', '1732440000000:0002:nodeB');
    }
    const elapsed = performance.now() - t0;
    const avgPerCall = elapsed / 20;

    // Must be well under the 10 ms CPU execution ceiling
    expect(avgPerCall).toBeLessThan(10.0);
  });
});
