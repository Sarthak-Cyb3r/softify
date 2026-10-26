const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const http = require('http');

const PORT = process.env.PORT || 3000;
const DATA_DIR = process.env.VERCEL ? path.join('/tmp', 'softify-data') : path.join(__dirname, 'data');
const DEVICES_FILE = path.join(DATA_DIR, 'devices.json');
const CONFIG_FILE = path.join(DATA_DIR, 'config.json');

const GITHUB_GIST_ID = process.env.GITHUB_GIST_ID || 'a8e25d128307d38d875a138da38a7ddd';
const GITHUB_TOKEN = process.env.GITHUB_TOKEN || '';

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

// Default Configuration
const DEFAULT_CONFIG = {
  adminKey: process.env.ADMIN_KEY || '2010',
  defaultPolicy: 'auto_allow', // 'auto_allow' | 'require_approval'
  broadcastBanner: '',
  broadcastNotice: null,
  serverName: 'Softify Device Command Center'
};

// State Store with atomic file & cloud Gist persistence
class Store {
  constructor() {
    this.devices = new Map();
    this.config = { ...DEFAULT_CONFIG };
    this._remoteTimer = null;
    this._load();
  }

  async _load() {
    // 1. Load from local cache/disk
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

    // 2. Hydrate from GitHub Gist if credentials available
    if (GITHUB_TOKEN && GITHUB_GIST_ID) {
      try {
        const res = await fetch(`https://api.github.com/gists/${GITHUB_GIST_ID}`, {
          headers: {
            'Authorization': `Bearer ${GITHUB_TOKEN}`,
            'User-Agent': 'Softify-Server'
          }
        });
        if (res.ok) {
          const data = await res.json();
          const file = data.files && data.files['devices.json'];
          if (file && file.content) {
            const parsed = JSON.parse(file.content);
            if (parsed.devices) {
              const items = Array.isArray(parsed.devices) ? parsed.devices : Object.values(parsed.devices);
              for (const item of items) {
                if (item && item.id) {
                  this.devices.set(item.id, item);
                }
              }
            }
            if (parsed.config) {
              this.config = { ...DEFAULT_CONFIG, ...parsed.config };
            }
          }
        }
      } catch (err) {
        console.error('Remote Gist sync error on load:', err.message);
      }
    }
  }

  _scheduleRemoteSync() {
    if (!GITHUB_TOKEN || !GITHUB_GIST_ID) return;
    if (this._remoteTimer) clearTimeout(this._remoteTimer);
    this._remoteTimer = setTimeout(() => {
      this._saveToRemoteGist();
    }, 800);
  }

  async _saveToRemoteGist() {
    if (!GITHUB_TOKEN || !GITHUB_GIST_ID) return;
    try {
      const devicesObj = {};
      for (const [id, d] of this.devices.entries()) {
        devicesObj[id] = d;
      }
      const payload = {
        files: {
          'devices.json': {
            content: JSON.stringify(
              {
                config: this.config,
                devices: devicesObj,
                updatedAt: new Date().toISOString()
              },
              null,
              2
            )
          }
        }
      };
      await fetch(`https://api.github.com/gists/${GITHUB_GIST_ID}`, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${GITHUB_TOKEN}`,
          'User-Agent': 'Softify-Server',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });
    } catch (e) {
      console.error('Error syncing state to Gist:', e.message);
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
    this._scheduleRemoteSync();
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
    this._scheduleRemoteSync();
  }

  syncDevice(info, clientIp) {
    const id = info.deviceId;
    if (!id) return null;

    const now = new Date().toISOString();
    let device = this.devices.get(id);

    let cleanModel = (info.deviceModel || '').trim();
    if (!cleanModel || cleanModel.toLowerCase() === 'localhost') {
      const p = (info.platform || '').toLowerCase();
      if (p === 'android') cleanModel = 'Android Device';
      else if (p === 'linux') cleanModel = 'Linux Desktop';
      else if (p === 'ios') cleanModel = 'Apple iPhone';
      else if (p === 'windows') cleanModel = 'Windows PC';
      else if (p === 'macos') cleanModel = 'Apple Mac';
      else cleanModel = 'Mobile Device';
    }

    if (!device) {
      const initialStatus = this.config.defaultPolicy === 'require_approval' ? 'pending' : 'allowed';
      device = {
        id,
        customAlias: info.customAlias || '',
        platform: info.platform || 'unknown',
        osVersion: info.osVersion || '',
        deviceModel: cleanModel,
        appVersion: info.appVersion || '3.0.2',
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
      device.deviceModel = cleanModel;
      if (info.appVersion) device.appVersion = info.appVersion;
      if (info.customAlias && !device.customAlias) device.customAlias = info.customAlias;
    }

    this._saveDevices();
    return device;
  }

  getAllDevices() {
    return Array.from(this.devices.values()).map(d => {
      let model = (d.deviceModel || '').trim();
      if (!model || model.toLowerCase() === 'localhost') {
        const p = (d.platform || '').toLowerCase();
        if (p === 'android') model = 'Android Device';
        else if (p === 'linux') model = 'Linux Desktop';
        else if (p === 'ios') model = 'Apple iPhone';
        else if (p === 'windows') model = 'Windows PC';
        else if (p === 'macos') model = 'Apple Mac';
        else model = 'Mobile Device';
      }
      return { ...d, deviceModel: model };
    }).sort(
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

  const notice = store.config.broadcastNotice || (store.config.broadcastBanner ? {
    id: 'active-banner',
    title: 'Announcement',
    message: store.config.broadcastBanner,
    type: 'info'
  } : null);

  return res.json({
    success: true,
    allowed: isAllowed,
    status: device.status,
    reason: isAllowed ? undefined : (device.blockReason || 'Access restricted by administrator'),
    banner: store.config.broadcastBanner || null,
    notice,
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
  const { key, password } = req.body || {};
  const pass = (key || password || '').toString().trim();
  if (pass === store.config.adminKey) {
    return res.json({ success: true, token: store.config.adminKey });
  }
  return res.status(401).json({ success: false, error: 'Incorrect Admin Password' });
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

app.get('/api/admin/notice', requireAdmin, (req, res) => {
  return res.json({
    success: true,
    notice: store.config.broadcastNotice || null,
    banner: store.config.broadcastBanner || ''
  });
});

app.post('/api/admin/notice', requireAdmin, (req, res) => {
  const { title, message, type } = req.body || {};
  const cleanMessage = (message || '').trim();
  const cleanTitle = (title || 'Announcement').trim();
  const noticeType = type || 'info';

  if (!cleanMessage) {
    return res.status(400).json({ error: 'Notice message cannot be empty' });
  }

  const notice = {
    id: Date.now().toString(),
    title: cleanTitle,
    message: cleanMessage,
    type: noticeType,
    createdAt: new Date().toISOString()
  };

  store.config.broadcastNotice = notice;
  store.config.broadcastBanner = cleanMessage;
  store._saveConfig();

  return res.json({ success: true, notice });
});

app.delete('/api/admin/notice', requireAdmin, (req, res) => {
  store.config.broadcastNotice = null;
  store.config.broadcastBanner = '';
  store._saveConfig();
  return res.json({ success: true, message: 'Notice cleared successfully' });
});

app.get('/api/admin/config', requireAdmin, (req, res) => {
  return res.json({
    success: true,
    config: {
      defaultPolicy: store.config.defaultPolicy,
      broadcastBanner: store.config.broadcastBanner,
      broadcastNotice: store.config.broadcastNotice || null,
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

// Wildcard route to serve dashboard SPA
app.get('*', (req, res, next) => {
  if (req.path.startsWith('/api') || req.path === '/health') return next();
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Start HTTP Server when run directly
if (!process.env.VERCEL) {
  const server = http.createServer(app);
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`=======================================================`);
    console.log(`🎵 Softify Device Command Center`);
    console.log(`🚀 Server running on: http://localhost:${PORT}`);
    console.log(`🔑 Default Admin Key: ${store.config.adminKey}`);
    console.log(`📡 Device Sync Endpoint: POST /api/device/sync`);
    console.log(`=======================================================`);
  });
}

module.exports = app;
