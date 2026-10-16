import { exec, spawn } from 'child_process';
import { logger } from '../core/logger/winston';
import { Server } from 'socket.io';

export interface ClipboardItem {
  id: string;
  content: string;
  source: 'mobile' | 'desktop';
  timestamp: number;
}

export class ClipboardService {
  private static ioServer: Server | null = null;
  private static lastContent: string = '';
  private static lastPhoneContent: string = '';
  private static lastDesktopContent: string = '';
  private static history: ClipboardItem[] = [];
  private static pollInterval: NodeJS.Timeout | null = null;

  public static init(io: Server): void {
    this.ioServer = io;
    this.paste((error, content) => {
      if (error) {
        logger.warn('Failed to initialize clipboard content:', error);
        this.lastContent = '';
      } else {
        this.lastContent = content || '';
        this.lastDesktopContent = content || '';
        if (content && content.trim() !== '') {
          this.addToHistory(content, 'desktop');
        }
      }
      this.startPolling();
    });
  }

  public static getState() {
    return {
      lastContent: this.lastContent,
      lastPhoneContent: this.lastPhoneContent,
      lastDesktopContent: this.lastDesktopContent,
      history: this.history,
    };
  }

  public static clearHistory(): void {
    this.history = [];
  }

  private static addToHistory(content: string, source: 'mobile' | 'desktop'): void {
    if (!content || content.trim() === '') return;
    
    // Avoid immediate duplicate at top of history
    if (this.history.length > 0 && this.history[0].content === content) {
      this.history[0].timestamp = Date.now();
      return;
    }

    const item: ClipboardItem = {
      id: `${Date.now()}-${Math.random().toString(36).substring(2, 7)}`,
      content,
      source,
      timestamp: Date.now(),
    };

    this.history.unshift(item);
    if (this.history.length > 25) {
      this.history.pop();
    }
  }

  private static paste(callback: (error: any, content: string) => void): void {
    // Run PowerShell to get clipboard with UTF-8 encoding to prevent garbled characters
    const cmd = `powershell.exe -NoProfile -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Get-Clipboard"`;
    exec(cmd, { encoding: 'utf8' }, (error, stdout, stderr) => {
      if (error) {
        callback(error, '');
      } else {
        // Strip trailing newlines/carriage returns that powershell may append
        const content = stdout.replace(/\r\n$/, '').replace(/\n$/, '');
        callback(null, content);
      }
    });
  }

  public static copy(content: string, callback?: (error: any) => void): void {
    // Run PowerShell to set clipboard with UTF-8 encoding
    const child = spawn('powershell.exe', [
      '-NoProfile',
      '-Command',
      '[Console]::InputEncoding = [System.Text.Encoding]::UTF8; $content = [Console]::In.ReadToEnd(); Set-Clipboard -Value $content'
    ]);

    let err = '';
    child.stderr.on('data', (data) => {
      err += data.toString();
    });

    child.on('close', (code) => {
      if (callback) {
        if (code !== 0) {
          callback(new Error(err || `Exit code ${code}`));
        } else {
          callback(null);
        }
      }
    });

    child.stdin.write(content);
    child.stdin.end();
  }

  public static startPolling(): void {
    if (this.pollInterval) {
      clearInterval(this.pollInterval);
    }

    this.pollInterval = setInterval(() => {
      this.paste((error, currentContent) => {
        if (error) return;

        if (currentContent !== this.lastContent && currentContent.trim() !== '') {
          this.lastContent = currentContent;
          this.lastDesktopContent = currentContent;
          this.addToHistory(currentContent, 'desktop');
          logger.info(`📋 Clipboard change detected on desktop: "${currentContent.substring(0, 30)}..."`);
          
          // Broadcast to all authenticated clients (mobile + local GUI)
          if (this.ioServer) {
            this.ioServer.emit('clipboard:sync', {
              content: currentContent,
              source: 'desktop',
              timestamp: Date.now(),
            });
          }
        }
      });
    }, 1000);
  }

  public static handleMobileSync(content: string): void {
    if (content === this.lastContent) return;
    
    this.lastContent = content;
    this.lastPhoneContent = content;
    this.addToHistory(content, 'mobile');

    this.copy(content, (error) => {
      if (error) {
        logger.error('Failed to write clipboard to system:', error);
      } else {
        logger.info(`📋 Clipboard synced from mobile to desktop: "${content.substring(0, 30)}..."`);
      }
    });
  }

  public static sendToMobile(content: string): void {
    if (!content || content.trim() === '') return;

    this.lastContent = content;
    this.lastDesktopContent = content;
    this.addToHistory(content, 'desktop');

    // Write to PC OS clipboard
    this.copy(content);

    // Broadcast to mobile devices and local GUI
    if (this.ioServer) {
      this.ioServer.emit('clipboard:sync', {
        content,
        source: 'desktop',
        timestamp: Date.now(),
      });
    }
  }

  public static stopPolling(): void {
    if (this.pollInterval) {
      clearInterval(this.pollInterval);
      this.pollInterval = null;
    }
  }
}
