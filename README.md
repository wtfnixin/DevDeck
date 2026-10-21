<p align="center">
  <img src="assets/devdeck-logo-horizontal.webp" alt="DevDeck Logo" width="340">
</p>

<p align="center">
  <strong>Customizable, local-first productivity deck and remote control ecosystem for developers.</strong>
</p>

<p align="center">
  <a href="https://github.com/wtfnixin/DevDeck/releases/latest"><img src="https://img.shields.io/github/v/release/wtfnixin/DevDeck?style=flat-square&color=55B9AA" alt="Latest Release"></a>
  <a href="https://github.com/wtfnixin/DevDeck/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/wtfnixin/DevDeck/release.yml?branch=main&style=flat-square&label=CI%2FCD&color=55B9AA" alt="Build Status"></a>
  <a href="CONTRIBUTING.md"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square" alt="PRs Welcome"></a>
  <a href="https://github.com/wtfnixin/DevDeck/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22"><img src="https://img.shields.io/badge/issues-good%20first%20issue-7057ff?style=flat-square" alt="Good First Issues"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License: MIT"></a>
</p>

---

DevDeck is an open-source productivity remote control suite designed as an extensible, privacy-focused alternative to dedicated macro pads. It transforms smartphones, tablets, or secondary browser tabs into interactive control surfaces for your workstation.

Trigger multi-step workspace routines, launch desktop software with automatically extracted high-resolution icons, bookmark URLs, synchronize system clipboards bidirectionally, and control cursor navigation through a multi-touch gesture pad—operating strictly over your local area network without external cloud services or telemetry.

---

## Downloads

| Platform | Package | Type | Direct Download |
| :--- | :--- | :--- | :--- |
| **Android** | `DevDeck.apk` | Client Application | [Download APK](https://github.com/wtfnixin/DevDeck/releases/latest/download/DevDeck.apk) |
| **Windows** | `DevDeckAgentSetup.exe` | Installer (Recommended) | [Download Setup](https://github.com/wtfnixin/DevDeck/releases/latest/download/DevDeckAgentSetup.exe) |
| **Windows** | `devdeck-agent.exe` | Portable Executable | [Download Binary](https://github.com/wtfnixin/DevDeck/releases/latest/download/devdeck-agent.exe) |

> [!NOTE]
> The setup installer (`DevDeckAgentSetup.exe`) enables automatic in-app updates and Windows Start Menu registration. The portable binary runs directly from any location without installation.

---

## Features

### Desktop GUI & Background Daemon
* **Dark Interface:** Electron-based dashboard with real-time status reporting, port monitoring, and paired client counters.
* **System Tray Integration:** Minimizes cleanly to the Windows system tray to maintain background macro execution while keeping the taskbar clear.
* **Single-Instance Enforcement:** Automatically detects existing running instances and performs clean takeover without port conflicts.

### In-App Auto-Updater
* **Continuous Updates:** Native integration with `electron-updater` and GitHub Releases.
* **In-App Notification:** Verifies updates silently in the background and provides an explicit "Restart & Update" flow via the Settings panel.

### Deck Apps Manager
* **Drag-and-Drop Binding:** Drop executable binaries (`.exe`) or shortcuts directly into the agent interface to register them as macros.
* **Automatic Icon Extraction:** Extracts high-resolution executable icons and serves them directly over WebSockets to client devices.

### Bidirectional Clipboard Synchronization
* **Cross-Device Clipboard:** Copies content between your workstation and connected mobile device in real time.
* **History Inspector:** Inspect recent clipboard entries from the desktop interface with quick-copy and history purging capabilities.

### Diagnostic Terminal
* **Live Log Stream:** Embedded logging terminal with real-time WebSocket event tracing.
* **Filtering and Export:** Filter logs by severity level (`INFO`, `WARN`, `ERROR`), search with regular expressions, and copy session output with one click.

### Stream Deck Interface
* **Tactile Keycaps:** Recessed keycap design with instant touch feedback and multi-page layout navigation.
* **Centered Iconography:** High-contrast icons optimized for readability on OLED and LCD mobile screens.

### Virtual Gesture Pad
* **Workstation Navigation:** Touchscreen trackpad with adjustable sensitivity and cursor acceleration.
* **Custom Gestures:** Configurable multi-directional swipes, double-taps, and long-press shortcuts for window snapping, workspace switching, and desktop navigation.

---

## Security & Privacy

DevDeck is designed to be local-first with zero data collection:

* **Local Network Only:** All traffic is confined to your local Wi-Fi or Ethernet network. No packets are routed to external servers.
* **No Telemetry:** The application contains no analytics, error trackers, or third-party tracking identifiers.
* **Local Persistence:** Workspaces, configurations, and paired device records reside exclusively in your local SQLite database (`%APPDATA%\DevDeck\devdeck.db`).
* **Authenticated Pairing:** Devices establish pairing through ephemeral tokens and HMAC-SHA256 signed JSON Web Tokens exchanged via QR code. Unauthenticated requests are rejected.

---

## Performance & Resource Utilization

| Metric | Specification | Note |
| :--- | :--- | :--- |
| **Idle CPU Usage** | **0.0% – 0.1%** | Event-driven WebSocket architecture with no busy-wait loops. |
| **Agent Memory (Headless)** | **< 30 MB RAM** | Lightweight background service footprint. |
| **Action Execution Latency** | **< 85 ms** | Direct Win32 C# micro-binaries bypass shell interpreter overhead. |
| **Window Focus Latency** | **~50 ms** | Restores and brings application windows into focus natively. |
| **Native Helper Size** | **~5.5 KB each** | Standalone C# helper utilities (`window-focus.exe`, `brightness-control.exe`). |

---

## Repository Structure

```
DevDeck/
├── android/                     # Android client build files and ProGuard configuration
├── assets/                      # Brand assets, icons, and banners
├── desktop-agent/               # Electron GUI and Node.js backend agent
│   ├── electron-main.js         # Electron lifecycle, tray integration, updater logic
│   ├── build-exe.js             # Automated packaging script for NSIS & portable builds
│   ├── public/                  # Agent dashboard frontend (HTML5, CSS, WebSockets)
│   ├── src/                     # TypeScript server implementation
│   │   ├── socket/              # WebSocket communication handlers
│   │   ├── services/            # Pairing, apps, clipboard, and workspace services
│   │   └── utils/native/        # Native Win32 C# helpers (WindowFocus, Brightness)
│   └── package.json             # Agent dependencies and run scripts
├── lib/                         # Cross-platform Flutter client application
│   ├── core/                    # Theme, networking, and security tokens
│   └── features/                # Application modules (Dashboard, Pairing, Gestures)
└── .github/workflows/           # Automated CI/CD release pipeline
```

---

## Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19 or later)
* [Node.js](https://nodejs.org/) (v20 LTS or later)

---

### Running the Desktop Agent

1. Navigate to the agent directory:
   ```bash
   cd desktop-agent
   npm install
   ```
2. Start the application:
   ```bash
   # Launch GUI dashboard (Electron)
   npm run gui

   # Or run headlessly in terminal mode
   npm run dev
   ```
3. The agent starts on port `8081` and renders a pairing QR code in the interface or terminal.

---

### Running the Client Application

1. From the repository root, start the Flutter client:
   ```bash
   flutter run -d chrome
   ```
   *(Or target an Android device / emulator).*
2. Scan the QR code displayed by the Desktop Agent to establish an authenticated connection.

---

## Building from Source

### Windows Desktop Agent

Build the NSIS installer, portable binary, and updater manifest with:

```bash
cd desktop-agent
npm run build:exe
```

Artifacts produced:
* `desktop-agent/build/DevDeckAgentSetup.exe` (NSIS Installer)
* `desktop-agent/build/devdeck-agent.exe` (Portable Binary)
* `desktop-agent/build/latest.yml` (Auto-updater Manifest)

### Android Client

```bash
flutter build apk --release
```
* Artifact: `build/app/outputs/flutter-apk/app-release.apk` (packaged as `DevDeck.apk`).

---

## Contributing

Contributions are welcome. To get started:

* Consult the [Contributing Guide](CONTRIBUTING.md) for local development workflows.
* Review open issues marked [Good First Issue](https://github.com/wtfnixin/DevDeck/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).
* Read the [Code of Conduct](CODE_OF_CONDUCT.md).
* Review our [Security Policy](SECURITY.md).
