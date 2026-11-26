import { Test } from '@nestjs/testing';
import { ForbiddenException, type INestApplication } from '@nestjs/common';
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
import { VehiculosController } from '../src/vehiculos/vehiculos.controller';
import { VehiculosService } from '../src/vehiculos/vehiculos.service';
import { PagosController } from '../src/pagos/pagos.controller';
import { PagosService } from '../src/pagos/pagos.service';
import { WompiService } from '../src/pagos/wompi.service';
import { ReservasController } from '../src/reservas/reservas.controller';
import { ReservasService } from '../src/reservas/reservas.service';
import { AdminController } from '../src/admin/admin.controller';
import { AdminService } from '../src/admin/admin.service';

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
    verificarAdministrador: jest.fn().mockRejectedValue(new ForbiddenException()),
  };
  const verification = {
    estado: jest.fn().mockResolvedValue({
      requiereVerificacion: false, correoVerificado: false,
      telefonoVerificado: false, activada: true,
    }),
    enviarCorreoConToken: jest.fn(),
    reenviarCodigo: jest.fn(),
    confirmarCodigo: jest.fn(),
    solicitarRecuperacion: jest.fn().mockResolvedValue(undefined),
  };
  const vehiculos = {
    catalogo: jest.fn().mockResolvedValue({ vehiculos: [], pagina: 1, hayMas: false }),
    obtenerMisVehiculos: jest.fn().mockResolvedValue([]),
    obtenerVehiculo: jest.fn().mockResolvedValue({ idVehiculo: 42, estado: 'inactivo' }),
    cambiarEstadoVehiculo: jest.fn().mockResolvedValue({
      mensaje: 'Estado del vehículo actualizado.', estado: 'inactivo',
    }),
    solicitarRevision: jest.fn().mockResolvedValue({
      mensaje: 'Solicitud de revisión técnica enviada.', estado: 'Pendiente',
    }),
  };
  const pagos = {
    consultarOrdenReserva: jest.fn().mockResolvedValue({
      idOrdenPago: 34, idReserva: 5, total: 100, totalAprobado: 0,
      anticipoAprobado: 0, saldoPendiente: 100, pagosEnProceso: 0,
      estado: 'Activa', estadoReserva: 'Confirmada',
    }),
  };
  const reservas = {
    obtenerDetalleReserva: jest.fn().mockResolvedValue({ idReserva: 5, estado: 'Confirmada' }),
    obtenerServiciosConductor: jest.fn().mockResolvedValue({
      disponibilidad: false, licenciaVigente: true,
      pagina: 2, hayMas: false, servicios: [],
    }),
  };
  const admin = {
    obtenerUsuarios: jest.fn().mockResolvedValue({
      total: 0, pagina: 1, hayMas: false, usuarios: [],
    }),
    obtenerSolicitudesRevision: jest.fn().mockResolvedValue({
      total: 0, pagina: 1, hayMas: false, solicitudes: [],
    }),
    rechazarSolicitudRevision: jest.fn().mockResolvedValue({
      estadoSolicitud: 'Rechazada',
    }),
  };

  beforeAll(async () => {
    process.env.CORS_ORIGINS = 'https://carman.example';
    const module = await Test.createTestingModule({
      controllers: [
        AppController, HealthController, PuntosController, MaintenanceController,
        AuthController, PersonasController,
        VehiculosController, PagosController, ReservasController, AdminController,
      ],
      providers: [
        AppService,
        AuthGuard, AdminGuard,
        { provide: 'DATABASE_CONNECTION', useValue: pool },
        { provide: AuthService, useValue: auth },
        { provide: VerificationService, useValue: verification },
        { provide: VehiculosService, useValue: vehiculos },
        { provide: PagosService, useValue: pagos },
        { provide: WompiService, useValue: {} },
        { provide: ReservasService, useValue: reservas },
        { provide: AdminService, useValue: admin },
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

  it('valida la solicitud de recuperación sin exponer la existencia de la cuenta', async () => {
    await request(app.getHttpServer())
      .post('/auth/password/solicitar-recuperacion')
      .send({ email: 'someone@example.com' })
      .expect(201, {
        mensaje: 'Si existe una cuenta para ese correo, se enviará un enlace de recuperación.',
      });
    expect(verification.solicitarRecuperacion).toHaveBeenCalledWith('someone@example.com');
    await request(app.getHttpServer())
      .post('/auth/password/solicitar-recuperacion')
      .send({ email: 'no-es-correo' }).expect(400);
    expect(verification.solicitarRecuperacion).toHaveBeenCalledTimes(1);
  });

  it('valida filtros públicos del catálogo antes de ejecutar SQL', async () => {
    await request(app.getHttpServer())
      .get('/vehiculos/catalogo')
      .query({
        ciudad: 'Cartagena',
        fechaInicio: '2027-02-10T10:00:00',
        fechaFin: '2027-02-12T10:00:00',
        pagina: '2',
      }).expect(200);
    expect(vehiculos.catalogo).toHaveBeenCalledWith(expect.objectContaining({
      ciudad: 'Cartagena', pagina: '2',
    }));
    await request(app.getHttpServer())
      .get('/vehiculos/catalogo')
      .query({ combustible: 'diesel' }).expect(400);
    await request(app.getHttpServer())
      .get('/vehiculos/catalogo')
      .query({ fechaInicio: 'sin-fecha' }).expect(400);
    expect(vehiculos.catalogo).toHaveBeenCalledTimes(1);
  });

  it('requiere sesión para leer detalle y saldo propios, y valida identificadores', async () => {
    await request(app.getHttpServer()).get('/reservas/5').expect(401);
    await request(app.getHttpServer()).get('/pagos/reservas/5/orden').expect(401);
    await request(app.getHttpServer()).get('/reservas/5')
      .set('Authorization', 'Bearer firebase-id-token')
      .expect(200, { idReserva: 5, estado: 'Confirmada' });
    expect(reservas.obtenerDetalleReserva).toHaveBeenCalledWith(12, 5);
    await request(app.getHttpServer()).get('/pagos/reservas/5/orden')
      .set('Authorization', 'Bearer firebase-id-token').expect(200);
    expect(pagos.consultarOrdenReserva).toHaveBeenCalledWith(12, 5);
    await request(app.getHttpServer()).get('/pagos/reservas/0/orden')
      .set('Authorization', 'Bearer firebase-id-token').expect(400);
  });

  it('exige sesión y DTO válido para el inventario y las acciones del propietario', async () => {
    await request(app.getHttpServer()).get('/vehiculos/mis-vehiculos').expect(401);
    await request(app.getHttpServer()).get('/vehiculos/mis-vehiculos')
      .set('Authorization', 'Bearer firebase-id-token').expect(200, []);
    expect(vehiculos.obtenerMisVehiculos).toHaveBeenCalledWith(12);
    await request(app.getHttpServer()).get('/vehiculos/42')
      .set('Authorization', 'Bearer firebase-id-token')
      .expect(200, { idVehiculo: 42, estado: 'inactivo' });
    expect(vehiculos.obtenerVehiculo).toHaveBeenCalledWith(12, 42);
    await request(app.getHttpServer()).patch('/vehiculos/42/estado')
      .send({ estado: 'Disponible' })
      .set('Authorization', 'Bearer firebase-id-token').expect(400);
    await request(app.getHttpServer()).patch('/vehiculos/42/estado')
      .send({ estado: 'inactivo' })
      .set('Authorization', 'Bearer firebase-id-token').expect(200);
    expect(vehiculos.cambiarEstadoVehiculo).toHaveBeenCalledWith(
      12, 42, { estado: 'inactivo' },
    );
    await request(app.getHttpServer()).post('/vehiculos/42/solicitar-revision')
      .send({ motivoSolicitud: '' })
      .set('Authorization', 'Bearer firebase-id-token').expect(400);
    await request(app.getHttpServer()).post('/vehiculos/42/solicitar-revision')
      .send({ motivoSolicitud: 'Revisar frenos' })
      .set('Authorization', 'Bearer firebase-id-token').expect(201);
    expect(vehiculos.solicitarRevision).toHaveBeenCalledWith(
      12, 42, { motivoSolicitud: 'Revisar frenos' },
    );
  });

  it('protege el listado de conductor y pasa identidad y página del token', async () => {
    await request(app.getHttpServer()).get('/reservas/conductor/servicios')
      .expect(401);
    await request(app.getHttpServer()).get('/reservas/conductor/servicios?pagina=2')
      .set('Authorization', 'Bearer firebase-id-token')
      .expect(200, {
        disponibilidad: false, licenciaVigente: true,
        pagina: 2, hayMas: false, servicios: [],
      });
    expect(reservas.obtenerServiciosConductor).toHaveBeenCalledWith(12, '2');
  });

  it('admin: 401 sin sesión, 403 sin rol y DTO obligatorio al rechazar', async () => {
    await request(app.getHttpServer()).get('/admin/usuarios').expect(401);
    await request(app.getHttpServer()).get('/admin/usuarios')
      .set('Authorization', 'Bearer firebase-id-token').expect(403);
    auth.verificarAdministrador.mockResolvedValueOnce(undefined);
    await request(app.getHttpServer()).get('/admin/usuarios?rol=Conductor&pagina=2')
      .set('Authorization', 'Bearer firebase-id-token').expect(200);
    expect(admin.obtenerUsuarios).toHaveBeenCalledWith('Conductor', undefined,
      undefined, '2');
    auth.verificarAdministrador.mockResolvedValueOnce(undefined);
    await request(app.getHttpServer()).patch('/admin/revisiones/8/rechazar')
      .send({ motivoRechazo: '' })
      .set('Authorization', 'Bearer firebase-id-token').expect(400);
    expect(admin.rechazarSolicitudRevision).not.toHaveBeenCalled();
    auth.verificarAdministrador.mockResolvedValueOnce(undefined);
    await request(app.getHttpServer()).patch('/admin/revisiones/8/rechazar')
      .send({ motivoRechazo: 'Inspección incompleta' })
      .set('Authorization', 'Bearer firebase-id-token').expect(200);
    expect(admin.rechazarSolicitudRevision).toHaveBeenCalledWith(8, {
      motivoRechazo: 'Inspección incompleta',
    });
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
