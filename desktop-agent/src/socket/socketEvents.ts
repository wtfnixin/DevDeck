import { Server, Socket } from 'socket.io';
import { logger, logEvents, logBuffer, LogEntry } from '../core/logger/winston';
import { PairingService } from '../authentication/pairingService';
import { TrustedDeviceService } from '../authentication/trustedDeviceService';
import { AppRegistryService } from '../services/appRegistryService';
import { WebsiteRegistryService } from '../services/websiteRegistryService';
import { ClipboardService } from '../services/clipboardService';
import { WorkspaceService } from '../services/workspaceService';
import { AppDiscoveryService } from '../services/appDiscoveryService';
import { DeviceRepository } from '../repositories/deviceRepository';
import { ShortcutResolver } from '../utils/shortcutResolver';
import { pairingRequestSchema } from '../core/validation/zodSchemas';
import { appEvents, EVENTS } from '../core/events/eventEmitter';
import { db } from '../core/database/connection';
import { env } from '../core/config/env';
import { exec } from 'child_process';
import path from 'path';
import { BrightnessManager } from '../utils/brightnessManager';
import { VolumeManager } from '../utils/volumeManager';

export function registerSocketEvents(io: Server, socket: Socket): void {
  const isAuth = socket.data.authenticated === true;
  
  if (isAuth) {
    logger.info(`🔌 Client authenticated: ${socket.data.deviceName} (${socket.data.deviceId}) [Socket ID: ${socket.id}]`);
    socket.emit('connection:status', { status: 'connected', deviceName: socket.data.deviceName });
    appEvents.emit(EVENTS.DEVICE_CONNECTED, { deviceId: socket.data.deviceId, socketId: socket.id });

    // Stream logs to local GUI client
    if (socket.data.isLocalGui) {
      socket.emit('logs:history', { logs: logBuffer });
      const logHandler = (entry: LogEntry) => {
        socket.emit('logs:stream', entry);
      };
      logEvents.on('log', logHandler);

      socket.on('disconnect', () => {
        logEvents.off('log', logHandler);
      });
    }

    // Handle authenticated disconnect
    socket.on('disconnect', (reason) => {
      logger.info(`🔌 Client disconnected: ${socket.data.deviceName} (${socket.data.deviceId}) [Reason: ${reason}]`);
      appEvents.emit(EVENTS.DEVICE_DISCONNECTED, { deviceId: socket.data.deviceId, socketId: socket.id });
    });


    // Clipboard Sync
    socket.on('clipboard:sync', (payload: { content: string }) => {
      try {
        if (payload && payload.content) {
          ClipboardService.handleMobileSync(payload.content);
          // Broadcast to other devices
          socket.broadcast.emit('clipboard:sync', {
            content: payload.content,
            source: 'mobile',
            timestamp: Date.now(),
          });
        }
      } catch (error) {
        logger.error('Failed to handle clipboard:sync event:', error);
      }
    });

    // Launcher: Query available apps
    socket.on('launcher:apps', (callback?: (res: any) => void) => {
      try {
        const apps = AppRegistryService.getAllApps();
        const res = { success: true, apps };
        if (callback) callback(res);
        socket.emit('launcher:apps:response', res);
      } catch (error: any) {
        logger.error('Failed to handle launcher:apps event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Launcher: Launch an app
    socket.on('launcher:launch-app', async (payload: { id: string }, callback?: (res: any) => void) => {
      try {
        if (!payload || !payload.id) {
          throw new Error('Missing app ID');
        }
        await AppRegistryService.launchApp(payload.id);
        const res = { success: true };
        if (callback) callback(res);
      } catch (error: any) {
        logger.error('Failed to handle launcher:launch-app event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Launcher: Register/Update an app
    socket.on('launcher:register-app', (payload: any, callback?: (res: any) => void) => {
      try {
        const app = AppRegistryService.registerApp(payload);
        const res = { success: true, app };
        if (callback) callback(res);
        io.emit('launcher:apps:updated', { apps: AppRegistryService.getAllApps() });
      } catch (error: any) {
        logger.error('Failed to handle launcher:register-app event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Launcher: Scan running and installed apps on PC
    socket.on('launcher:scan-system-apps', async (callback?: (res: any) => void) => {
      try {
        const [running, installed] = await Promise.all([
          AppDiscoveryService.getRunningApps(),
          AppDiscoveryService.getInstalledApps()
        ]);
        const res = { success: true, running, installed };
        if (callback) callback(res);
      } catch (error: any) {
        logger.error('Failed to scan system apps:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Launcher: Extract icon for discovered installed app on demand
    socket.on('launcher:extract-discovered-icon', (payload: { path: string }, callback?: (res: any) => void) => {
      try {
        if (!payload || !payload.path) {
          throw new Error('Missing application path');
        }
        const icon = AppRegistryService.extractExeIcon(payload.path);
        const res = { success: true, icon };
        if (callback) callback(res);
      } catch (error: any) {
        logger.error('Failed to extract discovered icon:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Launcher: Delete an app
    socket.on('launcher:delete-app', (payload: { id: string }, callback?: (res: any) => void) => {
      try {
        if (!payload || !payload.id) {
          throw new Error('Missing app ID');
        }
        AppRegistryService.deleteApp(payload.id);
        const res = { success: true };
        if (callback) callback(res);
        io.emit('launcher:apps:updated', { apps: AppRegistryService.getAllApps() });
      } catch (error: any) {
        logger.error('Failed to handle launcher:delete-app event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Launcher: Register app directly from dropped file path
    socket.on('launcher:register-from-file', async (payload: { filePath: string; category?: string }, callback?: (res: any) => void) => {
      try {
        if (!payload || !payload.filePath) {
          throw new Error('Missing file path');
        }
        const rawPath = payload.filePath.trim();
        logger.info(`Drag & Drop received: ${rawPath}`);
        const resolvedPath = await ShortcutResolver.resolve(rawPath);
        const parsed = path.parse(resolvedPath);
        const rawName = parsed.name || 'Application';
        const friendlyName = rawName.charAt(0).toUpperCase() + rawName.slice(1);

        const app = AppRegistryService.registerApp({
          name: friendlyName,
          executablePath: resolvedPath,
          icon: null,
          category: payload.category || 'Developer',
        });


        logger.info(`✨ Successfully registered app from drop: ${app.name} (${resolvedPath})`);
        const res = { success: true, app };
        if (callback) callback(res);
        io.emit('launcher:apps:updated', { apps: AppRegistryService.getAllApps() });
      } catch (error: any) {
        logger.error('Failed to register app from dropped file:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Device Management: List all trusted devices
    socket.on('device:list', (callback?: (res: any) => void) => {
      try {
        const devices = DeviceRepository.getAllTrustedDevices();
        const activeSockets = Array.from(io.sockets.sockets.values()).filter(s => s.data.authenticated && !s.data.isLocalGui);
        const activeDeviceIds = new Set(activeSockets.map(s => s.data.deviceId));
        
        const enriched = devices.map(d => ({
          ...d,
          isOnline: activeDeviceIds.has(d.id),
        }));

        const res = { success: true, devices: enriched };
        if (callback) callback(res);
        socket.emit('device:list:response', res);
      } catch (error: any) {
        logger.error('Failed to list devices:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Device Management: Revoke a device
    socket.on('device:revoke', (payload: { deviceId: string }, callback?: (res: any) => void) => {
      try {
        if (!payload || !payload.deviceId) {
          throw new Error('Missing device ID');
        }
        DeviceRepository.revokeDevice(payload.deviceId);
        
        // Disconnect sockets for this device
        const sockets = Array.from(io.sockets.sockets.values());
        for (const s of sockets) {
          if (s.data.deviceId === payload.deviceId) {
            s.emit('connection:status', { status: 'revoked' });
            s.disconnect(true);
          }
        }

        const res = { success: true };
        if (callback) callback(res);
        io.emit('device:list:updated', { devices: DeviceRepository.getAllTrustedDevices() });
      } catch (error: any) {
        logger.error('Failed to revoke device:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // System: Get status, network info, active pairing details
    socket.on('system:info', (callback?: (res: any) => void) => {
      try {
        const token = PairingService.getActivePairingToken();
        const ips = PairingService.getLocalIPAddresses();
        const host = ips[0] || '127.0.0.1';
        const port = env.PORT;
        const pairingUri = `devdeck://pair?host=${host}&port=${port}&token=${token}`;
        const activeSockets = Array.from(io.sockets.sockets.values()).filter(s => s.data.authenticated && !s.data.isLocalGui);

        const res = {
          success: true,
          host,
          port,
          ips,
          token,
          pairingUri,
          activeDeviceCount: activeSockets.length,
          totalRegisteredApps: AppRegistryService.getAllApps().length,
        };
        if (callback) callback(res);
        socket.emit('system:info:response', res);
      } catch (error: any) {
        logger.error('Failed to query system info:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });


    // Launcher: Query available websites
    socket.on('launcher:websites', (callback?: (res: any) => void) => {
      try {
        const websites = WebsiteRegistryService.getAllWebsites();
        const res = { success: true, websites };
        if (callback) callback(res);
        socket.emit('launcher:websites:response', res);
      } catch (error: any) {
        logger.error('Failed to handle launcher:websites event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Launcher: Launch a website
    socket.on('launcher:launch-website', async (payload: { id: string }, callback?: (res: any) => void) => {
      try {
        if (!payload || !payload.id) {
          throw new Error('Missing website ID');
        }
        await WebsiteRegistryService.launchWebsite(payload.id);
        const res = { success: true };
        if (callback) callback(res);
      } catch (error: any) {
        logger.error('Failed to handle launcher:launch-website event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Launcher: Register/Update a website
    socket.on('launcher:register-website', (payload: any, callback?: (res: any) => void) => {
      try {
        const website = WebsiteRegistryService.registerWebsite(payload);
        const res = { success: true, website };
        if (callback) callback(res);
        io.emit('launcher:websites:updated', { websites: WebsiteRegistryService.getAllWebsites() });
      } catch (error: any) {
        logger.error('Failed to handle launcher:register-website event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Launcher: Delete a website
    socket.on('launcher:delete-website', (payload: { id: string }, callback?: (res: any) => void) => {
      try {
        if (!payload || !payload.id) {
          throw new Error('Missing website ID');
        }
        WebsiteRegistryService.deleteWebsite(payload.id);
        const res = { success: true };
        if (callback) callback(res);
        io.emit('launcher:websites:updated', { websites: WebsiteRegistryService.getAllWebsites() });
      } catch (error: any) {
        logger.error('Failed to handle launcher:delete-website event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Workspace: List workspaces
    socket.on('workspace:list', (callback?: (res: any) => void) => {
      try {
        const workspaces = WorkspaceService.getAllWorkspaces();
        const res = { success: true, workspaces };
        if (callback) callback(res);
        socket.emit('workspace:list:response', res);
      } catch (error: any) {
        logger.error('Failed to handle workspace:list event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Workspace: Execute workspace flow
    socket.on('workspace:execute', (payload: { id: string }, callback?: (res: any) => void) => {
      try {
        if (!payload || !payload.id) {
          throw new Error('Missing workspace ID');
        }
        WorkspaceService.executeWorkspace(payload.id);
        const res = { success: true };
        if (callback) callback(res);
      } catch (error: any) {
        logger.error('Failed to handle workspace:execute event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Workspace: Register a new workspace
    socket.on('workspace:register', (payload: any, callback?: (res: any) => void) => {
      try {
        const success = WorkspaceService.registerWorkspace(payload);
        const res = { success };
        if (callback) callback(res);
        io.emit('workspace:list:updated', { workspaces: WorkspaceService.getAllWorkspaces() });
      } catch (error: any) {
        logger.error('Failed to handle workspace:register event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Workspace: Delete a workspace
    socket.on('workspace:delete', (payload: { id: string }, callback?: (res: any) => void) => {
      try {
        if (!payload || !payload.id) {
          throw new Error('Missing workspace ID');
        }
        const success = WorkspaceService.deleteWorkspace(payload.id);
        const res = { success };
        if (callback) callback(res);
        io.emit('workspace:list:updated', { workspaces: WorkspaceService.getAllWorkspaces() });
      } catch (error: any) {
        logger.error('Failed to handle workspace:delete event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // Gesture: Trigger action
    socket.on('gesture:trigger', async (payload: { gestureType: string }, callback?: (res: any) => void) => {
      try {
        if (!payload || !payload.gestureType) {
          throw new Error('Missing gesture type');
        }
        
        logger.info(`🎯 Gesture triggered: ${payload.gestureType}`);
        
        // Find gesture mapping in SQLite
        const gesture = db.prepare('SELECT action_type as actionType, payload FROM gestures WHERE gesture_type = ?').get(payload.gestureType) as { actionType: string; payload: string } | undefined;
        
        if (!gesture) {
          logger.warn(`No action mapping found for gesture: ${payload.gestureType}`);
          if (callback) callback({ success: false, error: 'No mapping found' });
          return;
        }

        const actionPayload = JSON.parse(gesture.payload);
        logger.info(`Executing action for gesture ${payload.gestureType}: ${gesture.actionType}`);

        if (gesture.actionType === 'run_command' && actionPayload.command) {
          exec(actionPayload.command, (err) => {
            if (err) logger.error(`Gesture command failed: ${actionPayload.command}`, err);
          });
          if (callback) callback({ success: true });
        } else if (gesture.actionType === 'launch_workspace' && (actionPayload.workspaceId || actionPayload.workspace_id)) {
          const wsId = actionPayload.workspaceId || actionPayload.workspace_id;
          WorkspaceService.executeWorkspace(wsId);
          if (callback) callback({ success: true });
        } else {
          logger.warn(`Unsupported gesture action type: ${gesture.actionType}`);
          if (callback) callback({ success: false, error: 'Unsupported action type' });
        }
      } catch (error: any) {
        logger.error('Failed to handle gesture:trigger event:', error);
        if (callback) callback({ success: false, error: error.message });
      }
    });

    // System controls: Volume Up
    socket.on('system:volume-up', (dataOrCallback?: any, callback?: (res: any) => void) => {
      const cb = typeof dataOrCallback === 'function' ? dataOrCallback : (typeof callback === 'function' ? callback : undefined);
      try {
        VolumeManager.volumeUp(cb);
      } catch (error: any) {
        logger.error('system:volume-up error:', error);
        if (cb) cb({ success: false, error: error.message });
      }
    });

    // System controls: Volume Down
    socket.on('system:volume-down', (dataOrCallback?: any, callback?: (res: any) => void) => {
      const cb = typeof dataOrCallback === 'function' ? dataOrCallback : (typeof callback === 'function' ? callback : undefined);
      try {
        VolumeManager.volumeDown(cb);
      } catch (error: any) {
        logger.error('system:volume-down error:', error);
        if (cb) cb({ success: false, error: error.message });
      }
    });

    // System controls: Volume Mute (Silent)
    socket.on('system:volume-mute', (dataOrCallback?: any, callback?: (res: any) => void) => {
      const cb = typeof dataOrCallback === 'function' ? dataOrCallback : (typeof callback === 'function' ? callback : undefined);
      try {
        VolumeManager.volumeMute(cb);
      } catch (error: any) {
        logger.error('system:volume-mute error:', error);
        if (cb) cb({ success: false, error: error.message });
      }
    });

    // System controls: Brightness Up
    socket.on('system:brightness-up', async (dataOrCallback?: any, callback?: (res: any) => void) => {
      const cb = typeof dataOrCallback === 'function' ? dataOrCallback : (typeof callback === 'function' ? callback : undefined);
      try {
        const res = await BrightnessManager.adjustBrightness(10);
        if (cb) cb(res);
      } catch (error: any) {
        logger.error('system:brightness-up error:', error);
        if (cb) cb({ success: false, error: error.message });
      }
    });

    // System controls: Brightness Down
    socket.on('system:brightness-down', async (dataOrCallback?: any, callback?: (res: any) => void) => {
      const cb = typeof dataOrCallback === 'function' ? dataOrCallback : (typeof callback === 'function' ? callback : undefined);
      try {
        const res = await BrightnessManager.adjustBrightness(-10);
        if (cb) cb(res);
      } catch (error: any) {
        logger.error('system:brightness-down error:', error);
        if (cb) cb({ success: false, error: error.message });
      }
    });
    
  } else {
    logger.info(`🔌 Unauthenticated client connected [Socket ID: ${socket.id}]. Awaiting pairing...`);
    socket.emit('connection:status', { status: 'pairingRequired' });

    // Handle pairing request
    socket.on('pairing:request', async (payload: unknown, callback?: (response: any) => void) => {
      try {
        logger.info(`Received pairing:request from socket ${socket.id}`);
        
        // Validate payload
        const validation = pairingRequestSchema.safeParse(payload);
        if (!validation.success) {
          logger.warn(`Invalid pairing payload: ${JSON.stringify(validation.error.format())}`);
          const errRes = { success: false, error: 'Invalid pairing request fields' };
          if (callback) callback(errRes);
          socket.emit('pairing:response', errRes);
          return;
        }

        const { deviceId, deviceName, pairingToken } = validation.data;
        const result = PairingService.verifyPairingRequest(deviceId, deviceName, pairingToken);

        if (result.success) {
          const successRes = { success: true, token: result.jwt };
          if (callback) callback(successRes);
          socket.emit('pairing:response', successRes);
          
          // Notify app pairing approved
          socket.emit('pairing:approved');
          
          // Let client know they should disconnect and reconnect using the token
          logger.info(`Device ${deviceName} successfully paired. Requesting client reconnection with token.`);
        } else {
          const failRes = { success: false, error: result.error || 'Pairing verification failed' };
          if (callback) callback(failRes);
          socket.emit('pairing:response', failRes);
        }
      } catch (error) {
        logger.error('Error during pairing request execution:', error);
        const errRes = { success: false, error: 'Internal server error during pairing' };
        if (callback) callback(errRes);
        socket.emit('pairing:response', errRes);
      }
    });

    socket.on('disconnect', (reason) => {
      logger.info(`🔌 Unauthenticated client disconnected [Socket ID: ${socket.id}] [Reason: ${reason}]`);
    });

    // Catch-all block for unauthenticated clients: ignore other requests
    const originalOn = socket.on;
    socket.on = function (event: string, listener: (...args: any[]) => void) {
      if (event === 'pairing:request' || event === 'disconnect') {
        return originalOn.call(this, event, listener);
      }
      logger.warn(`Blocked event '${event}' from unauthenticated client [Socket ID: ${socket.id}]`);
      return socket;
    };
  }
}

function runKeyboardEvent(vkCode: number, callback?: (res: any) => void) {
  VolumeManager.sendVolumeEvent(vkCode, callback);
}

