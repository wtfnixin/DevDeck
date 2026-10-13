const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('🚀 Preparing native dependencies for DevDeck Electron build...');

const electronNativePath = path.join(__dirname, 'lib-native', 'better_sqlite3_electron31.node');
const targetPath = path.join(__dirname, 'node_modules', 'better-sqlite3', 'build', 'Release', 'better_sqlite3.node');

// 1. Ensure better-sqlite3 native binary for Electron is placed
if (fs.existsSync(electronNativePath)) {
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.copyFileSync(electronNativePath, targetPath);
  console.log('✅ Electron 31 SQLite native addon prepared from lib-native.');
}

// 2. Ensure bin folder exists
const binDir = path.join(__dirname, 'bin');
fs.mkdirSync(binDir, { recursive: true });

// 3. Package with electron-builder
console.log('📦 Bundling DevDeck GUI Desktop Application (NSIS Installer & Portable Executable)...');
try {
  execSync('npx electron-builder --win', { stdio: 'inherit', cwd: __dirname });
  console.log('✅ DevDeck GUI application & setup installer built successfully!');
} catch (error) {
  console.error('❌ Build failed:', error.message);
  process.exit(1);
}
