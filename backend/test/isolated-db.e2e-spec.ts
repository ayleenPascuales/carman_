import { randomUUID } from 'node:crypto';
import { ConfigService } from '@nestjs/config';
import { type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { createPool, type Pool, type ResultSetHeader, type RowDataPacket } from 'mysql2/promise';
import request from 'supertest';
import { AdminController } from '../src/admin/admin.controller';
import { AdminService } from '../src/admin/admin.service';
import { AdminGuard } from '../src/auth/admin.guard';
import { AuthGuard } from '../src/auth/auth.guard';
import { AuthService } from '../src/auth/auth.service';
import { VerificationService } from '../src/auth/verification.service';
import { configureApp } from '../src/configure-app';
import { databaseOptions } from '../src/database/database.config';
import { HealthController } from '../src/health/health.controller';
import { NotificacionesService } from '../src/notificaciones/notificaciones.service';
import { PagosService } from '../src/pagos/pagos.service';
import { ReservasController } from '../src/reservas/reservas.controller';
import { ReservasService } from '../src/reservas/reservas.service';
import { FavoritosController } from '../src/vehiculos/favoritos.controller';
import { FavoritosService } from '../src/vehiculos/favoritos.service';
import { VehiculosController } from '../src/vehiculos/vehiculos.controller';
import { VehiculosService } from '../src/vehiculos/vehiculos.service';

// Run explicitly with a fresh, isolated DB. No production credentials or live
// Firebase/Wompi traffic: only the token verifier is stubbed; SQL is real.
const enabled = process.env.CARMAN_ISOLATED_DB_TEST === '1';
const suite = enabled ? describe : describe.skip;

suite('HTTP y SQL reales en MySQL local de ensayo', () => {
  let app: INestApplication;
  let db: Pool;
  const personas: number[] = [];
  const vehiculos: number[] = [];
  const reservas: number[] = [];
  const puntos: number[] = [];
  let administrador: number;
  let segundoAdmin: number;
  let cliente: number;
  let owner: number;
  let aceptado: number;
  let rechazado: number;
  let publicado: number;
  const suffix = randomUUID().replace(/-/g, '').slice(0, 14);

  async function persona(index: number) {
    const [result] = await db.execute<ResultSetHeader>(
      `INSERT INTO persona (documento, nombre, apellido, email, usuario,
        contrasenaHash, uidFirebase, telefono, fechaNacimiento, ciudad,
        direccion, fotoPerfil)
       VALUES (?, 'Ensayo', 'Aislado', ?, ?, 'no-login',
         ?, '0000000000', '1990-01-01', 'Bogotá', 'Ficticia', 'about:blank')`,
      [`ensayo-${suffix}-${index}`, `test-${suffix}-${index}@example.invalid`,
        `test-${suffix}-${index}`, `test-uid-${suffix}-${index}`],
    );
    personas.push(result.insertId);
    return result.insertId;
  }

  async function punto(index: number) {
    const [result] = await db.execute<ResultSetHeader>(
      `INSERT INTO punto_autorizado (nombre, ciudad, direccion, activo)
       VALUES (?, 'Bogotá', 'Ficticia', 1)`, [`Ensayo ${suffix} ${index}`],
    );
    puntos.push(result.insertId);
    return result.insertId;
  }

  beforeAll(async () => {
    if (process.env.DB_NAME !== 'carman_ensayo' ||
        process.env.DB_SSL_MODE !== 'DISABLED' ||
        !['127.0.0.1', 'localhost'].includes(process.env.DB_HOST ?? '')) {
      throw new Error('El test SQL solo admite carman_ensayo en localhost sin TLS.');
    }
    db = createPool(databaseOptions(process.env));
    const [rows] = await db.query<RowDataPacket[]>(
      'SELECT DATABASE() AS db',
    );
    if (rows[0]?.db !== 'carman_ensayo') {
      throw new Error('Base de ensayo incorrecta.');
    }
    administrador = await persona(1);
    segundoAdmin = await persona(2);
    cliente = await persona(3);
    owner = await persona(4);
    await db.execute('INSERT INTO administrador (idPersona) VALUES (?), (?)',
      [administrador, segundoAdmin]);
    await db.execute('INSERT INTO cliente (idPersona) VALUES (?)', [cliente]);
    const [own] = await db.execute<ResultSetHeader>(
      'INSERT INTO propietario (idPersona) VALUES (?)', [owner],
    );
    const pickUp = await punto(1);
    const dropOff = await punto(2);
    for (const index of [1, 2, 3]) {
      const [result] = await db.execute<ResultSetHeader>(
        `INSERT INTO vehiculo (idPropietario, placa, marca, modelo, anio,
          capacidad, tipoVehiculo, estado, idPuntoRecogida, idPuntoEntrega,
          fotos, tarjetaPropiedad, precioPorDia, estado_solicitud_revision)
         VALUES (?, ?, 'Prueba', 'Aislado', 2022, 4, 'Automóvil',
           ?, ?, ?, '[]', 'about:blank', 100, ?)`,
        [own.insertId, `T${suffix.slice(0, 9)}${index}`,
          index === 3 ? 'Activo' : 'revision_pendiente',
          pickUp, dropOff, index === 3 ? 'Finalizada' : 'Pendiente'],
      );
      vehiculos.push(result.insertId);
    }
    [aceptado, rechazado, publicado] = vehiculos;

    const module = await Test.createTestingModule({
      controllers: [AdminController, HealthController, FavoritosController,
        VehiculosController, ReservasController],
      providers: [
        AdminService, AuthService, AuthGuard, AdminGuard, VehiculosService,
        ReservasService, FavoritosService,
        { provide: 'DATABASE_CONNECTION', useValue: db },
        { provide: ConfigService, useValue: {} },
        { provide: VerificationService, useValue: {} },
        { provide: NotificacionesService, useValue: {
          avisarPersona: async () => {}, avisarReserva: async () => {},
        } },
        { provide: PagosService, useValue: {} },
        { provide: 'FIREBASE_AUTH', useValue: {
          verifyIdToken: async (token: string) => {
            const tokens: Record<string, number> =
              { admin: 1, admin2: 2, client: 3, owner: 4 };
            const index = tokens[token];
            if (!index) throw new Error('Token de ensayo no válido');
            return { uid: `test-uid-${suffix}-${index}`, email_verified: true };
          },
        } },
      ],
    }).compile();
    app = module.createNestApplication();
    configureApp(app);
    await app.init();
  });

  afterAll(async () => {
    if (app) await app.close();
    if (db) {
      // Limpiar solo los IDs creados por el test, en orden de dependencias.
      for (const id of reservas) {
        await db.execute('DELETE FROM reserva WHERE idReserva = ?', [id]);
      }
      for (const id of vehiculos) {
        await db.execute('DELETE FROM estado_tecnico_vehiculo WHERE idVehiculo = ?', [id]);
        await db.execute('DELETE FROM vehiculo WHERE idVehiculo = ?', [id]);
      }
      for (const id of puntos) {
        await db.execute('DELETE FROM punto_autorizado WHERE idPunto = ?', [id]);
      }
      for (const id of personas) {
        await db.execute('DELETE FROM licencia WHERE idPersona = ?', [id]);
        await db.execute('DELETE FROM administrador WHERE idPersona = ?', [id]);
        await db.execute('DELETE FROM cliente WHERE idPersona = ?', [id]);
        await db.execute('DELETE FROM propietario WHERE idPersona = ?', [id]);
        await db.execute('DELETE FROM persona WHERE idPersona = ?', [id]);
      }
      await db.end();
    }
  });

  it('health constata las 20 tablas de negocio migradas', async () => {
    await request(app.getHttpServer()).get('/health').expect(200);
    const response = await request(app.getHttpServer()).get('/health/tablas').expect(200);
    expect(response.body.total).toBe(20);
    expect(response.body.tablas.every((item: { accesible: boolean }) => item.accesible)).toBe(true);
  });

  it('comprueba 401, 403, filtros y detalle sobre filas ficticias', async () => {
    await request(app.getHttpServer()).get('/admin/usuarios').expect(401);
    await request(app.getHttpServer()).get('/admin/usuarios')
      .set('Authorization', 'Bearer invalid').expect(401);
    await request(app.getHttpServer()).get('/admin/usuarios')
      .set('Authorization', 'Bearer client').expect(403);
    const list = await request(app.getHttpServer()).get('/admin/usuarios?rol=Propietario&pagina=1')
      .set('Authorization', 'Bearer admin').expect(200);
    expect(list.body.usuarios.some((user: { idPersona: number }) => user.idPersona === owner))
      .toBe(true);
    const detail = await request(app.getHttpServer()).get(`/admin/usuarios/${owner}`)
      .set('Authorization', 'Bearer admin').expect(200);
    expect(detail.body.roles.propietario).toBe(true);
    await request(app.getHttpServer()).get('/admin/resumen')
      .set('Authorization', 'Bearer admin').expect(200);
  });

  it('consulta catálogo real, protege el detalle ajeno y respeta solapes', async () => {
    const catalog = await request(app.getHttpServer()).get('/vehiculos/catalogo').expect(200);
    expect(catalog.body.vehiculos.map((v: { idVehiculo: number }) => v.idVehiculo))
      .toContain(publicado);
    expect(catalog.body.vehiculos.every((v: Record<string, unknown>) =>
      !('placa' in v) && !('tarjetaPropiedad' in v))).toBe(true);
    await request(app.getHttpServer()).get(`/vehiculos/${publicado}`)
      .set('Authorization', 'Bearer client').expect(404);
    await request(app.getHttpServer()).get(`/vehiculos/${publicado}`)
      .set('Authorization', 'Bearer owner').expect(200);

    const [client] = await db.query<RowDataPacket[]>(
      'SELECT idCliente FROM cliente WHERE idPersona = ?', [cliente],
    );
    const [result] = await db.execute<ResultSetHeader>(
      `INSERT INTO reserva (idCliente, idVehiculo, fechaInicioServicio,
         horaInicioServicio, fechaFinServicio, horaFinServicio, estado)
       VALUES (?, ?, '2030-04-01', '10:00:00', '2030-04-03', '10:00:00', 'Confirmada')`,
      [client[0].idCliente, publicado],
    );
    reservas.push(result.insertId);
    const overlapping = await request(app.getHttpServer())
      .get('/vehiculos/catalogo?fechaInicio=2030-04-02T10:00:00&fechaFin=2030-04-02T11:00:00')
      .expect(200);
    expect(overlapping.body.vehiculos.some((v: { idVehiculo: number }) =>
      v.idVehiculo === publicado)).toBe(false);
    const available = await request(app.getHttpServer())
      .get('/vehiculos/catalogo?fechaInicio=2030-04-03T10:00:00&fechaFin=2030-04-04T10:00:00')
      .expect(200);
    expect(available.body.vehiculos.some((v: { idVehiculo: number }) =>
      v.idVehiculo === publicado)).toBe(true);
  });

  it('sincroniza favoritos propios sin publicar vehículos inactivos', async () => {
    const endpoint = `/vehiculos/favoritos/${publicado}`;
    const clientAuth = { Authorization: 'Bearer client' };
    await request(app.getHttpServer()).get('/vehiculos/favoritos').expect(401);
    await request(app.getHttpServer()).post(endpoint)
      .set(clientAuth).expect(201);
    await request(app.getHttpServer()).post(endpoint)
      .set(clientAuth).expect(201);
    const first = await request(app.getHttpServer()).get('/vehiculos/favoritos?pagina=1')
      .set(clientAuth).expect(200);
    expect(first.body.ids).toEqual([publicado]);
    expect(first.body.hayMas).toBe(false);
    const other = await request(app.getHttpServer()).get('/vehiculos/favoritos')
      .set('Authorization', 'Bearer admin2').expect(200);
    expect(other.body.ids).toEqual([]);
    await request(app.getHttpServer()).post(`/vehiculos/favoritos/${rechazado}`)
      .set(clientAuth).expect(404);
    await request(app.getHttpServer()).get('/vehiculos/favoritos?pagina=0')
      .set(clientAuth).expect(400);
    await request(app.getHttpServer()).delete(endpoint).set(clientAuth).expect(200);
    await request(app.getHttpServer()).delete(endpoint).set(clientAuth).expect(200);
    const empty = await request(app.getHttpServer()).get('/vehiculos/favoritos')
      .set(clientAuth).expect(200);
    expect(empty.body.ids).toEqual([]);
  });

  it('exige licencia y serializa dos reservas sobre el mismo vehículo', async () => {
    const endpoint = `/reservas/vehiculo/${publicado}`;
    const payload = {
      fechaInicioServicio: '2031-04-01', horaInicioServicio: '10:00 AM',
      fechaFinServicio: '2031-04-03', horaFinServicio: '10:00 AM',
      solicitarConductor: false,
    };
    await request(app.getHttpServer()).post(endpoint)
      .send(payload).expect(401);
    await request(app.getHttpServer()).post(endpoint)
      .set('Authorization', 'Bearer client').send(payload).expect(400);
    await db.execute(
      `INSERT INTO licencia (idPersona, numeroDocumento, fechaExpiracion,
        tipoLicencia, estado, fotoLicencia)
       VALUES (?, ?, '2040-01-01', 'B1', 'Vigente', 'about:blank')`,
      [cliente, `ensayo-lic-${suffix}`],
    );
    const results = await Promise.all([
      request(app.getHttpServer()).post(endpoint)
        .set('Authorization', 'Bearer client').send(payload),
      request(app.getHttpServer()).post(endpoint)
        .set('Authorization', 'Bearer client').send(payload),
    ]);
    expect(results.map((r) => r.status).sort((a, b) => a - b)).toEqual([201, 400]);
    const created = results.find((r) => r.status === 201);
    expect(created?.body.estado).toBe('Confirmada');
    const idReserva = Number(created?.body.idReserva);
    expect(Number.isSafeInteger(idReserva)).toBe(true);
    reservas.push(idReserva);
    await request(app.getHttpServer()).get(`/reservas/${idReserva}`)
      .set('Authorization', 'Bearer client').expect(200);
    await request(app.getHttpServer()).get(`/reservas/${idReserva}`)
      .set('Authorization', 'Bearer admin').expect(404);
  });

  it('bloquea administradores, suspende cliente y exige estado antes de reactivar', async () => {
    await request(app.getHttpServer()).patch(`/admin/usuarios/${administrador}/suspender`)
      .set('Authorization', 'Bearer admin').expect(400);
    await request(app.getHttpServer()).patch(`/admin/usuarios/${segundoAdmin}/suspender`)
      .set('Authorization', 'Bearer admin').expect(400);
    await request(app.getHttpServer()).patch(`/admin/usuarios/${cliente}/suspender`)
      .set('Authorization', 'Bearer admin').expect(200);
    await request(app.getHttpServer()).get('/admin/resumen')
      .set('Authorization', 'Bearer client').expect(403);
    await request(app.getHttpServer()).patch(`/admin/usuarios/${cliente}/reactivar`)
      .set('Authorization', 'Bearer admin').expect(200);
    await request(app.getHttpServer()).patch(`/admin/usuarios/${cliente}/reactivar`)
      .set('Authorization', 'Bearer admin').expect(400);
  });

  it('detecta decisiones concurrentes y guarda informe sin publicar por accidente', async () => {
    const auth = (token: string) => ({ Authorization: `Bearer ${token}` });
    const results = await Promise.all([
      request(app.getHttpServer()).patch(`/admin/revisiones/${aceptado}/aceptar`)
        .set(auth('admin')),
      request(app.getHttpServer()).patch(`/admin/revisiones/${aceptado}/aceptar`)
        .set(auth('admin2')),
    ]);
    expect(results.map((r) => r.status).sort((a, b) => a - b)).toEqual([200, 400]);
    await request(app.getHttpServer()).patch(`/admin/revisiones/${aceptado}/finalizar`)
      .set(auth('admin')).send({
        nombreTecnico: 'Técnico Ficticio', documentoTecnico: 'ENSAYO',
        observaciones: 'Prueba de mantenimiento', necesitaMantenimiento: true,
        estadoFinal: 'inactivo',
      }).expect(200);
    const [reports] = await db.query<RowDataPacket[]>(
      'SELECT necesitaMantenimiento FROM estado_tecnico_vehiculo WHERE idVehiculo = ?',
      [aceptado],
    );
    expect(reports).toHaveLength(1);
    expect(reports[0].necesitaMantenimiento).toBe(1);
    const rejected = await request(app.getHttpServer())
      .patch(`/admin/revisiones/${rechazado}/rechazar`)
      .set(auth('admin2')).send({ motivoRechazo: 'Motivo de ensayo' }).expect(200);
    expect(rejected.body.estado).toBe('inactivo');
    await request(app.getHttpServer()).patch(`/admin/revisiones/${rechazado}/rechazar`)
      .set(auth('admin')).send({ motivoRechazo: 'Segundo intento' }).expect(400);
  });
});
