const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const http = require('http');

const PORT = process.env.PORT || 3000;
const DATA_DIR = process.env.VERCEL ? path.join('/tmp', 'softify-data') : path.join(__dirname, 'data');
const DEVICES_FILE = path.join(DATA_DIR, 'devices.json');
const CONFIG_FILE = path.join(DATA_DIR, 'config.json');
const ROOMS_FILE = path.join(DATA_DIR, 'rooms.json');

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
  minAppVersion: '3.0.6',
  features: {
    spotifyLyrics: true,
    pipedFallback: true,
    discordRpc: true,
    autoHeartbeat: true,
    losslessStream: false,
    canvasVideo: true
  },
  heartbeatIntervalSeconds: 60,
  serverName: 'Softify Fleet Command Center'
};

// ============================================================================
// Intelligent Phone Model Resolver & Commercial Hardware Marketing Dictionary
// Resolves raw SKU / build numbers (e.g. BVL-N49, V2515, E076B) to genuine commercial names
// ============================================================================
function resolveExactDeviceModel(info = {}) {
  const rawModel = (info.deviceModel || info.modelCode || '').trim();
  const brand = (info.brand || '').trim();
  const manufacturer = (info.manufacturer || '').trim();
  const osVer = (info.osVersion || '').trim();
  const fingerprint = (info.fingerprint || '').trim();
  const product = (info.product || '').trim();
  const hardware = (info.hardware || '').trim();
  const platform = (info.platform || '').toLowerCase();

  const searchStr = `${rawModel} ${info.modelCode || ''} ${brand} ${manufacturer} ${osVer} ${fingerprint} ${product} ${hardware}`.toUpperCase();

  // 1. Honor Models
  if (searchStr.includes('BVL-N49') || searchStr.includes('BVL-AN00') || searchStr.includes('BVL-AN16') || searchStr.includes('BVL-AN20')) {
    return { commercialName: 'Honor Magic6 Pro', modelCode: 'BVL-N49', brand: 'Honor' };
  }
  if (searchStr.includes('BVG-AN00') || searchStr.includes('BVG-N49')) {
    return { commercialName: 'Honor Magic6', modelCode: 'BVG-AN00', brand: 'Honor' };
  }
  if (searchStr.includes('VER-AN00') || searchStr.includes('VER-N49')) {
    return { commercialName: 'Honor Magic V2', modelCode: 'VER-AN00', brand: 'Honor' };
  }
  if (searchStr.includes('PGT-AN00') || searchStr.includes('PGT-N19')) {
    return { commercialName: 'Honor Magic5 Pro', modelCode: 'PGT-N19', brand: 'Honor' };
  }
  if (searchStr.includes('ALI-NX1')) {
    return { commercialName: 'Honor Magic6 Lite', modelCode: 'ALI-NX1', brand: 'Honor' };
  }
  if (searchStr.includes('FNE-AN00') || searchStr.includes('FNE-NX9')) {
    return { commercialName: 'Honor 70', modelCode: 'FNE-NX9', brand: 'Honor' };
  }
  if (searchStr.includes('REA-AN00') || searchStr.includes('REA-NX9')) {
    return { commercialName: 'Honor 90', modelCode: 'REA-NX9', brand: 'Honor' };
  }
  if (searchStr.includes('ELI-AN00') || searchStr.includes('ELI-NX9')) {
    return { commercialName: 'Honor 200', modelCode: 'ELI-NX9', brand: 'Honor' };
  }
  if (searchStr.includes('ELP-AN00') || searchStr.includes('ELP-NX9')) {
    return { commercialName: 'Honor 200 Pro', modelCode: 'ELP-NX9', brand: 'Honor' };
  }
  if (searchStr.includes('ROD-AN00')) {
    return { commercialName: 'Honor 400', modelCode: 'ROD-AN00', brand: 'Honor' };
  }

  // 2. Vivo & iQOO Models
  if (searchStr.includes('V2515')) {
    return { commercialName: 'vivo X300', modelCode: 'V2515', brand: 'vivo' };
  }
  if (searchStr.includes('V2415') || searchStr.includes('V2403')) {
    return { commercialName: 'Vivo V40 5G', modelCode: 'V2415', brand: 'Vivo' };
  }
  if (searchStr.includes('V2418')) {
    return { commercialName: 'Vivo V40e 5G', modelCode: 'V2418', brand: 'Vivo' };
  }
  if (searchStr.includes('V2318')) {
    return { commercialName: 'Vivo V30 5G', modelCode: 'V2318', brand: 'Vivo' };
  }
  if (searchStr.includes('V2327')) {
    return { commercialName: 'Vivo V30e 5G', modelCode: 'V2327', brand: 'Vivo' };
  }
  if (searchStr.includes('V2319')) {
    return { commercialName: 'Vivo V30 Pro', modelCode: 'V2319', brand: 'Vivo' };
  }
  if (searchStr.includes('V2405A') || searchStr.includes('V2413A')) {
    return { commercialName: 'Vivo X200 Pro', modelCode: 'V2413A', brand: 'Vivo' };
  }
  if (searchStr.includes('V2303') || searchStr.includes('V2324A')) {
    return { commercialName: 'Vivo X100 Pro', modelCode: 'V2303', brand: 'Vivo' };
  }
  if (searchStr.includes('I2208') || searchStr.includes('I2209')) {
    return { commercialName: 'iQOO Neo 9 Pro', modelCode: 'I2208', brand: 'iQOO' };
  }
  if (searchStr.includes('I2220')) {
    return { commercialName: 'iQOO 12', modelCode: 'I2220', brand: 'iQOO' };
  }
  if (searchStr.includes('I2301')) {
    return { commercialName: 'iQOO 13', modelCode: 'I2301', brand: 'iQOO' };
  }

  // 3. Samsung Galaxy Models & Build fingerprints
  if (searchStr.includes('E076B') || searchStr.includes('SM-E076B')) {
    return { commercialName: 'Samsung Galaxy F70e 5G', modelCode: 'SM-E076B', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-S928') || searchStr.includes('S928')) {
    return { commercialName: 'Samsung Galaxy S24 Ultra', modelCode: 'SM-S928', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-S926') || searchStr.includes('S926')) {
    return { commercialName: 'Samsung Galaxy S24+', modelCode: 'SM-S926', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-S921') || searchStr.includes('S921')) {
    return { commercialName: 'Samsung Galaxy S24', modelCode: 'SM-S921', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-S918') || searchStr.includes('S918')) {
    return { commercialName: 'Samsung Galaxy S23 Ultra', modelCode: 'SM-S918', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-S916')) {
    return { commercialName: 'Samsung Galaxy S23+', modelCode: 'SM-S916', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-S911')) {
    return { commercialName: 'Samsung Galaxy S23', modelCode: 'SM-S911', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-S908')) {
    return { commercialName: 'Samsung Galaxy S22 Ultra', modelCode: 'SM-S908', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-A556')) {
    return { commercialName: 'Samsung Galaxy A55 5G', modelCode: 'SM-A556', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-A546')) {
    return { commercialName: 'Samsung Galaxy A54 5G', modelCode: 'SM-A546', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-A356')) {
    return { commercialName: 'Samsung Galaxy A35 5G', modelCode: 'SM-A356', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-A346')) {
    return { commercialName: 'Samsung Galaxy A34 5G', modelCode: 'SM-A346', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-A155') || searchStr.includes('SM-A156')) {
    return { commercialName: 'Samsung Galaxy A15', modelCode: 'SM-A156', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-M346')) {
    return { commercialName: 'Samsung Galaxy M34 5G', modelCode: 'SM-M346', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-M146')) {
    return { commercialName: 'Samsung Galaxy M14 5G', modelCode: 'SM-M146', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-F946') || searchStr.includes('SM-F956')) {
    return { commercialName: 'Samsung Galaxy Z Fold', modelCode: rawModel || 'Galaxy Z Fold', brand: 'Samsung' };
  }
  if (searchStr.includes('SM-F731') || searchStr.includes('SM-F741')) {
    return { commercialName: 'Samsung Galaxy Z Flip', modelCode: rawModel || 'Galaxy Z Flip', brand: 'Samsung' };
  }

  // 4. OnePlus Models
  if (searchStr.includes('CPH2581') || searchStr.includes('CPH2583') || searchStr.includes('PJD110')) {
    return { commercialName: 'OnePlus 12', modelCode: 'CPH2581', brand: 'OnePlus' };
  }
  if (searchStr.includes('CPH2609') || searchStr.includes('CPH2611') || searchStr.includes('PJE110')) {
    return { commercialName: 'OnePlus 12R', modelCode: 'CPH2609', brand: 'OnePlus' };
  }
  if (searchStr.includes('CPH2449') || searchStr.includes('CPH2447') || searchStr.includes('PHB110')) {
    return { commercialName: 'OnePlus 11', modelCode: 'CPH2449', brand: 'OnePlus' };
  }
  if (searchStr.includes('CPH2551') || searchStr.includes('PEB10')) {
    return { commercialName: 'OnePlus Open', modelCode: 'CPH2551', brand: 'OnePlus' };
  }
  if (searchStr.includes('CPH2613')) {
    return { commercialName: 'OnePlus Nord 4', modelCode: 'CPH2613', brand: 'OnePlus' };
  }
  if (searchStr.includes('CPH2513')) {
    return { commercialName: 'OnePlus Nord 3 5G', modelCode: 'CPH2513', brand: 'OnePlus' };
  }
  if (searchStr.includes('CPH2493') || searchStr.includes('CPH2491')) {
    return { commercialName: 'OnePlus Nord CE 3 Lite', modelCode: 'CPH2491', brand: 'OnePlus' };
  }

  // 5. Xiaomi, Redmi, Poco Models
  if (searchStr.includes('23124RN87I') || searchStr.includes('23124RN87')) {
    return { commercialName: 'Redmi 13C 5G', modelCode: '23124RN87I', brand: 'Xiaomi' };
  }
  if (searchStr.includes('23116PN5BC') || searchStr.includes('23117PN64G')) {
    return { commercialName: 'Xiaomi 14', modelCode: '23117PN64G', brand: 'Xiaomi' };
  }
  if (searchStr.includes('24030PN60G')) {
    return { commercialName: 'Xiaomi 14 Ultra', modelCode: '24030PN60G', brand: 'Xiaomi' };
  }
  if (searchStr.includes('2312DRA50G')) {
    return { commercialName: 'Redmi Note 13 Pro 5G', modelCode: '2312DRA50G', brand: 'Redmi' };
  }
  if (searchStr.includes('2312DRAABG')) {
    return { commercialName: 'Redmi Note 13 Pro+ 5G', modelCode: '2312DRAABG', brand: 'Redmi' };
  }
  if (searchStr.includes('2311DRK48G')) {
    return { commercialName: 'Poco X6 Pro 5G', modelCode: '2311DRK48G', brand: 'Poco' };
  }
  if (searchStr.includes('24053PY09G')) {
    return { commercialName: 'Poco F6', modelCode: '24053PY09G', brand: 'Poco' };
  }

  // 6. Google Pixel Models
  if (searchStr.includes('PIXEL 9 PRO XL')) return { commercialName: 'Google Pixel 9 Pro XL', modelCode: 'Pixel 9 Pro XL', brand: 'Google' };
  if (searchStr.includes('PIXEL 9 PRO')) return { commercialName: 'Google Pixel 9 Pro', modelCode: 'Pixel 9 Pro', brand: 'Google' };
  if (searchStr.includes('PIXEL 9')) return { commercialName: 'Google Pixel 9', modelCode: 'Pixel 9', brand: 'Google' };
  if (searchStr.includes('PIXEL 8 PRO')) return { commercialName: 'Google Pixel 8 Pro', modelCode: 'Pixel 8 Pro', brand: 'Google' };
  if (searchStr.includes('PIXEL 8A')) return { commercialName: 'Google Pixel 8a', modelCode: 'Pixel 8a', brand: 'Google' };
  if (searchStr.includes('PIXEL 8')) return { commercialName: 'Google Pixel 8', modelCode: 'Pixel 8', brand: 'Google' };
  if (searchStr.includes('PIXEL 7 PRO')) return { commercialName: 'Google Pixel 7 Pro', modelCode: 'Pixel 7 Pro', brand: 'Google' };
  if (searchStr.includes('PIXEL 7A')) return { commercialName: 'Google Pixel 7a', modelCode: 'Pixel 7a', brand: 'Google' };
  if (searchStr.includes('PIXEL 7')) return { commercialName: 'Google Pixel 7', modelCode: 'Pixel 7', brand: 'Google' };
  if (searchStr.includes('PIXEL 6')) return { commercialName: 'Google Pixel 6 Series', modelCode: 'Pixel 6', brand: 'Google' };
  if (searchStr.includes('PIXEL FOLD')) return { commercialName: 'Google Pixel Fold', modelCode: 'Pixel Fold', brand: 'Google' };

  // 7. Nothing Models
  if (searchStr.includes('A063')) return { commercialName: 'Nothing Phone (1)', modelCode: 'A063', brand: 'Nothing' };
  if (searchStr.includes('A065')) return { commercialName: 'Nothing Phone (2)', modelCode: 'A065', brand: 'Nothing' };
  if (searchStr.includes('A142P')) return { commercialName: 'Nothing Phone (2a) Plus', modelCode: 'A142P', brand: 'Nothing' };
  if (searchStr.includes('A142')) return { commercialName: 'Nothing Phone (2a)', modelCode: 'A142', brand: 'Nothing' };

  // 8. Motorola Models
  if (searchStr.includes('XT2363') || (searchStr.includes('MOTO') && searchStr.includes('G34'))) {
    return { commercialName: 'Moto G34 5G', modelCode: 'XT2363', brand: 'Motorola' };
  }
  if (searchStr.includes('XT2347') || (searchStr.includes('MOTO') && searchStr.includes('G54'))) {
    return { commercialName: 'Moto G54 5G', modelCode: 'XT2347', brand: 'Motorola' };
  }
  if (searchStr.includes('XT2431') || (searchStr.includes('MOTO') && searchStr.includes('G64'))) {
    return { commercialName: 'Moto G64 5G', modelCode: 'XT2431', brand: 'Motorola' };
  }
  if (searchStr.includes('XT2401')) return { commercialName: 'Motorola Edge 50 Ultra', modelCode: 'XT2401', brand: 'Motorola' };
  if (searchStr.includes('XT2403')) return { commercialName: 'Motorola Edge 50 Pro', modelCode: 'XT2403', brand: 'Motorola' };
  if (searchStr.includes('XT2407')) return { commercialName: 'Motorola Edge 50 Fusion', modelCode: 'XT2407', brand: 'Motorola' };
  if (searchStr.includes('XT2343')) return { commercialName: 'Moto G84 5G', modelCode: 'XT2343', brand: 'Motorola' };

  // 9. Apple Models
  if (searchStr.includes('IPHONE17,2')) return { commercialName: 'iPhone 16 Pro Max', modelCode: 'iPhone17,2', brand: 'Apple' };
  if (searchStr.includes('IPHONE17,1')) return { commercialName: 'iPhone 16 Pro', modelCode: 'iPhone17,1', brand: 'Apple' };
  if (searchStr.includes('IPHONE16,2')) return { commercialName: 'iPhone 15 Pro Max', modelCode: 'iPhone16,2', brand: 'Apple' };
  if (searchStr.includes('IPHONE16,1')) return { commercialName: 'iPhone 15 Pro', modelCode: 'iPhone16,1', brand: 'Apple' };
  if (searchStr.includes('IPHONE15,4')) return { commercialName: 'iPhone 15', modelCode: 'iPhone15,4', brand: 'Apple' };
  if (searchStr.includes('IPHONE15,2')) return { commercialName: 'iPhone 14 Pro', modelCode: 'iPhone15,2', brand: 'Apple' };

  // 10. Linux Desktop
  if (platform === 'linux' || searchStr.includes('LINUX MINT') || searchStr.includes('UBUNTU') || searchStr.includes('ARCH') || searchStr.includes('FEDORA') || searchStr.includes('DEBIAN')) {
    let desktopName = (info.deviceModel && info.deviceModel !== 'PC-x86_64' && info.deviceModel !== 'localhost' && info.deviceModel !== 'Linux Desktop')
      ? info.deviceModel
      : '';
    if (!desktopName) {
      if (searchStr.includes('MINT') || osVer === '22.3' || osVer.startsWith('22.') || osVer.startsWith('21.')) {
        desktopName = 'Linux Mint ' + (osVer || '');
      } else if (searchStr.includes('UBUNTU') || osVer.startsWith('24.04') || osVer.startsWith('22.04')) {
        desktopName = 'Ubuntu ' + (osVer || '');
      } else {
        desktopName = 'Linux Desktop';
      }
    }
    return { commercialName: desktopName.trim(), modelCode: 'PC-x86_64', brand: 'Linux' };
  }
  if (platform === 'windows') {
    return { commercialName: rawModel || 'Windows PC', modelCode: 'PC-Windows', brand: 'Microsoft' };
  }
  if (platform === 'macos') {
    return { commercialName: rawModel || 'Apple Mac', modelCode: 'Mac', brand: 'Apple' };
  }

  // 11. Generic clean fallback
  let clean = rawModel.replace(/localhost/gi, '').trim();
  const cBrand = brand || manufacturer || '';
  if (clean && cBrand && !clean.toLowerCase().includes(cBrand.toLowerCase())) {
    clean = `${cBrand} ${clean}`;
  }
  if (!clean) {
    clean = platform === 'android' ? 'Android Device' : (platform || 'Mobile Device');
  }

  return {
    commercialName: clean,
    modelCode: rawModel || clean,
    brand: cBrand || (platform === 'android' ? 'Android' : 'Unknown')
  };
}

// State Store with atomic file & cloud Gist persistence and cross-container merging
class Store {
  constructor() {
    this.devices = new Map();
    this.rooms = new Map();
    this.targetedNotices = new Map();
    this.auditLogs = [];
    this.config = { ...DEFAULT_CONFIG };
    this.lastLoadedAt = 0;
    this._loadPromise = null;
    this._savePromise = null;
    this._gistSyncTimeout = null;

    // Load initial local backup
    this._loadLocalBackup();
  }

  logEvent(event, target, details, level = 'info') {
    const entry = {
      id: Date.now().toString() + '-' + Math.random().toString(36).substr(2, 4),
      timestamp: new Date().toISOString(),
      event,
      target: target || 'system',
      details: details || '',
      level
    };
    this.auditLogs.unshift(entry);
    if (this.auditLogs.length > 100) {
      this.auditLogs.pop();
    }
    return entry;
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

    try {
      if (fs.existsSync(ROOMS_FILE)) {
        const raw = fs.readFileSync(ROOMS_FILE, 'utf8');
        const parsed = JSON.parse(raw);
        const list = Array.isArray(parsed) ? parsed : Object.values(parsed);
        for (const item of list) {
          if (item && item.roomCode) {
            this.rooms.set(item.roomCode.toUpperCase(), item);
          }
        }
      }
    } catch (_) {}
  }

  async ensureLoaded(force = false) {
    const now = Date.now();
    // In-memory cache TTL: 60 seconds (unless explicitly forced) for ultra-fast <5ms response
    if (!force && this.lastLoadedAt > 0 && now - this.lastLoadedAt < 60000) {
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
                const resolved = resolveExactDeviceModel(remoteDev);
                remoteDev.deviceModel = resolved.commercialName;
                remoteDev.modelCode = remoteDev.modelCode || resolved.modelCode;
                remoteDev.brand = remoteDev.brand || resolved.brand;
                remoteDev.pendingCommands = remoteDev.pendingCommands || [];

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
                      deviceModel: resolved.commercialName,
                      modelCode: remoteDev.modelCode || resolved.modelCode,
                      brand: remoteDev.brand || resolved.brand,
                      pendingCommands: remoteDev.pendingCommands || localDev.pendingCommands || [],
                      pingCount: Math.max(localDev.pingCount || 1, remoteDev.pingCount || 1)
                    });
                  }
                }
              }
            }

            // Merge Listen Together Rooms
            if (parsed.rooms) {
              const remoteRooms = Array.isArray(parsed.rooms)
                ? parsed.rooms
                : Object.values(parsed.rooms);

              for (const r of remoteRooms) {
                if (!r || !r.roomCode) continue;
                const code = r.roomCode.toUpperCase();
                const localRoom = this.rooms.get(code);
                if (!localRoom) {
                  this.rooms.set(code, r);
                } else {
                  const rTime = new Date(r.lastActivityAt || r.createdAt || 0).getTime();
                  const lTime = new Date(localRoom.lastActivityAt || localRoom.createdAt || 0).getTime();
                  if (rTime >= lTime) {
                    this.rooms.set(code, { ...localRoom, ...r });
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
      const roomList = Array.from(this.rooms.values());
      fs.writeFileSync(DEVICES_FILE, JSON.stringify(devList, null, 2), 'utf8');
      fs.writeFileSync(CONFIG_FILE, JSON.stringify(this.config, null, 2), 'utf8');
      fs.writeFileSync(ROOMS_FILE, JSON.stringify(roomList, null, 2), 'utf8');
    } catch (_) {}
  }

  scheduleCloudSync() {
    if (!GITHUB_TOKEN || !GITHUB_GIST_ID) return;
    if (this._gistSyncTimeout) return;

    this._gistSyncTimeout = setTimeout(async () => {
      this._gistSyncTimeout = null;
      try {
        await this.saveFleet();
      } catch (err) {
        console.error('Debounced Gist sync error:', err.message);
      }
    }, 5000);
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
      let remoteRooms = {};
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
            remoteRooms = parsed.rooms || {};
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
        } else if (targetDevice && targetDevice.id === id) {
          finalDevices[id] = { ...remote, ...d };
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

      // Merge rooms
      const finalRooms = { ...remoteRooms };
      for (const [code, r] of this.rooms.entries()) {
        finalRooms[code] = r;
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
                rooms: finalRooms,
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

    const resolved = resolveExactDeviceModel(info);
    const commercialModel = resolved.commercialName;
    const modelCode = info.modelCode || resolved.modelCode;
    const brand = info.brand || resolved.brand;

    let device = this.devices.get(id);

    if (!device) {
      const initialStatus = this.config.defaultPolicy === 'require_approval' ? 'pending' : 'allowed';
      device = {
        id,
        customAlias: info.customAlias || '',
        platform: info.platform || 'unknown',
        osVersion: info.osVersion || '',
        deviceModel: commercialModel,
        modelCode: modelCode,
        brand: brand,
        manufacturer: info.manufacturer || brand,
        hardware: info.hardware || '',
        board: info.board || '',
        isPhysicalDevice: info.isPhysicalDevice !== 'false' && info.isPhysicalDevice !== false,
        fingerprint: info.fingerprint || '',
        appVersion: info.appVersion || '3.0.6',
        ipAddress: clientIp,
        status: initialStatus,
        blockReason: initialStatus === 'pending' ? 'Device pending administrator approval' : '',
        maintenanceAffected: true,
        pendingCommands: [],
        firstSeen: now,
        lastSeen: now,
        pingCount: 1
      };
      this.devices.set(id, device);
      this.logEvent('DEVICE_REGISTERED', commercialModel, `New ${brand} device registered (${id.substring(0, 8)}) from IP ${clientIp}`, 'success');
    } else {
      device.lastSeen = now;
      device.pingCount = (device.pingCount || 0) + 1;
      device.ipAddress = clientIp || device.ipAddress;
      if (info.platform) device.platform = info.platform;
      if (info.osVersion) device.osVersion = info.osVersion;
      if (commercialModel) device.deviceModel = commercialModel;
      if (modelCode) device.modelCode = modelCode;
      if (brand) device.brand = brand;
      if (info.manufacturer) device.manufacturer = info.manufacturer;
      if (info.hardware) device.hardware = info.hardware;
      if (info.board) device.board = info.board;
      if (info.isPhysicalDevice !== undefined) {
        device.isPhysicalDevice = info.isPhysicalDevice !== 'false' && info.isPhysicalDevice !== false;
      }
      if (info.fingerprint) device.fingerprint = info.fingerprint;
      if (info.appVersion) device.appVersion = info.appVersion;
      if (info.customAlias && !device.customAlias) device.customAlias = info.customAlias;
      if (device.maintenanceAffected === undefined) device.maintenanceAffected = true;
      if (!device.pendingCommands) device.pendingCommands = [];
    }

    return device;
  }

  getAllDevices() {
    const now = Date.now();
    const fiveMinutesAgo = now - 5 * 60 * 1000;
    const oneDayAgo = now - 24 * 60 * 60 * 1000;

    return Array.from(this.devices.values())
      .map(d => {
        const resolved = resolveExactDeviceModel(d);
        const model = resolved.commercialName || d.deviceModel || 'Mobile Device';
        const modelCode = d.modelCode || resolved.modelCode;
        const brand = d.brand || resolved.brand;

        const last = new Date(d.lastSeen || 0).getTime();
        const isOnline = last >= fiveMinutesAgo;
        const isActiveToday = !isOnline && last >= oneDayAgo;
        const isOffline = last < oneDayAgo;

        return {
          ...d,
          deviceModel: model,
          modelCode,
          brand,
          maintenanceAffected: d.maintenanceAffected !== false,
          isOnline,
          isActiveToday,
          isOffline
        };
      })
      .sort((a, b) => new Date(b.lastSeen).getTime() - new Date(a.lastSeen).getTime());
  }

  queueCommand(id, command) {
    const device = this.devices.get(id);
    if (!device) return null;
    device.pendingCommands = device.pendingCommands || [];
    if (!device.pendingCommands.includes(command)) {
      device.pendingCommands.push(command);
    }
    this.logEvent('COMMAND_DISPATCHED', device.deviceModel, `Queued remote action '${command}' for device ${device.id.substring(0, 8)}`, 'info');
    return device;
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
        this.logEvent('DEVICE_ALLOWED', device.deviceModel, `Device unblocked by administrator`, 'success');
      } else if (updates.status === 'blocked') {
        this.logEvent('DEVICE_BLOCKED', device.deviceModel, `Device suspended: ${updates.blockReason || 'Manual block'}`, 'warning');
      }
    }
    if (updates.maintenanceAffected !== undefined) {
      device.maintenanceAffected = Boolean(updates.maintenanceAffected);
      this.logEvent(
        'MAINTENANCE_TARGET',
        device.deviceModel,
        `Device ${device.id.substring(0, 8)} ${device.maintenanceAffected ? 'marked as affected by' : 'exempted from'} maintenance mode`,
        'info'
      );
    }
    if (updates.blockReason !== undefined) {
      device.blockReason = updates.blockReason;
    }
    if (updates.customAlias !== undefined) {
      device.customAlias = updates.customAlias;
      this.logEvent('ALIAS_UPDATED', device.deviceModel, `Alias renamed to '${updates.customAlias}'`, 'info');
    }
    if (updates.ipAddress !== undefined) {
      device.ipAddress = updates.ipAddress;
    }
    if (updates.lastSeen !== undefined) {
      device.lastSeen = updates.lastSeen;
    }
    if (updates.pingCount !== undefined) {
      device.pingCount = updates.pingCount;
    }

    return device;
  }

  deleteDevice(id) {
    const device = this.devices.get(id);
    const name = device ? device.deviceModel : id;
    const exists = this.devices.delete(id);
    this.targetedNotices.delete(id);
    if (!this.deletedDeviceIds) this.deletedDeviceIds = new Set();
    this.deletedDeviceIds.add(id);
    this.logEvent('DEVICE_DELETED', name, `Device ${id.substring(0, 8)} removed from fleet`, 'warning');
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

  // ==========================================================================
  // Listen Together Room Management & Session History Subsystem
  // ==========================================================================

  createOrUpdateRoom({ roomCode, hostUserId, hostUsername, hostDeviceModel, hostPlatform, clientIp, isPublic = true }) {
    if (!roomCode) return null;
    const code = roomCode.trim().toUpperCase();
    const now = new Date().toISOString();

    let room = this.rooms.get(code);
    if (!room) {
      room = {
        roomCode: code,
        id: code,
        status: 'active',
        createdAt: now,
        endedAt: null,
        durationSeconds: 0,
        lastActivityAt: now,
        host: {
          userId: hostUserId || 'host_' + Math.random().toString(36).substring(2, 8),
          username: hostUsername || 'Host',
          deviceModel: hostDeviceModel || 'Mobile Device',
          platform: hostPlatform || 'unknown',
          ipAddress: clientIp || '',
          joinedAt: now
        },
        users: [
          {
            userId: hostUserId || 'host_' + Math.random().toString(36).substring(2, 8),
            username: hostUsername || 'Host',
            isHost: true,
            isOnline: true,
            deviceModel: hostDeviceModel || 'Mobile Device',
            platform: hostPlatform || 'unknown',
            ipAddress: clientIp || '',
            joinedAt: now,
            leftAt: null,
            activeDurationSeconds: 0
          }
        ],
        peakUsers: 1,
        currentTrack: null,
        songsListened: [],
        totalSongsPlayed: 0,
        totalListeningSeconds: 0,
        settings: {
          isPublic: isPublic !== false,
          allowChat: true,
          autoApprove: true
        }
      };
      this.rooms.set(code, room);
      this.logEvent('ROOM_CREATED', code, `New Listen Together room created by ${hostUsername || 'Host'} (${code})`, 'success');
    } else {
      room.lastActivityAt = now;
      if (room.status === 'closed') {
        room.status = 'active';
        room.endedAt = null;
      }
      if (hostUserId && hostUsername) {
        room.host = {
          userId: hostUserId,
          username: hostUsername,
          deviceModel: hostDeviceModel || room.host?.deviceModel || 'Mobile Device',
          platform: hostPlatform || room.host?.platform || 'unknown',
          ipAddress: clientIp || room.host?.ipAddress || '',
          joinedAt: room.host?.joinedAt || now
        };
      }
    }

    this._writeLocalBackup();
    this.scheduleCloudSync();
    return room;
  }

  recordRoomUserJoin(roomCode, { userId, username, deviceModel, platform, clientIp }) {
    if (!roomCode || !userId) return null;
    const code = roomCode.trim().toUpperCase();
    const room = this.rooms.get(code);
    if (!room) return null;

    const now = new Date().toISOString();
    room.lastActivityAt = now;

    let user = room.users.find(u => u.userId === userId);
    if (!user) {
      user = {
        userId,
        username: username || 'Guest',
        isHost: false,
        isOnline: true,
        deviceModel: deviceModel || 'Mobile Device',
        platform: platform || 'unknown',
        ipAddress: clientIp || '',
        joinedAt: now,
        leftAt: null,
        activeDurationSeconds: 0
      };
      room.users.push(user);
    } else {
      user.isOnline = true;
      user.leftAt = null;
      if (username) user.username = username;
      if (deviceModel) user.deviceModel = deviceModel;
      if (platform) user.platform = platform;
      if (clientIp) user.ipAddress = clientIp;
    }

    const currentOnlineCount = room.users.filter(u => u.isOnline).length;
    if (currentOnlineCount > (room.peakUsers || 1)) {
      room.peakUsers = currentOnlineCount;
    }

    this.logEvent('ROOM_USER_JOINED', code, `${username || 'User'} joined room ${code}`, 'info');
    this._writeLocalBackup();
    this.scheduleCloudSync();
    return room;
  }

  recordRoomUserLeave(roomCode, userId) {
    if (!roomCode || !userId) return null;
    const code = roomCode.trim().toUpperCase();
    const room = this.rooms.get(code);
    if (!room) return null;

    const now = new Date().toISOString();
    room.lastActivityAt = now;

    const user = room.users.find(u => u.userId === userId);
    if (user) {
      user.isOnline = false;
      user.leftAt = now;
      const joinedTime = new Date(user.joinedAt || now).getTime();
      const leftTime = new Date(now).getTime();
      user.activeDurationSeconds = Math.max(0, Math.round((leftTime - joinedTime) / 1000));
      this.logEvent('ROOM_USER_LEFT', code, `${user.username} left room ${code}`, 'info');
    }

    const onlineUsers = room.users.filter(u => u.isOnline);
    if (onlineUsers.length === 0) {
      this.closeRoom(code, 'all_users_left');
    } else {
      this._writeLocalBackup();
      this.scheduleCloudSync();
    }

    return room;
  }

  recordRoomSongPlayed(roomCode, track) {
    if (!roomCode || !track || !track.title) return null;
    const code = roomCode.trim().toUpperCase();
    const room = this.rooms.get(code);
    if (!room) return null;

    const now = new Date().toISOString();
    room.lastActivityAt = now;

    const lastSong = room.songsListened[room.songsListened.length - 1];
    if (lastSong && lastSong.id === track.id && (Date.now() - new Date(lastSong.playedAt).getTime() < 5000)) {
      return room;
    }

    const songEntry = {
      id: track.id || 'track_' + Math.random().toString(36).substring(2, 8),
      title: (track.title || 'Unknown Title').trim(),
      artist: (track.artist || 'Unknown Artist').trim(),
      album: (track.album || '').trim(),
      durationMs: track.durationMs || (track.duration ? track.duration * 1000 : 180000),
      thumbnailUrl: track.thumbnailUrl || track.coverUrl || '',
      playedAt: now,
      playedDurationSeconds: Math.round((track.durationMs || 180000) / 1000)
    };

    room.currentTrack = songEntry;
    room.songsListened.push(songEntry);
    room.totalSongsPlayed = room.songsListened.length;
    room.totalListeningSeconds = (room.totalListeningSeconds || 0) + songEntry.playedDurationSeconds;

    this.logEvent('ROOM_TRACK_PLAYED', code, `Played "${songEntry.title}" by ${songEntry.artist} in room ${code}`, 'info');
    this._writeLocalBackup();
    this.scheduleCloudSync();
    return room;
  }

  recordRoomHeartbeat(roomCode, { activeUsers, currentTrack, positionMs }) {
    if (!roomCode) return null;
    const code = roomCode.trim().toUpperCase();
    const room = this.rooms.get(code);
    if (!room) return null;

    const now = new Date().toISOString();
    room.lastActivityAt = now;

    if (activeUsers && Array.isArray(activeUsers)) {
      const activeIds = new Set(activeUsers.map(u => typeof u === 'string' ? u : u.userId));
      for (const u of room.users) {
        if (activeIds.has(u.userId)) {
          u.isOnline = true;
        }
      }
      if (activeUsers.length > (room.peakUsers || 1)) {
        room.peakUsers = activeUsers.length;
      }
    }

    if (currentTrack && currentTrack.title) {
      if (!room.currentTrack || room.currentTrack.id !== currentTrack.id) {
        this.recordRoomSongPlayed(code, currentTrack);
      }
    }

    this._writeLocalBackup();
    return room;
  }

  closeRoom(roomCode, reason = 'manual_close') {
    if (!roomCode) return null;
    const code = roomCode.trim().toUpperCase();
    const room = this.rooms.get(code);
    if (!room) return null;

    const now = new Date().toISOString();
    room.status = 'closed';
    room.endedAt = now;
    room.lastActivityAt = now;

    const start = new Date(room.createdAt).getTime();
    const end = new Date(now).getTime();
    room.durationSeconds = Math.max(0, Math.round((end - start) / 1000));

    for (const u of room.users) {
      if (u.isOnline) {
        u.isOnline = false;
        u.leftAt = now;
        const uStart = new Date(u.joinedAt || room.createdAt).getTime();
        u.activeDurationSeconds = Math.max(0, Math.round((end - uStart) / 1000));
      }
    }

    this.logEvent('ROOM_CLOSED', code, `Listen Together room ${code} closed (${reason}, duration: ${this._formatDuration(room.durationSeconds)})`, 'warning');
    this._writeLocalBackup();
    this.scheduleCloudSync();
    return room;
  }

  deleteRoom(roomCode) {
    if (!roomCode) return false;
    const code = roomCode.trim().toUpperCase();
    const deleted = this.rooms.delete(code);
    if (deleted) {
      this.logEvent('ROOM_DELETED', code, `Room ${code} purged from database`, 'warning');
      this._writeLocalBackup();
      this.scheduleCloudSync();
    }
    return deleted;
  }

  getAllRooms({ status, search = '' } = {}) {
    const now = Date.now();
    let list = Array.from(this.rooms.values()).map(r => {
      let duration = r.durationSeconds || 0;
      if (r.status === 'active') {
        const start = new Date(r.createdAt).getTime();
        duration = Math.max(0, Math.round((now - start) / 1000));
      }

      const lastAct = new Date(r.lastActivityAt || r.createdAt).getTime();
      if (r.status === 'active' && (now - lastAct > 60 * 60 * 1000)) {
        r.status = 'closed';
        r.endedAt = new Date(lastAct).toISOString();
        r.durationSeconds = Math.max(0, Math.round((lastAct - new Date(r.createdAt).getTime()) / 1000));
        duration = r.durationSeconds;
      }

      const activeUserCount = r.users ? r.users.filter(u => u.isOnline).length : 0;
      const totalUserCount = r.users ? r.users.length : 0;

      return {
        ...r,
        durationSeconds: duration,
        durationFormatted: this._formatDuration(duration),
        activeUserCount,
        totalUserCount
      };
    });

    if (status && status !== 'all') {
      list = list.filter(r => r.status === status);
    }

    if (search && search.trim().length > 0) {
      const q = search.trim().toUpperCase();
      list = list.filter(r =>
        r.roomCode.includes(q) ||
        (r.host && r.host.username && r.host.username.toUpperCase().includes(q)) ||
        (r.currentTrack && r.currentTrack.title && r.currentTrack.title.toUpperCase().includes(q)) ||
        (r.users && r.users.some(u => u.username && u.username.toUpperCase().includes(q)))
      );
    }

    list.sort((a, b) => {
      if (a.status === 'active' && b.status !== 'active') return -1;
      if (b.status === 'active' && a.status !== 'active') return 1;
      return new Date(b.lastActivityAt || b.createdAt).getTime() - new Date(a.lastActivityAt || a.createdAt).getTime();
    });

    return list;
  }

  getRoomStats() {
    const all = Array.from(this.rooms.values());
    const active = all.filter(r => r.status === 'active');
    const totalSongs = all.reduce((sum, r) => sum + (r.totalSongsPlayed || (r.songsListened ? r.songsListened.length : 0)), 0);
    const totalSeconds = all.reduce((sum, r) => sum + (r.totalListeningSeconds || 0), 0);
    const peakListeners = all.reduce((max, r) => Math.max(max, r.peakUsers || 0), 0);

    return {
      totalRooms: all.length,
      activeRooms: active.length,
      closedRooms: all.length - active.length,
      totalSongsListened: totalSongs,
      totalListeningHours: (totalSeconds / 3600).toFixed(1),
      peakListeners
    };
  }

  _formatDuration(seconds) {
    if (!seconds || seconds <= 0) return '0s';
    const hrs = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    if (hrs > 0) return `${hrs}h ${mins}m ${secs}s`;
    if (mins > 0) return `${mins}m ${secs}s`;
    return `${secs}s`;
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
    let maintenanceAffectedCount = 0;
    let maintenanceExemptCount = 0;
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

      if (d.maintenanceAffected === false) {
        maintenanceExemptCount++;
      } else {
        maintenanceAffectedCount++;
      }

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
      maintenanceAffectedCount,
      maintenanceExemptCount,
      platforms,
      versions,
      roomStats: this.getRoomStats(),
      maintenanceMode: Boolean(this.config.maintenanceMode),
      minAppVersion: this.config.minAppVersion || '3.0.6',
      broadcastActive: Boolean(this.config.broadcastNotice || this.config.broadcastBanner)
    };
  }
}

const store = new Store();
const app = express();

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Middleware: Fast non-blocking store hydration with in-memory cache TTL
app.use(async (req, res, next) => {
  try {
    const forceFresh = req.query.force === 'true';
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
  const {
    deviceId,
    platform,
    osVersion,
    deviceModel,
    modelCode,
    brand,
    manufacturer,
    hardware,
    board,
    isPhysicalDevice,
    fingerprint,
    appVersion,
    customAlias
  } = req.body || {};

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
      modelCode,
      brand,
      manufacturer,
      hardware,
      board,
      isPhysicalDevice,
      fingerprint,
      appVersion,
      customAlias
    },
    clientIp
  );

  // Deliver queued commands and clear
  const commandsToDeliver = [...(device.pendingCommands || [])];
  device.pendingCommands = [];

  // Synchronously persist merged fleet state
  await store.saveFleet(device);

  let isAllowed = device.status === 'allowed';
  let blockReason = device.blockReason || 'Access restricted by administrator';

  // Check Maintenance Mode (respects per-device maintenance exemption)
  const isMaintenanceAffected = device.maintenanceAffected !== false;
  const inMaintenance = Boolean(store.config.maintenanceMode && isMaintenanceAffected);

  if (inMaintenance) {
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
    status: isAllowed ? 'allowed' : (inMaintenance ? 'maintenance' : device.status),
    reason: isAllowed ? undefined : blockReason,
    maintenanceExempt: !isMaintenanceAffected,
    banner: store.config.broadcastBanner || null,
    notice,
    commands: commandsToDeliver,
    config: {
      features: store.config.features,
      heartbeatIntervalSeconds: store.config.heartbeatIntervalSeconds || 60,
      minAppVersion: store.config.minAppVersion || '3.0.6',
      maintenanceMode: Boolean(store.config.maintenanceMode),
      maintenanceExempt: !isMaintenanceAffected
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
  const isMaintenanceAffected = device.maintenanceAffected !== false;
  const inMaintenance = Boolean(store.config.maintenanceMode && isMaintenanceAffected);
  let isAllowed = device.status === 'allowed';
  let reason = device.blockReason || 'Access restricted by administrator';
  if (inMaintenance) {
    isAllowed = false;
    reason = store.config.maintenanceMessage || 'Softify is currently undergoing maintenance.';
  }
  return res.json({
    allowed: isAllowed,
    status: isAllowed ? 'allowed' : (inMaintenance ? 'maintenance' : device.status),
    reason: isAllowed ? undefined : reason,
    maintenanceExempt: !isMaintenanceAffected,
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
    store.logEvent('ADMIN_LOGIN', 'Dashboard', 'Admin logged in successfully', 'info');
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
  const { status, blockReason, customAlias, ipAddress, lastSeen, pingCount, maintenanceAffected } = req.body || {};
  const updated = store.updateDevice(req.params.id, { status, blockReason, customAlias, ipAddress, lastSeen, pingCount, maintenanceAffected });
  if (!updated) {
    return res.status(404).json({ error: 'Device not found' });
  }

  await store.saveFleet(updated);
  return res.json({ success: true, device: updated });
});

// Single device maintenance exemption toggle
app.post('/api/admin/devices/:id/maintenance', requireAdmin, async (req, res) => {
  const { affected } = req.body || {};
  const device = store.getDevice(req.params.id);
  if (!device) {
    return res.status(404).json({ error: 'Device not found' });
  }

  const isAffected = Boolean(affected);
  const updated = store.updateDevice(req.params.id, { maintenanceAffected: isAffected });
  await store.saveFleet(updated);
  return res.json({ success: true, device: updated });
});

// Batch maintenance exemption toggle across multiple or all devices
app.post('/api/admin/devices/maintenance-batch', requireAdmin, async (req, res) => {
  const { deviceIds, affected, all } = req.body || {};
  const isAffected = Boolean(affected);
  const targets = (all === true || deviceIds === 'all')
    ? Array.from(store.devices.keys())
    : (Array.isArray(deviceIds) ? deviceIds : []);

  if (targets.length === 0) {
    return res.status(400).json({ error: 'No target device IDs specified' });
  }

  const updatedDevices = [];
  for (const id of targets) {
    const dev = store.updateDevice(id, { maintenanceAffected: isAffected });
    if (dev) updatedDevices.push(dev);
  }

  store.logEvent(
    'MAINTENANCE_BATCH',
    'Fleet',
    `${updatedDevices.length} devices ${isAffected ? 'marked as affected by' : 'exempted from'} maintenance mode`,
    'info'
  );

  await store.saveFleet();
  return res.json({ success: true, count: updatedDevices.length, affected: isAffected });
});

// Remote device command dispatcher
app.post('/api/admin/devices/:id/command', requireAdmin, async (req, res) => {
  const { command } = req.body || {};
  if (!command) {
    return res.status(400).json({ error: 'Missing command parameter' });
  }

  const updated = store.queueCommand(req.params.id, command);
  if (!updated) {
    return res.status(404).json({ error: 'Device not found' });
  }

  await store.saveFleet(updated);
  return res.json({ success: true, message: `Command '${command}' queued for device`, device: updated });
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

  store.logEvent('NOTICE_TARGETED', device.deviceModel, `Notice sent to device: "${title || message}"`, 'info');
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

  const targetLabel = targetDeviceId && targetDeviceId !== 'all' ? `Device ${targetDeviceId.substring(0, 8)}` : 'Fleet Broadcast';
  store.logEvent('NOTICE_DISPATCHED', targetLabel, `Notice posted: "${cleanTitle}"`, 'info');

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

  store.logEvent('NOTICE_CLEARED', targetDeviceId || 'All', 'Notice dismissed by administrator', 'info');
  await store.saveFleet();
  return res.json({
    success: true,
    message: targetDeviceId && targetDeviceId !== 'all'
      ? `Notice for device ${targetDeviceId} cleared.`
      : 'Global broadcast notice cleared successfully.'
  });
});

// Activity / Audit Logs Endpoint
app.get('/api/admin/logs', requireAdmin, (req, res) => {
  return res.json({
    success: true,
    logs: store.auditLogs
  });
});

// Fleet Data Export Endpoints
app.get('/api/admin/export/json', requireAdmin, (req, res) => {
  const devices = store.getAllDevices();
  const dateStr = new Date().toISOString().slice(0, 10);
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Content-Disposition', `attachment; filename="softify-fleet-${dateStr}.json"`);
  return res.send(JSON.stringify({
    exportDate: new Date().toISOString(),
    totalDevices: devices.length,
    config: store.config,
    devices
  }, null, 2));
});

app.get('/api/admin/export/csv', requireAdmin, (req, res) => {
  const devices = store.getAllDevices();
  const dateStr = new Date().toISOString().slice(0, 10);
  const headers = ['Device ID', 'Custom Alias', 'Commercial Model', 'SKU Code', 'Brand', 'Platform', 'OS Version', 'App Version', 'IP Address', 'Physical Device', 'Status', 'Maintenance Affected', 'Ping Count', 'First Seen', 'Last Seen'];
  const rows = [headers.join(',')];

  for (const d of devices) {
    const row = [
      `"${d.id || ''}"`,
      `"${(d.customAlias || '').replace(/"/g, '""')}"`,
      `"${(d.deviceModel || '').replace(/"/g, '""')}"`,
      `"${(d.modelCode || '').replace(/"/g, '""')}"`,
      `"${(d.brand || '').replace(/"/g, '""')}"`,
      `"${d.platform || ''}"`,
      `"${(d.osVersion || '').replace(/"/g, '""')}"`,
      `"${d.appVersion || ''}"`,
      `"${d.ipAddress || ''}"`,
      d.isPhysicalDevice !== false ? 'Yes' : 'No',
      `"${d.status || ''}"`,
      d.maintenanceAffected !== false ? 'Affected (Yes)' : 'Exempt (No)',
      d.pingCount || 1,
      `"${d.firstSeen || ''}"`,
      `"${d.lastSeen || ''}"`
    ];
    rows.push(row.join(','));
  }

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', `attachment; filename="softify-fleet-${dateStr}.csv"`);
  return res.send(rows.join('\r\n'));
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
  store.logEvent('CONFIG_UPDATED', 'System', 'Fleet configuration and policy parameters updated', 'warning');
  await store.saveFleet();

  return res.json({
    success: true,
    config: updated
  });
});

// Force Cloud Synchronization Endpoint
app.post('/api/admin/sync-cloud', requireAdmin, async (req, res) => {
  await store.ensureLoaded(true);
  store.logEvent('CLOUD_SYNC', 'GitHub Gist', 'Fleet re-hydrated from cloud backup', 'info');
  return res.json({
    success: true,
    devices: store.getAllDevices(),
    stats: store.getStats(),
    config: store.config
  });
});

// ============================================================================
// 3. Listen Together Room Lifecycle & Session Database API
// ============================================================================

// Client Endpoint: Register / Create Room
app.post('/api/rooms/create', (req, res) => {
  const { roomCode, hostUserId, hostUsername, hostDeviceModel, hostPlatform, isPublic } = req.body || {};
  if (!roomCode) {
    return res.status(400).json({ error: 'roomCode is required' });
  }

  const clientIp = getClientIp(req);
  const room = store.createOrUpdateRoom({
    roomCode,
    hostUserId,
    hostUsername,
    hostDeviceModel,
    hostPlatform,
    clientIp,
    isPublic
  });

  return res.json({ success: true, room });
});

// Client Endpoint: User Join Room
app.post('/api/rooms/join', (req, res) => {
  const { roomCode, userId, username, deviceModel, platform } = req.body || {};
  if (!roomCode || !userId) {
    return res.status(400).json({ error: 'roomCode and userId are required' });
  }

  const clientIp = getClientIp(req);
  const room = store.recordRoomUserJoin(roomCode, {
    userId,
    username,
    deviceModel,
    platform,
    clientIp
  });

  if (!room) {
    return res.status(404).json({ error: 'Room not found' });
  }

  return res.json({ success: true, room });
});

// Client Endpoint: User Leave Room
app.post('/api/rooms/leave', (req, res) => {
  const { roomCode, userId } = req.body || {};
  if (!roomCode || !userId) {
    return res.status(400).json({ error: 'roomCode and userId are required' });
  }

  const room = store.recordRoomUserLeave(roomCode, userId);
  return res.json({ success: true, room });
});

// Client Endpoint: Song Played in Room
app.post('/api/rooms/song-played', (req, res) => {
  const { roomCode, track } = req.body || {};
  if (!roomCode || !track) {
    return res.status(400).json({ error: 'roomCode and track are required' });
  }

  const room = store.recordRoomSongPlayed(roomCode, track);
  if (!room) {
    return res.status(404).json({ error: 'Room not found' });
  }

  return res.json({ success: true, room });
});

// Client Endpoint: Room Heartbeat / State Sync
app.post('/api/rooms/heartbeat', (req, res) => {
  const { roomCode, activeUsers, currentTrack, positionMs } = req.body || {};
  if (!roomCode) {
    return res.status(400).json({ error: 'roomCode is required' });
  }

  const room = store.recordRoomHeartbeat(roomCode, { activeUsers, currentTrack, positionMs });
  if (!room) {
    return res.status(404).json({ error: 'Room not found' });
  }

  return res.json({ success: true, room });
});

// Client Endpoint: Close Room
app.post('/api/rooms/close', (req, res) => {
  const { roomCode, reason } = req.body || {};
  if (!roomCode) {
    return res.status(400).json({ error: 'roomCode is required' });
  }

  const room = store.closeRoom(roomCode, reason || 'host_closed');
  if (!room) {
    return res.status(404).json({ error: 'Room not found' });
  }

  return res.json({ success: true, room });
});

// Public / Client Endpoint: Get Active Rooms
app.get('/api/rooms/active', (req, res) => {
  const activeRooms = store.getAllRooms({ status: 'active' });
  return res.json({ success: true, rooms: activeRooms });
});

// Public / Client Endpoint: Get Specific Room Details
app.get('/api/rooms/:roomCode', (req, res) => {
  const room = store.rooms.get(req.params.roomCode.trim().toUpperCase());
  if (!room) {
    return res.status(404).json({ error: 'Room not found' });
  }
  return res.json({ success: true, room });
});

// ==========================================
// 4. Admin Listen Together Room Database API
// ==========================================

// Get All Rooms with Statistics & Filters
app.get('/api/admin/rooms', requireAdmin, (req, res) => {
  const { status, search } = req.query;
  const rooms = store.getAllRooms({ status, search });
  const stats = store.getRoomStats();
  return res.json({ success: true, stats, rooms });
});

// Get Deep Room Ledger (All users, full song history, audit)
app.get('/api/admin/rooms/:roomCode', requireAdmin, (req, res) => {
  const room = store.rooms.get(req.params.roomCode.trim().toUpperCase());
  if (!room) {
    return res.status(404).json({ error: 'Room not found' });
  }
  return res.json({ success: true, room });
});

// Admin Remotely Closes Active Room
app.post('/api/admin/rooms/:roomCode/close', requireAdmin, (req, res) => {
  const room = store.closeRoom(req.params.roomCode.trim().toUpperCase(), 'admin_terminated');
  if (!room) {
    return res.status(404).json({ error: 'Room not found' });
  }
  return res.json({ success: true, room });
});

// Admin Purges Room Record from Database
app.delete('/api/admin/rooms/:roomCode', requireAdmin, (req, res) => {
  const deleted = store.deleteRoom(req.params.roomCode.trim().toUpperCase());
  if (!deleted) {
    return res.status(404).json({ error: 'Room not found' });
  }
  return res.json({ success: true, message: 'Room successfully deleted' });
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
