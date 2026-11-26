import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import type { PoolOptions } from 'mysql2';

export function databaseOptions(env: Record<string, string | undefined>): PoolOptions {
  const localTestDatabase = ['127.0.0.1', 'localhost', '::1'].includes(env.DB_HOST ?? '')
    && /^carman_(?:ensayo|test)(?:_|$)/.test(env.DB_NAME ?? '');
  if (env.DB_SSL_MODE === 'DISABLED' && !localTestDatabase) {
    throw new Error('Solo puede deshabilitarse TLS para una base Carman de ensayo local.');
  }
  const ca = env.DB_SSL_CA
    ? env.DB_SSL_CA.replace(/\\n/g, '\n')
    : env.DB_SSL_CA_PATH
      ? readFileSync(resolve(env.DB_SSL_CA_PATH), 'utf8')
      : undefined;
  return {
    host: env.DB_HOST,
    port: Number(env.DB_PORT ?? 4000),
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    database: env.DB_NAME,
    timezone: '-05:00',
    ssl: env.DB_SSL_MODE === 'DISABLED' ? undefined : {
      rejectUnauthorized: true,
      minVersion: 'TLSv1.2',
      ...(ca ? { ca } : {}),
    },
    waitForConnections: true,
    connectionLimit: Number(env.DB_POOL_SIZE ?? 2),
    maxIdle: 1,
    idleTimeout: 60_000,
    connectTimeout: 10_000,
    queueLimit: 0,
  };
}
