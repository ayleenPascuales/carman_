import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app';
import type { App, ServiceAccount } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const appName = 'carman-backend';

function credentials(config: ConfigService) {
  const json = config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (json) {
    let account: ServiceAccount;
    try {
      account = JSON.parse(json) as ServiceAccount;
    } catch {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON no es un JSON válido');
    }
    if ((account.projectId ?? (account as ServiceAccount & { project_id?: string }).project_id)
      !== config.getOrThrow<string>('FIREBASE_PROJECT_ID')) {
      throw new Error('FIREBASE_PROJECT_ID no coincide con la cuenta de servicio');
    }
    return cert(account);
  }

  const clientEmail = config.get<string>('FIREBASE_CLIENT_EMAIL');
  const privateKey = config.get<string>('FIREBASE_PRIVATE_KEY');
  if (clientEmail && privateKey) {
    return cert({
      projectId: config.getOrThrow<string>('FIREBASE_PROJECT_ID'),
      clientEmail,
      privateKey: privateKey.replace(/\\n/g, '\n'),
    });
  }

  // Para desarrollo local se puede indicar GOOGLE_APPLICATION_CREDENTIALS.
  return applicationDefault();
}

@Module({
  providers: [{
    provide: 'FIREBASE_AUTH',
    inject: [ConfigService],
    useFactory: (config: ConfigService) => {
      const projectId = config.getOrThrow<string>('FIREBASE_PROJECT_ID');
      const app: App = getApps().find((existing) => existing.name === appName)
        ?? initializeApp({ credential: credentials(config), projectId }, appName);
      if (app.options.projectId !== projectId) {
        throw new Error('FIREBASE_PROJECT_ID no coincide con la aplicación Firebase inicializada');
      }
      return getAuth(app);
    },
  }],
  exports: ['FIREBASE_AUTH'],
})
export class FirebaseModule {}
