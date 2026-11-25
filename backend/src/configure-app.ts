import { ValidationPipe } from '@nestjs/common';
import type { INestApplication } from '@nestjs/common';

export function configureApp(app: INestApplication): void {
  const origins = process.env.CORS_ORIGINS?.split(',').map((origin) => origin.trim()).filter(Boolean);
  app.enableCors({
    // Sin lista en desarrollo, únicamente se aceptan orígenes locales.
    origin: origins?.length ? origins : /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/,
  });
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  }));
}
