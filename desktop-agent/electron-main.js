const { app, BrowserWindow, Tray, Menu, nativeImage, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { spawn, execSync } = require('child_process');

let autoUpdater = null;
try {
  autoUpdater = require('electron-updater').autoUpdater;
} catch (e) {
  console.log('electron-updater not available in current environment:', e.message);
}

// Set distinct application name and user data directory
app.setName('devdeck-agent');
const userDataPath = path.join(app.getPath('appData'), 'DevDeckAgentElectron');
app.setPath('userData', userDataPath);

let activePort = process.env.PORT ? parseInt(process.env.PORT, 10) : 8081;
let mainWindow = null;
let tray = null;
let agentServer = null;
let agentProcess = null;
let latestDownloadedVersion = null;
app.isQuitting = false;

// ---------------------------------------------------------------------------
// 1. SINGLE-INSTANCE LOCK & 100% AUTOMATIC TAKEOVER
// ---------------------------------------------------------------------------
const currentVersion = app.getVersion();
const currentExecPath = process.execPath;

const gotLock = app.requestSingleInstanceLock({
  pid: process.pid,
  version: currentVersion,
  execPath: currentExecPath,
  time: Date.now(),
});

if (!gotLock) {
  // Another instance holds the lock. Inspect running instance and execute takeover if needed.
  handleTakeoverOrExit();
} else {
  // We hold the lock. Listen for second-instance attempts.
  app.on('second-instance', (event, commandLine, workingDirectory, additionalData) => {
    if (additionalData) {
      const isDifferentExec = additionalData.execPath && additionalData.execPath.toLowerCase() !== currentExecPath.toLowerCase();
      const isDifferentVersion = additionalData.version && additionalData.version !== currentVersion;
      if (isDifferentExec || isDifferentVersion || additionalData.takeover) {
        console.log('🔄 Newer/different DevDeck instance launched. Gracefully retiring old instance for takeover...');
        shutdownAndQuit();
        return;
      }
    }

    // Exact same executable re-launched: restore and bring window to front
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.show();
      mainWindow.focus();
    }
  });

  // Proceed with normal application boot
  initializeApp();
}

function handleTakeoverOrExit() {
  const req = http.get(`http://localhost:${activePort}/api/status`, (res) => {
    let body = '';
    res.on('data', (chunk) => (body += chunk));
    res.on('end', () => {
      try {
        const data = JSON.parse(body);
        const isSameExec = data.execPath && data.execPath.toLowerCase() === currentExecPath.toLowerCase();
        const isSameVersion = data.version && data.version === currentVersion;

        // If the exact same executable is already running and active, the second-instance
        // event has already brought its window to front. Exit this duplicate cleanly.
        if (isSameExec && isSameVersion) {
          console.log('✅ Existing DevDeck instance is already active. Focusing window.');
          app.quit();
          process.exit(0);
          return;
        }
      } catch (e) {
        // Parse error or ancient build without version/execPath fields: force takeover
      }
      executeTakeover();
    });
  });

  req.on('error', () => {
    // Port 8081 is dead or unresponsive: force takeover to clean up any ghost lock
    executeTakeover();
  });

  req.setTimeout(600, () => {
    req.destroy();
    executeTakeover();
  });
}

function executeTakeover() {
  console.log('🔄 Automatic Takeover: Replacing old DevDeck background instance with new version...');

  // 1. Send graceful shutdown HTTP signal
  try {
    const shutReq = http.request(`http://localhost:${activePort}/api/shutdown`, { method: 'POST', timeout: 500 }, () => {});
    shutReq.on('error', () => {});
    shutReq.end();
  } catch (e) {}

  // 2. On Windows, terminate any conflicting older DevDeck Agent executables
  if (process.platform === 'win32') {
    try {
      execSync(`taskkill /F /FI "PID ne ${process.pid}" /IM "DevDeck Agent.exe" /IM "devdeck-agent.exe"`, { stdio: 'ignore' });
    } catch (e) {}

    // Free port 8081 if occupied
    try {
      execSync(`powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort ${activePort} -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }"`, { stdio: 'ignore' });
    } catch (e) {}
  }

  // 3. Wait briefly for OS socket/file lock release then relaunch this new instance
  setTimeout(() => {
    app.relaunch();
    app.exit(0);
  }, 400);
}

function shutdownAndQuit() {
  app.isQuitting = true;
  if (agentServer && typeof agentServer.stop === 'function') {
    try { agentServer.stop(); } catch (e) {}
  }
  if (agentProcess) {
    try { agentProcess.kill(); } catch (e) {}
  }
  app.quit();
  process.exit(0);
}

// ---------------------------------------------------------------------------
// 2. TRAY & ICON
// ---------------------------------------------------------------------------
function createTrayIcon() {
  const iconPath = path.join(__dirname, 'public', 'icon.png');
  if (fs.existsSync(iconPath)) {
    return nativeImage.createFromPath(iconPath).resize({ width: 16, height: 16 });
  }
  const size = 16;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#18181b" stroke="#3b82f6" stroke-width="2"/><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" fill="#10b981"/></svg>`;
  const base64 = Buffer.from(svg).toString('base64');
  return nativeImage.createFromDataURL(`data:image/svg+xml;base64,${base64}`);
}

function buildTrayMenu(updateVersion = null) {
  const items = [
    {
      label: 'Open Dashboard',
      click: () => {
        if (mainWindow) {
          mainWindow.show();
          mainWindow.focus();
        } else {
          createWindow();
        }
      },
    },
    { type: 'separator' },
    { label: `Status: Agent Active (:${activePort})`, enabled: false },
    { label: `Version: v${app.getVersion()}`, enabled: false },
  ];

  if (updateVersion) {
    items.push({ type: 'separator' });
    items.push({
      label: `✨ Restart & Install v${updateVersion}`,
      click: () => {
        if (autoUpdater) {
          app.isQuitting = true;
          autoUpdater.quitAndInstall(false, true);
        }
      },
    });
  } else if (app.isPackaged && autoUpdater) {
    items.push({ type: 'separator' });
    items.push({
      label: 'Check for Updates...',
      click: () => {
        autoUpdater.checkForUpdates().catch(() => {});
      },
    });
  }

  items.push({ type: 'separator' });
  items.push({
    label: 'Quit DevDeck Agent',
    click: () => {
      shutdownAndQuit();
    },
  });

  return Menu.buildFromTemplate(items);
}

function createTray() {
  const icon = createTrayIcon();
  tray = new Tray(icon);
  tray.setToolTip(`DevDeck Desktop Agent v${app.getVersion()} (:${activePort})`);
  tray.setContextMenu(buildTrayMenu());

  tray.on('click', () => {
    if (mainWindow) {
      if (mainWindow.isVisible()) {
        mainWindow.hide();
      } else {
        mainWindow.show();
        mainWindow.focus();
      }
    } else {
      createWindow();
    }
  });
}

function updateTrayWithUpdateAvailable(version) {
  latestDownloadedVersion = version;
  if (tray) {
    tray.setContextMenu(buildTrayMenu(version));
    tray.setToolTip(`DevDeck Agent - Update v${version} ready to install!`);
  }
}

// ---------------------------------------------------------------------------
// 3. SERVER BOOTSTRAP & LIFECYCLE
// ---------------------------------------------------------------------------
function waitForServer(url, timeoutMs = 8000) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    function ping() {
      http.get(url, (res) => {
        if (res.statusCode === 200) {
          return resolve();
        }
        retry();
      }).on('error', retry);
    }

    function retry() {
      if (Date.now() - start > timeoutMs) {
        return reject(new Error('Timeout waiting for DevDeck agent server'));
      }
      setTimeout(ping, 200);
    }

    ping();
  });
}

async function startAgentProcess() {
  // Check if port 8081 is currently listening
  const isRunning = await new Promise((resolve) => {
    const req = http.get(`http://localhost:${activePort}/api/status`, (res) => {
      resolve(res.statusCode === 200);
    });
    req.on('error', () => resolve(false));
    req.setTimeout(500, () => {
      req.destroy();
      resolve(false);
    });
  });

  if (isRunning) {
    if (app.isPackaged) {
      // In packaged app, an existing server is an old daemon/zombie process. Clean it up!
      console.log(`⚠️ Leftover agent server detected on port ${activePort}. Freeing port for fresh server...`);
      try {
        await new Promise((resolve) => {
          const req = http.request(`http://localhost:${activePort}/api/shutdown`, { method: 'POST', timeout: 600 }, resolve);
          req.on('error', resolve);
          req.end();
        });
      } catch (e) {}
      await new Promise((r) => setTimeout(r, 400));
    } else {
      console.log(`✅ Connected to existing DevDeck agent on port ${activePort}.`);
      return activePort;
    }
  }

  // Development mode: spawn standalone Node agent to match local Node ABI
  if (!app.isPackaged) {
    console.log('🚀 Development mode: spawning standalone Node agent process...');
    await new Promise((resolve) => spawnNodeAgent(resolve));
    return activePort;
  }

  // Packaged production: bootstrap in-process (or fallback to standalone)
  console.log('🚀 Starting DevDeck Agent server in production mode...');
  try {
    const { bootstrap } = require(path.join(__dirname, 'dist', 'index.js'));
    agentServer = await bootstrap();
    console.log(`✅ DevDeck Agent server started.`);
    return activePort;
  } catch (err) {
    console.warn('⚠️ In-process startup failed, falling back to standalone process:', err.message);
    await new Promise((resolve) => spawnNodeAgent(resolve));
    return activePort;
  }
}

function spawnNodeAgent(callback) {
  const entryScript = path.join(__dirname, 'dist', 'index.js');
  console.log('🚀 Spawning standalone Node agent process...');

  let nodeBin = 'node';
  const bundledNode = path.join(__dirname, 'bin', 'node.exe');
  if (app.isPackaged && fs.existsSync(bundledNode)) {
    nodeBin = bundledNode;
  }

  agentProcess = spawn(nodeBin, [entryScript], {
    cwd: __dirname,
    stdio: 'inherit',
    env: process.env,
  });

  agentProcess.on('error', (err) => {
    console.error('Failed to spawn agent process:', err);
  });

  waitForServer(`http://localhost:${activePort}/api/status`)
    .then(() => {
      console.log(`✅ Agent server is ready on port ${activePort}.`);
      callback();
    })
    .catch((err) => {
      console.error('Failed to connect to agent server:', err);
      callback();
    });
}

// ---------------------------------------------------------------------------
// 4. BROWSER WINDOW
// ---------------------------------------------------------------------------
function createWindow() {
  const iconPath = path.join(__dirname, 'public', 'icon.png');
  mainWindow = new BrowserWindow({
    width: 1060,
    height: 750,
    minWidth: 840,
    minHeight: 620,
    frame: false,
    backgroundColor: '#191D21',
    title: 'DevDeck Desktop Agent',
    icon: fs.existsSync(iconPath) ? iconPath : undefined,
    autoHideMenuBar: true,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
  });

  mainWindow.loadURL(`http://localhost:${activePort}`);

  // Minimize to tray on close
  mainWindow.on('close', (event) => {
    if (!app.isQuitting) {
      event.preventDefault();
      mainWindow.hide();
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

function broadcastToRenderer(channel, data) {
  if (mainWindow && !mainWindow.isDestroyed() && mainWindow.webContents) {
    mainWindow.webContents.send(channel, data);
  }
}

// ---------------------------------------------------------------------------
// 5. IN-APP AUTO-UPDATER
// ---------------------------------------------------------------------------
function setupAutoUpdater() {
  if (!autoUpdater || !app.isPackaged) {
    console.log('ℹ️ Auto-updater is disabled in development mode.');
    return;
  }

  autoUpdater.logger = console;
  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = true;

  autoUpdater.on('checking-for-update', () => {
    console.log('🔍 Checking for DevDeck updates...');
    broadcastToRenderer('update:status', { status: 'checking' });
  });

  autoUpdater.on('update-available', (info) => {
    console.log('✨ DevDeck update available:', info.version);
    broadcastToRenderer('update:status', {
      status: 'available',
      version: info.version,
    });
  });

  autoUpdater.on('update-not-available', (info) => {
    console.log('✅ DevDeck is up to date (v' + (info ? info.version : app.getVersion()) + ')');
    broadcastToRenderer('update:status', {
      status: 'up-to-date',
      version: app.getVersion(),
    });
  });

  autoUpdater.on('download-progress', (progressObj) => {
    const percent = Math.round(progressObj.percent);
    broadcastToRenderer('update:status', {
      status: 'downloading',
      percent: percent,
      bytesPerSecond: progressObj.bytesPerSecond,
    });
  });

  autoUpdater.on('update-downloaded', (info) => {
    console.log('🎉 Update downloaded:', info.version);
    broadcastToRenderer('update:status', {
      status: 'downloaded',
      version: info.version,
    });

    updateTrayWithUpdateAvailable(info.version);

    dialog
      .showMessageBox(mainWindow || undefined, {
        type: 'info',
        buttons: ['Restart & Install Now', 'Later'],
        defaultId: 0,
        cancelId: 1,
        title: 'DevDeck Update Ready',
        message: `DevDeck v${info.version} has been downloaded and is ready to install!`,
        detail: 'Restart now to apply the latest improvements and features.',
      })
      .then((result) => {
        if (result.response === 0) {
          app.isQuitting = true;
          autoUpdater.quitAndInstall(false, true);
        }
      });
  });

  autoUpdater.on('error', (err) => {
    console.warn('⚠️ Auto-updater check error:', err.message);
    broadcastToRenderer('update:status', { status: 'error', error: err.message });
  });

  // Check 5 seconds after startup
  setTimeout(() => {
    autoUpdater.checkForUpdates().catch((err) => {
      console.log('Initial background update check error:', err.message);
    });
  }, 5000);

  // Periodically check every 4 hours
  setInterval(() => {
    autoUpdater.checkForUpdates().catch(() => {});
  }, 4 * 60 * 60 * 1000);
}

// ---------------------------------------------------------------------------
// 6. IPC HANDLERS
// ---------------------------------------------------------------------------
ipcMain.on('window:minimize', () => {
  if (mainWindow) mainWindow.minimize();
});

ipcMain.on('window:maximize', () => {
  if (mainWindow) {
    if (mainWindow.isMaximized()) mainWindow.unmaximize();
    else mainWindow.maximize();
  }
});

ipcMain.on('window:close', () => {
  if (mainWindow) mainWindow.hide();
});

ipcMain.handle('app:get-version', () => {
  return app.getVersion();
});

ipcMain.handle('app:check-for-updates', async () => {
  if (autoUpdater && app.isPackaged) {
    try {
      const result = await autoUpdater.checkForUpdates();
      return { success: true, result };
    } catch (err) {
      return { success: false, error: err.message };
    }
  }
  return { success: false, message: 'Updates are only active in packaged release mode' };
});

ipcMain.handle('app:install-update', () => {
  if (autoUpdater && app.isPackaged) {
    app.isQuitting = true;
    autoUpdater.quitAndInstall(false, true);
    return { success: true };
  }
  return { success: false };
});

// ---------------------------------------------------------------------------
// 7. APP BOOTSTRAPPER
// ---------------------------------------------------------------------------
function initializeApp() {
  app.whenReady().then(async () => {
    await startAgentProcess();
    createWindow();
    createTray();
    setupAutoUpdater();

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) {
        createWindow();
      }
    });
  });

  app.on('before-quit', () => {
    app.isQuitting = true;
    if (agentServer && typeof agentServer.stop === 'function') {
      try {
        agentServer.stop();
      } catch (e) {}
    }
    if (agentProcess) {
      try {
        agentProcess.kill();
      } catch (e) {}
    }
  });

  app.on('window-all-closed', () => {
    // Stay running in tray
    if (process.platform === 'darwin') {
      app.dock.hide();
    }
  });
}
