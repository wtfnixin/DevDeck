import { Server } from 'socket.io';
import http from 'http';
import https from 'https';
import fs from 'fs';
import path from 'path';
import { URL } from 'url';
import { env } from '../core/config/env';
import { logger } from '../core/logger/winston';
import { TrustedDeviceService } from '../authentication/trustedDeviceService';
import { registerSocketEvents } from './socketEvents';
import { PairingService } from '../authentication/pairingService';
import { ClipboardService } from '../services/clipboardService';


function proxyFavicon(domain: string, res: http.ServerResponse, currentUrl?: string, depth = 0): void {
  if (depth > 5) {
    logger.error(`Favicon proxy: Too many redirects for domain ${domain}`);
    res.writeHead(502);
    res.end('Too many redirects');
    return;
  }

  let url = currentUrl;
  if (!url) {
    if (domain.toLowerCase().includes('github.com')) {
      url = 'https://github.githubassets.com/apple-touch-icon.png';
    } else {
      url = `https://t2.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://${domain}&size=128`;
    }
  }

  https.get(url, (upstreamRes) => {
    const statusCode = upstreamRes.statusCode || 200;
    
    // Check if it's a redirect (3xx)
    if (statusCode >= 300 && statusCode < 400 && upstreamRes.headers.location) {
      let redirectUrl = upstreamRes.headers.location;
      
      // Handle relative redirect URL
      if (!redirectUrl.startsWith('http://') && !redirectUrl.startsWith('https://')) {
        try {
          const parsedUrl = new URL(url);
          redirectUrl = new URL(redirectUrl, parsedUrl.origin).toString();
        } catch (err) {
          logger.error('Favicon proxy: Failed to resolve relative redirect URL:', err);
          res.writeHead(502);
          res.end();
          return;
        }
      }
      
      proxyFavicon(domain, res, redirectUrl, depth + 1);
    } else {
      const contentType = upstreamRes.headers['content-type'] || 'image/png';
      res.writeHead(statusCode, {
        'Content-Type': contentType,
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=86400',
      });
      upstreamRes.pipe(res);
    }
  }).on('error', (err) => {
    logger.error('Favicon proxy error:', err);
    res.writeHead(502);
    res.end();
  });
}

export class SocketServer {
  private io: Server | null = null;
  private server: http.Server | null = null;

  public start(port: number = env.PORT): void {
    this.server = http.createServer((req, res) => {
      // CORS preflight
      if (req.method === 'OPTIONS') {
        res.writeHead(204, { 
          'Access-Control-Allow-Origin': '*', 
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization' 
        });
        res.end();
        return;
      }

      const reqUrl = new URL(req.url || '/', `http://localhost:${port}`);

      // Favicon proxy endpoint: GET /favicon?domain=open.spotify.com
      if (reqUrl.pathname === '/favicon') {
        const domain = reqUrl.searchParams.get('domain');
        if (domain) {
          proxyFavicon(domain, res);
          return;
        }
        res.writeHead(400);
        res.end('Missing domain parameter');
        return;
      }

      // API: Get QR Code Data URL
      if (reqUrl.pathname === '/api/qr-code' || reqUrl.pathname === '/api/pairing/qr') {
        const customHost = reqUrl.searchParams.get('host') || undefined;
        const allIps = PairingService.getLocalIPAddresses();
        const activeHost = customHost || allIps[0] || '127.0.0.1';
        PairingService.getQRCodeDataUrl(port, activeHost)
          .then((dataUrl) => {
            res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
            res.end(JSON.stringify({ 
              success: true, 
              dataUrl, 
              qrCode: dataUrl,
              pairingToken: PairingService.getActivePairingToken() || '',
              host: activeHost,
              port,
              ips: allIps
            }));
          })
          .catch((err) => {
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: false, error: err.message }));
          });
        return;
      }

      // API: Get Agent Status & Network Info
      if (reqUrl.pathname === '/api/status') {
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({
          status: 'running',
          port,
          pid: process.pid,
          version: env.VERSION || '1.0.0',
          execPath: process.execPath,
          ips: PairingService.getLocalIPAddresses(),
          token: PairingService.getActivePairingToken(),
        }));
        return;
      }

      // API: Local-only Shutdown for Instance Takeover / Clean Restart
      if (reqUrl.pathname === '/api/shutdown' && (req.method === 'POST' || req.method === 'GET')) {
        const clientAddress = req.socket.remoteAddress || '';
        const isLoopback = clientAddress === '127.0.0.1' || 
                           clientAddress === '::1' || 
                           clientAddress === '::ffff:127.0.0.1' || 
                           clientAddress.includes('127.0.0.1');
        if (!isLoopback) {
          res.writeHead(403, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: false, error: 'Forbidden' }));
          return;
        }
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({ success: true, message: 'DevDeck server shutting down...' }));
        logger.info('🛑 Received local shutdown request. Stopping agent server cleanly...');
        setTimeout(() => {
          this.stop();
          process.exit(0);
        }, 200);
        return;
      }

      // Serve static frontend files from 'public' directory
      let publicDir = path.join(__dirname, '../../public');
      if (!fs.existsSync(publicDir)) {
        publicDir = path.join(process.cwd(), 'public');
      }

      let filePath = reqUrl.pathname === '/' ? '/index.html' : reqUrl.pathname;
      const safePath = path.normalize(path.join(publicDir, filePath));

      if (safePath.startsWith(publicDir) && fs.existsSync(safePath) && fs.statSync(safePath).isFile()) {
        const ext = path.extname(safePath).toLowerCase();
        const mimeTypes: Record<string, string> = {
          '.html': 'text/html; charset=utf-8',
          '.css': 'text/css; charset=utf-8',
          '.js': 'application/javascript; charset=utf-8',
          '.png': 'image/png',
          '.webp': 'image/webp',
          '.svg': 'image/svg+xml',
          '.json': 'application/json',
          '.ico': 'image/x-icon',
        };
        const contentType = mimeTypes[ext] || 'application/octet-stream';
        res.writeHead(200, { 'Content-Type': contentType, 'Cache-Control': 'no-cache' });
        fs.createReadStream(safePath).pipe(res);
        return;
      }

      // Fallback
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end('DevDeck Agent is running.\n');
    });

    this.io = new Server(this.server, {
      cors: {
        origin: '*', // Allow connections from any IP (especially mobile clients on local network)
        methods: ['GET', 'POST'],
      },
      pingTimeout: 10000,
      pingInterval: 5000,
    });

    this.io.use((socket, next) => {
      const auth = socket.handshake.auth;
      const clientAddress = socket.handshake.address;
      const isLoopback = clientAddress === '127.0.0.1' || 
                         clientAddress === '::1' || 
                         clientAddress === '::ffff:127.0.0.1' || 
                         clientAddress.includes('127.0.0.1');

      // Desktop GUI client loopback bypass
      if (auth?.clientType === 'desktop-gui' && isLoopback) {
        socket.data.authenticated = true;
        socket.data.isLocalGui = true;
        socket.data.deviceId = 'local-desktop-gui';
        socket.data.deviceName = 'DevDeck Dashboard';
        return next();
      }

      const token = auth?.token;

      if (token) {
        const result = TrustedDeviceService.validateDeviceToken(token);
        if (result.valid) {
          socket.data.authenticated = true;
          socket.data.deviceId = result.deviceId;
          socket.data.deviceName = result.deviceName;
          return next();
        } else {
          logger.warn(`Authentication failed: ${result.error}. Treating as unauthenticated.`);
          socket.data.authenticated = false;
          return next();
        }
      }

      // No token provided: connection is permitted, but will only be allowed to run pairing
      socket.data.authenticated = false;
      return next();
    });


    // Connection Handler
    this.io.on('connection', (socket) => {
      registerSocketEvents(this.io!, socket);
    });

    this.server.on('error', (err: any) => {
      if (err.code === 'EADDRINUSE') {
        logger.error(`❌ Port ${port} is already in use by another program. Please change the PORT in .env or stop the conflicting application.`);
      } else {
        logger.error('❌ Server encounter an unexpected error:', err);
      }
      process.exit(1);
    });

    this.server.listen(port, async () => {
      logger.info(`🚀 Socket.IO Server running on port ${port}`);
      
      // Initialize clipboard watcher/syncer
      ClipboardService.init(this.io!);
      
      // Generate Pairing QR Code and print to terminal
      try {
        await PairingService.generateQRCode(port);
      } catch (err) {
        logger.error('Failed to generate pairing QR code during startup:', err);
      }
    });
  }

  public getIO(): Server {
    if (!this.io) {
      throw new Error('SocketServer is not started yet.');
    }
    return this.io;
  }

  public stop(): void {
    ClipboardService.stopPolling();
    if (this.io) {
      this.io.close();
      logger.info('Socket.IO Server closed.');
    }
    if (this.server) {
      this.server.close();
      logger.info('HTTP Server stopped.');
    }
  }
}
