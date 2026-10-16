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
  execSync('npx electron-builder --win --publish never', { stdio: 'inherit', cwd: __dirname });
  console.log('✅ DevDeck GUI application & setup installer built successfully!');

  // Generate latest.yml for electron-updater
  const setupExePath = path.join(__dirname, 'build', 'DevDeckAgentSetup.exe');
  const latestYmlPath = path.join(__dirname, 'build', 'latest.yml');
  if (fs.existsSync(setupExePath)) {
    const crypto = require('crypto');
    const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'));
    const fileBuffer = fs.readFileSync(setupExePath);
    const sha512 = crypto.createHash('sha512').update(fileBuffer).digest('base64');
    const size = fs.statSync(setupExePath).size;
    const releaseDate = new Date().toISOString();

    const yamlContent = [
      `version: ${pkg.version || '1.0.0'}`,
      `files:`,
      `  - url: DevDeckAgentSetup.exe`,
      `    sha512: ${sha512}`,
      `    size: ${size}`,
      `path: DevDeckAgentSetup.exe`,
      `sha512: ${sha512}`,
      `releaseDate: '${releaseDate}'`,
      ``
    ].join('\n');

    fs.writeFileSync(latestYmlPath, yamlContent, 'utf8');
    console.log('✅ Generated latest.yml for auto-updater release.');
  }
} catch (error) {
  console.error('❌ Build failed:', error.message);
  process.exit(1);
} finally {
  const nodeMajor = process.versions.node.split('.')[0];
  const nodeNativeCandidate = path.join(__dirname, 'lib-native', `better_sqlite3_node${nodeMajor}.node`);
  const nodeNativePath = fs.existsSync(nodeNativeCandidate) ? nodeNativeCandidate : path.join(__dirname, 'lib-native', 'better_sqlite3_node22.node');
  if (fs.existsSync(nodeNativePath)) {
    fs.copyFileSync(nodeNativePath, targetPath);
    console.log(`🔄 Restored Node.js (v${nodeMajor}) SQLite native addon for development environment.`);
  }
}
