export function validateEnv(env: Record<string, unknown>): Record<string, unknown> {
  const required = ['DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME', 'FIREBASE_PROJECT_ID', 'FIREBASE_API_KEY'];
  const missing = required.filter((key) => typeof env[key] !== 'string' || !String(env[key]).trim());

  const hasServiceAccount = Boolean(
    env.FIREBASE_SERVICE_ACCOUNT_JSON ||
    (env.FIREBASE_CLIENT_EMAIL && env.FIREBASE_PRIVATE_KEY) ||
    env.GOOGLE_APPLICATION_CREDENTIALS,
  );
  if (!hasServiceAccount) {
    missing.push('FIREBASE_SERVICE_ACCOUNT_JSON o FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY o GOOGLE_APPLICATION_CREDENTIALS');
  }
  const corsOrigins = typeof env.CORS_ORIGINS === 'string' ? env.CORS_ORIGINS : '';
  if (env.VERCEL && !(typeof env.CRON_SECRET === 'string' && env.CRON_SECRET.trim())) {
    missing.push('CRON_SECRET');
  }
  if ((env.VERCEL || env.NODE_ENV === 'production') && !corsOrigins.trim()) {
    missing.push('CORS_ORIGINS');
  }
  if (missing.length) {
    throw new Error(`Configuración incompleta: ${missing.join(', ')}`);
  }

  if (env.CORS_ORIGINS !== undefined && typeof env.CORS_ORIGINS !== 'string') {
    throw new Error('CORS_ORIGINS debe ser una lista de orígenes');
  }
  if (corsOrigins) {
    for (const origin of corsOrigins.split(',').map((value) => value.trim())) {
      try {
        const url = new URL(origin);
        if (!['http:', 'https:'].includes(url.protocol) || url.origin !== origin) {
          throw new Error('origen inválido');
        }
      } catch {
        throw new Error(`CORS_ORIGINS contiene un origen inválido: ${origin}`);
      }
    }
  }

  for (const [key, value, min, max] of [
    ['DB_PORT', env.DB_PORT ?? '4000', 1, 65535],
    ['DB_POOL_SIZE', env.DB_POOL_SIZE ?? '2', 1, 20],
  ] as const) {
    if (typeof value !== 'string' || !/^\d+$/.test(value) || Number(value) < min || Number(value) > max) {
      throw new Error(`${key} debe ser un entero entre ${min} y ${max}`);
    }
  }
  return env;
}
