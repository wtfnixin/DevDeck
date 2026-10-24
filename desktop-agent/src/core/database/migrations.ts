import { db } from './connection';
import { SCHEMA_SQL } from './schema';
import { logger } from '../logger/winston';
import { AppRegistryService } from '../../services/appRegistryService';
import { WebsiteRegistryService } from '../../services/websiteRegistryService';
import { WorkspaceService } from '../../services/workspaceService';
import crypto from 'crypto';

export function runMigrations(): void {
  try {
    logger.info('🔄 Running database migrations...');
    
    // Create tables
    db.exec(SCHEMA_SQL);
    logger.info('✅ Tables checked/created successfully.');

    // Seed default settings if not exists
    const settingsCount = db.prepare('SELECT count(*) as count FROM settings').get() as { count: number };
    if (settingsCount.count === 0) {
      logger.info('🌱 Seeding default settings...');
      const insertSetting = db.prepare('INSERT INTO settings (key, value) VALUES (?, ?)');
      insertSetting.run('theme', 'dark');
      insertSetting.run('clipboard_sync', 'true');
      insertSetting.run('notifications', 'true');
    }

    // Seed default gestures if not exists
    const gesturesCount = db.prepare('SELECT count(*) as count FROM gestures').get() as { count: number };
    if (gesturesCount.count === 0) {
      logger.info('🌱 Seeding default gestures...');
      const insertGesture = db.prepare('INSERT INTO gestures (id, gesture_type, action_type, payload) VALUES (?, ?, ?, ?)');
      
      const defaultGestures = [
        {
          id: crypto.randomUUID(),
          gesture_type: 'swipe_left',
          action_type: 'switch_desktop',
          payload: JSON.stringify({ direction: 'right' })
        },
        {
          id: crypto.randomUUID(),
          gesture_type: 'swipe_right',
          action_type: 'switch_desktop',
          payload: JSON.stringify({ direction: 'left' })
        },
        {
          id: crypto.randomUUID(),
          gesture_type: 'swipe_up',
          action_type: 'run_command',
          payload: JSON.stringify({ command: 'powershell -Command "$wsh = New-Object -ComObject Wscript.Shell; $wsh.SendKeys(\'^{ESC}\')"' }) // Example: Win menu
        },
        {
          id: crypto.randomUUID(),
          gesture_type: 'swipe_down',
          action_type: 'run_command',
          payload: JSON.stringify({ command: 'powershell -Command "(New-Object -ComObject Shell.Application).ToggleDesktop()"' })
        },
        {
          id: crypto.randomUUID(),
          gesture_type: 'double_tap',
          action_type: 'launch_workspace',
          payload: JSON.stringify({ workspaceId: 'default-dev-env' })
        },
        {
          id: crypto.randomUUID(),
          gesture_type: 'long_press',
          action_type: 'run_command',
          payload: JSON.stringify({ command: 'calc.exe' }) // Quick calculator launcher
        }
      ];

      for (const gesture of defaultGestures) {
        insertGesture.run(gesture.id, gesture.gesture_type, gesture.action_type, gesture.payload);
      }
    }

    // Explicitly update existing tables to correct incorrect mapping payloads
    try {
      db.prepare("UPDATE gestures SET payload = ? WHERE gesture_type = 'double_tap'")
        .run(JSON.stringify({ workspaceId: 'default-dev-env' }));
      
      db.prepare("UPDATE gestures SET payload = ? WHERE gesture_type = 'swipe_down'")
        .run(JSON.stringify({ command: 'powershell -Command "(New-Object -ComObject Shell.Application).ToggleDesktop()"' }));

      db.prepare("UPDATE gestures SET action_type = 'switch_desktop', payload = ? WHERE gesture_type = 'swipe_left'")
        .run(JSON.stringify({ direction: 'right' }));

      db.prepare("UPDATE gestures SET action_type = 'switch_desktop', payload = ? WHERE gesture_type = 'swipe_right'")
        .run(JSON.stringify({ direction: 'left' }));
    } catch (dbErr) {
      logger.warn('Failed to perform incremental gesture mappings update:', dbErr);
    }

    // Seed default apps and websites
    AppRegistryService.seedDefaults();
    WebsiteRegistryService.seedDefaults();
    WorkspaceService.seedDefaults();

    logger.info('🎉 Database migration and seeding completed.');
  } catch (error) {
    logger.error('❌ Migration failed:', error);
    throw error;
  }
}
