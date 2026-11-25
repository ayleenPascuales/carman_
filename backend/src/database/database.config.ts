import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import type { PoolOptions } from 'mysql2';

export function databaseOptions(env: Record<string, string | undefined>): PoolOptions {
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
    ssl: {
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
