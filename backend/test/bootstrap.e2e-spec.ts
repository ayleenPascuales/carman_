import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { configureApp } from '../src/configure-app';

describe('Arranque real del grafo Nest en Vercel (servicios externos simulados)', () => {
  let app: INestApplication;
  const variables = {
    VERCEL: '1',
    DB_HOST: 'example.tidbcloud.com',
    DB_USER: 'user',
    DB_PASSWORD: 'password',
    DB_NAME: 'carman',
    FIREBASE_PROJECT_ID: 'carman-test',
    FIREBASE_API_KEY: 'web-api-key',
    FIREBASE_CLIENT_EMAIL: 'admin@carman-test.iam.gserviceaccount.com',
    FIREBASE_PRIVATE_KEY: 'private-key',
    CORS_ORIGINS: 'https://carman.example',
    CRON_SECRET: 'testing-secret',
  };
  const previous = Object.fromEntries(
    Object.keys(variables).map((key) => [key, process.env[key]]),
  );
  const pool = {
    query: jest.fn().mockResolvedValue([[{ ok: 1 }]]),
    end: jest.fn().mockResolvedValue(undefined),
  };

  beforeAll(async () => {
    Object.assign(process.env, variables);
    // La validación de entorno se registra al importar AppModule.
    const { AppModule } = await import('../src/app.module');
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider('DATABASE_CONNECTION').useValue(pool)
      .overrideProvider('FIREBASE_AUTH').useValue({ verifyIdToken: jest.fn() })
      .compile();
    app = module.createNestApplication();
    configureApp(app);
    await app.init();
  });

  afterAll(async () => {
    if (app) await app.close();
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });

  it('inicializa todos los módulos sin archivos locales ni cron en memoria', async () => {
    await request(app.getHttpServer()).get('/health').expect(200, {
      status: 'ok',
      database: 'ok',
    });
    expect(pool.query).toHaveBeenCalledWith('SELECT 1');
  });
});
