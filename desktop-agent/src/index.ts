import { logger } from './core/logger/winston';
import { runMigrations } from './core/database/migrations';
import { SocketServer } from './socket/socketServer';
import { PairingService } from './authentication/pairingService';

export async function bootstrap() {
  try {
    logger.info('🚀 Starting DevDeck Desktop Agent...');

    // 1. Run database migrations and seeding
    runMigrations();

    // 2. Generate active pairing token
    PairingService.generatePairingToken();

    // 3. Start Socket Server
    const server = new SocketServer();
    server.start();

    // Handle process termination cleanly
    const handleShutdown = (signal: string) => {
      logger.info(`Received ${signal}. Shutting down DevDeck Agent...`);
      server.stop();
      process.exit(0);
    };

    process.on('SIGINT', () => handleShutdown('SIGINT'));
    process.on('SIGTERM', () => handleShutdown('SIGTERM'));

    return server;
  } catch (error) {
    logger.error('💥 DevDeck Agent failed to start:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  bootstrap();
}

