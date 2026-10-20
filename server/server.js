const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const http = require('http');

const PORT = process.env.PORT || 3000;
const DATA_DIR = path.join(__dirname, 'data');
const DEVICES_FILE = path.join(DATA_DIR, 'devices.json');
const CONFIG_FILE = path.join(DATA_DIR, 'config.json');

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

// Default Configuration
const DEFAULT_CONFIG = {
  adminKey: process.env.ADMIN_KEY || 'admin123',
  defaultPolicy: 'auto_allow', // 'auto_allow' | 'require_approval'
  broadcastBanner: '',
  serverName: 'Softify Device Command Center'
};

// State Store with atomic file persistence
class Store {
  constructor() {
    this.devices = new Map();
    this.config = { ...DEFAULT_CONFIG };
    this._load();
  }

  _load() {
    try {
      if (fs.existsSync(CONFIG_FILE)) {
        const raw = fs.readFileSync(CONFIG_FILE, 'utf8');
        this.config = { ...DEFAULT_CONFIG, ...JSON.parse(raw) };
      } else {
        this._saveConfig();
      }
    } catch (e) {
      console.error('Failed to load config, using defaults:', e.message);
    }

    try {
      if (fs.existsSync(DEVICES_FILE)) {
        const raw = fs.readFileSync(DEVICES_FILE, 'utf8');
        const list = JSON.parse(raw);
        for (const item of list) {
          if (item && item.id) {
            this.devices.set(item.id, item);
          }
        }
      }
    } catch (e) {
      console.error('Failed to load devices:', e.message);
    }
  }

  _saveDevices() {
    try {
      const data = JSON.stringify(Array.from(this.devices.values()), null, 2);
      const tmpFile = `${DEVICES_FILE}.tmp`;
      fs.writeFileSync(tmpFile, data, 'utf8');
      fs.renameSync(tmpFile, DEVICES_FILE);
    } catch (e) {
      console.error('Error saving devices:', e.message);
    }
  }

  _saveConfig() {
    try {
      const data = JSON.stringify(this.config, null, 2);
      const tmpFile = `${CONFIG_FILE}.tmp`;
      fs.writeFileSync(tmpFile, data, 'utf8');
      fs.renameSync(tmpFile, CONFIG_FILE);
    } catch (e) {
      console.error('Error saving config:', e.message);
    }
  }

  syncDevice(info, clientIp) {
    const id = info.deviceId;
    if (!id) return null;

    const now = new Date().toISOString();
    let device = this.devices.get(id);

    if (!device) {
      const initialStatus = this.config.defaultPolicy === 'require_approval' ? 'pending' : 'allowed';
      device = {
        id,
        customAlias: info.customAlias || '',
        platform: info.platform || 'unknown',
        osVersion: info.osVersion || '',
        deviceModel: info.deviceModel || 'Unknown Device',
        appVersion: info.appVersion || '2.1.0',
        ipAddress: clientIp,
        status: initialStatus, // 'allowed' | 'blocked' | 'pending'
        blockReason: initialStatus === 'pending' ? 'Device pending administrator approval' : '',
        firstSeen: now,
        lastSeen: now,
        pingCount: 1
      };
      this.devices.set(id, device);
    } else {
      device.lastSeen = now;
      device.pingCount = (device.pingCount || 0) + 1;
      device.ipAddress = clientIp || device.ipAddress;
      if (info.platform) device.platform = info.platform;
      if (info.osVersion) device.osVersion = info.osVersion;
      if (info.deviceModel) device.deviceModel = info.deviceModel;
      if (info.appVersion) device.appVersion = info.appVersion;
      if (info.customAlias && !device.customAlias) device.customAlias = info.customAlias;
    }

    this._saveDevices();
    return device;
  }

  getAllDevices() {
    return Array.from(this.devices.values()).sort(
      (a, b) => new Date(b.lastSeen).getTime() - new Date(a.lastSeen).getTime()
    );
  }

  getDevice(id) {
    return this.devices.get(id);
  }

  updateDevice(id, updates) {
    const device = this.devices.get(id);
    if (!device) return null;

    if (updates.status !== undefined) {
      device.status = updates.status;
      if (updates.status === 'allowed') {
        device.blockReason = '';
      }
    }
    if (updates.blockReason !== undefined) {
      device.blockReason = updates.blockReason;
    }
    if (updates.customAlias !== undefined) {
      device.customAlias = updates.customAlias;
    }

    this._saveDevices();
    return device;
  }

  deleteDevice(id) {
    const exists = this.devices.delete(id);
    if (exists) this._saveDevices();
    return exists;
  }

  updateConfig(updates) {
    if (updates.adminKey !== undefined && updates.adminKey.trim()) {
      this.config.adminKey = updates.adminKey.trim();
    }
    if (updates.defaultPolicy !== undefined) {
      this.config.defaultPolicy = updates.defaultPolicy;
    }
    if (updates.broadcastBanner !== undefined) {
      this.config.broadcastBanner = updates.broadcastBanner;
    }
    this._saveConfig();
    return this.config;
  }

  getStats() {
    const devices = Array.from(this.devices.values());
    const now = Date.now();
    const oneDayAgo = now - 24 * 60 * 60 * 1000;
    const fiveMinutesAgo = now - 5 * 60 * 1000;

    let onlineNow = 0;
    let activeToday = 0;
    let allowedCount = 0;
    let blockedCount = 0;
    let pendingCount = 0;
    const platforms = {};

    for (const d of devices) {
      const last = new Date(d.lastSeen).getTime();
      if (last >= fiveMinutesAgo) onlineNow++;
      if (last >= oneDayAgo) activeToday++;

      if (d.status === 'allowed') allowedCount++;
      else if (d.status === 'blocked') blockedCount++;
      else if (d.status === 'pending') pendingCount++;

      const p = (d.platform || 'other').toLowerCase();
      platforms[p] = (platforms[p] || 0) + 1;
    }

    return {
      total: devices.length,
      onlineNow,
      activeToday,
      allowedCount,
      blockedCount,
      pendingCount,
      platforms
    };
  }
}

const store = new Store();
const app = express();

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Helper to extract client IP accurately behind proxies
function getClientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    return forwarded.split(',')[0].trim();
  }
  return req.socket.remoteAddress || req.ip || '127.0.0.1';
}

// Authentication middleware for admin endpoints
function requireAdmin(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : (req.query.key || req.headers['x-admin-key']);

  if (!token || token !== store.config.adminKey) {
    return res.status(401).json({ error: 'Unauthorized: Invalid or missing Admin Key' });
  }
  next();
}

// ==========================================
// 1. Client App Device Heartbeat & Registration
// ==========================================
app.post('/api/device/sync', (req, res) => {
  const { deviceId, platform, osVersion, deviceModel, appVersion, customAlias } = req.body || {};

  if (!deviceId || typeof deviceId !== 'string' || deviceId.trim().length === 0) {
    return res.status(400).json({ error: 'Missing deviceId parameter' });
  }

  const clientIp = getClientIp(req);
  const device = store.syncDevice(
    {
      deviceId: deviceId.trim(),
      platform,
      osVersion,
      deviceModel,
      appVersion,
      customAlias
    },
    clientIp
  );

  const isAllowed = device.status === 'allowed';

  return res.json({
    success: true,
    allowed: isAllowed,
    status: device.status,
    reason: isAllowed ? undefined : (device.blockReason || 'Access restricted by administrator'),
    banner: store.config.broadcastBanner || null,
    serverTime: new Date().toISOString()
  });
});

// Simple public status check for a device
app.get('/api/device/status/:id', (req, res) => {
  const device = store.getDevice(req.params.id);
  if (!device) {
    return res.status(404).json({ error: 'Device not found' });
  }
  const isAllowed = device.status === 'allowed';
  return res.json({
    allowed: isAllowed,
    status: device.status,
    reason: isAllowed ? undefined : (device.blockReason || 'Access restricted by administrator'),
    banner: store.config.broadcastBanner || null
  });
});

// ==========================================
// 2. Admin Authentication & Dashboard API
// ==========================================
app.post('/api/admin/login', (req, res) => {
  const { key } = req.body || {};
  if (key === store.config.adminKey) {
    return res.json({ success: true, token: store.config.adminKey });
  }
  return res.status(401).json({ success: false, error: 'Incorrect Admin Key' });
});

app.get('/api/admin/stats', requireAdmin, (req, res) => {
  return res.json({ success: true, stats: store.getStats() });
});

app.get('/api/admin/devices', requireAdmin, (req, res) => {
  const devices = store.getAllDevices();
  return res.json({ success: true, devices });
});

app.post('/api/admin/devices/:id/toggle', requireAdmin, (req, res) => {
  const device = store.getDevice(req.params.id);
  if (!device) {
    return res.status(404).json({ error: 'Device not found' });
  }

  const newStatus = device.status === 'allowed' ? 'blocked' : 'allowed';
  const reason = newStatus === 'blocked' ? (req.body.reason || 'Access revoked by administrator') : '';
  const updated = store.updateDevice(req.params.id, { status: newStatus, blockReason: reason });

  return res.json({ success: true, device: updated });
});

app.post('/api/admin/devices/:id/update', requireAdmin, (req, res) => {
  const { status, blockReason, customAlias } = req.body || {};
  const updated = store.updateDevice(req.params.id, { status, blockReason, customAlias });
  if (!updated) {
    return res.status(404).json({ error: 'Device not found' });
  }
  return res.json({ success: true, device: updated });
});

app.delete('/api/admin/devices/:id', requireAdmin, (req, res) => {
  const deleted = store.deleteDevice(req.params.id);
  return res.json({ success: deleted });
});

app.get('/api/admin/config', requireAdmin, (req, res) => {
  return res.json({
    success: true,
    config: {
      defaultPolicy: store.config.defaultPolicy,
      broadcastBanner: store.config.broadcastBanner,
      serverName: store.config.serverName
    }
  });
});

app.post('/api/admin/config', requireAdmin, (req, res) => {
  const updated = store.updateConfig(req.body || {});
  return res.json({
    success: true,
    config: {
      defaultPolicy: updated.defaultPolicy,
      broadcastBanner: updated.broadcastBanner,
      serverName: updated.serverName
    }
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// Start HTTP Server
const server = http.createServer(app);
server.listen(PORT, '0.0.0.0', () => {
  console.log(`=======================================================`);
  console.log(`🎵 Softify Device Command Center`);
  console.log(`🚀 Server running on: http://localhost:${PORT}`);
  console.log(`🔑 Default Admin Key: ${store.config.adminKey}`);
  console.log(`📡 Device Sync Endpoint: POST /api/device/sync`);
  console.log(`=======================================================`);
});
