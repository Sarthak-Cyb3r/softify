import { DurableObject } from 'cloudflare:workers';

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

export class ListenTogetherRoom extends DurableObject {
  private state: RoomState;

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

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    // WebSocket upgrade for real-time room connection
    if (request.headers.get('Upgrade')?.toLowerCase() === 'websocket') {
      const activeSockets = this.ctx.getWebSockets();
      if (activeSockets.length >= 6) {
        return new Response('Room is full (max 6 participants on Free Tier)', { status: 429 });
      }

      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);

      const participantId = url.searchParams.get('peerId') || crypto.randomUUID();
      const peerName = url.searchParams.get('name') || 'Listener';
      const isHost = activeSockets.length === 0;

      // Use Cloudflare WebSocket Hibernation API: zero duration charges when idle!
      this.ctx.acceptWebSocket(server, [participantId]);
      server.serializeAttachment({
        id: participantId,
        name: peerName,
        isHost,
        lastPingMs: Date.now()
      });

      // Send initial state to newly joined peer
      server.send(JSON.stringify({
        type: 'ROOM_STATE',
        state: this.getInterpolatedState(),
        yourId: participantId,
        isHost
      }));

      // Broadcast join event to others
      this.broadcast(JSON.stringify({
        type: 'PEER_JOINED',
        peer: { id: participantId, name: peerName, isHost },
        peerCount: this.ctx.getWebSockets().length
      }), participantId);

      return new Response(null, { status: 101, webSocket: client });
    }

    return new Response('Expected WebSocket upgrade', { status: 426 });
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
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
          this.broadcast(JSON.stringify({
            type: 'PAUSE_SYNC',
            positionMs: this.state.playbackPositionMs
          }));
          break;
        }

        case 'SEEK': {
          this.state.playbackPositionMs = msg.positionMs || 0;
          this.state.positionAnchorTimestampMs = now;
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
            this.broadcast(JSON.stringify({
              type: 'QUEUE_SYNC',
              queue: this.state.queue
            }));
          }
          break;
        }

        case 'PING': {
          ws.send(JSON.stringify({
            type: 'PONG',
            serverTime: now,
            currentPosition: this.getInterpolatedState().playbackPositionMs
          }));
          break;
        }
      }
    } catch {
      // Malformed message ignored
    }
  }

  async webSocketClose(ws: WebSocket, code: number, reason: string, wasClean: boolean): Promise<void> {
    const attachment = ws.deserializeAttachment() as RoomParticipant | null;
    if (attachment) {
      this.broadcast(JSON.stringify({
        type: 'PEER_LEFT',
        peerId: attachment.id,
        peerCount: this.ctx.getWebSockets().length
      }));
    }
  }

  private broadcast(payload: string, excludeId?: string): void {
    for (const ws of this.ctx.getWebSockets()) {
      const att = ws.deserializeAttachment() as RoomParticipant | null;
      if (!excludeId || att?.id !== excludeId) {
        ws.send(payload);
      }
    }
  }

  private getInterpolatedState(): RoomState {
    const now = Date.now();
    let pos = this.state.playbackPositionMs;
    if (this.state.isPlaying) {
      pos += (now - this.state.positionAnchorTimestampMs);
    }
    return {
      ...this.state,
      playbackPositionMs: Math.max(0, pos)
    };
  }
}
