import { execFile, exec } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import { logger } from '../core/logger/winston';

export class BrightnessManager {
  private static binaryPath: string | null = null;

  /**
   * Locates the ultra-fast native Windows brightness helper binary.
   */
  private static getBrightnessBinaryPath(): string | null {
    if (this.binaryPath && fs.existsSync(this.binaryPath)) {
      return this.binaryPath;
    }

    const candidatePaths = [
      path.join(__dirname, '../../bin/brightness-control.exe'),
      path.join(process.cwd(), 'bin/brightness-control.exe'),
      path.join(__dirname, '../bin/brightness-control.exe'),
      path.join(process.cwd(), 'desktop-agent/bin/brightness-control.exe'),
      path.join(__dirname, '../../build/brightness-control.exe'),
      path.join(process.cwd(), 'build/brightness-control.exe'),
    ];

    for (const p of candidatePaths) {
      if (fs.existsSync(p)) {
        this.binaryPath = p;
        return p;
      }
    }

    return null;
  }

  /**
   * Adjusts system screen brightness up or down by the specified delta percentage.
   * Runs natively via Win32/WMI/DXVA2 in < 100ms.
   *
   * @param delta e.g. +10 or -10
   */
  public static adjustBrightness(delta: number): Promise<{ success: boolean; brightness?: number; error?: string }> {
    return new Promise((resolve) => {
      // 1. Linux Support (Fedora / GNOME / Wayland via brightnessctl)
      if (process.platform === 'linux') {
        const sign = delta >= 0 ? '+' : '';
        const cmd = delta >= 0 ? `brightnessctl set +${Math.abs(delta)}%` : `brightnessctl set ${Math.abs(delta)}%-`;
        exec(cmd, (err, stdout) => {
          if (err) {
            logger.error('Linux brightnessctl execution failed:', err);
            return resolve({ success: false, error: err.message });
          }
          return resolve({ success: true });
        });
        return;
      }

      // 2. Windows Support via ultra-fast precompiled native binary
      if (process.platform === 'win32') {
        const binary = this.getBrightnessBinaryPath();
        if (!binary) {
          logger.warn('Native brightness-control binary not found. Skipping brightness adjustment.');
          return resolve({ success: false, error: 'Binary not found' });
        }

        const arg = delta >= 0 ? `+${delta}` : `${delta}`;

        execFile(binary, [arg], { timeout: 1500 }, (err, stdout, stderr) => {
          if (err) {
            logger.error(`Native brightness adjustment (${arg}) failed:`, err);
            return resolve({ success: false, error: err.message });
          }

          const out = (stdout || '').trim();
          const match = out.match(/BRIGHTNESS:(\d+)/);
          const currentLevel = match ? parseInt(match[1], 10) : undefined;

          logger.debug(`Brightness adjusted successfully: ${out}`);
          return resolve({ success: true, brightness: currentLevel });
        });
        return;
      }

      return resolve({ success: false, error: `Platform ${process.platform} not supported for brightness control` });
    });
  }

  /**
   * Reads current screen brightness percentage.
   */
  public static getBrightness(): Promise<{ success: boolean; brightness?: number; error?: string }> {
    return new Promise((resolve) => {
      if (process.platform === 'win32') {
        const binary = this.getBrightnessBinaryPath();
        if (!binary) {
          return resolve({ success: false, error: 'Binary not found' });
        }

        execFile(binary, ['status'], { timeout: 1500 }, (err, stdout) => {
          if (err) {
            return resolve({ success: false, error: err.message });
          }
          const out = (stdout || '').trim();
          const match = out.match(/BRIGHTNESS:(\d+)/);
          const currentLevel = match ? parseInt(match[1], 10) : undefined;
          return resolve({ success: true, brightness: currentLevel });
        });
        return;
      }

      return resolve({ success: false, error: 'Unsupported platform' });
    });
  }
}
