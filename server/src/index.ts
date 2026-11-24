import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { Env, AnonymousAuthRequest, SyncBatchRequest, TelemetryReport } from './types';
import { BudgetGuard } from './budget';
import { handleAnonymousAuth, authenticateRequest } from './auth';
import { handleSyncBatch } from './sync';
import { handleGetLyrics } from './lyrics';
import { handleGetCharts } from './charts';
import { handleTelemetry } from './telemetry';
import { handleUserExport, handleUserDelete } from './user';
import { ListenTogetherRoom } from './room';

export { ListenTogetherRoom };

const app = new Hono<{ Bindings: Env }>();

// 1. End-to-end Request ID tracking
app.use('*', async (c, next) => {
  const reqId = c.req.header('x-request-id') || crypto.randomUUID();
  c.header('x-request-id', reqId);
  BudgetGuard.recordRequest();
  await next();
});

// 2. CORS middleware
app.use('*', cors({
  origin: '*',
  allowHeaders: ['Content-Type', 'Authorization', 'x-request-id'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
}));

// 3. Strict 256 KB Body Cap to protect edge memory and CPU
app.use('*', async (c, next) => {
  const cl = c.req.header('content-length');
  if (cl && parseInt(cl, 10) > 262_144) {
    return c.json({ error: 'Payload Too Large (max 256 KB allowed)' }, 413);
  }
  await next();
});

// Liveness & Readiness Probes
app.get('/healthz', (c) => c.json({ status: 'ok', time: Date.now() }));

app.get('/readyz', async (c) => {
  try {
    BudgetGuard.recordD1Read(1);
    await c.env.DB.prepare('SELECT 1').first();
    const tier = await BudgetGuard.getBudgetTier(c.env);
    return c.json({ ready: true, budgetTier: tier });
  } catch (err: any) {
    return c.json({ ready: false, error: err.message }, 503);
  }
});

// Auth Routes
app.post('/v1/auth/anonymous', async (c) => {
  try {
    const body = await c.req.json<AnonymousAuthRequest>();
    if (!body.deviceId || !body.recoveryHash) {
      return c.json({ error: 'Missing deviceId or recoveryHash' }, 400);
    }
    const res = await handleAnonymousAuth(body, c.env);
    return c.json(res);
  } catch (err: any) {
    return c.json({ error: err.message }, 500);
  }
});

// Offline-First Sync Routes
app.post('/v1/sync', async (c) => {
  const authHeader = c.req.header('Authorization');
  const device = await authenticateRequest(authHeader, c.env);
  if (!device) {
    return c.json({ error: 'Unauthorized: Invalid or revoked device token' }, 401);
  }

  const body = await c.req.json<SyncBatchRequest>();
  const res = await handleSyncBatch(device, body, c.env);
  if (res.status === 429) {
    return c.json({ error: res.error }, 429, { 'Retry-After': '3600' });
  }
  return c.json(res.data, res.status as any);
});

app.get('/v1/sync', async (c) => {
  const authHeader = c.req.header('Authorization');
  const device = await authenticateRequest(authHeader, c.env);
  if (!device) {
    return c.json({ error: 'Unauthorized' }, 401);
  }
  const cursor = parseInt(c.req.query('cursor') || '0', 10);
  const res = await handleSyncBatch(device, { cursor, items: [] }, c.env);
  return c.json(res.data, res.status as any);
});

// Lyrics & Charts Edge Cache
app.get('/v1/lyrics', async (c) => {
  const trackId = c.req.query('trackId');
  const provider = c.req.query('provider') || 'lrclib';
  const title = c.req.query('title');
  const artist = c.req.query('artist');
  const duration = parseInt(c.req.query('duration') || '0', 10);

  if (!trackId) {
    return c.json({ error: 'Missing trackId query parameter' }, 400);
  }

  const res = await handleGetLyrics(trackId, provider, title, artist, duration, c.env);
  return new Response(res.body, {
    status: res.status,
    headers: res.headers
  });
});

app.get('/v1/charts', async (c) => {
  return await handleGetCharts(c.env);
});

// Client Telemetry
app.post('/v1/telemetry', async (c) => {
  try {
    const report = await c.req.json<TelemetryReport>();
    const res = await handleTelemetry(report, c.env);
    return c.json({ message: res.message }, res.status as any);
  } catch {
    return c.json({ error: 'Malformed telemetry report' }, 400);
  }
});

// Privacy & User Rights (GDPR)
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

// Listen-Together WebSocket Room Route (Phase 3)
app.get('/v1/room/:code', async (c) => {
  const roomCode = c.req.param('code').toUpperCase();
  if (roomCode.length < 3 || roomCode.length > 12) {
    return c.text('Invalid room code', 400);
  }
  const id = c.env.ROOMS.idFromName(roomCode);
  const roomObj = c.env.ROOMS.get(id);
  return await roomObj.fetch(c.req.raw);
});

export default {
  fetch: app.fetch,
  async scheduled(event: any, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil((async () => {
      // 1. Flush in-memory budget statistics to D1
      await BudgetGuard.flushStats(env).catch(() => {});

      // 2. Nightly cleanup: purge expired sessions (> 30 days old)
      await env.DB.prepare('DELETE FROM sessions WHERE expires_at < ?').bind(Date.now()).run().catch(() => {});

      // 3. Purge expired negative lyrics cache
      await env.DB.prepare('DELETE FROM lyrics_cache WHERE expires_at < ? AND http_status != 200').bind(Date.now()).run().catch(() => {});
    })());
  }
};
