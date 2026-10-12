import { exec } from 'child_process';
import path from 'path';
import fs from 'fs';
import { logger } from '../core/logger/winston';

export class ShortcutResolver {
  /**
   * Resolves a Windows shortcut (.lnk) or Linux .desktop entry to the actual target executable.
   * If the file is already an executable or cannot be resolved, returns the original path.
   */
  public static async resolve(filePath: string): Promise<string> {
    try {
      if (!filePath || !fs.existsSync(filePath)) {
        return filePath;
      }

      const ext = path.extname(filePath).toLowerCase();

      // Windows .lnk Shortcut
      if (process.platform === 'win32' && ext === '.lnk') {
        return await this.resolveWindowsLnk(filePath);
      }

      // Linux .desktop Entry
      if (process.platform === 'linux' && ext === '.desktop') {
        return await this.resolveLinuxDesktopFile(filePath);
      }

      return filePath;
    } catch (err) {
      logger.error(`Error resolving shortcut for ${filePath}:`, err);
      return filePath;
    }
  }

  /**
   * Resolves a Windows .lnk shortcut target using PowerShell WScript.Shell COM object
   */
  private static resolveWindowsLnk(lnkPath: string): Promise<string> {
    return new Promise((resolve) => {
      const escapedPath = lnkPath.replace(/'/g, "''");
      const psCommand = `
        try {
          $sh = New-Object -ComObject WScript.Shell
          $sc = $sh.CreateShortcut('${escapedPath}')
          if ($sc -and $sc.TargetPath -and (Test-Path $sc.TargetPath)) {
            Write-Output $sc.TargetPath
          } else {
            Write-Output '${escapedPath}'
          }
        } catch {
          Write-Output '${escapedPath}'
        }
      `.trim();

      const encoded = Buffer.from(psCommand, 'utf16le').toString('base64');
      exec(`powershell -NoProfile -NonInteractive -EncodedCommand ${encoded}`, (err, stdout) => {
        if (!err && stdout && stdout.trim().length > 0) {
          const target = stdout.trim();
          if (fs.existsSync(target)) {
            logger.info(`Resolved shortcut: "${lnkPath}" -> "${target}"`);
            return resolve(target);
          }
        }
        resolve(lnkPath);
      });
    });
  }

  /**
   * Resolves a Linux .desktop entry by parsing Exec= parameter
   */
  private static async resolveLinuxDesktopFile(desktopPath: string): Promise<string> {
    try {
      const content = await fs.promises.readFile(desktopPath, 'utf8');
      const lines = content.split('\n');
      for (const line of lines) {
        if (line.startsWith('Exec=')) {
          let execCmd = line.substring(5).trim();
          // Remove arguments like %u, %F, %U
          execCmd = execCmd.replace(/%[a-zA-Z]/g, '').trim();
          // Extract first binary token if it contains parameters
          const parts = execCmd.split(' ');
          const binary = parts[0];
          return binary;
        }
      }
    } catch (err) {
      logger.warn(`Failed to parse .desktop file ${desktopPath}:`, err);
    }
    return desktopPath;
  }
}
