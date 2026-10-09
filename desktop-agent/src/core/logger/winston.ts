import winston from 'winston';
import path from 'path';
import { env } from '../config/env';

const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.splat(),
  winston.format.json()
);

const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.printf(({ timestamp, level, message, stack }) => {
    return `[${timestamp}] ${level}: ${message}${stack ? `\n${stack}` : ''}`;
  })
);

const isPackaged = typeof (process as any).pkg !== 'undefined';
let logsBaseDir: string;

if (isPackaged) {
  const appData = process.env.APPDATA || (process.platform === 'darwin' ? path.join(process.env.HOME || '', 'Library', 'Application Support') : path.join(process.env.HOME || '', '.config'));
  logsBaseDir = path.join(appData, 'DevDeck');
} else {
  logsBaseDir = path.join(__dirname, '../../../../');
}

export const logger = winston.createLogger({
  level: env.LOG_LEVEL,
  format: logFormat,
  transports: [
    new winston.transports.Console({
      format: consoleFormat,
    }),
    new winston.transports.File({
      filename: path.join(logsBaseDir, 'logs/error.log'),
      level: 'error',
    }),
    new winston.transports.File({
      filename: path.join(logsBaseDir, 'logs/combined.log'),
    }),
  ],
});
