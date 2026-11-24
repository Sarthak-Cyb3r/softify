# Softify Backend Architecture & Platform Decisions

## 1. Executive Summary & Hard Constraints
- **Primary Goal**: Provide a lightweight, offline-first backend for Softify that users never feel. The client app works 100% autonomously without it.
- **Hard Constraint**: **Total monetary cost must be exactly $0.00**. Never attach a payment card, never activate paid tiers or add-ons, and operate strictly within permanent free quotas. If a feature incurs financial cost or requires paid infrastructure, it is rejected by design.

---

## 2. Platform Selection & Architecture

### Chosen Platform: Cloudflare Free Tier
Softify leverages Cloudflare's serverless edge infrastructure:
- **Compute**: Cloudflare Workers (V8 isolates running across 300+ edge locations).
- **Relational Storage**: Cloudflare D1 (serverless SQLite at the edge).
- **Fast Key-Value Storage**: Cloudflare Workers KV (distributed configuration cache).
- **Blob & Object Storage**: Cloudflare R2 (S3-compatible, zero egress fees, used for automated nightly database backups).
- **Real-Time Collaboration**: Cloudflare Durable Objects (actor model for Listen-Together synchronized rooms with WebSocket hibernation).
- **Scheduled Automation**: Cloudflare Cron Triggers (scheduled cache regeneration and maintenance).
- **Edge Static Delivery**: Cloudflare Workers Static Assets (unlimited static asset delivery for configuration manifests, explore charts, and update metadata).

### Comparison with Alternatives

| Dimension | Cloudflare Free Tier (Selected) | Always-Free VM (e.g. Oracle Cloud Free / AWS EC2) | Free Managed Postgres (e.g. Supabase / Neon / Render) |
| :--- | :--- | :--- | :--- |
| **Monetary Cost** | Exactly $0, no credit card required | Officially free, but Oracle frequently reclaims idle instances; AWS free tier expires after 12 months | Free tier exists, but projects pause/expire automatically |
| **Cold Starts** | 0 ms (V8 isolates boot in < 5 ms) | 0 ms if VM stays running, but 2–5s if sleeping on container platforms (Fly.io) | 500 ms – 1500 ms (Neon compute wake) or 30–60s (Supabase unpausing) |
| **Idle Pausing & Reclaim** | **Zero idle pausing**. Workers never sleep or get reclaimed for inactivity. | **High Risk**: Oracle Cloud idle instance reclamation policy routinely terminates VMs with low CPU utilization. | **Severe**: Supabase pauses projects after 7 days of inactivity; Render deletes free DBs after 30 days. |
| **Global Distribution** | Edge deployed across 300+ cities globally; sub-20ms latency worldwide. | Single region datacenter; high latency to mobile users overseas. | Single region datacenter (e.g. AWS us-east-1). |
| **Connection Limits** | HTTP stateless requests scale up to 1,000 req/min burst; no TCP connection pool exhaustion. | Limited by OS file descriptors and local RAM (1 GB max). | Hard connection pool limits (typically 20 max connections on free tier); easily exhausted by mobile bursts. |
| **Maintenance Burden** | Zero OS patching, zero kernel updates, automated zero-downtime deployments. | Full Linux OS maintenance, SSH key management, firewall, systemd services. | Database version upgrades and storage quota monitoring. |

---

## 3. Verified Free Tier Limits

All platform limits documented below are verified against official Cloudflare documentation as of **November 2026**:

| Service / Resource | Free Tier Limit | Official Documentation Reference | Verified Date |
| :--- | :--- | :--- | :--- |
| **Cloudflare Workers** | 100,000 requests / day<br>10 ms CPU time / request<br>50 subrequests / invocation<br>1,000 req / minute burst | [Cloudflare Workers Pricing](https://developers.cloudflare.com/workers/platform/pricing/) | Nov 2026 |
| **Cloudflare D1 (SQLite)** | 5,000,000 rows read / day<br>100,000 rows written / day<br>5 GB total storage<br>Max 10 databases | [Cloudflare D1 Pricing](https://developers.cloudflare.com/d1/platform/pricing/) | Nov 2026 |
| **Cloudflare KV** | 100,000 read operations / day<br>1,000 write operations / day<br>1,000 delete operations / day<br>1 GB stored data | [Cloudflare KV Pricing](https://developers.cloudflare.com/kv/platform/pricing/) | Nov 2026 |
| **Cloudflare R2** | 10 GB storage / month<br>1,000,000 Class A operations (writes) / month<br>10,000,000 Class B operations (reads) / month<br>**$0 egress fees** | [Cloudflare R2 Pricing](https://developers.cloudflare.com/r2/pricing/) | Nov 2026 |
| **Durable Objects** | 1,000,000 requests / month<br>400,000 GB-seconds duration / month<br>WebSocket hibernation supported (zero duration cost while idle) | [Durable Objects Pricing](https://developers.cloudflare.com/durable-objects/platform/pricing/) | Nov 2026 |
| **Workers Static Assets** | **Unlimited requests** (served via Cloudflare edge CDN)<br>Up to 20,000 files, max 25 MiB / file | [Workers Static Assets](https://developers.cloudflare.com/workers/static-assets/) | Nov 2026 |
| **Cron Triggers** | Up to 3 Cron Triggers per Worker | [Workers Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/) | Nov 2026 |

---

## 4. Budget Engineering & Capacity Planning

### Design Target: 300 Daily Active Users (DAU)

To ensure the backend never breaches free quotas, per-device daily budgets are strictly calculated and enforced server-side:

```
+---------------------------------------------------------------------------------------+
| Resource             | Total Daily Free Budget | Target Fleet (300 DAU) | Allocated Budget Per Device | Actual Expected Use |
|----------------------|-------------------------|------------------------|-----------------------------|---------------------|
| Worker API Requests  | 100,000 req/day         | 300 devices            | 333 req/day                 | 10 - 15 req/day     |
| D1 Rows Written      | 100,000 rows/day        | 300 devices            | 333 rows/day                | 5 - 15 rows/day     |
| D1 Rows Read         | 5,000,000 rows/day      | 300 devices            | 16,666 rows/day             | 50 - 100 rows/day   |
| KV Writes            | 1,000 writes/day        | Shared (not per device)| N/A (Server config only)    | 5 - 10 writes/day   |
+---------------------------------------------------------------------------------------+
```

### Mathematical Breakdown
1. **API Requests**:
   - Total daily allowance: 100,000.
   - At 300 active devices, 15 dynamic requests per device = 4,500 requests/day.
   - **Daily fleet utilization: 4.5%**. Over 95,000 requests remain as reserve capacity for traffic spikes.
2. **D1 Writes**:
   - Total daily write allowance: 100,000 rows. (Note: table indexes count toward written rows).
   - Sync occurs on schedule or on user-explicit action in compressed batches with idempotency keys, updating ~5–10 rows per sync session.
   - 300 devices * 10 writes = 3,000 rows written/day.
   - **Daily fleet utilization: 3.0%**.
3. **D1 Reads**:
   - Total daily read allowance: 5,000,000 rows.
   - 300 devices * 100 reads = 30,000 rows read/day.
   - **Daily fleet utilization: 0.6%**.
4. **KV Writes**:
   - Strict rule: **Never write to KV inside user request handlers**. KV is strictly read-only on the request path. Updates occur exclusively during deployment or through the nightly cron trigger.

---

## 5. Multi-Tier Budget Guard & Load Shedding

D1 and Workers fail with hard exceptions once free daily quotas are exceeded. To prevent hard failures, the backend implements an autonomous, multi-tier load-shedding circuit breaker:

```
[Incoming Request]
        │
        ▼
Is Daily Usage < 70%? ──Yes──► [Tier 0: Full Normal Operation]
        │ No
        ▼
Is Daily Usage < 90%? ──Yes──► [Tier 1: Telemetry Shedding]
        │                       - Return HTTP 204 or HTTP 429 to /v1/telemetry
        │                       - Live sync, lyrics & charts continue
        │ No
        ▼
Usage >= 90%?         ───────► [Tier 2: Degradation & Stale Serving]
                                - Return HTTP 429 + Retry-After to /v1/sync
                                - Lyrics/charts: return cached stale data or fallback
                                - Never touch /healthz, /readyz, or static config
```

- **Protected Routes (Never Shed)**:
  - `/healthz` and `/readyz`
  - Static configuration: `/config.json`, `/update.json` (served via Workers Static Assets at 0 Worker request cost)
- **Stale-While-Revalidate**:
  - Responses carry `Cache-Control: public, max-age=300, stale-while-revalidate=86400`. If upstream budget is exhausted, Cloudflare edge and client caches serve the last known good response.

---

## 6. Static-First Architecture & CPU Budget

1. **Static Assets Priority**:
   - The update manifest (`update.json`), remote configuration (`config.json`), and Home explore shelves/charts are compiled into static JSON files by a scheduled GitHub Actions workflow and served directly from Workers Static Assets.
   - Edge requests to static files do NOT consume Worker request quotas.
2. **CPU Execution Budget**:
   - The free tier enforces a strict **10 ms CPU execution limit** per request.
   - **Rule**: Workers never parse heavy formats (e.g. XML TTML lyrics, DOM parsing, or audio transcoding).
   - Lyrics payloads fetched from upstream providers are stored and served as raw compressed strings (`gzip`/`brotli`).
   - Format parsing is performed client-side by Softify's native Rust core (`softify_core`).

---

## 7. What Stays on the Device vs What Lives on the Server

```
+---------------------------------------------+---------------------------------------------+
| CLIENT DEVICE ONLY (Android / Kotlin / Rust)| BACKEND SERVER (Cloudflare Workers / D1)   |
+---------------------------------------------+---------------------------------------------+
| • Audio stream URL resolution (Saavn / YTM) | • Anonymous device registration & auth      |
| • Audio playback & ExoPlayer decoding       | • Offline-first library & playlist sync     |
| • Local file scanning & ReplayGain tagging  | • Upstream lyrics & charts response caching |
| • YouTube Innertube client authentication   | • Remote configuration & kill switches      |
| • Residential IP queries (audio fetching)   | • Update manifest & release metadata        |
| • Local SQLite database & FTS5 search       | • Durable Objects real-time sync rooms      |
+---------------------------------------------+---------------------------------------------+
```
> [!IMPORTANT]
> The backend **NEVER** proxies, streams, downloads, or stores audio content. Audio streaming occurs strictly peer-to-peer between the client device and the content delivery network.

---

## 8. Licensing Decision: AGPL-3.0

- **Softify Client**: Licensed under **GNU General Public License v3.0 (GPL-3.0)**.
- **Backend Server (`server/`)**: Recommended license is **GNU Affero General Public License v3.0 (AGPL-3.0)**.
- **Rationale & Implication**:
  - GPL-3.0 copyleft triggers upon *distribution* of software binaries. In cloud computing, a party can run a modified version of server software over a network without distributing binaries, bypassing the requirement to contribute source code back to the community (the "network/SaaS loophole").
  - AGPL-3.0 explicitly mandates that anyone hosting a modified version of the backend service must provide the complete corresponding source code to users interacting with it over the network.
  - This ensures that community forks and cloud hosting implementations remain open-source and free for all users.

---

## 9. Provider Reachability Matrix (Datacenter Verification)

Direct reachability test executed from a cloud datacenter environment on **2026-11-24**:

| Provider | Endpoint | HTTP Status | Latency | Datacenter IP Blocked? | Server Caching Approved? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **BetterLyrics** | `https://lyrics-api.boidu.dev/getLyrics` | **200 OK** | 849 ms | **NO** | **YES** (Server cache miss fetch) |
| **LRCLIB** | `https://lrclib.net/api/get` | **200 OK** | 726 ms | **NO** | **YES** (Server cache miss fetch) |
| **lrc.red** | `https://lrc.red/api/v1` | **200 OK** | 719 ms | **NO** | **YES** (Server cache miss fetch) |
| **KuGou** | `http://lyrics.kugou.com/search` | **200 OK** | 1310 ms | **NO** | **YES** (Server cache miss fetch) |
| **Unison** | `https://unison.boidu.dev/lyrics` | **404 Not Found** (Upstream content miss) | 325 ms | **NO** | **YES** (Negative caching applied) |
| **Paxsenix** | `https://lyrics.paxsenix.org/apple-music/lyrics` | **502 Bad Gateway** (Upstream server down) | 1055 ms | **NO** | **NO** (Client direct with fallback) |
| **Spotify Embed** | `https://open.spotify.com/embed/track/...` | **200 OK** | 339 ms | **NO** | **YES** (Metadata scrape permitted) |
