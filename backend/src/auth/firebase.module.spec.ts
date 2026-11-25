import { generateKeyPairSync } from 'node:crypto';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { deleteApp, getApps } from 'firebase-admin/app';
import type { Auth } from 'firebase-admin/auth';
import { FirebaseModule } from './firebase.module';

describe('Firebase Admin en entornos sin archivo de credenciales', () => {
  const previous = {
    project: process.env.FIREBASE_PROJECT_ID,
    email: process.env.FIREBASE_CLIENT_EMAIL,
    key: process.env.FIREBASE_PRIVATE_KEY,
  };

  afterAll(async () => {
    const app = getApps().find((candidate) => candidate.name === 'carman-backend');
    if (app) await deleteApp(app);
    for (const [name, value] of Object.entries({
      FIREBASE_PROJECT_ID: previous.project,
      FIREBASE_CLIENT_EMAIL: previous.email,
      FIREBASE_PRIVATE_KEY: previous.key,
    })) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  });

  it('inicializa con llave PEM escapada desde variables de Vercel', async () => {
    const { privateKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
      publicKeyEncoding: { type: 'spki', format: 'pem' },
    });
    process.env.FIREBASE_PROJECT_ID = 'carman-test';
    process.env.FIREBASE_CLIENT_EMAIL = 'admin@carman-test.iam.gserviceaccount.com';
    process.env.FIREBASE_PRIVATE_KEY = privateKey.replace(/\n/g, '\\n');

    const module = await Test.createTestingModule({
      imports: [ConfigModule.forRoot({ isGlobal: true, ignoreEnvFile: true }), FirebaseModule],
    }).compile();
    const auth = module.get<Auth>('FIREBASE_AUTH');
    expect(auth.app.options.projectId).toBe('carman-test');
    await module.close();
  });
});
