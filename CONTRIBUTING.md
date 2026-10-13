# Contributing to DevDeck 🚀

Thank you for your interest in contributing to **DevDeck**! DevDeck is a free, local-first, open-source productivity and macro controller suite built for developers and creators. We welcome contributions from everyone—whether you're fixing a typo, building a new stream deck macro, or porting to a new operating system.

Please take a moment to read this guide to make the contribution process smooth and enjoyable.

---

## 📜 Code of Conduct

DevDeck follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating in this project, you are expected to uphold this code of conduct. Please report unacceptable behavior to `nitinkumardontam@gmail.com`.

---

## 🗺️ Codebase Overview

DevDeck is composed of two primary sub-projects:

```
devdeck/
├── lib/                     # 📱 Mobile / Client (Flutter + Dart)
│   ├── core/                # Themes, routing, network, WebSocket services
│   └── features/            # Stream deck grid, dashboard, gestures, pairing
├── desktop-agent/           # 💻 Desktop Backend (Node.js + TypeScript + Electron)
│   ├── src/                 # Sockets, app launcher, clipboard, native drivers
│   ├── public/              # Desktop Agent GUI dashboard (Vanilla HTML/CSS/JS)
│   ├── bin/                 # Precompiled lightweight native Win32 helpers
│   └── electron-main.js     # Frameless Electron window wrapper
└── .github/                 # Workflows (CI/CD) and Issue/PR templates
```

---

## 🛠️ Local Development Setup

### 1. Prerequisites
* **Git** installed and configured
* **Node.js** (v20+ recommended) & `npm`
* **Flutter SDK** (v3.20+ recommended) for mobile app development
* **Windows 10/11** (for desktop agent Win32 features) or **Linux Fedora/Ubuntu**

---

### 2. Setting Up the Desktop Agent (`desktop-agent`)
1. Open a terminal and navigate to the directory:
   ```bash
   cd desktop-agent
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Run the development server:
   ```bash
   npm run dev       # Runs headless background daemon via ts-node
   # OR
   npm run gui       # Builds TypeScript and launches the Electron desktop dashboard
   ```
4. Verify the server is running on `http://localhost:8081/api/status`.

---

### 3. Setting Up the Mobile App (`Flutter Client`)
1. From the repository root, install Flutter dependencies:
   ```bash
   flutter pub get
   ```
2. Connect your Android phone (or launch an Android emulator with Wi-Fi bridge).
3. Run the application:
   ```bash
   flutter run
   ```
4. Pair your mobile app with your desktop by scanning the QR code displayed on the desktop dashboard.

---

## 🎯 How to Contribute

### Finding an Issue to Work On
Check out our [GitHub Issues](https://github.com/wtfnixin/DevDeck/issues):
* Look for the **`good first issue`** label if you are new to the project or looking for a bite-sized task.
* Look for the **`help wanted`** label for established feature requests and bug fixes.
* If you want to work on an issue, please leave a comment like: `"I'd like to work on this!"` so maintainers can assign it to you and prevent duplicate efforts.

---

## 🌿 Git & Pull Request Guidelines

### 1. Branching Strategy
Always create a branch from the `main` branch with a descriptive name:
* `feature/audio-sliders`
* `fix/pairing-timeout`
* `docs/contributing-guide`

```bash
git checkout main
git pull origin main
git checkout -b feature/my-new-feature
```

### 2. Conventional Commit Messages
We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:
* `feat:` A new feature or macro action
* `fix:` A bug fix
* `docs:` Documentation changes only
* `style:` Formatting, UI style tweaks (no logic change)
* `refactor:` Code restructuring without changing behavior
* `perf:` Performance optimizations
* `test:` Adding or updating tests

*Example:* `feat(agent): add support for Spotify media hotkeys`

### 3. Submitting a Pull Request
1. Ensure your code passes TypeScript build:
   ```bash
   cd desktop-agent && npm run build
   ```
2. For Flutter, run the analyzer:
   ```bash
   flutter analyze
   ```
3. Push your branch to your fork:
   ```bash
   git push origin feature/my-new-feature
   ```
4. Open a Pull Request targeting `main`. Fill in the [Pull Request Template](.github/pull_request_template.md).
5. A maintainer will review your code, provide constructive feedback, and merge once ready!

---

## 💡 Contribution Ideas for Beginners

* **New Deck Actions**: Add support for mute microphone, lock workstation, or screenshot macros.
* **Deck Customization**: Add new color palettes, haptic feedback intensities, or custom icon packs.
* **Linux Port**: Help test and implement Linux Wayland/PipeWire drivers (see roadmap).
* **Internationalization (i18n)**: Translate the UI into Spanish, French, German, Japanese, or Hindi.
* **Documentation**: Improve troubleshooting guides, tutorials, and YouTube/blog walkthroughs.

---

## 🏆 Contributor Recognition

All contributors who have code, designs, or documentation merged into DevDeck will be featured in our `README.md` and release notes. 

Thank you for helping make DevDeck the best open-source macro controller! ❤️
