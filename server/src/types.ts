export interface Env {
  DB: D1Database;
  KV: KVNamespace;
  ROOMS: DurableObjectNamespace;
  ASSETS?: Fetcher;
  ENVIRONMENT?: string;
  SERVER_HMAC_SECRET?: string;
  ALERT_WEBHOOK_URL?: string;
}

export type BudgetTier =
  | 'TIER_0_NORMAL'
  | 'TIER_1_SHED_TELEMETRY'
  | 'TIER_2_SHED_CACHE_REFRESH'
  | 'TIER_3_SHED_WRITE';

export interface DeviceContext {
  deviceId: string;
  accountId: string;
  deviceHash: string;
}

export interface SyncItem {
  id: string;
  type: 'playlist' | 'track_like' | 'history_aggregate' | 'setting';
  payload: string;
  hlc: string;
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
  serverHlc: string;
}

export interface AnonymousAuthRequest {
  deviceId: string;
  recoveryHash: string;
}

export interface RefreshTokenRequest {
  refreshToken: string;
}

export interface AnonymousAuthResponse {
  accessToken: string;
  expiresInSeconds: number;
  refreshToken: string;
  accountId: string;
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

export interface RoomInfoResponse {
  roomCode: string;
  wsPath: string;
  maxParticipants: number;
  peerCount: number;
  currentTrackId: string | null;
  isPlaying: boolean;
  playbackPositionMs: number;
}
