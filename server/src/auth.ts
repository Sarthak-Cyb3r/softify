import {
  Env,
  DeviceContext,
  AnonymousAuthRequest,
  AnonymousAuthResponse
} from './types';
import { BudgetGuard } from './budget';

const DEFAULT_SECRET = 'softify_default_anonymous_hmac_secret_2026';

export async function hashString(str: string): Promise<string> {
  const enc = new TextEncoder().encode(str);
  const buf = await crypto.subtle.digest('SHA-256', enc);
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

export async function generateToken(
  deviceId: string,
  type: 'access' | 'refresh',
  secret: string,
  ttlMs?: number
): Promise<string> {
  const now = Date.now();
  const duration = ttlMs ?? (type === 'access' ? 3600_000 : 30 * 86400_000);
  const payload = {
    sub: deviceId,
    type,
    jti: crypto.randomUUID(),
    iat: now,
    exp: now + duration
  };
  const jsonStr = JSON.stringify(payload);
  const base64Payload = btoa(jsonStr);
  const encSecret = new TextEncoder().encode(secret);
  const key = await crypto.subtle.importKey(
    'raw',
    encSecret,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(base64Payload));
  const base64Sig = btoa(String.fromCharCode(...new Uint8Array(signature)));
  return `${base64Payload}.${base64Sig}`;
}

export async function verifyToken(
  token: string,
  secret: string
): Promise<{ deviceId: string; type: string } | null> {
  try {
    const parts = token.split('.');
    if (parts.length !== 2) return null;
    const [base64Payload, base64Sig] = parts;
    const encSecret = new TextEncoder().encode(secret);
    const key = await crypto.subtle.importKey(
      'raw',
      encSecret,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify']
    );
    const sigBytes = Uint8Array.from(atob(base64Sig), (c) => c.charCodeAt(0));
    const isValid = await crypto.subtle.verify(
      'HMAC',
      key,
      sigBytes,
      new TextEncoder().encode(base64Payload)
    );
    if (!isValid) return null;

    const payload = JSON.parse(atob(base64Payload));
    if (Date.now() > payload.exp) return null;
    return { deviceId: payload.sub, type: payload.type };
  } catch {
    return null;
  }
}

async function issueTokensAndSession(
  deviceId: string,
  accountId: string,
  env: Env
): Promise<AnonymousAuthResponse> {
  const secret = env.SERVER_HMAC_SECRET || DEFAULT_SECRET;
  const now = Date.now();
  const accessToken = await generateToken(deviceId, 'access', secret);
  const refreshToken = await generateToken(deviceId, 'refresh', secret);
  const refreshHash = await hashString(refreshToken);

  BudgetGuard.recordD1Write(1);
  await env.DB.prepare(`
    INSERT INTO sessions (id, device_id, token_hash, expires_at, created_at)
    VALUES (?, ?, ?, ?, ?)
  `).bind(crypto.randomUUID(), deviceId, refreshHash, now + 30 * 86400_000, now).run();

  return {
    accessToken,
    expiresInSeconds: 3600,
    refreshToken,
    accountId,
    recoveryCodeReminder: 'Store your recovery code safely to reclaim your library on new devices'
  };
}

export async function handleAnonymousAuth(
  req: AnonymousAuthRequest,
  env: Env
): Promise<AnonymousAuthResponse> {
  const deviceHash = await hashString(req.deviceId);
  const recoveryHash = await hashString(req.recoveryHash);
  const now = Date.now();

  BudgetGuard.recordD1Read(1);
  const existing = await env.DB.prepare(
    'SELECT id, COALESCE(account_id, id) AS account_id FROM devices WHERE device_id_hash = ?'
  ).bind(deviceHash).first<{ id: string; account_id: string }>();

  const accountId = existing?.account_id ?? req.deviceId;

  BudgetGuard.recordD1Write(1);
  await env.DB.prepare(`
    INSERT INTO devices (id, device_id_hash, recovery_hash, account_id, created_at, last_active_at)
    VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(device_id_hash) DO UPDATE SET
      last_active_at = excluded.last_active_at,
      revoked_at = NULL
  `).bind(req.deviceId, deviceHash, recoveryHash, accountId, now, now).run();

  return issueTokensAndSession(req.deviceId, accountId, env);
}

export async function handleRecoverAccount(
  req: AnonymousAuthRequest,
  env: Env
): Promise<{ status: number; data?: AnonymousAuthResponse; error?: string }> {
  const deviceHash = await hashString(req.deviceId);
  const recoveryHash = await hashString(req.recoveryHash);
  const now = Date.now();

  BudgetGuard.recordD1Read(1);
  const anchor = await env.DB.prepare(
    'SELECT id, COALESCE(account_id, id) AS account_id FROM devices WHERE recovery_hash = ? AND revoked_at IS NULL ORDER BY created_at ASC LIMIT 1'
  ).bind(recoveryHash).first<{ id: string; account_id: string }>();

  if (!anchor) {
    return { status: 404, error: 'Recovery code not found' };
  }

  const accountId = anchor.account_id;
  BudgetGuard.recordD1Write(1);
  await env.DB.prepare(`
    INSERT INTO devices (id, device_id_hash, recovery_hash, account_id, created_at, last_active_at)
    VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(device_id_hash) DO UPDATE SET
      account_id = excluded.account_id,
      recovery_hash = excluded.recovery_hash,
      last_active_at = excluded.last_active_at,
      revoked_at = NULL
  `).bind(req.deviceId, deviceHash, recoveryHash, accountId, now, now).run();

  const data = await issueTokensAndSession(req.deviceId, accountId, env);
  return { status: 200, data };
}

export async function handleRefreshToken(
  refreshToken: string,
  env: Env
): Promise<{ status: number; data?: AnonymousAuthResponse; error?: string }> {
  const secret = env.SERVER_HMAC_SECRET || DEFAULT_SECRET;
  const parsed = await verifyToken(refreshToken, secret);
  if (!parsed || parsed.type !== 'refresh') {
    return { status: 401, error: 'Invalid or expired refresh token' };
  }

  const tokenHash = await hashString(refreshToken);
  const now = Date.now();

  BudgetGuard.recordD1Read(2);
  const session = await env.DB.prepare(
    'SELECT id, device_id, expires_at FROM sessions WHERE token_hash = ? AND expires_at > ?'
  ).bind(tokenHash, now).first<{ id: string; device_id: string; expires_at: number }>();

  if (!session) {
    return { status: 401, error: 'Refresh session revoked or expired' };
  }

  const device = await env.DB.prepare(
    'SELECT id, COALESCE(account_id, id) AS account_id, revoked_at FROM devices WHERE id = ?'
  ).bind(session.device_id).first<{ id: string; account_id: string; revoked_at: number | null }>();

  if (!device || device.revoked_at !== null) {
    return { status: 401, error: 'Device revoked or deleted' };
  }

  BudgetGuard.recordD1Write(1);
  await env.DB.prepare('DELETE FROM sessions WHERE id = ?').bind(session.id).run();

  const data = await issueTokensAndSession(device.id, device.account_id, env);
  return { status: 200, data };
}

export async function authenticateRequest(
  authHeader: string | undefined,
  env: Env
): Promise<DeviceContext | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7).trim();
  const secret = env.SERVER_HMAC_SECRET || DEFAULT_SECRET;
  const parsed = await verifyToken(token, secret);
  if (!parsed || parsed.type !== 'access') return null;

  BudgetGuard.recordD1Read(1);
  const device = await env.DB.prepare(
    'SELECT id, device_id_hash, COALESCE(account_id, id) AS account_id, revoked_at FROM devices WHERE id = ?'
  ).bind(parsed.deviceId).first<{
    id: string;
    device_id_hash: string;
    account_id: string;
    revoked_at: number | null;
  }>();

  if (!device || device.revoked_at !== null) return null;
  return {
    deviceId: device.id,
    accountId: device.account_id,
    deviceHash: device.device_id_hash
  };
}
