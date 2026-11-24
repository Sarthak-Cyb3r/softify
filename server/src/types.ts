export interface Env {
  DB: D1Database;
  KV: KVNamespace;
  ROOMS: DurableObjectNamespace;
  ASSETS?: Fetcher;
  ENVIRONMENT?: string;
  SERVER_HMAC_SECRET?: string;
}

export type BudgetTier = 'TIER_0_NORMAL' | 'TIER_1_SHED_TELEMETRY' | 'TIER_2_SHED_WRITE';

export interface DeviceContext {
  deviceId: string;
  deviceHash: string;
}

export interface SyncItem {
  id: string; // item_id (e.g. playlist_id or track_id)
  type: 'playlist' | 'track_like' | 'history_aggregate' | 'setting';
  payload: string; // JSON stringified data
  hlc: string; // Hybrid logical clock string (e.g. 1732440000000:0001:dev1)
  deleted?: boolean;
  version?: number;
}

export interface SyncBatchRequest {
  cursor?: number;
  items: SyncItem[];
}

export interface SyncBatchResponse {
  cursor: number;
  items: SyncItem[];
  budgetTier: BudgetTier;
}

export interface AnonymousAuthRequest {
  deviceId: string;
  recoveryHash: string;
}

export interface AnonymousAuthResponse {
  accessToken: string;
  expiresInSeconds: number;
  refreshToken: string;
  recoveryCodeReminder: string;
}

export interface TelemetryReport {
  appVersion: string;
  osVersion: string;
  abi: string;
  errorType: string;
  redactedMessage: string;
  stackTrace?: string;
  occurredAtMs: number;
}
