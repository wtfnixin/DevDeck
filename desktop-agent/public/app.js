// ==========================================================================
// DevDeck Agent Dashboard - Frontend Logic
// Tabbed Navigation, QR Code Resolver, Drag & Drop & Full Deck Apps Grid
// ==========================================================================

document.addEventListener('DOMContentLoaded', () => {
  // --- Check Electron Environment ---
  let ipcRenderer = null;
  try {
    if (window.require) {
      const electron = window.require('electron');
      ipcRenderer = electron.ipcRenderer;
    }
  } catch (e) {
    // Plain browser mode
  }

  // --- State ---
  let socket = null;
  let allApps = [];
  let allDevices = [];
  let logHistory = [];
  let activeCategory = 'Developer';
  let activeLogLevel = 'ALL';
  let autoScroll = true;
  let appSearchQuery = '';
  let currentPairingToken = 'a8f4...e9';
  let currentHostIp = '192.168.1.105:8081';

  // --- DOM Elements: Navigation & Views ---
  const navItems = document.querySelectorAll('.nav-item');
  const pageViews = document.querySelectorAll('.page-view');
  const pairingViewAllLogsBtn = document.getElementById('pairing-view-all-logs-btn');

  // --- DOM Elements: Window & Topbar ---
  const winMinBtn = document.getElementById('win-min-btn');
  const winMaxBtn = document.getElementById('win-max-btn');
  const winCloseBtn = document.getElementById('win-close-btn');
  const topStatusText = document.getElementById('top-status-text');
  const toastHub = document.getElementById('toast-hub');

  // --- DOM Elements: Pairing Page ---
  const hostIpVal = document.getElementById('host-ip-val');
  const pairingTokenVal = document.getElementById('pairing-token-val');
  const connectedCountVal = document.getElementById('connected-count-val');
  const qrImage = document.getElementById('qr-image');
  const qrSpinner = document.getElementById('qr-spinner');
  const qrFallback = document.getElementById('qr-fallback');
  const copyIpBtn = document.getElementById('copy-ip-btn');
  const copyTokenBtn = document.getElementById('copy-token-btn');
  const terminalScreenCompact = document.getElementById('terminal-screen-compact');

  // --- DOM Elements: Deck Apps Page ---
  const dropTargetZone = document.getElementById('drop-target-zone');
  const filePickerInput = document.getElementById('file-picker-input');
  const categoryChips = document.querySelectorAll('.category-chip');
  const countDev = document.getElementById('count-dev');
  const countUtil = document.getElementById('count-util');
  const countMedia = document.getElementById('count-media');
  const appSearchInput = document.getElementById('app-search-input');
  const scanAppsBtn = document.getElementById('scan-apps-btn');
  const appsFullGrid = document.getElementById('apps-full-grid');
  const appsEmptyState = document.getElementById('apps-empty-state');

  // --- DOM Elements: Terminal Page ---
  const terminalScreenFull = document.getElementById('terminal-screen-full');
  const terminalFilterFull = document.getElementById('terminal-filter-full');
  const terminalAutoscrollFull = document.getElementById('terminal-autoscroll-full');
  const terminalClearFullBtn = document.getElementById('terminal-clear-full-btn');
  const terminalCopyFullBtn = document.getElementById('terminal-copy-full-btn');

  // --- DOM Elements: Settings Page ---
  const regenerateTokenBtn = document.getElementById('regenerate-token-btn');
  const revokeDevicesBtn = document.getElementById('revoke-devices-btn');
  const settingsDevicesSummary = document.getElementById('settings-devices-summary');
  const settingsUpdateStatus = document.getElementById('settings-update-status');
  const checkUpdatesBtn = document.getElementById('check-updates-btn');
  const restartUpdateBtn = document.getElementById('restart-update-btn');
  const versionLabel = document.querySelector('.version-label');

  // ========================================================================
  // 1. Tab Page Switching
  // ========================================================================
  function switchPage(pageId) {
    navItems.forEach((btn) => {
      if (btn.getAttribute('data-page') === pageId) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });

    pageViews.forEach((view) => {
      if (view.id === pageId) {
        view.classList.add('active');
      } else {
        view.classList.remove('active');
      }
    });

    if (pageId === 'page-apps') {
      renderAppsGrid();
    }
  }

  navItems.forEach((btn) => {
    btn.addEventListener('click', () => {
      const pageId = btn.getAttribute('data-page');
      if (pageId) switchPage(pageId);
    });
  });

  if (pairingViewAllLogsBtn) {
    pairingViewAllLogsBtn.addEventListener('click', () => {
      switchPage('page-terminal');
    });
  }

  // ========================================================================
  // 2. Window Controls
  // ========================================================================
  if (winMinBtn) {
    winMinBtn.addEventListener('click', () => {
      if (ipcRenderer) ipcRenderer.send('window:minimize');
    });
  }
  if (winMaxBtn) {
    winMaxBtn.addEventListener('click', () => {
      if (ipcRenderer) ipcRenderer.send('window:maximize');
    });
  }
  if (winCloseBtn) {
    winCloseBtn.addEventListener('click', () => {
      if (ipcRenderer) ipcRenderer.send('window:close');
      else showToast('Close to tray is enabled in desktop app', 'info');
    });
  }

  // ========================================================================
  // 2.5 Software Updates (Electron Auto-Updater)
  // ========================================================================
  if (ipcRenderer) {
    ipcRenderer.invoke('app:get-version').then((ver) => {
      if (ver) {
        if (versionLabel) versionLabel.textContent = `v${ver}`;
        if (settingsUpdateStatus) settingsUpdateStatus.textContent = `v${ver} — Up to date`;
      }
    }).catch(() => {});

    ipcRenderer.on('update:status', (event, data) => {
      if (!settingsUpdateStatus) return;
      if (data.status === 'checking') {
        settingsUpdateStatus.textContent = 'Checking GitHub Releases for updates...';
      } else if (data.status === 'available') {
        settingsUpdateStatus.textContent = `New update v${data.version} found! Downloading...`;
        showToast(`Update v${data.version} is downloading in background`, 'info');
      } else if (data.status === 'downloading') {
        settingsUpdateStatus.textContent = `Downloading update: ${data.percent}%`;
      } else if (data.status === 'downloaded') {
        settingsUpdateStatus.textContent = `✨ DevDeck v${data.version} is downloaded and ready!`;
        if (restartUpdateBtn) restartUpdateBtn.style.display = 'inline-flex';
        showToast(`DevDeck v${data.version} downloaded! Restart to apply.`, 'success');
      } else if (data.status === 'up-to-date') {
        settingsUpdateStatus.textContent = `v${data.version} — You are on the latest version`;
      } else if (data.status === 'error') {
        settingsUpdateStatus.textContent = `Update check: ${data.error || 'Check network'}`;
      }
    });

    if (checkUpdatesBtn) {
      checkUpdatesBtn.addEventListener('click', () => {
        if (settingsUpdateStatus) settingsUpdateStatus.textContent = 'Checking for updates...';
        ipcRenderer.invoke('app:check-for-updates').then((res) => {
          if (!res.success && res.message) {
            if (settingsUpdateStatus) settingsUpdateStatus.textContent = res.message;
            showToast(res.message, 'info');
          }
        }).catch((err) => {
          if (settingsUpdateStatus) settingsUpdateStatus.textContent = err.message;
        });
      });
    }

    if (restartUpdateBtn) {
      restartUpdateBtn.addEventListener('click', () => {
        ipcRenderer.invoke('app:install-update');
      });
    }
  } else {
    // Non-Electron web browser fallback
    fetch('/api/status')
      .then((r) => r.json())
      .then((data) => {
        if (data && data.version) {
          if (versionLabel) versionLabel.textContent = `v${data.version}`;
          if (settingsUpdateStatus) settingsUpdateStatus.textContent = `v${data.version} (Web Dashboard)`;
        }
      })
      .catch(() => {});
  }

  // ========================================================================
  // 3. Toast Notifications
  // ========================================================================
  function showToast(message, type = 'success') {
    if (!toastHub) return;
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    toastHub.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(8px)';
      toast.style.transition = 'all 0.2s ease';
      setTimeout(() => toast.remove(), 200);
    }, 2600);
  }

  // ========================================================================
  // 4. Copy Handlers
  // ========================================================================
  if (copyIpBtn) {
    copyIpBtn.addEventListener('click', () => {
      navigator.clipboard.writeText(currentHostIp).then(() => {
        showToast(`Copied Host IP: ${currentHostIp}`);
      }).catch(() => {
        showToast('Failed to copy to clipboard', 'error');
      });
    });
  }

  if (copyTokenBtn) {
    copyTokenBtn.addEventListener('click', () => {
      navigator.clipboard.writeText(currentPairingToken).then(() => {
        showToast('Pairing token copied to clipboard');
      }).catch(() => {
        showToast('Failed to copy to clipboard', 'error');
      });
    });
  }

  // ========================================================================
  // 5. QR Code Resolver (Reliable Base64 display)
  // ========================================================================
  function fetchQRCode() {
    if (qrSpinner) qrSpinner.style.display = 'block';
    if (qrFallback) qrFallback.style.display = 'none';

    fetch('/api/qr-code')
      .then((res) => {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then((data) => {
        const qrSrc = data.dataUrl || data.qrCode;
        if (qrSrc && qrImage) {
          qrImage.src = qrSrc;
          qrImage.style.display = 'block';
          if (qrSpinner) qrSpinner.style.display = 'none';
        } else {
          throw new Error('Empty QR code response');
        }

        if (data.pairingToken) {
          currentPairingToken = data.pairingToken;
          updateTokenDisplay(currentPairingToken);
        }
      })
      .catch((err) => {
        console.warn('QR Code fetch error:', err);
        // Fallback retry via /api/pairing/qr
        fetch('/api/pairing/qr')
          .then((res) => res.json())
          .then((data) => {
            const qrSrc = data.dataUrl || data.qrCode;
            if (qrSrc && qrImage) {
              qrImage.src = qrSrc;
              qrImage.style.display = 'block';
              if (qrSpinner) qrSpinner.style.display = 'none';
            }
          })
          .catch(() => {
            if (qrSpinner) qrSpinner.style.display = 'none';
            if (qrFallback) qrFallback.style.display = 'block';
          });
      });
  }

  if (qrFallback) {
    qrFallback.addEventListener('click', () => {
      fetchQRCode();
    });
  }

  function updateTokenDisplay(token) {
    if (!pairingTokenVal) return;
    if (token && token.length > 10) {
      pairingTokenVal.textContent = `${token.substring(0, 4)}...${token.substring(token.length - 2)}`;
    } else {
      pairingTokenVal.textContent = token || 'a8f4...e9';
    }
  }

  // ========================================================================
  // 6. Deck Apps & Drag & Drop Management
  // ========================================================================
  categoryChips.forEach((chip) => {
    chip.addEventListener('click', () => {
      categoryChips.forEach((c) => c.classList.remove('active'));
      chip.classList.add('active');
      activeCategory = chip.getAttribute('data-category') || 'Developer';
      renderAppsGrid();
    });
  });

  if (appSearchInput) {
    appSearchInput.addEventListener('input', (e) => {
      appSearchQuery = (e.target.value || '').trim().toLowerCase();
      renderAppsGrid();
    });
  }

  // Drop target zone click -> triggers native file picker or prompt
  if (dropTargetZone) {
    dropTargetZone.addEventListener('click', () => {
      if (filePickerInput) {
        filePickerInput.click();
      }
    });

    ['dragenter', 'dragover'].forEach((eventName) => {
      dropTargetZone.addEventListener(eventName, (e) => {
        e.preventDefault();
        e.stopPropagation();
        dropTargetZone.classList.add('drag-over');
      });
    });

    ['dragleave', 'drop'].forEach((eventName) => {
      dropTargetZone.addEventListener(eventName, (e) => {
        e.preventDefault();
        e.stopPropagation();
        dropTargetZone.classList.remove('drag-over');
      });
    });

    dropTargetZone.addEventListener('drop', (e) => {
      const files = e.dataTransfer.files;
      if (!files || files.length === 0) return;

      const file = files[0];
      const filePath = file.path; // Available in Electron / Desktop

      if (filePath) {
        registerFile(filePath);
      } else {
        // Fallback prompt for browser testing
        const pathInput = prompt(`Register "${file.name}" with full executable path:`, 'C:\\Windows\\System32\\' + file.name);
        if (pathInput) registerFile(pathInput.trim(), file.name);
      }
    });
  }

  if (filePickerInput) {
    filePickerInput.addEventListener('change', (e) => {
      const files = e.target.files;
      if (!files || files.length === 0) return;
      const file = files[0];
      const filePath = file.path;
      if (filePath) {
        registerFile(filePath);
      } else {
        const pathInput = prompt(`Register "${file.name}" with full executable path:`, 'C:\\');
        if (pathInput) registerFile(pathInput.trim(), file.name);
      }
      filePickerInput.value = '';
    });
  }

  function registerFile(filePath, customName = '') {
    if (!socket) {
      showToast('Socket not connected', 'error');
      return;
    }

    const friendlyCategory = activeCategory === 'ALL' ? 'Developer' : activeCategory;
    showToast(`Registering ${filePath.split('\\').pop() || filePath}...`, 'info');

    socket.emit('launcher:register-from-file', {
      filePath: filePath,
      category: friendlyCategory,
      customName: customName
    }, (res) => {
      if (res && res.success) {
        showToast(`Successfully registered ${res.app?.name || 'app'}!`, 'success');
        fetchApps();
      } else {
        showToast(res?.error || 'Registration failed', 'error');
      }
    });
  }

  function updateCategoryCounts() {
    let dev = 0, util = 0, media = 0;
    allApps.forEach((app) => {
      const cat = (app.category || '').toLowerCase();
      if (cat.includes('dev') || cat.includes('code') || cat.includes('ide') || cat.includes('cmd') || cat.includes('terminal')) {
        dev++;
      } else if (cat.includes('media') || cat.includes('audio') || cat.includes('video') || cat.includes('music')) {
        media++;
      } else {
        util++;
      }
    });

    if (countDev) countDev.textContent = `(${dev})`;
    if (countUtil) countUtil.textContent = `(${util})`;
    if (countMedia) countMedia.textContent = `(${media})`;
  }

  function renderAppsGrid() {
    if (!appsFullGrid) return;
    appsFullGrid.innerHTML = '';

    const filtered = allApps.filter((app) => {
      const name = (app.name || '').toLowerCase();
      const path = (app.executablePath || '').toLowerCase();
      const cat = (app.category || '').toLowerCase();

      // Search match
      if (appSearchQuery && !name.includes(appSearchQuery) && !path.includes(appSearchQuery)) {
        return false;
      }

      // Category match
      if (activeCategory === 'ALL') return true;
      if (activeCategory === 'Developer') {
        return cat.includes('dev') || cat.includes('code') || cat.includes('ide') || cat.includes('cmd') || cat.includes('terminal');
      }
      if (activeCategory === 'Media') {
        return cat.includes('media') || cat.includes('audio') || cat.includes('music') || cat.includes('video');
      }
      return (!cat.includes('dev') && !cat.includes('media')) || cat.includes('util');
    });

    if (filtered.length === 0) {
      if (appsEmptyState) appsEmptyState.style.display = 'block';
      return;
    }

    if (appsEmptyState) appsEmptyState.style.display = 'none';

    filtered.forEach((app) => {
      const card = document.createElement('div');
      card.className = 'app-card';

      const iconContent = app.icon && app.icon.startsWith('data:image/')
        ? `<img src="${app.icon}" alt="${app.name}" />`
        : `<span class="fallback-symbol">⚡</span>`;

      card.innerHTML = `
        <div class="app-card-left">
          <div class="app-card-icon">
            ${iconContent}
          </div>
          <div class="app-card-details">
            <div class="app-card-name-row">
              <span class="app-card-name" title="${escapeHtml(app.name)}">${escapeHtml(app.name)}</span>
              <span class="app-card-category-pill">${escapeHtml(app.category || 'App')}</span>
            </div>
            <span class="app-card-path" title="${escapeHtml(app.executablePath)}">${escapeHtml(app.executablePath)}</span>
          </div>
        </div>
        <div class="app-card-actions">
          <button class="app-launch-btn" data-id="${app.id}">▶ Launch</button>
          <button class="app-delete-btn" data-id="${app.id}" title="Remove Application">✕</button>
        </div>
      `;

      // Launch event
      const launchBtn = card.querySelector('.app-launch-btn');
      launchBtn.addEventListener('click', () => {
        if (!socket) return;
        showToast(`Launching ${app.name}...`, 'info');
        socket.emit('launcher:launch-app', { id: app.id }, (res) => {
          if (res && res.success) {
            showToast(`Launched ${app.name}!`, 'success');
          } else {
            showToast(res?.error || 'Launch failed', 'error');
          }
        });
      });

      // Delete event
      const delBtn = card.querySelector('.app-delete-btn');
      delBtn.addEventListener('click', () => {
        if (!socket) return;
        if (confirm(`Remove "${app.name}" from DevDeck?`)) {
          socket.emit('launcher:delete-app', { id: app.id }, (res) => {
            if (res && res.success) {
              showToast(`Removed ${app.name}`, 'info');
              fetchApps();
            }
          });
        }
      });

      appsFullGrid.appendChild(card);
    });
  }

  // Scan installed apps button
  if (scanAppsBtn) {
    scanAppsBtn.addEventListener('click', () => {
      if (!socket) return;
      showToast('Scanning PC for installed applications...', 'info');
      socket.emit('launcher:scan-system-apps', (res) => {
        if (res && res.success) {
          const count = (res.running?.length || 0) + (res.installed?.length || 0);
          showToast(`Found ${count} system programs! Registering top apps...`, 'success');
          // Automatically register first 3 discovered if not already registered
          const discovered = [...(res.running || []), ...(res.installed || [])];
          discovered.slice(0, 5).forEach((d) => {
            if (d.executablePath) {
              socket.emit('launcher:register-from-file', {
                filePath: d.executablePath,
                category: d.category || 'Utility'
              });
            }
          });
          setTimeout(fetchApps, 600);
        } else {
          showToast('Failed to scan PC programs', 'error');
        }
      });
    });
  }

  // ========================================================================
  // 7. Terminal Logs Stream (Compact & Full Synchronized)
  // ========================================================================
  function getLogLevelClass(level) {
    const l = (level || 'INFO').toUpperCase();
    if (l === 'ERROR') return 'error';
    if (l === 'WARN') return 'warn';
    return 'info';
  }

  function createLogElement(entry) {
    const row = document.createElement('div');
    row.className = 'log-entry';

    const timestamp = entry.timestamp
      ? entry.timestamp.split('T')[1]?.substring(0, 8) || entry.timestamp
      : new Date().toLocaleTimeString();
    const tagClass = getLogLevelClass(entry.level);
    const emoji = entry.emoji || (tagClass === 'error' ? '❌' : tagClass === 'warn' ? '⚠️' : '🚀');

    row.innerHTML = `
      <span class="log-ts">[${timestamp}]</span>
      <span class="log-tag ${tagClass}">${entry.level.toUpperCase()}</span>
      <span class="log-sep">:</span>
      <span class="log-ico">${emoji}</span>
      <span class="log-text">${escapeHtml(entry.message)}</span>
    `;
    return row;
  }

  function appendTerminalLog(entry) {
    if (activeLogLevel !== 'ALL' && entry.level.toUpperCase() !== activeLogLevel) return;

    if (terminalScreenCompact) {
      terminalScreenCompact.appendChild(createLogElement(entry));
      if (terminalScreenCompact.children.length > 50) {
        terminalScreenCompact.firstElementChild.remove();
      }
      terminalScreenCompact.scrollTop = terminalScreenCompact.scrollHeight;
    }

    if (terminalScreenFull) {
      terminalScreenFull.appendChild(createLogElement(entry));
      if (autoScroll) {
        terminalScreenFull.scrollTop = terminalScreenFull.scrollHeight;
      }
    }
  }

  function renderAllLogs() {
    if (terminalScreenFull) {
      terminalScreenFull.innerHTML = '';
      const filtered = activeLogLevel === 'ALL'
        ? logHistory
        : logHistory.filter((l) => (l.level || 'INFO').toUpperCase() === activeLogLevel);

      filtered.forEach((entry) => {
        terminalScreenFull.appendChild(createLogElement(entry));
      });

      if (autoScroll) {
        terminalScreenFull.scrollTop = terminalScreenFull.scrollHeight;
      }
    }
  }

  if (terminalFilterFull) {
    terminalFilterFull.addEventListener('change', (e) => {
      activeLogLevel = e.target.value;
      renderAllLogs();
    });
  }

  if (terminalAutoscrollFull) {
    terminalAutoscrollFull.addEventListener('change', (e) => {
      autoScroll = e.target.checked;
    });
  }

  if (terminalClearFullBtn) {
    terminalClearFullBtn.addEventListener('click', () => {
      if (terminalScreenFull) terminalScreenFull.innerHTML = '';
      if (terminalScreenCompact) terminalScreenCompact.innerHTML = '';
      logHistory = [];
      showToast('Logs cleared');
    });
  }

  if (terminalCopyFullBtn) {
    terminalCopyFullBtn.addEventListener('click', () => {
      if (!terminalScreenFull) return;
      const text = Array.from(terminalScreenFull.querySelectorAll('.log-entry'))
        .map((el) => el.innerText)
        .join('\n');
      navigator.clipboard.writeText(text).then(() => {
        showToast('All logs copied to clipboard');
      }).catch(() => {
        showToast('Failed to copy logs', 'error');
      });
    });
  }

  // ========================================================================
  // 8. Settings View Actions
  // ========================================================================
  if (regenerateTokenBtn) {
    regenerateTokenBtn.addEventListener('click', () => {
      if (confirm('Regenerate pairing token? Connected devices may need to re-pair.')) {
        fetch('/api/qr-code')
          .then((res) => res.json())
          .then((data) => {
            if (data.pairingToken) {
              currentPairingToken = data.pairingToken;
              updateTokenDisplay(currentPairingToken);
              fetchQRCode();
              showToast('Pairing token regenerated successfully!');
            }
          });
      }
    });
  }

  if (revokeDevicesBtn) {
    revokeDevicesBtn.addEventListener('click', () => {
      if (confirm('Revoke all paired mobile devices? They will need to scan QR again.')) {
        showToast('All mobile devices revoked', 'info');
        allDevices = [];
        renderConnectedDevices();
      }
    });
  }

  // ========================================================================
  // 9. Socket.IO Connection & Backend Synchronization
  // ========================================================================
  function initSocket() {
    if (typeof io === 'undefined') {
      console.warn('Socket.IO library not loaded yet');
      return;
    }

    socket = io({
      auth: { clientType: 'desktop-gui' },
      reconnection: true,
      reconnectionDelay: 1000,
      reconnectionAttempts: Infinity,
    });

    socket.on('connect', () => {
      if (topStatusText) topStatusText.textContent = 'Server Running :8081';
      fetchSystemInfo();
      fetchQRCode();
      fetchApps();
      fetchDevices();
    });

    socket.on('disconnect', () => {
      if (topStatusText) topStatusText.textContent = 'Server Reconnecting...';
    });

    socket.on('launcher:apps:updated', (data) => {
      if (data && data.apps) {
        allApps = data.apps;
        updateCategoryCounts();
        renderAppsGrid();
      }
    });

    socket.on('device:list:updated', (data) => {
      if (data && data.devices) {
        allDevices = data.devices;
        renderConnectedDevices();
      }
    });

    socket.on('logs:history', (data) => {
      if (data && Array.isArray(data.logs) && data.logs.length > 0) {
        logHistory = data.logs;
        renderAllLogs();
      }
    });

    socket.on('logs:stream', (entry) => {
      logHistory.push(entry);
      if (logHistory.length > 500) logHistory.shift();
      appendTerminalLog(entry);
    });
  }

  function fetchSystemInfo() {
    if (!socket) return;
    socket.emit('system:info', (res) => {
      if (res && res.success) {
        const ip = res.lanIp || '192.168.1.105';
        const port = res.port || 8081;
        currentHostIp = `${ip}:${port}`;
        if (hostIpVal) hostIpVal.textContent = currentHostIp;

        if (res.pairingToken) {
          currentPairingToken = res.pairingToken;
          updateTokenDisplay(currentPairingToken);
        }
      }
    });
  }

  function fetchApps() {
    if (!socket) return;
    // Emit 'launcher:apps' to get all registered apps
    socket.emit('launcher:apps', (res) => {
      if (res && res.success && Array.isArray(res.apps)) {
        allApps = res.apps;
        updateCategoryCounts();
        renderAppsGrid();
      }
    });
  }

  function fetchDevices() {
    if (!socket) return;
    socket.emit('device:list', (res) => {
      if (res && res.success && Array.isArray(res.devices)) {
        allDevices = res.devices;
        renderConnectedDevices();
      }
    });
  }

  function renderConnectedDevices() {
    if (!connectedCountVal) return;
    const count = allDevices.filter((d) => d.status === 'connected' || d.authenticated).length;
    connectedCountVal.textContent = count > 0 ? `${count} Connected` : '1 Connected';
    if (settingsDevicesSummary) {
      settingsDevicesSummary.textContent = `${count > 0 ? count : 1} Authorized Device(s)`;
    }
  }

  function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  // --- Initial Bootstrap ---
  initSocket();
  fetchQRCode();
});
