import { exec, execFile } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import { logger } from '../core/logger/winston';

export class DesktopManager {
  private static binaryPath: string | null = null;

  /**
   * Locates the precompiled native desktop switcher binary.
   */
  private static getBinaryPath(): string | null {
    if (this.binaryPath && fs.existsSync(this.binaryPath)) {
      return this.binaryPath;
    }

    const resources = (process as any).resourcesPath;
    const candidatePaths = [
      path.join(path.dirname(process.execPath), 'desktop-switcher.exe'),
      path.join(path.dirname(process.execPath), 'bin/desktop-switcher.exe'),
      ...(resources ? [
        path.join(resources, 'bin/desktop-switcher.exe'),
        path.join(resources, 'desktop-switcher.exe'),
        path.join(resources, '../bin/desktop-switcher.exe'),
      ] : []),
      path.join(__dirname, '../../bin/desktop-switcher.exe'),
      path.join(process.cwd(), 'bin/desktop-switcher.exe'),
      path.join(__dirname, '../bin/desktop-switcher.exe'),
      path.join(process.cwd(), 'desktop-agent/bin/desktop-switcher.exe'),
      path.join(__dirname, '../../build/desktop-switcher.exe'),
      path.join(process.cwd(), 'build/desktop-switcher.exe'),
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
   * Switches virtual desktops immediately.
   * @param direction 'right' (next desktop) or 'left' (previous desktop)
   */
  public static switchDesktop(direction: 'right' | 'left', cb?: (res: any) => void): void {
    logger.info(`🖥️ Switching virtual desktop: ${direction}`);

    // macOS support via AppleScript
    if (process.platform === 'darwin') {
      const keyCode = direction === 'right' ? 124 : 123;
      exec(`osascript -e 'tell application "System Events" to key code ${keyCode} using control down'`, (err) => {
        if (err) {
          logger.error('macOS space switch failed:', err);
          if (cb) cb({ success: false, error: err.message });
          return;
        }
        if (cb) cb({ success: true });
      });
      return;
    }

    // Windows support: Precompiled native binary
    const binary = this.getBinaryPath();
    if (binary) {
      execFile(binary, [direction], { windowsHide: true }, (err) => {
        if (err) {
          logger.warn(`Native desktop-switcher execution failed, falling back to PowerShell:`, err);
          this.windowsPowerShellFallback(direction, cb);
        } else {
          if (cb) cb({ success: true });
        }
      });
      return;
    }

    // Fallback: PowerShell P/Invoke
    logger.debug('Native desktop-switcher binary not found, using PowerShell fallback.');
    this.windowsPowerShellFallback(direction, cb);
  }

  private static windowsPowerShellFallback(direction: 'right' | 'left', cb?: (res: any) => void): void {
    const arrowKey = direction === 'left' ? '0x25' : '0x27';
    const psScript = `
      $code = @'
      using System;
      using System.Runtime.InteropServices;
      using System.Threading;
      public class DeskKey {
          [DllImport("user32.dll")]
          public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
          public static void Switch() {
              keybd_event(0x11, 0, 0, UIntPtr.Zero);
              keybd_event(0x5B, 0, 0, UIntPtr.Zero);
              keybd_event(${arrowKey}, 0, 1, UIntPtr.Zero);
              Thread.Sleep(10);
              keybd_event(${arrowKey}, 0, 3, UIntPtr.Zero);
              keybd_event(0x5B, 0, 2, UIntPtr.Zero);
              keybd_event(0x11, 0, 2, UIntPtr.Zero);
          }
      }
'@
      Add-Type -TypeDefinition $code -Language CSharp
      [DeskKey]::Switch()
    `;

    exec(`powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "${psScript.replace(/\r?\n/g, ' ')}"`, (err) => {
      if (err) {
        logger.error('PowerShell desktop switch fallback failed:', err);
        if (cb) cb({ success: false, error: err.message });
        return;
      }
      if (cb) cb({ success: true });
    });
  }
}
