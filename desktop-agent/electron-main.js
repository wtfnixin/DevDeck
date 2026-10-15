const { app, BrowserWindow, Tray, Menu, nativeImage } = require('electron');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { spawn } = require('child_process');

// Set distinct application name and user data directory to prevent singleton conflicts
app.setName('devdeck-agent');
const userDataPath = path.join(app.getPath('appData'), 'DevDeckAgentElectron');
app.setPath('userData', userDataPath);

// Enforce single instance lock
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
  process.exit(0);
}

let mainWindow = null;
let tray = null;
let agentServer = null;
let agentProcess = null;
let activePort = process.env.PORT ? parseInt(process.env.PORT, 10) : 8081;
app.isQuitting = false;

// Create 16x16 tray icon
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

// Poll server until ready
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
  // 1. Check if server is already running (e.g. from terminal or external daemon)
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
    console.log(`✅ Connected to existing DevDeck agent on port ${activePort}.`);
    return activePort;
  }

  // 2. In development (!app.isPackaged), spawn standalone Node agent to match Node ABI
  if (!app.isPackaged) {
    console.log('🚀 Development mode: spawning standalone Node agent process...');
    await new Promise((resolve) => spawnNodeAgent(resolve));
    return activePort;
  }

  // 3. In packaged production app, start agent in-process or fallback to standalone process
  console.log('🚀 Starting DevDeck Agent server...');
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

  // IPC controls for frameless window
  const { ipcMain } = require('electron');
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

function createTray() {
  const icon = createTrayIcon();
  tray = new Tray(icon);
  tray.setToolTip(`DevDeck Desktop Agent (Active :${activePort})`);

  const contextMenu = Menu.buildFromTemplate([
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
    { type: 'separator' },
    {
      label: 'Quit DevDeck Agent',
      click: () => {
        app.isQuitting = true;
        app.quit();
      },
    },
  ]);

  tray.setContextMenu(contextMenu);

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

app.on('second-instance', () => {
  if (mainWindow) {
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.show();
    mainWindow.focus();
  }
});

app.whenReady().then(async () => {
  await startAgentProcess();
  createWindow();
  createTray();

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
      console.log('Stopping agent server...');
      agentServer.stop();
    } catch (e) {
      // ignore
    }
  }
  if (agentProcess) {
    console.log('Terminating agent process...');
    agentProcess.kill();
  }
});

app.on('window-all-closed', () => {
  // Stay running in tray
  if (process.platform === 'darwin') {
    app.dock.hide();
  }
});
