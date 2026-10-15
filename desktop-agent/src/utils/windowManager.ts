import { execFile } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import { logger } from '../core/logger/winston';

export class WindowManager {
  private static binaryPath: string | null = null;

  /**
   * Locates the ultra-fast native Windows window focus helper binary.
   */
  private static getFocusBinaryPath(): string | null {
    if (this.binaryPath && fs.existsSync(this.binaryPath)) {
      return this.binaryPath;
    }

    const resources = (process as any).resourcesPath;
    const candidatePaths = [
      path.join(path.dirname(process.execPath), 'window-focus.exe'),
      path.join(path.dirname(process.execPath), 'bin/window-focus.exe'),
      ...(resources ? [
        path.join(resources, 'bin/window-focus.exe'),
        path.join(resources, 'window-focus.exe'),
        path.join(resources, '../bin/window-focus.exe'),
      ] : []),
      path.join(__dirname, '../../bin/window-focus.exe'),
      path.join(process.cwd(), 'bin/window-focus.exe'),
      path.join(__dirname, '../bin/window-focus.exe'),
      path.join(process.cwd(), 'desktop-agent/bin/window-focus.exe'),
      path.join(__dirname, '../../build/window-focus.exe'),
      path.join(process.cwd(), 'build/window-focus.exe'),
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
   * Attempts to find an open window matching keywords,
   * restores it if minimized, and brings it to the foreground.
   *
   * Executes via native Win32 API in under 50ms.
   * Returns true if focused successfully, false otherwise.
   */
  public static focusWindow(keywords: string[]): Promise<boolean> {
    return new Promise((resolve) => {
      // Filter valid keywords
      const cleanKeywords = keywords
        .filter(k => k && typeof k === 'string' && k.trim().length > 0)
        .map(k => k.trim());

      if (cleanKeywords.length === 0) {
        return resolve(false);
      }

      // Linux/macOS fallback: bypass until Linux wmctrl is implemented
      if (process.platform !== 'win32') {
        return resolve(false);
      }

      const binary = this.getFocusBinaryPath();
      if (!binary) {
        // If helper is missing, do not block; proceed directly
        logger.debug('Native window-focus binary not found. Skipping focus check.');
        return resolve(false);
      }

      const startTime = Date.now();

      // Execute native helper with a safety timeout of 1200ms
      execFile(binary, cleanKeywords, { timeout: 1200, windowsHide: true }, (error) => {
        const elapsed = Date.now() - startTime;
        if (!error) {
          logger.info(`⚡ Native window focus succeeded in ${elapsed}ms for [${cleanKeywords.join(', ')}]`);
          resolve(true);
        } else {
          logger.debug(`Window not found for [${cleanKeywords.join(', ')}] (${elapsed}ms). Proceeding to launch.`);
          resolve(false);
        }
      });
    });
  }
}
