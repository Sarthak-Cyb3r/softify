# Softify Backend Security & Threat Model

## 1. Threat Modeling & Scope

The Softify backend (`server/`) is designed with a **zero-trust, anonymous-first architecture**. It stores zero personal identifiable information (PII) and provides zero audio streaming/proxying.

```
+--------------------------------------------------------------------------------+
| Threat Vector                  | Mitigation Strategy                           |
|--------------------------------|-----------------------------------------------|
| Database breach / leak         | No passwords, emails, or PII stored.          |
|                                | Tokens hashed with SHA-256 at rest.           |
| Impersonation / Token Hijack   | Short-lived access tokens (1 hr) + refresh.   |
|                                | Client recovery key required to reclaim.     |
| Shared Free Quota Exhaustion   | Per-device daily write & request rate limits. |
| (DoS / Abuse)                  | 256 KB payload cap; fail-closed budget guard. |
| In-transit intercept           | Mandatory TLS 1.3 edge-to-client enforcement. |
| Server-side Audio Copyright    | Server NEVER touches, proxies or caches audio.|
+--------------------------------------------------------------------------------+
```

---

## 2. Authentication Architecture: Anonymous Device Accounts

Softify uses cryptographically secure, anonymous device accounts:
1. **Initial Provisioning**:
   - On first install, the client generates a 128-bit cryptographically secure random device secret (`device_secret`) and a user-facing recovery code (e.g. `SOFT-XXXX-XXXX-XXXX`).
   - The client calls `POST /v1/auth/anonymous` with `{ device_id, recovery_code_hash }`.
2. **Hashing at Rest**:
   - The server **NEVER** stores raw device secrets or recovery codes.
   - It hashes incoming tokens using SHA-256 with server-side salt before inserting into the `devices` table in Cloudflare D1.
3. **Session Tokens**:
   - Access tokens are lightweight HMAC-SHA256 tokens valid for **60 minutes**.
   - Refresh tokens are valid for **30 days** and can be revoked per-device instantly by deleting the session row in D1.
4. **Account Recovery & Rotation**:
   - If a user changes phones or reinstalls Softify, they input their 16-character recovery code in Settings > Account.
   - The server verifies the hash, re-binds the device session, and issues a new access token while revoking the old session.

---

## 3. Abuse Protection & Rate Limiting

Because the backend runs on Cloudflare's permanent free tier (100,000 requests/day, 100,000 D1 writes/day), a single malicious or malfunctioning client must never be able to consume the shared community quota:

1. **Per-Device Quota Enforcement**:
   - Maximum 60 dynamic requests per minute per device.
   - Maximum 50 sync write batches per day per device.
   - Requests exceeding quotas receive `HTTP 429 Too Many Requests` with a standard `Retry-After: 3600` header.
2. **Per-IP Rate Limiting**:
   - Edge protection via Cloudflare rate limiting: max 120 requests/minute per IP to mitigate distributed scraping botnets.
3. **Strict Payload Caps**:
   - Global body size limit enforced by Hono middleware: **256 KB maximum**.
   - Any payload exceeding 256 KB is rejected at the HTTP router before reading into memory or invoking D1 queries (`HTTP 413 Payload Too Large`).
4. **Budget Guard Circuit Breaker**:
   - The backend tracks aggregate daily quota consumption.
   - At 70% of daily free capacity, all telemetry ingest is shed with `HTTP 204 No Content` (silent drop).
   - At 90% of daily free capacity, dynamic sync writes are suspended with `HTTP 429` + `Retry-After: 86400`, protecting core read availability until daily reset at 00:00 UTC.

---

## 4. Data Storage & Backup Security

1. **At-Rest Encryption**:
   - Cloudflare D1 databases are transparently encrypted at rest by Cloudflare.
   - Database backups exported to R2 are encrypted with AES-256 and stored in an isolated, private R2 bucket inaccessible from the public internet.
2. **Access Control**:
   - Cloudflare API tokens use strict least-privilege scoping:
     - Worker deploy token: `Workers Scripts:Edit`, `D1:Edit`.
     - Read-only audit token: `Workers Scripts:Read`, `D1:Read`.
   - No Cloudflare credentials, API tokens, or HMAC secrets are committed to Git. All secrets are injected dynamically via GitHub Actions Secrets (`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`).

---

## 5. Security Vulnerability Reporting

Security vulnerabilities in the Softify backend should be reported via GitHub Security Advisories or by emailing the project maintainers. Exploits will be addressed promptly with automated CI edge deployments.
