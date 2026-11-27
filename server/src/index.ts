import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { z } from 'zod';
import {
  Env,
  AnonymousAuthRequest,
  SyncBatchRequest,
  TelemetryReport
} from './types';
import { BudgetGuard } from './budget';
import {
  handleAnonymousAuth,
  handleRefreshToken,
  handleRecoverAccount,
  authenticateRequest
} from './auth';
import { handleSyncBatch } from './sync';
import { handleGetLyrics } from './lyrics';
import { handleGetCharts } from './charts';
import { handleTelemetry } from './telemetry';
import { handleUserExport, handleUserDelete } from './user';
import { ListenTogetherRoom } from './room';

export { ListenTogetherRoom };

const MAX_BODY_BYTES = 262_144; // 256 KB

const authSchema = z.object({
  deviceId: z.string().min(1).max(128),
  recoveryHash: z.string().min(8).max(256)
});

const refreshSchema = z.object({
  refreshToken: z.string().min(16).max(2048)
});

const syncItemSchema = z.object({
  id: z.string().min(1).max(256),
  type: z.enum(['playlist', 'track_like', 'history_aggregate', 'setting']),
  payload: z.string().max(65_536),
  hlc: z.string().min(3).max(128),
  deleted: z.boolean().optional(),
  version: z.number().int().min(1).optional()
});

const syncBatchSchema = z.object({
  cursor: z.number().int().min(0).optional(),
  items: z.array(syncItemSchema).max(100)
});

const telemetrySchema = z.object({
  appVersion: z.string().min(1).max(64),
  osVersion: z.string().min(1).max(64),
  abi: z.string().min(1).max(64),
  errorType: z.string().min(1).max(128),
  redactedMessage: z.string().max(1024),
  stackTrace: z.string().max(8192).optional(),
  occurredAtMs: z.number().int().nonnegative()
});

const createRoomSchema = z.object({
  hostName: z.string().max(64).optional(),
  trackId: z.string().max(128).optional()
}).optional();

const app = new Hono<{ Bindings: Env }>();

// 1. Request ID tracking + global request counter
app.use('*', async (c, next) => {
  const reqId = c.req.header('x-request-id') || crypto.randomUUID();
  c.header('x-request-id', reqId);
  const path = c.req.path;
  // Static config/update/health do not count toward protected shed decisions
  if (path !== '/healthz' && path !== '/readyz' && !path.endsWith('.json')) {
    BudgetGuard.recordRequest();
  }
  await next();
});

// 2. CORS middleware
app.use('*', cors({
  origin: '*',
  allowHeaders: ['Content-Type', 'Authorization', 'x-request-id'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
}));

// 3. Strict 256 KB Body Cap (checked via Content-Length and actual byte size)
app.use('*', async (c, next) => {
  const cl = c.req.header('content-length');
  if (cl && parseInt(cl, 10) > MAX_BODY_BYTES) {
    return c.json({ error: 'Payload Too Large (max 256 KB allowed)' }, 413);
  }
  if (c.req.method === 'POST' || c.req.method === 'PUT') {
    const ab = await c.req.raw.clone().arrayBuffer();
    if (ab.byteLength > MAX_BODY_BYTES) {
      return c.json({ error: 'Payload Too Large (max 256 KB allowed)' }, 413);
    }
  }
  await next();
});

// 4. Protected Liveness & Readiness Probes (Never Shed)
app.get('/healthz', (c) => c.json({ status: 'ok', time: Date.now() }));

app.get('/readyz', async (c) => {
  try {
    await c.env.DB.prepare('SELECT 1').first();
    const tier = await BudgetGuard.getBudgetTier(c.env);
    return c.json({ ready: true, budgetTier: tier });
  } catch (err: any) {
    return c.json({ ready: false, error: err.message }, 503);
  }
});

// 5. Protected Static Fallback Routes when ASSETS binding not handled upstream
async function serveStaticOrFallback(c: any, assetPath: string, fallbackObj: unknown) {
  if (c.env.ASSETS) {
    const resp = await c.env.ASSETS.fetch(`https://softify.local${assetPath}`).catch(() => null);
    if (resp && resp.status === 200) {
      return new Response(resp.body, {
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=300, stale-while-revalidate=86400'
        }
      });
    }
  }
  return c.json(fallbackObj);
}

app.get('/config.json', (c) => serveStaticOrFallback(c, '/config.json', {
  version: 1,
  minAppVersionCode: 40000,
  features: {
    lyricsSync: true,
    cloudSync: true,
    listenTogether: true,
    downloads: true,
    audioNormalization: true,
    crossfade: true
  },
  providers: {
    betterlyrics: { enabled: true },
    lrclib: { enabled: true },
    lrcred: { enabled: true },
    kugou: { enabled: true },
    paxsenix: { enabled: false },
    unison: { enabled: true }
  },
  endpoints: {
    apiBaseUrl: 'https://softify-server.workers.dev',
    backupMirrorUrl: 'https://sarthak-cyb3r.github.io/softify-static'
  },
  updatedAt: new Date().toISOString()
}));

app.get('/update.json', (c) => serveStaticOrFallback(c, '/update.json', {
  versionCode: 40301,
  versionName: '4.3.1-experimental',
  minSupportedVersionCode: 40000,
  releaseDate: '2026-11-27',
  changelog: ['Unified OpenAPI contract and fixed seek range handling'],
  downloadUrl: 'https://github.com/Sarthak-Cyb3r/softify/releases/latest',
  sha256: '0000000000000000000000000000000000000000000000000000000000000000',
  fileSizeBytes: 0
}));

app.get('/home_shelves.json', (c) => serveStaticOrFallback(c, '/home_shelves.json', {
  updatedAt: Date.now(),
  shelves: []
}));

// 6. Auth Routes
app.post('/v1/auth/anonymous', async (c) => {
  const raw = await c.req.json().catch(() => null);
  const parsed = authSchema.safeParse(raw);
  if (!parsed.success) {
    return c.json({ error: 'Invalid auth payload', issues: parsed.error.issues }, 400);
  }
  try {
    const res = await handleAnonymousAuth(parsed.data as AnonymousAuthRequest, c.env);
    return c.json(res);
  } catch (err: any) {
    return c.json({ error: err.message }, 500);
  }
});

app.post('/v1/auth/refresh', async (c) => {
  const raw = await c.req.json().catch(() => null);
  const parsed = refreshSchema.safeParse(raw);
  if (!parsed.success) {
    return c.json({ error: 'Invalid refresh payload' }, 400);
  }
  const res = await handleRefreshToken(parsed.data.refreshToken, c.env);
  if (res.status !== 200) {
    return c.json({ error: res.error }, res.status as any);
  }
  return c.json(res.data);
});

app.post('/v1/auth/recover', async (c) => {
  const raw = await c.req.json().catch(() => null);
  const parsed = authSchema.safeParse(raw);
  if (!parsed.success) {
    return c.json({ error: 'Invalid recover payload' }, 400);
  }
  const res = await handleRecoverAccount(parsed.data as AnonymousAuthRequest, c.env);
  if (res.status !== 200) {
    return c.json({ error: res.error }, res.status as any);
  }
  return c.json(res.data);
});

// 7. Offline-First Sync Routes
app.post('/v1/sync', async (c) => {
  const authHeader = c.req.header('Authorization');
  const device = await authenticateRequest(authHeader, c.env);
  if (!device) {
    return c.json({ error: 'Unauthorized: Invalid or expired device token' }, 401);
  }

  const rate = BudgetGuard.checkAndRecordDeviceRequest(device.deviceId);
  if (!rate.allowed) {
    return c.json({ error: 'Per-device rate limit exceeded' }, 429, { 'Retry-After': String(rate.retryAfterSec) });
  }

  const raw = await c.req.json().catch(() => null);
  const parsed = syncBatchSchema.safeParse(raw);
  if (!parsed.success) {
    return c.json({ error: 'Invalid sync payload', issues: parsed.error.issues }, 400);
  }

  const res = await handleSyncBatch(device, parsed.data as SyncBatchRequest, c.env);
  if (res.status === 429) {
    return c.json({ error: res.error }, 429, { 'Retry-After': String(res.retryAfterSec || 3600) });
  }
  return c.json(res.data, res.status as any);
});

app.get('/v1/sync', async (c) => {
  const authHeader = c.req.header('Authorization');
  const device = await authenticateRequest(authHeader, c.env);
  if (!device) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  const rate = BudgetGuard.checkAndRecordDeviceRequest(device.deviceId);
  if (!rate.allowed) {
    return c.json({ error: 'Per-device rate limit exceeded' }, 429, { 'Retry-After': String(rate.retryAfterSec) });
  }

  const cursor = parseInt(c.req.query('cursor') || '0', 10);
  const res = await handleSyncBatch(device, { cursor: Number.isNaN(cursor) ? 0 : cursor, items: [] }, c.env);
  return c.json(res.data, res.status as any);
});

// 8. Lyrics & Charts Edge Cache
app.get('/v1/lyrics', async (c) => {
  const trackId = c.req.query('trackId');
  const provider = c.req.query('provider') || 'lrclib';
  const title = c.req.query('title');
  const artist = c.req.query('artist');
  const duration = parseInt(c.req.query('duration') || '0', 10);

  if (!trackId) {
    return c.json({ error: 'Missing trackId query parameter' }, 400);
  }

  const res = await handleGetLyrics(
    trackId,
    provider,
    title,
    artist,
    Number.isNaN(duration) ? 0 : duration,
    c.env
  );
  return new Response(res.body, {
    status: res.status,
    headers: res.headers
  });
});

app.get('/v1/charts', async (c) => {
  return await handleGetCharts(c.env);
});

// 9. Client Telemetry (Opt-In)
app.post('/v1/telemetry', async (c) => {
  const raw = await c.req.json().catch(() => null);
  const parsed = telemetrySchema.safeParse(raw);
  if (!parsed.success) {
    return c.json({ error: 'Malformed telemetry report' }, 400);
  }
  const res = await handleTelemetry(parsed.data as TelemetryReport, c.env);
  if (res.status === 204) {
    return c.body(null, 204);
  }
  return c.json({ message: res.message }, res.status as any);
});

// 10. Privacy & User Rights (GDPR)
app.get('/v1/user/export', async (c) => {
  const authHeader = c.req.header('Authorization');
  const device = await authenticateRequest(authHeader, c.env);
  if (!device) return c.json({ error: 'Unauthorized' }, 401);
  const res = await handleUserExport(device, c.env);
  return c.json(res.data);
});

app.post('/v1/user/delete', async (c) => {
  const authHeader = c.req.header('Authorization');
  const device = await authenticateRequest(authHeader, c.env);
  if (!device) return c.json({ error: 'Unauthorized' }, 401);
  const res = await handleUserDelete(device, c.env);
  return c.json({ message: res.message });
});

// 11. Listen-Together Durable Object Room Routes
function randomRoomCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  const bytes = new Uint8Array(6);
  crypto.getRandomValues(bytes);
  for (let i = 0; i < 6; i++) {
    out += chars[bytes[i] % chars.length];
  }
  return out;
}

app.post('/v1/room', async (c) => {
  const tier = await BudgetGuard.getBudgetTier(c.env);
  if (tier === 'TIER_3_SHED_WRITE') {
    return c.json({ error: 'Durable Objects budget exceeded' }, 429, { 'Retry-After': '3600' });
  }
  const raw = await c.req.json().catch(() => ({}));
  const parsed = createRoomSchema.safeParse(raw);
  const body = parsed.success ? parsed.data || {} : {};
  const roomCode = randomRoomCode();
  BudgetGuard.recordDoRequest(1);
  const id = c.env.ROOMS.idFromName(roomCode);
  const roomObj = c.env.ROOMS.get(id);
  const url = new URL(c.req.url);
  url.pathname = `/v1/room/${roomCode}`;
  url.searchParams.set('code', roomCode);
  return await roomObj.fetch(new Request(url.toString(), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }));
});

app.get('/v1/room/:code', async (c) => {
  const roomCode = c.req.param('code').toUpperCase();
  if (roomCode.length < 3 || roomCode.length > 12) {
    return c.text('Invalid room code', 400);
  }
  BudgetGuard.recordDoRequest(1);
  const id = c.env.ROOMS.idFromName(roomCode);
  const roomObj = c.env.ROOMS.get(id);
  const url = new URL(c.req.url);
  url.searchParams.set('code', roomCode);
  return await roomObj.fetch(new Request(url.toString(), c.req.raw));
});

export default {
  fetch: app.fetch,
  async scheduled(_event: any, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil((async () => {
      await BudgetGuard.flushStats(env).catch(() => {});
      await env.DB.prepare('DELETE FROM sessions WHERE expires_at < ?').bind(Date.now()).run().catch(() => {});
      await env.DB.prepare('DELETE FROM lyrics_cache WHERE expires_at < ? AND http_status != 200').bind(Date.now()).run().catch(() => {});
    })());
  }
};
