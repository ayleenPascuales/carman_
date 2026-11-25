import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppController } from '../src/app.controller';
import { AppService } from '../src/app.service';
import { HealthController } from '../src/health/health.controller';
import { MaintenanceController } from '../src/auth/maintenance.controller';
import { AuthController } from '../src/auth/auth.controller';
import { AuthGuard } from '../src/auth/auth.guard';
import { AdminGuard } from '../src/auth/admin.guard';
import { AuthService } from '../src/auth/auth.service';
import { PersonasController } from '../src/personas/personas.controller';
import { PersonasService } from '../src/personas/personas.service';
import { ConfigService } from '@nestjs/config';
import { configureApp } from '../src/configure-app';
import { PuntosController } from '../src/puntos/puntos.controller';
import { VerificationService } from '../src/auth/verification.service';

describe('API con dependencias externas simuladas (e2e)', () => {
  let app: INestApplication;
  const pool = { query: jest.fn().mockImplementation(async (sql: string) => [
    sql.includes('punto_autorizado')
      ? [{ idPunto: 1, nombre: 'Punto de prueba', ciudad: null,
        direccion: 'Calle de prueba', latitud: '4.600000', longitud: '-74.100000' }]
      : [{ ok: 1 }],
  ]) };
  const auth = {
    verificarToken: jest.fn().mockResolvedValue({ uid: 'firebase-uid' }),
    obtenerIdPersona: jest.fn().mockResolvedValue(12),
    verificarEstadoCuenta: jest.fn().mockResolvedValue(undefined),
    registrarActividad: jest.fn().mockResolvedValue(undefined),
    sincronizarEmailVerificado: jest.fn().mockResolvedValue(undefined),
    actualizarCuentasInactivas: jest.fn().mockResolvedValue(undefined),
    iniciarSesion: jest.fn().mockResolvedValue({ idToken: 'firebase-id-token' }),
  };
  const verification = {
    estado: jest.fn().mockResolvedValue({
      requiereVerificacion: false, correoVerificado: false,
      telefonoVerificado: false, activada: true,
    }),
    enviarCorreoConToken: jest.fn(),
    reenviarCodigo: jest.fn(),
    confirmarCodigo: jest.fn(),
  };

  beforeAll(async () => {
    process.env.CORS_ORIGINS = 'https://carman.example';
    const module = await Test.createTestingModule({
      controllers: [
        AppController, HealthController, PuntosController, MaintenanceController,
        AuthController, PersonasController,
      ],
      providers: [
        AppService,
        AuthGuard, AdminGuard,
        { provide: 'DATABASE_CONNECTION', useValue: pool },
        { provide: AuthService, useValue: auth },
        { provide: VerificationService, useValue: verification },
        { provide: PersonasService, useValue: {
          obtenerPerfil: jest.fn().mockResolvedValue({ idPersona: 12, nombre: 'Ada' }),
        } },
        { provide: ConfigService, useValue: { get: (key: string) => key === 'CRON_SECRET' ? 'secret-for-tests' : undefined } },
      ],
    }).compile();
    app = module.createNestApplication();
    configureApp(app);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
    delete process.env.CORS_ORIGINS;
  });

  it('expone salud de TiDB y rechaza orígenes no permitidos', async () => {
    const response = await request(app.getHttpServer()).get('/health')
      .set('Origin', 'https://carman.example').expect(200);
    expect(response.body).toEqual({ status: 'ok', database: 'ok' });
    expect(response.headers['access-control-allow-origin']).toBe('https://carman.example');
    const disallowed = await request(app.getHttpServer()).get('/health')
      .set('Origin', 'https://evil.example').expect(200);
    expect(disallowed.headers['access-control-allow-origin']).toBeUndefined();
    expect(pool.query).toHaveBeenCalledWith('SELECT 1');
    await request(app.getHttpServer()).get('/puntos-autorizados')
      .expect(200, [{ idPunto: 1, nombre: 'Punto de prueba', ciudad: null,
        direccion: 'Calle de prueba', latitud: '4.600000', longitud: '-74.100000' }]);
    await request(app.getHttpServer()).get('/puntos-autorizados?ciudad=Prueba')
      .expect(200);
    expect(pool.query).toHaveBeenCalledWith(
      expect.stringContaining('AND ciudad = ?'), ['Prueba'],
    );
    await request(app.getHttpServer()).get(`/puntos-autorizados?ciudad=${'a'.repeat(51)}`)
      .expect(400);
  });

  it('acepta login y exige token Firebase para el perfil', async () => {
    await request(app.getHttpServer()).post('/auth/login')
      .send({ identificador: 'ada@example.com', contrasena: 'password123' })
      .expect(201, { idToken: 'firebase-id-token' });
    await request(app.getHttpServer()).get('/personas/perfil').expect(401);
    await request(app.getHttpServer()).get('/personas/perfil')
      .set('Authorization', 'Bearer firebase-id-token')
      .expect(200, { idPersona: 12, nombre: 'Ada' });
    expect(auth.verificarToken).toHaveBeenCalledWith('firebase-id-token');
    expect(auth.registrarActividad).toHaveBeenCalledWith(12);
  });

  it('protege el mantenimiento con CRON_SECRET', async () => {
    await request(app.getHttpServer()).get('/internal/inactive-accounts').expect(403);
    await request(app.getHttpServer()).get('/internal/inactive-accounts')
      .set('Authorization', 'Bearer secret-for-tests')
      .expect(200, { status: 'ok' });
    expect(auth.actualizarCuentasInactivas).toHaveBeenCalled();
  });

  it('permite reenvíos y confirmación solo con sesión Firebase, sin elegir destinatario', async () => {
    verification.estado.mockResolvedValue({
      requiereVerificacion: true, correoVerificado: false,
      telefonoVerificado: false, activada: false,
    });
    auth.verificarToken.mockResolvedValue({
      uid: 'firebase-uid', requiresVerification: true,
    });
    await request(app.getHttpServer()).post('/auth/correo/reenviar').expect(401);
    await request(app.getHttpServer()).post('/auth/correo/reenviar')
      .set('Authorization', 'Bearer firebase-id-token').expect(201);
    expect(verification.enviarCorreoConToken).toHaveBeenCalledWith('firebase-id-token');
    await request(app.getHttpServer()).post('/auth/telefono/reenviar')
      .set('Authorization', 'Bearer firebase-id-token').expect(201);
    expect(verification.reenviarCodigo).toHaveBeenCalledWith('firebase-uid', 12);
    await request(app.getHttpServer()).post('/auth/telefono/confirmar')
      .set('Authorization', 'Bearer firebase-id-token')
      .send({ codigo: '123456' }).expect(201);
    expect(verification.confirmarCodigo).toHaveBeenCalledWith('firebase-uid', 12, '123456');
    await request(app.getHttpServer()).post('/auth/telefono/confirmar')
      .set('Authorization', 'Bearer firebase-id-token')
      .send({ codigo: '12345' }).expect(400);
  });
});
