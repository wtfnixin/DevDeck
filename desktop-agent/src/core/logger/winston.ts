import winston from 'winston';
import path from 'path';
import { EventEmitter } from 'events';
import { env } from '../config/env';
import Transport from 'winston-transport';

export interface LogEntry {
  timestamp: string;
  level: string;
  message: string;
  stack?: string;
}

export const logEvents = new EventEmitter();
const MAX_LOG_BUFFER = 500;
export const logBuffer: LogEntry[] = [];

class EventLogTransport extends Transport {
  constructor(opts?: Transport.TransportStreamOptions) {
    super(opts);
  }

  log(info: any, callback: () => void) {
    setImmediate(() => {
      const entry: LogEntry = {
        timestamp: info.timestamp || new Date().toISOString(),
        level: info.level || 'info',
        message: typeof info.message === 'string' ? info.message : JSON.stringify(info.message),
        stack: info.stack,
      };

      if (logBuffer.length >= MAX_LOG_BUFFER) {
        logBuffer.shift();
      }
      logBuffer.push(entry);
      logEvents.emit('log', entry);
    });
    callback();
  }
}

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
    new EventLogTransport(),
  ],
});

