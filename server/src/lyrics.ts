import { Env } from './types';
import { BudgetGuard } from './budget';

export async function handleGetLyrics(
  trackId: string,
  provider: string,
  title: string | undefined,
  artist: string | undefined,
  durationSec: number | undefined,
  env: Env
): Promise<{ status: number; body: string; headers: Record<string, string> }> {
  const cacheKey = `${trackId}:${provider}`;
  const now = Date.now();

  BudgetGuard.recordD1Read(1);
  const cached = await env.DB.prepare(
    'SELECT raw_payload, format, http_status, expires_at FROM lyrics_cache WHERE id = ?'
  ).bind(cacheKey).first<{
    raw_payload: string;
    format: string;
    http_status: number;
    expires_at: number;
  }>();

  if (cached && now < cached.expires_at) {
    return {
      status: cached.http_status,
      body: cached.raw_payload,
      headers: {
        'Content-Type': cached.format === 'ttml' ? 'application/xml' : 'application/json',
        'Cache-Control': 'public, max-age=86400, stale-while-revalidate=86400',
        'X-Cache-Status': 'HIT'
      }
    };
  }

  // Budget Guard Shedding: >=80% sheds upstream lyrics cache misses while serving stale if available
  const tier = await BudgetGuard.getBudgetTier(env);
  if (tier === 'TIER_2_SHED_CACHE_REFRESH' || tier === 'TIER_3_SHED_WRITE') {
    if (cached) {
      return {
        status: cached.http_status,
        body: cached.raw_payload,
        headers: {
          'Content-Type': cached.format === 'ttml' ? 'application/xml' : 'application/json',
          'Cache-Control': 'public, max-age=300, stale-while-revalidate=86400',
          'X-Cache-Status': 'STALE_SHED'
        }
      };
    }
    return {
      status: 503,
      body: JSON.stringify({ error: 'Upstream lyrics refresh shed under budget guard', budgetTier: tier }),
      headers: { 'Content-Type': 'application/json', 'Retry-After': '300' }
    };
  }

  let upstreamUrl: string | null = null;
  let detectedFormat = 'json';

  if (provider === 'lrclib' && title) {
    const q = new URLSearchParams({ track_name: title });
    if (artist) q.set('artist_name', artist);
    upstreamUrl = `https://lrclib.net/api/get?${q.toString()}`;
  } else if (provider === 'betterlyrics' && title) {
    const q = new URLSearchParams({ s: title });
    if (artist) q.set('a', artist);
    if (durationSec) q.set('d', durationSec.toString());
    upstreamUrl = `https://lyrics-api.boidu.dev/getLyrics?${q.toString()}`;
    detectedFormat = 'ttml';
  } else if (provider === 'lrcred' && title) {
    const q = `${artist ? artist + ' ' : ''}${title}`;
    upstreamUrl = `https://lrc.red/api/v1?q=${encodeURIComponent(q)}`;
  }

  if (!upstreamUrl) {
    return {
      status: 400,
      body: JSON.stringify({ error: 'Unsupported provider or missing title' }),
      headers: { 'Content-Type': 'application/json' }
    };
  }

  try {
    const resp = await fetch(upstreamUrl, {
      headers: { 'User-Agent': 'Mozilla/5.0 (Softify-Backend/1.0)' },
      cf: { cacheTtl: 86400 }
    });

    const bodyText = await resp.text();
    const status = resp.status;
    const ttl = status === 200 ? 7 * 86400_000 : 86400_000;

    BudgetGuard.recordD1Write(1);
    await env.DB.prepare(`
      INSERT INTO lyrics_cache (id, track_id, provider, raw_payload, format, http_status, created_at, expires_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        raw_payload = excluded.raw_payload,
        format = excluded.format,
        http_status = excluded.http_status,
        expires_at = excluded.expires_at
    `).bind(cacheKey, trackId, provider, bodyText, detectedFormat, status, now, now + ttl).run();

    return {
      status,
      body: bodyText,
      headers: {
        'Content-Type': detectedFormat === 'ttml' ? 'application/xml' : 'application/json',
        'Cache-Control': 'public, max-age=86400, stale-while-revalidate=86400',
        'X-Cache-Status': 'MISS'
      }
    };
  } catch (err: any) {
    return {
      status: 502,
      body: JSON.stringify({ error: `Upstream error: ${err.message}` }),
      headers: { 'Content-Type': 'application/json' }
    };
  }
}
