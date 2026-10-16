import crypto from 'crypto';
import QRCode from 'qrcode';
import path from 'path';
import fs from 'fs';
import os from 'os';
import { env } from '../core/config/env';
import { logger } from '../core/logger/winston';
import { DeviceRepository } from '../repositories/deviceRepository';
import { JWTService } from './jwtService';

export class PairingService {
  private static activePairingToken: string | null = null;

  public static generatePairingToken(): string {
    // If PAIRING_TOKEN is set in env, use that. Otherwise, generate a random one.
    if (env.PAIRING_TOKEN) {
      this.activePairingToken = env.PAIRING_TOKEN;
    } else {
      this.activePairingToken = crypto.randomBytes(16).toString('hex');
    }
    logger.info(`🔑 Active pairing token: ${this.activePairingToken}`);
    return this.activePairingToken;
  }

  public static getActivePairingToken(): string | null {
    if (!this.activePairingToken) {
      return this.generatePairingToken();
    }
    return this.activePairingToken;
  }

  public static getLocalIPAddresses(): string[] {
    const interfaces = os.networkInterfaces();
    const addresses: string[] = [];
    for (const name of Object.keys(interfaces)) {
      const netInterface = interfaces[name];
      if (netInterface) {
        for (const address of netInterface) {
          if (address.family === 'IPv4' && !address.internal) {
            addresses.push(address.address);
          }
        }
      }
    }
    return addresses;
  }

  public static async generateQRCode(port: number): Promise<{ pairingUri: string; qrPngPath: string }> {
    const token = this.getActivePairingToken() || this.generatePairingToken();
    const localIPs = this.getLocalIPAddresses();
    const host = localIPs[0] || '127.0.0.1'; // Use first non-internal IP or localhost fallback
    
    // Construct pairing URI
    const pairingUri = `devdeck://pair?host=${host}&port=${port}&token=${token}`;
    
    const isPackaged = typeof (process as any).pkg !== 'undefined';
    const baseDir = isPackaged ? path.dirname(process.execPath) : path.join(__dirname, '../../../');
    const qrDir = path.join(baseDir, 'artifacts');
    if (!fs.existsSync(qrDir)) {
      fs.mkdirSync(qrDir, { recursive: true });
    }
    
    const qrPngPath = path.join(qrDir, 'pairing-qr.png');
    
    // Also copy to AppData brain folder for artifact embedding
    const brainDir = 'C:\\Users\\NITIN\\.gemini\\antigravity\\brain\\13a9817a-ee8d-4767-819c-023ad9ad59b7';
    const brainPngPath = path.join(brainDir, 'pairing-qr.png');
    
    try {
      // 1. Save QR code to a PNG image file
      await QRCode.toFile(qrPngPath, pairingUri, {
        color: {
          dark: '#0f172a',  // Slate 900
          light: '#f8fafc', // Slate 50
        },
        width: 300,
      });

      if (fs.existsSync(brainDir)) {
        fs.copyFileSync(qrPngPath, brainPngPath);
      }

      // 2. Generate a text-based QR code for terminal output
      const terminalQR = await QRCode.toString(pairingUri, { type: 'terminal', small: true });
      
      logger.info('\n' + '='.repeat(50) + '\n' +
        '📱 DEVDECK PAIRING QR CODE\n' +
        '='.repeat(50) + '\n' +
        `Pairing URI: ${pairingUri}\n` +
        `Local IPs detected: ${localIPs.join(', ')}\n` +
        'Scan the QR code below using the DevDeck Android App to pair:\n' +
        terminalQR + '\n' +
        '='.repeat(50) + '\n' +
        `🖼️ QR Code image saved to: ${qrPngPath}`
      );
      
      return { pairingUri, qrPngPath };
    } catch (error) {
      logger.error('Failed to generate pairing QR code:', error);
      throw error;
    }
  }

  public static async getQRCodeDataUrl(port: number, customHost?: string): Promise<string> {
    const token = this.getActivePairingToken() || this.generatePairingToken();
    const localIPs = this.getLocalIPAddresses();
    const host = customHost || localIPs[0] || '127.0.0.1';
    const pairingUri = `devdeck://pair?host=${host}&port=${port}&token=${token}`;
    return await QRCode.toDataURL(pairingUri, {
      color: {
        dark: '#0f172a',
        light: '#ffffff',
      },
      width: 280,
      margin: 1,
    });
  }

  public static verifyPairingRequest(deviceId: string, deviceName: string, token: string): { success: boolean; jwt?: string; error?: string } {

    const activeToken = this.getActivePairingToken();
    
    if (!activeToken) {
      return { success: false, error: 'No active pairing session. Restart server.' };
    }

    if (token !== activeToken) {
      logger.warn(`⚠️ Pairing attempt failed for device ${deviceName} (${deviceId}): Invalid token.`);
      return { success: false, error: 'Invalid pairing token.' };
    }

    // Success: Create token hash for trusted_devices DB
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    DeviceRepository.saveTrustedDevice(deviceId, deviceName, tokenHash);

    // Issue JWT
    const jwt = JWTService.issueJWT({ deviceId, deviceName });

    logger.info(`🎉 Device paired successfully: ${deviceName} (${deviceId})`);
    
    return { success: true, jwt };
  }
}
