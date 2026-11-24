import { Env, DeviceContext, AnonymousAuthRequest, AnonymousAuthResponse } from './types';
import { BudgetGuard } from './budget';

export async function hashString(str: string): Promise<string> {
  const enc = new TextEncoder().encode(str);
  const buf = await crypto.subtle.digest('SHA-256', enc);
  return Array.from(new Uint8Array(buf))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

export async function generateToken(deviceId: string, type: 'access' | 'refresh', secret: string): Promise<string> {
  const payload = {
    sub: deviceId,
    type,
    iat: Date.now(),
    exp: type === 'access' ? Date.now() + 3600_000 : Date.now() + 30 * 86400_000
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

export async function verifyToken(token: string, secret: string): Promise<{ deviceId: string; type: string } | null> {
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
    const sigBytes = Uint8Array.from(atob(base64Sig), c => c.charCodeAt(0));
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

export async function handleAnonymousAuth(req: AnonymousAuthRequest, env: Env): Promise<AnonymousAuthResponse> {
  const secret = env.SERVER_HMAC_SECRET || 'softify_default_anonymous_hmac_secret_2026';
  const deviceHash = await hashString(req.deviceId);
  const recoveryHash = await hashString(req.recoveryHash);
  const now = Date.now();

  BudgetGuard.recordD1Write(2);

  // Upsert device
  await env.DB.prepare(`
    INSERT INTO devices (id, device_id_hash, recovery_hash, created_at, last_active_at)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(device_id_hash) DO UPDATE SET
      last_active_at = excluded.last_active_at
  `).bind(req.deviceId, deviceHash, recoveryHash, now, now).run();

  const accessToken = await generateToken(req.deviceId, 'access', secret);
  const refreshToken = await generateToken(req.deviceId, 'refresh', secret);
  const refreshHash = await hashString(refreshToken);

  // Store refresh session
  await env.DB.prepare(`
    INSERT INTO sessions (id, device_id, token_hash, expires_at, created_at)
    VALUES (?, ?, ?, ?, ?)
  `).bind(crypto.randomUUID(), req.deviceId, refreshHash, now + 30 * 86400_000, now).run();

  return {
    accessToken,
    expiresInSeconds: 3600,
    refreshToken,
    recoveryCodeReminder: 'Store your recovery code safely to reclaim your library on new devices'
  };
}

export async function authenticateRequest(authHeader: string | undefined, env: Env): Promise<DeviceContext | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7).trim();
  const secret = env.SERVER_HMAC_SECRET || 'softify_default_anonymous_hmac_secret_2026';
  const parsed = await verifyToken(token, secret);
  if (!parsed || parsed.type !== 'access') return null;

  BudgetGuard.recordD1Read(1);
  const device = await env.DB.prepare(
    'SELECT id, device_id_hash, revoked_at FROM devices WHERE id = ?'
  ).bind(parsed.deviceId).first<{ id: string; device_id_hash: string; revoked_at: number | null }>();

  if (!device || device.revoked_at !== null) return null;
  return { deviceId: device.id, deviceHash: device.device_id_hash };
}
