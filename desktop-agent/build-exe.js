const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const node22Path = path.join(__dirname, 'lib-native', 'better_sqlite3_node22.node');
const node24Path = path.join(__dirname, 'lib-native', 'better_sqlite3_node24.node');
const targetPath = path.join(__dirname, 'node_modules', 'better-sqlite3', 'build', 'Release', 'better_sqlite3.node');

console.log('🔄 Preparing Node 22 binary for standalone packaging...');
try {
  if (fs.existsSync(node22Path)) {
    fs.mkdirSync(path.dirname(targetPath), { recursive: true });
    fs.copyFileSync(node22Path, targetPath);
    console.log('✅ Node 22 binary swapped from lib-native successfully.');
  } else {
    console.log('🌐 lib-native binary not found, downloading Node 22 native addon via prebuild-install...');
    execSync('npx prebuild-install --target=22.0.0 --platform=win32 --arch=x64 --runtime=node', { stdio: 'inherit' });
    console.log('✅ Node 22 native addon downloaded successfully.');
  }

  console.log('📦 Bundling standalone devdeck-agent.exe...');
  execSync('npx @yao-pkg/pkg . --targets node22-win-x64 --output build/devdeck-agent.exe', { stdio: 'inherit' });
  console.log('✅ Standalone executable built successfully!');

} catch (error) {
  console.error('❌ Build failed:', error.message);
  process.exit(1);
} finally {
  if (fs.existsSync(node24Path)) {
    console.log('🔄 Restoring Node 24 binary for local development...');
    try {
      fs.copyFileSync(node24Path, targetPath);
      console.log('✅ Node 24 binary restored successfully.');
    } catch (restoreError) {
      console.error('❌ Failed to restore Node 24 binary:', restoreError.message);
    }
  }
}
