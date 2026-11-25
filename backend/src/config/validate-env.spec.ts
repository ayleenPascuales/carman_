import { validateEnv } from './validate-env';

const valid = {
  DB_HOST: 'example.tidbcloud.com',
  DB_USER: 'user',
  DB_PASSWORD: 'password',
  DB_NAME: 'carman',
  FIREBASE_PROJECT_ID: 'example',
  FIREBASE_API_KEY: 'api-key',
  FIREBASE_CLIENT_EMAIL: 'admin@example.iam.gserviceaccount.com',
  FIREBASE_PRIVATE_KEY: 'private-key',
};

describe('Configuración obligatoria', () => {
  it('acepta credenciales de servicio y puerto predeterminado', () => {
    expect(validateEnv(valid)).toEqual(valid);
  });

  it('se niega a iniciar con datos incompletos sin mostrar contraseñas', () => {
    expect(() => validateEnv({ ...valid, DB_PASSWORD: '' })).toThrow('DB_PASSWORD');
  });

  it('exige origen web y secreto del scheduler en Vercel', () => {
    expect(() => validateEnv({ ...valid, VERCEL: '1' })).toThrow('CRON_SECRET');
    expect(() => validateEnv({ ...valid, VERCEL: '1', CRON_SECRET: 'secret' })).toThrow('CORS_ORIGINS');
  });

  it('rechaza puertos y tamaños de pool inválidos', () => {
    expect(() => validateEnv({ ...valid, DB_PORT: '0' })).toThrow('DB_PORT');
    expect(() => validateEnv({ ...valid, DB_POOL_SIZE: '21' })).toThrow('DB_POOL_SIZE');
  });

  it('rechaza comodines y rutas en los orígenes permitidos', () => {
    expect(() => validateEnv({ ...valid, CORS_ORIGINS: '*' })).toThrow('CORS_ORIGINS');
    expect(() => validateEnv({ ...valid, CORS_ORIGINS: 'https://carman.app/' })).toThrow('CORS_ORIGINS');
  });
});
