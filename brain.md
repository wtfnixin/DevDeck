# DevDeck Brain — Project Context & Architecture

This document serves as the single source of truth for the **DevDeck** project. If you lose session history or need to onboard a new AI assistant, direct them to read this file to reconstruct the full context of the project.

---

## 1. Executive Summary & Core Concept

**DevDeck** is a customizable, open-source productivity remote control suite (similar to Elgato Stream Deck). It allows developers and power users to control their PC, trigger multi-step workspace workflows, synchronize clipboard history in real-time, launch desktop apps or websites, and control windows remotely using a mobile app, browser tab, or second device.

It consists of two main parts:
1. **Frontend Client**: A compilation-friendly mobile, web, and desktop application written in **Flutter (Dart)** using Clean Architecture and the BLoC pattern.
2. **Desktop Agent (Daemon/Backend)**: A high-performance, background service written in **Node.js (TypeScript)** using `socket.io` for WebSockets, and `better-sqlite3` for local database configuration. It runs headlessly on the host machine.

---

## 2. High-Level Architecture & Communication Flow

```
+------------------------------------+
|         Flutter Client             | (Mobile / Tablet / Browser / Windows)
|                                    |
| +--------------------------------+ |
| |  State (BLoC)                  | |
| +--------------------------------+ |
| |  Storage (Hive Secure Box)     | | <--- Stores IP, Port, and Pairing Session JWT
| +--------------------------------+ |
| |  Networking (Socket.io Client) | |
| +--------------------------------+ |
+------------------------------------+
                  |
     WebSocket Connection (Port 8081)
                  |
                  v
+------------------------------------+
|       Node.js Desktop Agent        | (Headless Background Daemon)
|                                    |
| +--------------------------------+ |
| |  Socket.io Server              | | <--- Manages sessions & routes remote keys
| +--------------------------------+ |
| |  SQLite Database (better-sqlite| | <--- Stores apps, websites, settings & history
| +--------------------------------+ |
| |  PowerShell Interop Layer      | | <--- Uses native Win32 APIs (Compiled in-memory)
| +--------------------------------+ |
+------------------------------------+
```

---

## 3. Directory Structure

### Root Workspace Layout
*   `lib/` — Flutter application source code.
    *   `core/` — Cross-cutting concerns (DI, Network, Routing, Theme, Storage).
    *   `features/` — Feature modules (Clean Architecture layout: authentication, clipboard, connection, dashboard, gestures, launcher, settings, workspace).
*   `desktop-agent/` — Desktop backend daemon source code.
    *   `src/` — TypeScript source files.
        *   `authentication/` — Pairing, JWT and verification services.
        *   `core/` — DB connection, schema definition, migrations, and winston logger configuration.
        *   `repositories/` — DB abstractions (e.g. trusted devices).
        *   `services/` — Business logic (app discovery, application registry, clipboard sync, website management, and workspace macro sequencing).
        *   `socket/` — WebSocket server initialization and centralized event handlers.
        *   `utils/` — Windows browser utility, process and window focusing helper scripts.
        *   `types/` — Shared interfaces.
    *   `lib-native/` — Precompiled SQLite wrapper modules (`.node`) for swap builds targeting different Node versions during standalone packaging.
    *   `installer.iss` — Inno Setup Script for building Windows installers.
    *   `build-exe.js` — Swapping script to bundle `.exe` for Node v22.
*   `.github/workflows/release.yml` — Automated CI/CD pipeline for builds.

---

## 4. SQLite Database Schema & Migrations

The Desktop Agent maintains configuration in a local SQLite file (`devdeck.db`) using native `better-sqlite3`. On startup, it runs migrations defined in `desktop-agent/src/core/database/schema.ts`.

### Schema Details
*   **`trusted_devices`**: Pair verification storage.
    *   `id TEXT PRIMARY KEY` (Device UUID)
    *   `name TEXT NOT NULL` (Friendly device name)
    *   `paired_at DATETIME DEFAULT CURRENT_TIMESTAMP`
    *   `last_connected_at DATETIME`
    *   `token_hash TEXT NOT NULL` (SHA256 signature associated with paired token)
*   **`apps`**: Shortcut applications.
    *   `id TEXT PRIMARY KEY`
    *   `name TEXT NOT NULL`
    *   `icon TEXT` (Base64 PNG cache generated on-demand)
    *   `executable_path TEXT NOT NULL`
    *   `category TEXT`
*   **`websites`**: Shortcut bookmarks.
    *   `id TEXT PRIMARY KEY`
    *   `name TEXT NOT NULL`
    *   `url TEXT NOT NULL`
    *   `icon TEXT` (Base64 or name icon reference)
*   **`workspaces`**: Group workflows/macros.
    *   `id TEXT PRIMARY KEY`
    *   `name TEXT NOT NULL`
    *   `icon TEXT`
    *   `description TEXT`
*   **`workspace_actions`**: Sequence steps for workspace execution.
    *   `id TEXT PRIMARY KEY`
    *   `workspace_id TEXT NOT NULL` (Foreign key pointing to `workspaces(id)` on delete cascade)
    *   `action_type TEXT NOT NULL` (`launch_app`, `launch_website`, `run_command`)
    *   `payload TEXT NOT NULL` (JSON-encoded string storing parameters e.g., command, url, app path)
    *   `sequence_order INTEGER NOT NULL`
*   **`gestures`**: Direct mapping links for remote swipe pad operations.
    *   `id TEXT PRIMARY KEY`
    *   `gesture_type TEXT UNIQUE NOT NULL` (`swipe_left`, `swipe_right`, `swipe_up`, `swipe_down`, `double_tap`, `long_press`)
    *   `action_type TEXT NOT NULL` (`run_command`, `launch_workspace`)
    *   `payload TEXT NOT NULL` (JSON-encoded string)
*   **`clipboard_history`**: Temporary desktop/mobile clipboard logs.
    *   `id TEXT PRIMARY KEY`, `content TEXT NOT NULL`, `source TEXT NOT NULL`, `timestamp INTEGER NOT NULL`
*   **`settings`**: Key-value settings store.
    *   `key TEXT PRIMARY KEY`, `value TEXT NOT NULL`

### Database Seeding Defaults
On empty database setup:
- Sets default system shortcuts: Notepad (`notepad.exe`), Calculator (`calc.exe`), Command Prompt (`cmd.exe`), and Task Manager (`taskmgr.exe`).
- Seeds default websites: Google, GitHub, YouTube, and ChatGPT.
- Sets default workspaces: "Developer Workspace" (Runs command `code` to launch VS Code, then opens links to GitHub and ChatGPT in default browser with half-second task delays).
- Configures default gesture macros:
    - **Swipe Left**: Minimize all application windows.
    - **Swipe Right**: Undo minimizing windows.
    - **Swipe Up**: Opens Windows Start Menu.
    - **Swipe Down**: Toggles Desktop visibility.
    - **Double Tap**: Triggers "Developer Workspace".
    - **Long Press**: Spawns system calculator (`calc.exe`).

---

## 5. WebSockets Socket.IO Protocol

Authentication is handled via handshake. The Socket.io client can connect with or without a token:
- **No Token / Invalid Token**: Handshake sets `socket.data.authenticated = false`. The client is isolated and only permitted to trigger `pairing:request` and `disconnect` events.
- **Valid Token**: Handshake sets `socket.data.authenticated = true`. Enables access to all control features.

### Unauthenticated Operations
1.  **`pairing:request`**: Spawns device pairing request.
    *   *Payload*: `{ deviceId: string, deviceName: string, pairingToken: string }`
    *   *Action*: Validates pairing token matching agent console. On success, persists device info inside Database, returns signed JWT and triggers connection status redirect.
    *   *Callback*: returns `{ success: true, token: string }` on success, or `{ success: false, error: string }`.
2.  **`connection:status`**: Broadcast node status state to client: `pairingRequired` if unauthenticated.

### Authenticated Operations
1.  **`clipboard:sync`**: Broadcasts text syncing.
    *   *Payload*: `{ content: string }`
    *   *Action*: Updates desktop system clipboard with new remote value.
2.  **`launcher:apps`**: Queries DB registered applications list.
    *   *Callback*: returns `{ success: true, apps: Array }` (where apps includes ID, Name, cached base64 icon data URI, command path, category).
3.  **`launcher:launch-app`**: Launches registered application on the PC.
    *   *Payload*: `{ id: string }`
    *   *Action*: Searches app registry, attempts to focus existing window via C# interop. If no process window matches, executes from executable path.
4.  **`launcher:register-app`**: Saves new custom app configuration.
    *   *Payload*: `{ id?, name, executablePath, category, icon? }`
    *   *Action*: Saves/updates to Database, extracts icon base64 asynchronously, emits `launcher:apps:updated` to all connected screens.
5.  **`launcher:scan-system-apps`**: Discovers running and installed programs.
    *   *Callback*: returns `{ success: true, running: Array, installed: Array }` where `running` retrieves active windows and `installed` queries registry patterns.
6.  **`launcher:extract-discovered-icon`**: Resolves icon base64 on-demand for list views.
    *   *Payload*: `{ path: string }`
    *   *Callback*: returns `{ success: true, icon: string }` where icon is the base64 data URI of the executable icon.
7.  **`launcher:delete-app`**: Removes app configuration.
    *   *Payload*: `{ id: string }`
8.  **`launcher:websites`**: Queries DB website lists.
    *   *Callback*: returns `{ success: true, websites: Array }`.
9.  **`launcher:launch-website`**: Launches web URL in default browser.
    *   *Payload*: `{ id: string }`
    *   *Action*: Uses C# Win32 focusing keywords extracted from URL domain. If browser window with matching title isn't running, spawns a new tab using standard browser runner.
10. **`launcher:register-website`**: Updates or creates website bookmarks.
    *   *Payload*: `{ id?, name, url, icon? }`
11. **`launcher:delete-website`**: Removes website entry.
    *   *Payload*: `{ id: string }`
12. **`workspace:list`**: Lists workspaces.
    *   *Callback*: returns `{ success: true, workspaces: Array }`.
13. **`workspace:execute`**: Executes workspace sequential actions.
    *   *Payload*: `{ id: string }`
14. **`workspace:register` / `workspace:delete`**: Mutate workspace layout arrays.
15. **`gesture:trigger`**: Triggers a gesture-bound action.
    *   *Payload*: `{ gestureType: string }` (e.g. `swipe_left`, `double_tap`)
16. **`system:volume-up` / `system:volume-down` / `system:volume-mute`**: Adjusts system audio levels or toggles silent status.
17. **`system:brightness-up` / `system:brightness-down`**: Modifies the Windows system screen brightness.

---

## 6. Windows Native System Integrations (The Magic)

DevDeck uses Node.js child process scripts executing customized, encoded PowerShell blocks containing dynamically compiled C# code (`Add-Type -TypeDefinition` or `-MemberDefinition`). This eliminates heavy C++ prebuild native packages and keeps the background agent extremely lightweight (< 30 MB).

### Key Native Mechanisms
1.  **EXE Icon Extracting (`PrivateExtractIcons` via C# assembly)**:
    - Escapes exe filepath strings.
    - Uses compiled Win32 C# Class `IconExtractor` inside PowerShell using `DllImport("user32.dll")` to invoke `PrivateExtractIcons` parameters.
    - Saves graphic to `System.Drawing.Icon`, extracts bitmap, writes PNG format byte array buffer to memory block, encodes to Base64, and returns to Node client with `data:image/png;base64,` prefix.
2.  **Smart Window Focusing (`SetForegroundWindow` / `ShowWindowAsync`)**:
    - Avoids spawning duplicate application instances.
    - Queries active process listing: `Get-Process | Where-Object { $_.MainWindowTitle }`.
    - Iterates keywords to find target match. If not matched by window title, queries process executables.
    - Compiles Win32 `SetForegroundWindow`, `ShowWindowAsync`, and `IsIconic` helpers.
    - If the matching target window is minimized (`IsIconic` is true), restores it using `ShowWindowAsync(hwnd, 9)` (SW_RESTORE) and brings it to foreground using `SetForegroundWindow(hwnd)`.
3.  **Active Clipboard Thread Polling**:
    - Runs polling loop inside `ClipboardService` every 1000ms.
    - Polls system clipboard using high-fidelity command wrapper to avoid formatting corruptions:
      `powershell.exe -NoProfile -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Get-Clipboard"`
    - If contents differ from last cached string, broadcasts `clipboard:sync` with payload `{ content, source: 'desktop' }`.
    - Mobile clip changes are written back by spawning:
      `[Console]::InputEncoding = [System.Text.Encoding]::UTF8; ... Set-Clipboard`
4.  **Gesture Key Emulation**:
    - Swipe triggers call Shell automation structures or Wscript Shell SendKeys triggers:
      - Show Desktop: `(New-Object -ComObject Shell.Application).MinimizeAll()`
      - Toggle menu: `$wsh = New-Object -ComObject Wscript.Shell; $wsh.SendKeys('^{ESC}')`
5.  **System Volume & Brightness Controls**:
    - Emulates media keyboard keys for Volume Up (`[char]175`), Volume Down (`[char]174`), and Mute (`[char]173`) using Wscript.Shell SendKeys.
    - Queries active screen brightness via `WmiMonitorBrightness` select and sets new value using WmiSetBrightness on compatible displays.

---

## 7. Frontend Client Platform (Flutter App)

### Technical Stack
*   State Container: `flutter_bloc` managing events & states.
*   Data Cache / Local DB: `Hive` for quick key-value read-writes of device credentials.
*   Routing Engine: `GoRouter` configuring routes:
    *   `/` -> `SplashPage` (Verifies host pairing credentials)
    *   `/pairing` -> `PairingPage` (Camera scanner for pairing QR or custom text inputs)
    *   `/dashboard` -> `DashboardPage` (Status trackers, clipboard synchronizer card)
    *   `/apps` -> `AppsLauncherPage` (Registered app grid, system apps discovery)
    *   `/websites` -> `WebsitesLauncherPage` (Registered URLs, favicon proxies)
    *   `/workspaces` -> `WorkspacesPage` (Workspace workflow orchestrator manager)
    *   `/gesture-pad` -> `GesturePadPage` (Clean trackpad dashboard catching touch inputs)
    *   `/settings` -> `SettingsPage` (Theme configs, disconnection)
    *   `/stream-deck` -> `StreamDeckPage` (Interactive layout imitating a physical Elgato screen panel grid with customizable shortcut keys)

---

## 8. Build & Packaging Environment

### Standalone Agent Creation (.exe)
Since the agent requires SQLite binaries, building a bundled executable requires swapping native modules before packaging:
1.  Run `npm run build` in `desktop-agent/` to compile TypeScript to JS.
2.  Execute `npm run build:exe` (which runs `build-exe.js` script):
    - Copy Node 22 native sqlite bindings: `better_sqlite3_node22.node` to target path `better_sqlite3.node` inside the Release directory.
    - Package application to build target: `npx @yao-pkg/pkg . --targets node22-win-x64 --output build/devdeck-agent.exe`.
    - Automatically restores local node execution bindings (`better_sqlite3_node24.node`) post-build.
3.  Compile installer: Execute `iscc desktop-agent/installer.iss` (requires Inno Setup). Installs executable to user AppData and configures startup execution keys.

### CI/CD Deployment Target (`.github/workflows/release.yml`)
- Triggered upon pushes towards tagging patterns (`v*`) or code updates on `main`.
- **Job 1 (Android)**: Set up Java SDK 17, pulls stable Flutter branch, executes standard tests, and builds APK via `flutter build apk --release`.
- **Job 2 (Windows)**: Set up Node.js environment, executes standard TypeScript compilation builds, builds Node 22 desktop executable using `pkg`, compiles setup packages using Inno Setup Compiler (`iscc`), and uploads artifacts.
- **Job 3 (Release Creator)**: Fetches compiled binary components and creates an automatic GitHub Release draft publishing `app-release.apk`, `devdeck-agent.exe`, and `DevDeckAgentSetup.exe` assets.
