const { app, BrowserWindow, Tray, Menu, nativeImage } = require('electron');
const path = require('path');
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
let agentProcess = null;
app.isQuitting = false;

// Create 16x16 tray icon
function createTrayIcon() {
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

function startAgentProcess() {
  return new Promise((resolve) => {
    // Check if server is already running (e.g. from terminal)
    http.get('http://localhost:8081/api/status', (res) => {
      if (res.statusCode === 200) {
        console.log('✅ Connected to existing DevDeck agent on port 8081.');
        return resolve();
      }
      spawnNodeAgent(resolve);
    }).on('error', () => {
      spawnNodeAgent(resolve);
    });
  });
}

function spawnNodeAgent(callback) {
  const entryScript = path.join(__dirname, 'dist', 'index.js');
  console.log('🚀 Spawning standalone Node agent process...');
  
  agentProcess = spawn('node', [entryScript], {
    cwd: __dirname,
    stdio: 'inherit',
    env: process.env,
  });

  agentProcess.on('error', (err) => {
    console.error('Failed to spawn agent process:', err);
  });

  waitForServer('http://localhost:8081/api/status')
    .then(() => {
      console.log('✅ Agent server is ready on port 8081.');
      callback();
    })
    .catch((err) => {
      console.error(err);
      callback(); // proceed to create window anyway
    });
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1060,
    height: 750,
    minWidth: 840,
    minHeight: 620,
    frame: false,
    backgroundColor: '#191D21',
    title: 'DevDeck Desktop Agent',
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

  mainWindow.loadURL('http://localhost:8081');

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
  tray.setToolTip('DevDeck Desktop Agent (Active :8081)');

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
    { label: 'Status: Agent Active (:8081)', enabled: false },
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
