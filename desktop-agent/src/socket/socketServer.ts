import { Server } from 'socket.io';
import http from 'http';
import https from 'https';
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
        res.writeHead(204, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET' });
        res.end();
        return;
      }

      // Favicon proxy endpoint: GET /favicon?domain=open.spotify.com
      const reqUrl = new URL(req.url || '/', `http://localhost:${port}`);
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
