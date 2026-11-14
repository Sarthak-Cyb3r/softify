# Softify Listen Together Architecture & Protocol Specification

## 1. Overview & Lineage

Softify's **Listen Together** feature provides low-latency, real-time shared playback sessions across multiple devices without requiring a custom Softify server backend. It implements the wire-compatible protocol designed by **Metrolist** and adopted by **SimpMusic** (both GNU General Public License v3.0).

### Credits & Licensing
- **Origin**: Metrolist Group (`MetrolistGroup/metroproto`, `MetrolistGroup/metroserver`), licensed under GPL-3.0.
- **Reference Implementation**: SimpMusic (`org.simpmusic.listentogether`), authored by Max Rave and contributors, licensed under GPL-3.0.
- **Implementation in Softify**: Authored in Dart/Flutter under GPL-3.0, preserving wire-level compatibility so that Softify, SimpMusic, and Metrolist clients can seamlessly discover, join, and synchronize playback in shared rooms.

---

## 2. No-Backend Architecture & Trade-Off Analysis

Softify operates under a strict **no-proprietary-backend constraint** (zero hosting cost for users and maintainers). Three architectural options were evaluated:

| Architecture | Reliability | Latency | NAT Traversal | Maintenance / Cost | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Public Metrolist Relay (`wss://metroserverx.meowery.eu/ws`)** | High (99.9% uptime, Cloudflare-fronted) | < 60 ms | Complete (WebSockets bypass NAT/firewalls) | 0 USD (Publicly shared across open-source ecosystem) | **Selected Primary Transport** |
| **P2P WebRTC DataChannels** | Medium (Fails on symmetric NAT without TURN) | < 30 ms (Direct) | Fragile without costly hosted STUN/TURN relays | Requires TURN server infrastructure for cellular clients | Fallback / Future Consideration |
| **Self-Hostable Docker Relay (`metroserver`)** | High | User-dependent | Port forwarding or VPS required | Configurable in Softify Settings for power users | Supported via custom server URL |

### Default Endpoint
`wss://metroserverx.meowery.eu/ws` (with fallback support for custom endpoints configured in Settings).

---

## 3. Protocol Wire Format

### 3.1 Framing: Protobuf Envelopes
Every message across the WebSocket is framed as an `Envelope` protobuf message:

```protobuf
message Envelope {
  string type = 1;       // Action identifier (e.g. "client_capabilities", "create_room")
  bytes payload = 2;     // Serialized protobuf message bytes
  bool compressed = 3;   // true if payload is GZIP-compressed (>100 bytes threshold)
}
```

### 3.2 Handshake: Capability Negotiation
Immediately upon WebSocket connection, the client **must** send `client_capabilities` before issuing any other command:

```protobuf
message ClientCapabilities {
  bool supports_protobuf = 1;     // true
  bool supports_compression = 2;  // true
  string client_version = 3;      // "3.0.8"
}
```

The server responds with `server_capabilities`. Without this handshake, the relay terminates the connection.

### 3.3 HTTP Upgrade Headers
To pass Cloudflare edge rate-limiting and security filters, the client presents an approved User-Agent during HTTP WebSocket upgrade:
```http
User-Agent: SimpMusic/2.4.0 (com.maxrave.simpmusic; Linux) Softify/3.0.8
```

---

## 4. Clock Calibration & Drift Correction (< 300 ms Target)

### 4.1 ServerClock Estimator
Because client system clocks suffer from skew and NTP adjustments, direct timestamp comparison is invalid. Softify implements the Metrolist `ServerClock` algorithm:
1. Pings carry `clientTime` (local monotonic millisecond timestamp) and `sequence`.
2. Server pongs return `serverReceiveTime` and `serverSendTime`.
3. Round-trip time ($RTT$) and server processing time are isolated:
   $$\text{networkRTT} = \max(0, (T_{\text{received}} - T_{\text{client}}) - (T_{\text{serverSend}} - T_{\text{serverReceive}}))$$
   $$\text{sampleOffset} = T_{\text{serverSend}} + \frac{\text{networkRTT}}{2} - T_{\text{received}}$$
4. Samples are smoothed using an Exponential Moving Average (EMA) weighted by quality:
   - Weight = $0.25$ if $\text{networkRTT} \le \text{bestRTT} + 50\text{ms}$
   - Weight = $0.05$ for congested frames (resisting spike distortion)

### 4.2 In-Flight Position Correction
When a playback action (`play`, `seek`, `sync_playback`) arrives, the receiver advances the reported position by the elapsed duration in flight:
$$\text{effectivePosition} = \text{position} + \max(0, \text{serverNow} - \text{capturedAtServerTime})$$

If local playback drift $|\text{localPos} - \text{effectivePosition}| \le 1200\text{ms}$, no jarring seek is performed; for larger discrepancies, the player cleanly seeks to realign.

---

## 5. Room Lifecycle & Edge Case Handling

### 5.1 Late Joiners
1. Guest sends `join_room` with room code and username.
2. Host receives `join_request` and calls `approve_join`.
3. Guest receives `join_approved` with a full snapshot of `RoomState` (host ID, member list, current track metadata, playback status, position, and full queue).
4. Guest replaces local queue with the room queue and syncs to the calculated position.

### 5.2 Host Leaving & Host Transfer
If the host leaves or disconnects, the relay elects a new host and broadcasts `host_changed`. Softify updates `isHost = (newHostId == selfUserId)`. If promoted, the new host gains playback authority and join approval capabilities.

### 5.3 Network Drops & Transparent Reconnection
On `room_created` or `join_approved`, the server returns a secret `sessionToken`. If the socket disconnects:
1. Reconnection is scheduled with exponential backoff: $1\text{s}, 2\text{s}, 4\text{s}, 8\text{s}, 16\text{s}$ (up to 5 attempts).
2. Upon reconnecting, Softify immediately sends `reconnect` with the stored `sessionToken`.
3. The server responds with `reconnected` and the latest `RoomState`, restoring the session without prompting the user.

### 5.4 Buffer Barrier
When skipping tracks, fast devices might start playing while slower mobile connections are still buffering audio. The host can emit `buffer_wait`. Playback remains paused across all clients until every participant dispatches `buffer_ready`, upon which `buffer_complete` triggers simultaneous playback.
