import { DurableObject } from 'cloudflare:workers';
import { RoomInfoResponse } from './types';

interface RoomParticipant {
  id: string;
  name: string;
  isHost: boolean;
  lastPingMs: number;
}

interface RoomState {
  roomCode: string;
  hostId: string;
  currentTrackId: string | null;
  playbackPositionMs: number;
  positionAnchorTimestampMs: number;
  isPlaying: boolean;
  queue: string[];
}

export const MAX_ROOM_PARTICIPANTS = 6;

export class ListenTogetherRoom extends DurableObject {
  private state: RoomState;
  private initialized = false;

  constructor(ctx: DurableObjectState, env: any) {
    super(ctx, env);
    this.state = {
      roomCode: '',
      hostId: '',
      currentTrackId: null,
      playbackPositionMs: 0,
      positionAnchorTimestampMs: Date.now(),
      isPlaying: false,
      queue: []
    };
  }

  private async ensureLoaded(): Promise<void> {
    if (this.initialized) return;
    const saved = await this.ctx.storage.get<RoomState>('room_state');
    if (saved) {
      this.state = saved;
    }
    this.initialized = true;
  }

  private async persistState(): Promise<void> {
    await this.ctx.storage.put('room_state', this.state);
  }

  async fetch(request: Request): Promise<Response> {
    await this.ensureLoaded();
    const url = new URL(request.url);
    const codeParam = url.searchParams.get('code') || url.pathname.split('/').pop() || this.state.roomCode || 'ROOM';
    if (!this.state.roomCode) {
      this.state.roomCode = codeParam.toUpperCase();
      await this.persistState();
    }

    if (request.headers.get('Upgrade')?.toLowerCase() === 'websocket') {
      const activeSockets = this.ctx.getWebSockets();
      if (activeSockets.length >= MAX_ROOM_PARTICIPANTS) {
        return new Response('Room is full (max 6 participants on Free Tier)', { status: 429 });
      }

      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);

      const participantId = url.searchParams.get('peerId') || crypto.randomUUID();
      const peerName = url.searchParams.get('name') || 'Listener';
      const isHost = activeSockets.length === 0 && !this.state.hostId;
      if (isHost) {
        this.state.hostId = participantId;
        await this.persistState();
      }

      this.ctx.acceptWebSocket(server, [participantId]);
      server.serializeAttachment({
        id: participantId,
        name: peerName,
        isHost: participantId === this.state.hostId,
        lastPingMs: Date.now()
      });

      server.send(JSON.stringify({
        type: 'ROOM_STATE',
        state: this.getInterpolatedState(),
        yourId: participantId,
        isHost: participantId === this.state.hostId,
        peerCount: this.ctx.getWebSockets().length
      }));

      this.broadcast(JSON.stringify({
        type: 'PEER_JOINED',
        peer: { id: participantId, name: peerName, isHost: participantId === this.state.hostId },
        peerCount: this.ctx.getWebSockets().length
      }), participantId);

      return new Response(null, { status: 101, webSocket: client });
    }

    if (request.method === 'POST') {
      try {
        const body = await request.json<{ trackId?: string; hostName?: string }>().catch(() => ({} as any));
        if (body.trackId) {
          this.state.currentTrackId = body.trackId;
          await this.persistState();
        }
      } catch {
        // empty body allowed
      }
    }

    const interp = this.getInterpolatedState();
    const info: RoomInfoResponse = {
      roomCode: this.state.roomCode,
      wsPath: `/v1/room/${this.state.roomCode}`,
      maxParticipants: MAX_ROOM_PARTICIPANTS,
      peerCount: this.ctx.getWebSockets().length,
      currentTrackId: interp.currentTrackId,
      isPlaying: interp.isPlaying,
      playbackPositionMs: Math.round(interp.playbackPositionMs)
    };
    return Response.json(info);
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    await this.ensureLoaded();
    if (typeof message !== 'string') return;
    try {
      const msg = JSON.parse(message);
      const attachment = ws.deserializeAttachment() as RoomParticipant | null;
      if (!attachment) return;

      const now = Date.now();

      switch (msg.type) {
        case 'PLAY': {
          this.state.isPlaying = true;
          this.state.playbackPositionMs = msg.positionMs || 0;
          this.state.positionAnchorTimestampMs = now;
          if (msg.trackId) this.state.currentTrackId = msg.trackId;
          await this.persistState();
          this.broadcast(JSON.stringify({
            type: 'PLAY_SYNC',
            trackId: this.state.currentTrackId,
            positionMs: this.state.playbackPositionMs,
            anchorMs: this.state.positionAnchorTimestampMs
          }));
          break;
        }

        case 'PAUSE': {
          if (this.state.isPlaying) {
            const elapsed = now - this.state.positionAnchorTimestampMs;
            this.state.playbackPositionMs += elapsed;
          }
          this.state.isPlaying = false;
          this.state.positionAnchorTimestampMs = now;
          await this.persistState();
          this.broadcast(JSON.stringify({
            type: 'PAUSE_SYNC',
            positionMs: this.state.playbackPositionMs
          }));
          break;
        }

        case 'SEEK': {
          this.state.playbackPositionMs = msg.positionMs || 0;
          this.state.positionAnchorTimestampMs = now;
          await this.persistState();
          this.broadcast(JSON.stringify({
            type: 'SEEK_SYNC',
            positionMs: this.state.playbackPositionMs,
            anchorMs: this.state.positionAnchorTimestampMs
          }));
          break;
        }

        case 'QUEUE_UPDATE': {
          if (Array.isArray(msg.queue)) {
            this.state.queue = msg.queue.slice(0, 50);
            await this.persistState();
            this.broadcast(JSON.stringify({
              type: 'QUEUE_SYNC',
              queue: this.state.queue
            }));
          }
          break;
        }

        case 'REACTION': {
          this.broadcast(JSON.stringify({
            type: 'REACTION',
            peerId: attachment.id,
            code: String(msg.code || '').slice(0, 32)
          }));
          break;
        }

        case 'PING': {
          ws.send(JSON.stringify({
            type: 'PONG',
            serverTime: now,
            currentPosition: this.getInterpolatedState().playbackPositionMs,
            state: this.getInterpolatedState()
          }));
          break;
        }
      }
    } catch {
      // Malformed message ignored
    }
  }

  async webSocketClose(ws: WebSocket): Promise<void> {
    await this.ensureLoaded();
    const attachment = ws.deserializeAttachment() as RoomParticipant | null;
    if (attachment) {
      this.broadcast(JSON.stringify({
        type: 'PEER_LEFT',
        peerId: attachment.id,
        peerCount: Math.max(0, this.ctx.getWebSockets().length - 1)
      }), attachment.id);
    }
  }

  private broadcast(payload: string, excludeId?: string): void {
    for (const ws of this.ctx.getWebSockets()) {
      const att = ws.deserializeAttachment() as RoomParticipant | null;
      if (!excludeId || att?.id !== excludeId) {
        try {
          ws.send(payload);
        } catch {
          // stale socket ignored
        }
      }
    }
  }

  private getInterpolatedState(): RoomState {
    const now = Date.now();
    let pos = this.state.playbackPositionMs;
    if (this.state.isPlaying) {
      pos += now - this.state.positionAnchorTimestampMs;
    }
    return {
      ...this.state,
      playbackPositionMs: Math.max(0, pos)
    };
  }
}
