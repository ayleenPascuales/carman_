import { databaseOptions } from './database.config';

describe('Conexión MySQL TiDB', () => {
  it('usa TLS verificado y un pool pequeño reutilizable', () => {
    const config = databaseOptions({
      DB_HOST: 'example.tidbcloud.com',
      DB_NAME: 'carman',
      DB_USER: 'user',
      DB_PASSWORD: 'password',
    });
    expect(config).toMatchObject({
      port: 4000,
      connectionLimit: 2,
      maxIdle: 1,
      idleTimeout: 60_000,
      connectTimeout: 10_000,
      ssl: { rejectUnauthorized: true, minVersion: 'TLSv1.2' },
    });
  });

  it('acepta PEM privado inyectado desde Vercel', () => {
    const config = databaseOptions({ DB_SSL_CA: 'line1\\nline2', DB_POOL_SIZE: '3' });
    expect(config.ssl).toMatchObject({ ca: 'line1\nline2', rejectUnauthorized: true });
    expect(config.connectionLimit).toBe(3);
  });

  it('lee el certificado público ISRG Root X1 desde el archivo local', () => {
    const config = databaseOptions({ DB_SSL_CA_PATH: 'certs/isrgrootx1.pem' });
    expect(config.ssl).toMatchObject({
      ca: expect.stringContaining('-----BEGIN CERTIFICATE-----'),
      rejectUnauthorized: true,
    });
  });
});
