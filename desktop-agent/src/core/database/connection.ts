import Database from 'better-sqlite3';
import path from 'path';
import { env } from '../config/env';
import { logger } from '../logger/winston';
import fs from 'fs';

const isPackaged = (process as any).pkg !== undefined || process.env.NODE_ENV === 'production';
let dbPath = env.DATABASE_PATH;

if (isPackaged) {
  const appData = process.env.APPDATA || (process.platform === 'darwin' ? path.join(process.env.HOME || '', 'Library', 'Application Support') : path.join(process.env.HOME || '', '.config'));
  const devdeckDir = path.join(appData, 'DevDeck');
  if (!fs.existsSync(devdeckDir)) {
    fs.mkdirSync(devdeckDir, { recursive: true });
  }
  dbPath = path.join(devdeckDir, 'devdeck.db');
} else {
  const dbDir = path.dirname(path.resolve(dbPath));
  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
  }
}

let db: Database.Database;

try {
  db = new Database(dbPath, { verbose: (message) => logger.debug(`[DB] ${message}`) });
  db.pragma('journal_mode = WAL');
  logger.info(`💾 Database connected successfully at ${dbPath}`);
} catch (error) {
  logger.error('❌ Failed to connect to SQLite database:', error);
  throw error;
}

export { db };
