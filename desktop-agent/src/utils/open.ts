import { spawn } from 'child_process';

/**
 * Opens a URL in the host's default web browser instantly.
 */
export function openUrl(url: string): Promise<void> {
  return new Promise((resolve) => {
    if (process.platform === 'win32') {
      const child = spawn('cmd.exe', ['/c', 'start', '""', url], {
        detached: true,
        stdio: 'ignore',
        windowsHide: true,
      });
      child.unref();
      resolve();
    } else {
      const child = spawn('xdg-open', [url], { detached: true, stdio: 'ignore' });
      child.unref();
      resolve();
    }
  });
}
