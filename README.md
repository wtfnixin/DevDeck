# DevDeck ⚡

[![Latest Release](https://img.shields.io/github/v/release/wtfnixin/DevDeck?style=flat-square&color=55B9AA)](https://github.com/wtfnixin/DevDeck/releases/latest)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](CONTRIBUTING.md)
[![Good First Issues](https://img.shields.io/badge/issues-good%20first%20issue-7057ff?style=flat-square)](https://github.com/wtfnixin/DevDeck/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)

DevDeck is a customizable, open-source productivity remote control suite (an open alternative to the Elgato Stream Deck). It allows developers and power users to control their PC, trigger complex workspace workflows, sync clipboard history in real-time, launch apps/websites, and control their desktop remotely using a mobile app, browser tab, or second device.

### 📥 Downloads

| Platform | Download Link | File |
| :--- | :--- | :--- |
| **Android Client** | [Download APK](https://github.com/wtfnixin/DevDeck/releases/latest/download/DevDeck.apk) | `DevDeck.apk` |
| **Windows Desktop Agent (Installer)** | [Download Setup](https://github.com/wtfnixin/DevDeck/releases/latest/download/DevDeckAgentSetup.exe) | `DevDeckAgentSetup.exe` |
| **Windows Desktop Agent (Standalone)** | [Download Executable](https://github.com/wtfnixin/DevDeck/releases/latest/download/devdeck-agent.exe) | `devdeck-agent.exe` |

---

## 🚀 Latest Updates (v1.1.0)
* **Physical Hardware Deck Aesthetic**: 3D recessed keycaps and pagination controls.
* **Icon-First Launchers**: Cleaned up button faces and centered icons without cluttered text.
* **Desktop Agent Port `8081`**: Avoids Windows system service conflicts on `8080`.
* **AppData Persistence**: Config and logs properly stored in `%APPDATA%\DevDeck`.

---


## Key Features

*   **Secure Device Pairing**: Instant connection setup using scanned QR Codes. No manual IP typing required.
*   **Developer Workspace Flows**: Define custom macros and workspace launch sequences (e.g., launch a specific IDE, run a database server command, and open your project's GitHub repo in one tap).
*   **Application Launcher**: Add any native PC executable and launch it remotely. DevDeck automatically extracts and streams the application's icon to the client.
*   **Website Launcher**: Open bookmarked websites in your default browser. Features an integrated proxy that fetches the high-res favicon automatically.
*   **Bidirectional Live Clipboard**: Instantly share clipboard contents between your mobile device and your desktop in the background.
*   **Virtual Gesture Pad**: A remote trackpad supporting custom gesture bindings:
    *   **Double Tap**: Configurable action.
    *   **Long Press**: Context trigger.
    *   **Swipe Gestures (Left/Right/Up/Down)**: Run system hotkeys (e.g., minimize windows, open Start Menu, undo actions).

---

## Architecture

*   **Frontend Client**: Built with **Flutter (Dart)** using the BLoC pattern. Targets Android (native APK), Web, and Windows.
*   **Desktop Agent (Backend)**: Built with **Node.js (TypeScript)** using `socket.io` for WebSockets, and `better-sqlite3` for local configurations. It runs headlessly in the background, consuming less than 30MB of RAM (no heavy Electron wrapper needed).

---

## 🔒 Security & Privacy: Local-First by Design

DevDeck is engineered with a strict **local-first, privacy-by-design** philosophy. Unlike commercial macro controllers that require cloud accounts, background telemetry, or external servers:

*   **🏠 100% Local Network (LAN Only)**: All communication between your mobile client and your desktop happens strictly within your local Wi-Fi / Ethernet network via WebSocket. No traffic ever leaves your home network.
*   **🚫 Zero Cloud & Zero Telemetry**: DevDeck contains no analytics, tracking scripts, ad SDKs, or cloud relays. We do not collect, transmit, or store your personal data anywhere.
*   **💾 Local Storage Only**: Your custom workspaces, pinned apps, gestures, and paired device records are stored exclusively on your own machine in a local SQLite database (`devdeck.db`).
*   **🔐 Cryptographic Device Pairing**: Connections use ephemeral tokens and HMAC-signed JWTs generated dynamically via encrypted QR codes. Unauthenticated network requests are rejected automatically.
*   **📋 Secure Live Clipboard**: Clipboard sharing operates peer-to-peer over your local network and is never logged or uploaded to any third party.

---

## ⚡ Runtime Performance & Application Footprint

DevDeck is built to be ultra-lean and instantaneous, avoiding the bloat and sluggishness of heavy commercial background utilities.

### Resource Usage & Latency

| Metric | DevDeck Specification | Benefit |
| :--- | :--- | :--- |
| **Idle CPU Usage** | **0.0% – 0.1%** | Event-driven WebSocket architecture; zero polling loops. |
| **Desktop Agent RAM** | **< 30 MB** (headless background mode) | Runs silently in the background without hogging system memory. |
| **Action Execution Latency** | **< 85 ms** | Native Win32 C# micro-binaries bypass slow PowerShell interpreters. |
| **Window Activation Speed** | **~50 ms** | Restores and focuses existing windows natively. |

### Application & Binary Sizes

| Package | Typical Size | Description |
| :--- | :--- | :--- |
| **Android Client (`DevDeck.apk`)** | **~25 – 35 MB** | Complete mobile client with CameraX QR scanner, ML Kit, and responsive 3D deck. |
| **Windows Standalone (`devdeck-agent.exe`)** | **~80 MB** | Self-contained executable with embedded Node 22 runtime and SQLite (no Node.js installation needed). |
| **Windows Setup Installer (`DevDeckAgentSetup.exe`)** | **~20 MB** | High-efficiency LZMA compressed installer created via Inno Setup. |
| **Native Win32 Micro-Helpers** | **~5.5 KB each** | Standalone C# helper binaries (`window-focus.exe`, `brightness-control.exe`). |

---

## Getting Started (Development Mode)

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest version)
*   [Node.js](https://nodejs.org/) (v20+ recommended)`   

---

### Step 1: Start the Desktop Agent
1. Navigate to the `desktop-agent` folder:
   ```bash
   cd desktop-agent
   ```
2. Install the node packages:
   ```bash
   npm install
   ```
3. Run the agent in developer mode:
   ```bash
   npm run dev
   ```
   *The agent will spin up on port `8081` and output the active pairing QR code inside the terminal.*

---

### Step 2: Launch the Client App
1. Open the project root in your terminal.
2. Launch the Flutter application:
   ```bash
   flutter run -d chrome
   ```
   *(Or target an emulator/connected Android device).*
3. Scan the terminal's QR code (or upload the generated QR PNG) inside the client application to pair the devices securely.

---

## Building Standalone Production Releases

### 1. Compile the Standalone Desktop Agent (.exe)
You can package the Node.js agent into a single binary that doesn't require Node.js or npm to be installed on the destination PC.

1. Navigate to `desktop-agent` and build the source:
   ```bash
   npm run build
   ```
2. Recompile the SQLite native addon for Node 22 (the packaged target):
   ```bash
   npx prebuild-install --target=22.0.0 --platform=win32 --arch=x64 --runtime=node
   ```
3. Bundle the application into a standalone executable:
   ```bash
   npx @yao-pkg/pkg . --targets node22-win-x64 --output build/devdeck-agent.exe
   ```
*   **Result location**: `desktop-agent/build/devdeck-agent.exe`
*   *Note: On first startup, the `.exe` will automatically generate a persistent `.env` file next to itself with a secure `JWT_SECRET` key.*

### 2. Build the Android Client (APK)
1. Ensure your local PC has the [Android SDK](https://developer.android.com/studio) installed.
2. Ensure the ProGuard configuration (`android/app/proguard-rules.pro`) is present to prevent the R8 shrinker from removing CameraX and Google ML Kit modules during optimization.
3. Compile the release build:
   ```bash
   flutter build apk --release
   ```
*   **Result location**: `build/app/outputs/flutter-apk/app-release.apk` (packaged as `DevDeck.apk`)

---

## Creating Windows Installers

Once you've built `devdeck-agent.exe`, you can package it into a setup installer using these methods:

### Method A: Windows Built-in Installer Wizard (IExpress)
1. Press `Win + R`, type `iexpress`, and press Enter.
2. Select **Create new Self Extraction Directive file** -> **Extract files and run an installation command**.
3. Add `devdeck-agent.exe` as your package file.
4. Set the installation run command to: `devdeck-agent.exe`.
5. Save the output package as `DevDeckSetup.exe`.

### Method B: PowerShell Script Installer
Create an `install.ps1` script next to the executable:
```powershell
$InstallDir = "$env:USERPROFILE\AppData\Local\DevDeckAgent"
if (!(Test-Path $InstallDir)) { New-Item -ItemType Directory -Force -Path $InstallDir }
Copy-Item "devdeck-agent.exe" -Destination "$InstallDir\devdeck-agent.exe" -Force
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\DevDeckAgent.lnk")
$Shortcut.TargetPath = "$InstallDir\devdeck-agent.exe"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Save()
Write-Host "DevDeck Agent successfully installed to AppData and added to Startup!"
```

### Method C: Inno Setup Wizard
If you have **Inno Setup** installed, compile the `installer.iss` script to generate a standard installer:
```ini
[Setup]
AppName=DevDeck Desktop Agent
AppVersion=1.0.0
DefaultDirName={userpf}\DevDeckAgent
DefaultGroupName=DevDeck
OutputDir=build
OutputBaseFilename=DevDeckAgentSetup
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\devdeck-agent.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\DevDeck Agent"; Filename: "{app}\devdeck-agent.exe"
Name: "{userstartup}\DevDeck Agent"; Filename: "{app}\devdeck-agent.exe"
```

---

## 🤝 Contributing & Community

We love contributions! DevDeck is built by developers for developers. Whether you want to fix a bug, add a macro action, or polish the docs, we welcome your help:

* 📖 Check out our [Contributing Guide (CONTRIBUTING.md)](CONTRIBUTING.md) to get your local environment running.
* 🏷️ Browse our [Good First Issues](https://github.com/wtfnixin/DevDeck/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) for beginner-friendly tasks.
* 📜 Read our [Code of Conduct (CODE_OF_CONDUCT.md)](CODE_OF_CONDUCT.md).
* 🔒 Review our [Security Policy (SECURITY.md)](SECURITY.md).

*Once your pull request is reviewed and merged into `main`, our CI/CD pipeline will automatically run all tests, build the Android APK, package the Windows installer, and publish a new production release!*

