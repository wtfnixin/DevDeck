import { execFile, exec } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import { logger } from '../core/logger/winston';

export class VolumeManager {
  private static binaryPath: string | null = null;

  /**
   * Locates the native keypresser binary.
   */
  private static getBinaryPath(): string | null {
    if (this.binaryPath && fs.existsSync(this.binaryPath)) {
      return this.binaryPath;
    }

    const resources = (process as any).resourcesPath;
    const candidatePaths = [
      path.join(path.dirname(process.execPath), 'keypresser.exe'),
      path.join(path.dirname(process.execPath), 'bin/keypresser.exe'),
      ...(resources ? [
        path.join(resources, 'bin/keypresser.exe'),
        path.join(resources, 'keypresser.exe'),
        path.join(resources, '../bin/keypresser.exe'),
      ] : []),
      path.join(__dirname, '../../bin/keypresser.exe'),
      path.join(process.cwd(), 'bin/keypresser.exe'),
      path.join(__dirname, '../bin/keypresser.exe'),
      path.join(process.cwd(), 'desktop-agent/bin/keypresser.exe'),
      path.join(__dirname, '../../build/keypresser.exe'),
      path.join(process.cwd(), 'build/keypresser.exe'),
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
   * Adjusts master volume or mutes via native OS calls.
   * VK codes for Windows:
   * 175 = VK_VOLUME_UP
   * 174 = VK_VOLUME_DOWN
   * 173 = VK_VOLUME_MUTE
   */
  public static sendVolumeEvent(vkCode: number, callback?: (res: any) => void): void {
    const cb = (res: any) => {
      if (typeof callback === 'function') {
        callback(res);
      }
    };

    // 1. Linux support via pactl / amixer
    if (process.platform === 'linux') {
      let cmd = 'pactl set-sink-volume @DEFAULT_SINK@ +5%';
      if (vkCode === 174) cmd = 'pactl set-sink-volume @DEFAULT_SINK@ -5%';
      if (vkCode === 173) cmd = 'pactl set-sink-mute @DEFAULT_SINK@ toggle';

      exec(cmd, (err) => {
        if (err) {
          logger.error(`Linux pactl volume command failed:`, err);
          return cb({ success: false, error: err.message });
        }
        return cb({ success: true });
      });
      return;
    }

    // 2. macOS support via AppleScript
    if (process.platform === 'darwin') {
      let script = 'set volume output volume ((output volume of (get volume settings)) + 5)';
      if (vkCode === 174) script = 'set volume output volume ((output volume of (get volume settings)) - 5)';
      if (vkCode === 173) script = 'set volume output muted (not (output muted of (get volume settings)))';

      exec(`osascript -e "${script}"`, (err) => {
        if (err) {
          logger.error('macOS volume script failed:', err);
          return cb({ success: false, error: err.message });
        }
        return cb({ success: true });
      });
      return;
    }

    // 3. Windows support: Try fast native precompiled binary
    const binary = this.getBinaryPath();
    if (binary) {
      execFile(binary, [vkCode.toString()], { windowsHide: true }, (err) => {
        if (err) {
          logger.warn(`Native keypresser execution failed for VK ${vkCode}, trying PowerShell fallback:`, err);
          this.windowsPowerShellFallback(vkCode, cb);
        } else {
          cb({ success: true });
        }
      });
      return;
    }

    // Fallback: PowerShell P/Invoke
    logger.debug('Native keypresser binary not found, using PowerShell fallback.');
    this.windowsPowerShellFallback(vkCode, cb);
  }

  private static windowsPowerShellFallback(vkCode: number, cb: (res: any) => void): void {
    const psScript = `
      $code = @'
      using System;
      using System.Runtime.InteropServices;
      public class VolKey {
          [DllImport("user32.dll")]
          public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
          public static void Press(byte vk) {
              keybd_event(vk, 0, 1, UIntPtr.Zero);
              keybd_event(vk, 0, 3, UIntPtr.Zero);
          }
      }
'@
      Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
      [VolKey]::Press(${vkCode})
    `;
    const encoded = Buffer.from(psScript, 'utf16le').toString('base64');
    exec(`powershell -NoProfile -NonInteractive -EncodedCommand ${encoded}`, (err) => {
      if (err) {
        logger.error(`PowerShell volume fallback failed for VK ${vkCode}:`, err);
        return cb({ success: false, error: err.message });
      }
      return cb({ success: true });
    });
  }

  public static volumeUp(callback?: (res: any) => void): void {
    this.sendVolumeEvent(175, callback);
  }

  public static volumeDown(callback?: (res: any) => void): void {
    this.sendVolumeEvent(174, callback);
  }

  public static volumeMute(callback?: (res: any) => void): void {
    this.sendVolumeEvent(173, callback);
  }
}
