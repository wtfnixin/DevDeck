import { db } from '../core/database/connection';
import { logger } from '../core/logger/winston';
import { AppLauncher } from '../types/launcher';
import { exec, execSync, spawn } from 'child_process';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { WindowManager } from '../utils/windowManager';

export class AppRegistryService {
  private static resolveExePath(exePath: string): string {
    if (path.isAbsolute(exePath) && fs.existsSync(exePath)) {
      return exePath;
    }
    
    // Check in common system directories
    const systemDirs = [
      'C:\\Windows\\System32',
      'C:\\Windows',
      'C:\\Program Files',
      'C:\\Program Files (x86)'
    ];
    
    for (const dir of systemDirs) {
      const fullPath = path.join(dir, exePath);
      if (fs.existsSync(fullPath)) {
        return fullPath;
      }
    }
    
    return exePath;
  }

  public static extractExeIcon(exePath: string): string | null {
    try {
      const resolved = this.resolveExePath(exePath);
      if (!fs.existsSync(resolved)) {
        return null;
      }
      
      const escapedPath = resolved.replace(/'/g, "''");
      const psCommand = `
        Add-Type -AssemblyName System.Drawing
        $code = @"
        using System;
        using System.Runtime.InteropServices;
        using System.Drawing;
        using System.IO;

        public class IconExtractor {
            [DllImport("user32.dll", CharSet = CharSet.Auto)]
            public static extern uint PrivateExtractIcons(
                string lpszFile,
                int nIconIndex,
                int cxIcon,
                int cyIcon,
                IntPtr[] phicon,
                uint[] piconid,
                uint nIcons,
                uint flags
            );

            [DllImport("user32.dll")]
            public static extern bool DestroyIcon(IntPtr hIcon);

            public static string GetIconBase64(string filePath, int size) {
                IntPtr[] phicon = new IntPtr[1];
                uint[] piconid = new uint[1];
                uint count = PrivateExtractIcons(filePath, 0, size, size, phicon, piconid, 1, 0);
                if (count > 0 && phicon[0] != IntPtr.Zero) {
                    try {
                        using (Icon icon = Icon.FromHandle(phicon[0])) {
                            using (Bitmap bitmap = icon.ToBitmap()) {
                                using (MemoryStream stream = new MemoryStream()) {
                                    bitmap.Save(stream, System.Drawing.Imaging.ImageFormat.Png);
                                    return Convert.ToBase64String(stream.ToArray());
                                }
                            }
                        }
                    } finally {
                        DestroyIcon(phicon[0]);
                    }
                }
                return null;
            }
        }
"@
        Add-Type -TypeDefinition $code -ReferencedAssemblies "System.Drawing" -ErrorAction SilentlyContinue
        [IconExtractor]::GetIconBase64('${escapedPath}', 128)
      `;

      const buffer = Buffer.from(psCommand, 'utf16le');
      const base64Encoded = buffer.toString('base64');
      
      let base64 = execSync(`powershell -NoProfile -NonInteractive -EncodedCommand ${base64Encoded}`, { 
        encoding: 'utf8', 
        maxBuffer: 1024 * 1024 * 10 
      }).trim();
      
      if (base64.includes('#< CLIXML')) {
        const parts = base64.split('</Objs>');
        base64 = parts[parts.length - 1].trim();
      }
      
      if (base64 && base64.startsWith('iVBORw0KGgo')) {
        return `data:image/png;base64,${base64}`;
      }
    } catch (err) {
      logger.error(`Failed to extract icon for ${exePath}:`, err);
    }
    return null;
  }

  public static getAllApps(): AppLauncher[] {
    try {
      const rows = db.prepare('SELECT * FROM apps').all() as any[];
      return rows.map(row => {
        let icon = row.icon;
        
        // Lazy extraction & cache if not already base64
        if (!icon || !icon.startsWith('data:image/')) {
          const extracted = this.extractExeIcon(row.executable_path);
          if (extracted) {
            icon = extracted;
            try {
              db.prepare('UPDATE apps SET icon = ? WHERE id = ?').run(icon, row.id);
            } catch (err) {
              logger.error('Failed to update app icon cache in DB:', err);
            }
          }
        }

        return {
          id: row.id,
          name: row.name,
          icon: icon ?? row.icon ?? null,
          executablePath: row.executable_path,
          category: row.category ?? null,
        };
      });
    } catch (error) {
      logger.error('Failed to get apps from database:', error);
      return [];
    }
  }

  public static registerApp(app: Omit<AppLauncher, 'id'> & { id?: string }): AppLauncher {
    try {
      const id = app.id || crypto.randomUUID();
      
      // Auto-extract executable icon on registration
      let icon = app.icon;
      if (!icon || !icon.startsWith('data:image/')) {
        const extracted = this.extractExeIcon(app.executablePath);
        if (extracted) {
          icon = extracted;
        }
      }

      const stmt = db.prepare(`
        INSERT INTO apps (id, name, icon, executable_path, category)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          icon = excluded.icon,
          executable_path = excluded.executable_path,
          category = excluded.category
      `);
      stmt.run(id, app.name, icon ?? null, app.executablePath, app.category ?? null);
      
      const registeredApp: AppLauncher = {
        id,
        name: app.name,
        icon: icon ?? null,
        executablePath: app.executablePath,
        category: app.category ?? null,
      };
      
      logger.info(`🚀 App registered/updated: ${app.name} (${id})`);
      return registeredApp;
    } catch (error) {
      logger.error('Failed to register app:', error);
      throw error;
    }
  }

  public static deleteApp(id: string): void {
    try {
      const stmt = db.prepare('DELETE FROM apps WHERE id = ?');
      stmt.run(id);
      logger.info(`🗑️ App deleted: ${id}`);
    } catch (error) {
      logger.error(`Failed to delete app ${id}:`, error);
      throw error;
    }
  }

  public static executeApp(execPath: string): void {
    const cleanPath = execPath.trim();
    const isCmdOrBat = /\.(cmd|bat)$/i.test(cleanPath);
    const isLnk = /\.lnk$/i.test(cleanPath);

    if (process.platform === 'win32') {
      if (isLnk || isCmdOrBat) {
        const child = spawn('cmd.exe', ['/c', 'start', '""', cleanPath], {
          detached: true,
          stdio: 'ignore',
          windowsHide: true,
        });
        child.unref();
      } else {
        try {
          const child = spawn(cleanPath, [], {
            detached: true,
            stdio: 'ignore',
            shell: false,
            windowsHide: false,
          });
          child.on('error', (err) => {
            logger.warn(`Direct spawn failed for ${cleanPath}, falling back to shell start:`, err.message);
            const fallback = spawn('cmd.exe', ['/c', 'start', '""', cleanPath], {
              detached: true,
              stdio: 'ignore',
              windowsHide: true,
            });
            fallback.unref();
          });
          child.unref();
        } catch (err) {
          const fallback = spawn('cmd.exe', ['/c', 'start', '""', cleanPath], {
            detached: true,
            stdio: 'ignore',
            windowsHide: true,
          });
          fallback.unref();
        }
      }
    } else {
      const child = spawn(cleanPath, [], { detached: true, stdio: 'ignore' });
      child.unref();
    }
  }

  public static launchApp(id: string): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        const row = db.prepare('SELECT name, executable_path FROM apps WHERE id = ?').get(id) as { name: string, executable_path: string } | undefined;
        if (!row) {
          logger.warn(`Attempted to launch app with unknown ID: ${id}`);
          return reject(new Error('App not found in registry'));
        }

        const name = row.name;
        const execPath = row.executable_path;
        const execFilename = path.basename(execPath, path.extname(execPath));

        logger.info(`⚡ Fast launch triggered for app: ${name} (${execPath})`);

        // Build comprehensive keywords and aliases for window matching
        const subTerms = name.split(/[\/\-–—|&()]/).map(s => s.trim()).filter(s => s.length > 1);
        const keywords = [name, execFilename, ...subTerms];

        const lowerName = name.toLowerCase();
        const lowerExec = execFilename.toLowerCase();
        if (lowerName.includes('calc') || lowerExec === 'calc') {
          keywords.push('calculator', 'calculatorapp');
        }
        if (lowerName.includes('command') || lowerName.includes('terminal') || lowerExec === 'cmd') {
          keywords.push('cmd', 'windowsterminal', 'powershell');
        }
        if (lowerName.includes('spotify') || lowerExec === 'spotify') {
          keywords.push('spotify');
        }
        if (lowerName.includes('code') || lowerExec === 'code') {
          keywords.push('code', 'visual studio code');
        }

        const uniqueKeywords = Array.from(new Set(keywords));

        // Ultra-fast sub-50ms native focus check
        const focused = await WindowManager.focusWindow(uniqueKeywords);
        if (focused) {
          logger.info(`✅ Focused existing window for app: ${name}`);
          return resolve();
        }

        // App not already open: direct detached launch
        logger.info(`🚀 Spawning new instance for app: ${name}`);
        this.executeApp(execPath);
        resolve();
      } catch (error) {
        logger.error(`Exception during launching app ID ${id}:`, error);
        reject(error);
      }
    });
  }

  public static seedDefaults(): void {
    try {
      const countRow = db.prepare('SELECT count(*) as count FROM apps').get() as { count: number };
      if (countRow.count === 0) {
        logger.info('🌱 Seeding default apps...');
        const defaults = [
          { name: 'Visual Studio Code', executablePath: 'code.cmd', icon: 'code', category: 'Developer' },
          { name: 'Command Prompt', executablePath: 'cmd.exe', icon: 'terminal', category: 'Developer' },
          { name: 'Calculator', executablePath: 'calc.exe', icon: 'calculate', category: 'Utility' },
          { name: 'Notepad', executablePath: 'notepad.exe', icon: 'description', category: 'Utility' },
          { name: 'Task Manager', executablePath: 'taskmgr.exe', icon: 'assessment', category: 'Utility' },
          { name: 'Spotify / Media Player', executablePath: 'spotify.exe', icon: 'music_note', category: 'Media' }
        ];
        for (const app of defaults) {
          try {
            this.registerApp(app);
          } catch (e) {
            // continue if single app fails
          }
        }
      }
    } catch (error) {
      logger.error('Failed to seed default apps:', error);
    }
  }
}
