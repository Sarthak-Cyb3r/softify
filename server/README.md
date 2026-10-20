# Softify Device Command Center & Fleet Controller

Centralized device registry, heartbeat tracker, and access control backend for the Softify music streaming application.

## 🚀 Features

- **Device Registry & Telemetry**: Automatically records connecting devices, operating systems, hardware models, IP addresses, app versions, and live activity timestamps.
- **Remote Kill-Switch & Access Control**: 1-click allow/block toggle for any device. Suspended devices receive an instant lock screen in Softify.
- **Custom Block Reason**: Specify custom messages displayed directly to suspended devices (e.g., "Account suspended", "Payment overdue", "Contact admin").
- **Fleet Policy Engine**:
  - `auto_allow`: All new devices are automatically approved.
  - `require_approval`: New installations remain locked until manually approved in the dashboard.
- **Zero-Dependency Native Architecture**: Built on Node.js and Express with atomic JSON file persistence—zero native compile requirements and zero database migrations.

---

## 💻 Quick Start (Local)

1. Navigate to the server folder:
   ```bash
   cd server
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Start the server:
   ```bash
   npm start
   ```
4. Open the web dashboard in your browser:
   ```
   http://localhost:3000
   ```
   - **Default Admin Key**: `admin123` (configurable via `ADMIN_KEY` environment variable).

---

## 🌐 Deploy to Cloud (Render / Railway / VPS / Docker)

### Environment Variables
| Variable | Default | Description |
| :--- | :--- | :--- |
| `PORT` | `3000` | HTTP port to listen on |
| `ADMIN_KEY` | `admin123` | Secret key used to access the dashboard |

### Docker Deployment
```bash
docker build -t softify-server .
docker run -d -p 3000:3000 -v softify-data:/app/data softify-server
```

---

## 📡 API Reference

### 1. Device Heartbeat (`POST /api/device/sync`)
Called automatically by the Softify app on startup and background resume.
```json
// Request Body
{
  "deviceId": "550e8400-e29b-41d4-a716-446655440000",
  "platform": "android",
  "osVersion": "Android 14",
  "deviceModel": "Motorola moto g34 5G",
  "appVersion": "2.1.0"
}

// Response (Allowed)
{
  "success": true,
  "allowed": true,
  "status": "allowed",
  "serverTime": "2026-10-20T16:00:00.000Z"
}

// Response (Blocked)
{
  "success": true,
  "allowed": false,
  "status": "blocked",
  "reason": "Access revoked by administrator"
}
```

### 2. Admin Management Endpoints
- `GET /api/admin/devices` — List all registered devices (Requires `Authorization: Bearer <ADMIN_KEY>`)
- `POST /api/admin/devices/:id/update` — Update device status, alias, or block reason
- `DELETE /api/admin/devices/:id` — Delete a device
- `GET /api/admin/stats` — Fleet stats (total, online, allowed, blocked)
