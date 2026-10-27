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
  maintenanceMode: false,
  maintenanceMessage: 'Softify is currently undergoing brief maintenance. Normal playback will resume shortly.',
  minAppVersion: '3.0.3',
  features: {
    spotifyLyrics: true,
    pipedFallback: true,
    discordRpc: true,
    autoHeartbeat: true
  },
  heartbeatIntervalSeconds: 60,
  serverName: 'Softify Fleet Command Center'
};

// State Store with atomic file & cloud Gist persistence and cross-container merging
class Store {
  constructor() {
    this.devices = new Map();
    this.targetedNotices = new Map();
    this.config = { ...DEFAULT_CONFIG };
    this.lastLoadedAt = 0;
    this._loadPromise = null;
    this._savePromise = null;

    // Load initial local backup
    this._loadLocalBackup();
  }

  _loadLocalBackup() {
    try {
      if (fs.existsSync(CONFIG_FILE)) {
        const raw = fs.readFileSync(CONFIG_FILE, 'utf8');
        const parsed = JSON.parse(raw);
        this.config = { ...DEFAULT_CONFIG, ...parsed };
      }
    } catch (_) {}

    try {
      if (fs.existsSync(DEVICES_FILE)) {
        const raw = fs.readFileSync(DEVICES_FILE, 'utf8');
        const parsed = JSON.parse(raw);
        const list = Array.isArray(parsed) ? parsed : Object.values(parsed);
        for (const item of list) {
          if (item && item.id) {
            this.devices.set(item.id, item);
          }
        }
      }
    } catch (_) {}
  }

  async ensureLoaded(force = false) {
    const now = Date.now();
    if (!force && this.lastLoadedAt > 0 && now - this.lastLoadedAt < 3500) {
      return;
    }

    if (this._loadPromise) {
      return this._loadPromise;
    }

    this._loadPromise = (async () => {
      try {
        if (!GITHUB_TOKEN || !GITHUB_GIST_ID) {
          this.lastLoadedAt = Date.now();
          return;
        }

        const res = await fetch(`https://api.github.com/gists/${GITHUB_GIST_ID}`, {
          headers: {
            'Authorization': `Bearer ${GITHUB_TOKEN}`,
            'User-Agent': 'Softify-Server',
            'Accept': 'application/vnd.github.v3+json'
          },
          cache: 'no-store'
        });

        if (res.ok) {
          const data = await res.json();
          const file = data.files && data.files['devices.json'];
          if (file && file.content) {
            const parsed = JSON.parse(file.content);

            // Merge devices defensively (never wipe known devices)
            if (parsed.devices) {
              const remoteList = Array.isArray(parsed.devices)
                ? parsed.devices
                : Object.values(parsed.devices);

              for (const remoteDev of remoteList) {
                if (!remoteDev || !remoteDev.id) continue;
                const localDev = this.devices.get(remoteDev.id);
                if (!localDev) {
                  this.devices.set(remoteDev.id, remoteDev);
                } else {
                  const remoteTime = new Date(remoteDev.lastSeen || 0).getTime();
                  const localTime = new Date(localDev.lastSeen || 0).getTime();
                  if (remoteTime >= localTime) {
                    this.devices.set(remoteDev.id, {
                      ...localDev,
                      ...remoteDev,
                      pingCount: Math.max(localDev.pingCount || 1, remoteDev.pingCount || 1)
                    });
                  }
                }
              }
            }

            // Merge targeted notices
            if (parsed.targetedNotices) {
              for (const [devId, notice] of Object.entries(parsed.targetedNotices)) {
                if (notice) {
                  this.targetedNotices.set(devId, notice);
                } else {
                  this.targetedNotices.delete(devId);
                }
              }
            }

            // Merge remote config
            if (parsed.config) {
              this.config = {
                ...DEFAULT_CONFIG,
                ...this.config,
                ...parsed.config,
                features: {
                  ...DEFAULT_CONFIG.features,
                  ...(this.config.features || {}),
                  ...(parsed.config.features || {})
                }
              };
            }

            this.lastLoadedAt = Date.now();
            this._writeLocalBackup();
          }
        }
      } catch (err) {
        console.error('Remote Gist load error:', err.message);
      } finally {
        this._loadPromise = null;
      }
    })();

    return this._loadPromise;
  }

  _writeLocalBackup() {
    try {
      const devList = Array.from(this.devices.values());
      fs.writeFileSync(DEVICES_FILE, JSON.stringify(devList, null, 2), 'utf8');
      fs.writeFileSync(CONFIG_FILE, JSON.stringify(this.config, null, 2), 'utf8');
    } catch (_) {}
  }

  async saveFleet(targetDevice = null) {
    if (targetDevice && targetDevice.id) {
      this.devices.set(targetDevice.id, targetDevice);
    }
    this._writeLocalBackup();

    if (!GITHUB_TOKEN || !GITHUB_GIST_ID) return;

    try {
      // 1. Fetch current remote Gist to merge any concurrent devices from other containers
      let remoteDevices = {};
      let remoteTargeted = {};
      try {
        const res = await fetch(`https://api.github.com/gists/${GITHUB_GIST_ID}`, {
          headers: {
            'Authorization': `Bearer ${GITHUB_TOKEN}`,
            'User-Agent': 'Softify-Server'
          },
          cache: 'no-store'
        });
        if (res.ok) {
          const data = await res.json();
          const file = data.files && data.files['devices.json'];
          if (file && file.content) {
            const parsed = JSON.parse(file.content);
            remoteDevices = parsed.devices || {};
            remoteTargeted = parsed.targetedNotices || {};
          }
        }
      } catch (_) {}

      // 2. Merge local into remote dictionary
      const finalDevices = { ...remoteDevices };
      if (this.deletedDeviceIds) {
        for (const delId of this.deletedDeviceIds) {
          delete finalDevices[delId];
        }
      }

      for (const [id, d] of this.devices.entries()) {
        if (this.deletedDeviceIds && this.deletedDeviceIds.has(id)) continue;
        const remote = finalDevices[id];
        if (!remote) {
          finalDevices[id] = d;
        } else {
          const rTime = new Date(remote.lastSeen || 0).getTime();
          const lTime = new Date(d.lastSeen || 0).getTime();
          finalDevices[id] = lTime >= rTime ? { ...remote, ...d } : { ...d, ...remote };
        }
      }

      if (this.deletedDeviceIds) {
        this.deletedDeviceIds.clear();
      }

      // Also ensure this.devices has everything
      for (const [id, d] of Object.entries(finalDevices)) {
        this.devices.set(id, d);
      }

      const finalTargeted = { ...remoteTargeted };
      for (const [id, n] of this.targetedNotices.entries()) {
        finalTargeted[id] = n;
      }

      // 3. Atomically patch GitHub Gist
      const payload = {
        files: {
          'devices.json': {
            content: JSON.stringify(
              {
                config: this.config,
                targetedNotices: finalTargeted,
                devices: finalDevices,
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

      this.lastLoadedAt = Date.now();
    } catch (e) {
      console.error('Error persisting fleet to Gist:', e.message);
    }
  }

  syncDevice(info, clientIp) {
    const id = info.deviceId;
    const now = new Date().toISOString();

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

    let device = this.devices.get(id);

    if (!device) {
      const initialStatus = this.config.defaultPolicy === 'require_approval' ? 'pending' : 'allowed';
      device = {
        id,
        customAlias: info.customAlias || '',
        platform: info.platform || 'unknown',
        osVersion: info.osVersion || '',
        deviceModel: cleanModel,
        appVersion: info.appVersion || '3.0.3',
        ipAddress: clientIp,
        status: initialStatus,
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
      if (cleanModel && cleanModel !== 'localhost') device.deviceModel = cleanModel;
      if (info.appVersion) device.appVersion = info.appVersion;
      if (info.customAlias && !device.customAlias) device.customAlias = info.customAlias;
    }

    return device;
  }

  getAllDevices() {
    const now = Date.now();
    const fiveMinutesAgo = now - 5 * 60 * 1000;
    const oneDayAgo = now - 24 * 60 * 60 * 1000;

    return Array.from(this.devices.values())
      .map(d => {
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

        const last = new Date(d.lastSeen || 0).getTime();
        const isOnline = last >= fiveMinutesAgo;
        const isActiveToday = !isOnline && last >= oneDayAgo;
        const isOffline = last < oneDayAgo;

        return {
          ...d,
          deviceModel: model,
          isOnline,
          isActiveToday,
          isOffline
        };
      })
      .sort((a, b) => new Date(b.lastSeen).getTime() - new Date(a.lastSeen).getTime());
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

    return device;
  }

  deleteDevice(id) {
    const exists = this.devices.delete(id);
    this.targetedNotices.delete(id);
    if (!this.deletedDeviceIds) this.deletedDeviceIds = new Set();
    this.deletedDeviceIds.add(id);
    return exists;
  }

  setNotice({ title, message, type, targetDeviceId, actionUrl }) {
    const notice = {
      id: Date.now().toString(),
      title: (title || 'Announcement').trim(),
      message: (message || '').trim(),
      type: type || 'info',
      targetDeviceId: targetDeviceId || 'all',
      actionUrl: actionUrl || '',
      createdAt: new Date().toISOString()
    };

    if (targetDeviceId && targetDeviceId !== 'all') {
      this.targetedNotices.set(targetDeviceId, notice);
    } else {
      this.config.broadcastNotice = notice;
      this.config.broadcastBanner = notice.message;
    }

    return notice;
  }

  clearNotice(targetDeviceId) {
    if (targetDeviceId && targetDeviceId !== 'all') {
      this.targetedNotices.delete(targetDeviceId);
    } else {
      this.config.broadcastNotice = null;
      this.config.broadcastBanner = '';
    }
  }

  updateConfig(updates) {
    if (updates.adminKey !== undefined && updates.adminKey.trim()) {
      this.config.adminKey = updates.adminKey.trim();
    }
    if (updates.defaultPolicy !== undefined) {
      this.config.defaultPolicy = updates.defaultPolicy;
    }
    if (updates.maintenanceMode !== undefined) {
      this.config.maintenanceMode = Boolean(updates.maintenanceMode);
    }
    if (updates.maintenanceMessage !== undefined) {
      this.config.maintenanceMessage = updates.maintenanceMessage.trim();
    }
    if (updates.minAppVersion !== undefined) {
      this.config.minAppVersion = updates.minAppVersion.trim();
    }
    if (updates.broadcastBanner !== undefined) {
      this.config.broadcastBanner = updates.broadcastBanner;
    }
    if (updates.features !== undefined && typeof updates.features === 'object') {
      this.config.features = {
        ...this.config.features,
        ...updates.features
      };
    }
    if (updates.heartbeatIntervalSeconds !== undefined) {
      const sec = parseInt(updates.heartbeatIntervalSeconds, 10);
      if (!isNaN(sec) && sec >= 15) {
        this.config.heartbeatIntervalSeconds = sec;
      }
    }
    if (updates.serverName !== undefined) {
      this.config.serverName = updates.serverName.trim();
    }

    return this.config;
  }

  getStats() {
    const devices = Array.from(this.devices.values());
    const now = Date.now();
    const oneDayAgo = now - 24 * 60 * 60 * 1000;
    const fiveMinutesAgo = now - 5 * 60 * 1000;

    let onlineNow = 0;
    let activeToday = 0;
    let offlineCount = 0;
    let allowedCount = 0;
    let blockedCount = 0;
    let pendingCount = 0;
    const platforms = {};
    const versions = {};

    for (const d of devices) {
      const last = new Date(d.lastSeen || 0).getTime();
      if (last >= fiveMinutesAgo) onlineNow++;
      else if (last >= oneDayAgo) activeToday++;
      else offlineCount++;

      if (d.status === 'allowed') allowedCount++;
      else if (d.status === 'blocked') blockedCount++;
      else if (d.status === 'pending') pendingCount++;

      const p = (d.platform || 'other').toLowerCase();
      platforms[p] = (platforms[p] || 0) + 1;

      const v = d.appVersion || 'legacy';
      versions[v] = (versions[v] || 0) + 1;
    }

    return {
      total: devices.length,
      onlineNow,
      activeToday,
      offlineCount,
      allowedCount,
      blockedCount,
      pendingCount,
      platforms,
      versions,
      maintenanceMode: Boolean(this.config.maintenanceMode),
      minAppVersion: this.config.minAppVersion || '3.0.3',
      broadcastActive: Boolean(this.config.broadcastNotice || this.config.broadcastBanner)
    };
  }
}

const store = new Store();
const app = express();

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Middleware: Always ensure store is hydrated before handling requests
app.use(async (req, res, next) => {
  try {
    const forceFresh = req.path.startsWith('/api/admin');
    await store.ensureLoaded(forceFresh);
  } catch (e) {
    console.error('Store hydration middleware error:', e.message);
  }
  next();
});

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
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice(7)
    : (req.query.key || req.headers['x-admin-key']);

  if (!token || token !== store.config.adminKey) {
    return res.status(401).json({ error: 'Unauthorized: Invalid or missing Admin Key' });
  }
  next();
}

// ==========================================
// 1. Client App Device Heartbeat & Registration
// ==========================================
app.post('/api/device/sync', async (req, res) => {
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

  // Synchronously persist merged fleet state
  await store.saveFleet(device);

  let isAllowed = device.status === 'allowed';
  let blockReason = device.blockReason || 'Access restricted by administrator';

  // Check Maintenance Mode
  if (store.config.maintenanceMode) {
    isAllowed = false;
    blockReason = store.config.maintenanceMessage || 'Softify is currently undergoing maintenance.';
  }

  // Check Targeted Notice first, fallback to Broadcast Notice
  let notice = store.targetedNotices.get(deviceId.trim()) || null;
  if (!notice) {
    notice = store.config.broadcastNotice || (store.config.broadcastBanner ? {
      id: 'active-banner',
      title: 'Announcement',
      message: store.config.broadcastBanner,
      type: 'info'
    } : null);
  }

  // Version advisory if app is below minimum required version
  const minVer = store.config.minAppVersion;
  if (minVer && appVersion && appVersion !== minVer) {
    // If notice is not already urgent, attach update recommendation
    if (!notice) {
      notice = {
        id: `update-req-${minVer}`,
        title: 'Softify Update Available',
        message: `Softify v${minVer} is now available with the latest features. Please update your app.`,
        type: 'warning'
      };
    }
  }

  return res.json({
    success: true,
    allowed: isAllowed,
    status: isAllowed ? 'allowed' : (store.config.maintenanceMode ? 'maintenance' : device.status),
    reason: isAllowed ? undefined : blockReason,
    banner: store.config.broadcastBanner || null,
    notice,
    config: {
      features: store.config.features,
      heartbeatIntervalSeconds: store.config.heartbeatIntervalSeconds || 60,
      minAppVersion: store.config.minAppVersion || '3.0.3'
    },
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
// 2. Admin Authentication & Fleet Control API
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

app.post('/api/admin/devices/:id/toggle', requireAdmin, async (req, res) => {
  const device = store.getDevice(req.params.id);
  if (!device) {
    return res.status(404).json({ error: 'Device not found' });
  }

  const newStatus = device.status === 'allowed' ? 'blocked' : 'allowed';
  const reason = newStatus === 'blocked' ? (req.body.reason || 'Access revoked by administrator') : '';
  const updated = store.updateDevice(req.params.id, { status: newStatus, blockReason: reason });

  await store.saveFleet(updated);
  return res.json({ success: true, device: updated });
});

app.post('/api/admin/devices/:id/update', requireAdmin, async (req, res) => {
  const { status, blockReason, customAlias } = req.body || {};
  const updated = store.updateDevice(req.params.id, { status, blockReason, customAlias });
  if (!updated) {
    return res.status(404).json({ error: 'Device not found' });
  }

  await store.saveFleet(updated);
  return res.json({ success: true, device: updated });
});

// Send direct message / push notice to a single device
app.post('/api/admin/devices/:id/message', requireAdmin, async (req, res) => {
  const device = store.getDevice(req.params.id);
  if (!device) {
    return res.status(404).json({ error: 'Device not found' });
  }

  const { title, message, type, actionUrl } = req.body || {};
  if (!message || !message.trim()) {
    return res.status(400).json({ error: 'Message cannot be empty' });
  }

  const notice = store.setNotice({
    title,
    message,
    type: type || 'info',
    targetDeviceId: req.params.id,
    actionUrl
  });

  await store.saveFleet();
  return res.json({ success: true, notice, deviceId: req.params.id });
});

app.delete('/api/admin/devices/:id', requireAdmin, async (req, res) => {
  const deleted = store.deleteDevice(req.params.id);
  if (deleted) {
    await store.saveFleet();
  }
  return res.json({ success: deleted });
});

// Notice Management (Broadcast and Targeted)
app.get('/api/admin/notice', requireAdmin, (req, res) => {
  const targeted = [];
  for (const [deviceId, notice] of store.targetedNotices.entries()) {
    const dev = store.getDevice(deviceId);
    targeted.push({
      deviceId,
      deviceModel: dev ? dev.deviceModel : 'Unknown Device',
      customAlias: dev ? dev.customAlias : '',
      notice
    });
  }

  return res.json({
    success: true,
    broadcastNotice: store.config.broadcastNotice || null,
    broadcastBanner: store.config.broadcastBanner || '',
    targetedNotices: targeted
  });
});

app.post('/api/admin/notice', requireAdmin, async (req, res) => {
  const { title, message, type, targetDeviceId, actionUrl } = req.body || {};
  const cleanMessage = (message || '').trim();
  const cleanTitle = (title || 'Announcement').trim();
  const noticeType = type || 'info';

  if (!cleanMessage) {
    return res.status(400).json({ error: 'Notice message cannot be empty' });
  }

  const notice = store.setNotice({
    title: cleanTitle,
    message: cleanMessage,
    type: noticeType,
    targetDeviceId: targetDeviceId || 'all',
    actionUrl: actionUrl || ''
  });

  await store.saveFleet();
  return res.json({
    success: true,
    notice,
    target: targetDeviceId || 'all'
  });
});

app.delete('/api/admin/notice', requireAdmin, async (req, res) => {
  const targetDeviceId = req.query.targetDeviceId || (req.body && req.body.targetDeviceId);
  store.clearNotice(targetDeviceId);

  await store.saveFleet();
  return res.json({
    success: true,
    message: targetDeviceId && targetDeviceId !== 'all'
      ? `Notice for device ${targetDeviceId} cleared.`
      : 'Global broadcast notice cleared successfully.'
  });
});

// Full Remote System Configuration
app.get('/api/admin/config', requireAdmin, (req, res) => {
  return res.json({
    success: true,
    config: store.config
  });
});

app.post('/api/admin/config', requireAdmin, async (req, res) => {
  const updated = store.updateConfig(req.body || {});
  await store.saveFleet();

  return res.json({
    success: true,
    config: updated
  });
});

// Force Cloud Synchronization Endpoint
app.post('/api/admin/sync-cloud', requireAdmin, async (req, res) => {
  await store.ensureLoaded(true);
  return res.json({
    success: true,
    devices: store.getAllDevices(),
    stats: store.getStats(),
    config: store.config
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    devicesCount: store.devices.size,
    time: new Date().toISOString()
  });
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
    console.log(`🎵 Softify Fleet Command Center`);
    console.log(`🚀 Server running on: http://localhost:${PORT}`);
    console.log(`🔑 Default Admin Key: ${store.config.adminKey}`);
    console.log(`📡 Device Sync Endpoint: POST /api/device/sync`);
    console.log(`=======================================================`);
  });
}

module.exports = app;
