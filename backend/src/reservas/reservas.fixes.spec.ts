import { BadRequestException, NotFoundException } from '@nestjs/common';
import type { Pool } from 'mysql2/promise';
import { ReservasService } from './reservas.service';
import type { PagosService } from '../pagos/pagos.service';
import type { NotificacionesService } from '../notificaciones/notificaciones.service';

describe('Regresiones de reservas M0', () => {
  const connection = {
    query: jest.fn(),
    beginTransaction: jest.fn(),
    commit: jest.fn(),
    rollback: jest.fn(),
    release: jest.fn(),
  };
  const db = { getConnection: jest.fn().mockResolvedValue(connection) };
  const pagos = { prepararActualizacionOrdenPago: jest.fn().mockResolvedValue(null) };
  const avisos = { avisarReserva: jest.fn().mockResolvedValue(undefined) };
  const service = new ReservasService(
    db as unknown as Pool,
    pagos as unknown as PagosService,
    avisos as unknown as NotificacionesService,
  );
  beforeEach(() => {
    jest.clearAllMocks();
    db.getConnection.mockResolvedValue(connection);
    pagos.prepararActualizacionOrdenPago.mockResolvedValue(null);
    avisos.avisarReserva.mockResolvedValue(undefined);
  });

  it('aceptar conductor confirma la reserva para permitir una orden de pago', async () => {
    connection.query
      .mockResolvedValueOnce([[{ idConductor: 7, disponibilidad: 1 }]])
      .mockResolvedValueOnce([[{
        idReserva: 8, idConductor: 7, estado: 'Pendiente',
        estadoRespuestaConductor: 'Pendiente', cantidadDias: 2, precioEstimado: '100000',
        fechaInicioServicio: '2099-01-01', horaInicioServicio: '08:00:00',
        fechaFinServicio: '2099-01-03',
      }]])
      .mockResolvedValueOnce([[{ idLicencia: 1 }]])
      .mockResolvedValueOnce([{ affectedRows: 1 }]);
    await expect(service.responderReserva(4, 8, { aceptar: true })).resolves.toMatchObject({
      estado: 'Confirmada', estadoRespuestaConductor: 'Aceptada', precioEstimado: 240000,
    });
    expect(connection.query).toHaveBeenCalledWith(
      expect.stringContaining("estado = 'Confirmada'"), [240000, 8],
    );
    expect(connection.commit).toHaveBeenCalledTimes(1);
  });

  it('continuar sin conductor confirma y Esperar conserva Pendiente', async () => {
    for (const decision of ['Continuar', 'Esperar'] as const) {
      connection.query
        .mockResolvedValueOnce([[{
          idReserva: 8, idCliente: 3, idConductor: null, estado: 'Pendiente',
          estadoRespuestaConductor: 'Sin_conductor', decisionSinConductor: null,
          fechaInicioServicio: '2099-01-01', horaInicioServicio: '08:00:00',
          fechaFinServicio: '2099-01-02', idPersona: 4,
        }]])
        .mockResolvedValueOnce(decision === 'Continuar' ? [[{ idLicencia: 1 }]] : [{ affectedRows: 1 }]);
      if (decision === 'Continuar') {
        connection.query.mockResolvedValueOnce([{ affectedRows: 1 }]);
      }
      await expect(service.decidirSinConductor(4, 8, { decision })).resolves.toMatchObject({
        estado: decision === 'Continuar' ? 'Confirmada' : 'Pendiente',
      });
      expect(connection.query).toHaveBeenCalledWith(
        expect.stringContaining("CASE WHEN ? = 'Continuar'"), [decision, decision, 8],
      );
    }
  });

  it('crea dentro de una transacción con vehículo bloqueado y aviso posterior al commit', async () => {
    const calls: string[] = [];
    connection.beginTransaction.mockImplementation(async () => { calls.push('begin'); });
    connection.commit.mockImplementation(async () => { calls.push('commit'); });
    avisos.avisarReserva.mockImplementation(async () => { calls.push('aviso'); });
    connection.query.mockImplementation(async (sql: string) => {
      if (sql.includes('FROM persona')) return [[{ idPersona: 4 }]];
      if (sql.includes('FROM vehiculo')) {
        calls.push('lock');
        return [[{
          estado: 'Activo', estado_solicitud_revision: 'Sin_solicitud',
          precioPorDia: '100000', idPuntoRecogida: 1, idPuntoEntrega: 2,
        }]];
      }
      if (sql.includes('FROM cliente')) return [[{ idCliente: 3 }]];
      if (sql.includes('FROM punto_autorizado')) return [[{ idPunto: 1 }, { idPunto: 2 }]];
      if (sql.includes('FROM licencia')) return [[{ idLicencia: 1 }]];
      if (sql.includes('SELECT idReserva FROM reserva')) return [[]];
      if (sql.includes('INSERT INTO reserva')) return [{ insertId: 8 }];
      throw new Error(`Consulta inesperada: ${sql}`);
    });
    await expect(service.crearReserva(4, 7, {
      fechaInicioServicio: '2099-01-01', horaInicioServicio: '08:00 AM',
      fechaFinServicio: '2099-01-02', horaFinServicio: '08:00 AM',
    })).resolves.toMatchObject({ idReserva: 8, estado: 'Confirmada' });
    expect(calls).toEqual(['begin', 'lock', 'commit', 'aviso']);
    expect(connection.query.mock.calls[0][0]).toContain('FOR UPDATE');
    expect(connection.query.mock.calls[1][0]).toContain('FOR UPDATE');
    expect(connection.release).toHaveBeenCalledTimes(1);
  });

  it('revierte también la creación implícita de cliente si falla la reserva', async () => {
    connection.query.mockImplementation(async (sql: string) => {
      if (sql.includes('FROM persona')) return [[{ idPersona: 4 }]];
      if (sql.includes('FROM vehiculo')) return [[{
        estado: 'Activo', estado_solicitud_revision: 'Sin_solicitud',
        precioPorDia: '100000', idPuntoRecogida: 1, idPuntoEntrega: 2,
      }]];
      if (sql.includes('FROM cliente')) return [[]];
      if (sql.includes('INSERT INTO cliente')) return [{ insertId: 3 }];
      if (sql.includes('FROM punto_autorizado')) return [[{ idPunto: 1 }, { idPunto: 2 }]];
      if (sql.includes('FROM licencia')) return [[{ idLicencia: 1 }]];
      if (sql.includes('SELECT idReserva FROM reserva')) return [[{ idReserva: 9 }]];
      throw new Error(`Consulta inesperada: ${sql}`);
    });
    await expect(service.crearReserva(4, 7, {
      fechaInicioServicio: '2099-01-01', horaInicioServicio: '08:00 AM',
      fechaFinServicio: '2099-01-02', horaFinServicio: '08:00 AM',
    })).rejects.toBeInstanceOf(BadRequestException);
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.commit).not.toHaveBeenCalled();
    expect(avisos.avisarReserva).not.toHaveBeenCalled();
  });

  it('rechaza conducir sin licencia vigente hasta el fin del servicio', async () => {
    connection.query.mockImplementation(async (sql: string) => {
      if (sql.includes('FROM persona')) return [[{ idPersona: 4 }]];
      if (sql.includes('FROM vehiculo')) return [[{
        estado: 'Activo', estado_solicitud_revision: 'Sin_solicitud',
        precioPorDia: '100000', idPuntoRecogida: 1, idPuntoEntrega: 2,
      }]];
      if (sql.includes('FROM cliente')) return [[{ idCliente: 3 }]];
      if (sql.includes('FROM punto_autorizado')) return [[{ idPunto: 1 }, { idPunto: 2 }]];
      if (sql.includes('FROM licencia')) return [[]];
      throw new Error(`Consulta inesperada: ${sql}`);
    });
    await expect(service.crearReserva(4, 7, {
      fechaInicioServicio: '2099-01-01', horaInicioServicio: '08:00 AM',
      fechaFinServicio: '2099-01-02', horaFinServicio: '08:00 AM',
    })).rejects.toBeInstanceOf(BadRequestException);
    expect(connection.query).toHaveBeenCalledWith(
      expect.stringContaining('fechaExpiracion >= ?'), [4, '2099-01-02'],
    );
    expect(connection.rollback).toHaveBeenCalledTimes(1);
  });

  it('rechaza PATCH vacío sin abrir transacción', async () => {
    await expect(service.actualizarReserva(4, 8, {})).rejects.toBeInstanceOf(BadRequestException);
    expect(db.getConnection).not.toHaveBeenCalled();
  });

  it('normaliza DATE devuelto como Date y conserva conductor aceptado al editar fechas', async () => {
    connection.query
      .mockResolvedValueOnce([[{ idVehiculo: 5 }]])
      .mockResolvedValueOnce([[{
        idReserva: 8, idVehiculo: 5, idPersona: 4,
        estado: 'Confirmada', estadoRespuestaConductor: 'Aceptada',
        decisionSinConductor: null, idConductor: 7, precioPorDia: '100000',
        fechaInicioServicio: new Date('2099-01-01T05:00:00Z'),
        fechaFinServicio: new Date('2099-01-02T05:00:00Z'),
        horaInicioServicio: '08:00:00', horaFinServicio: '08:00:00',
      }]])
      .mockResolvedValueOnce([[]])
      .mockResolvedValueOnce([[{ idConductor: 7 }]])
      .mockResolvedValueOnce([[]])
      .mockResolvedValueOnce([{ affectedRows: 1 }]);
    const actualizada = await service.actualizarReserva(4, 8, {
      fechaInicioServicio: '2099-01-03', fechaFinServicio: '2099-01-04',
    });
    expect(actualizada).toMatchObject({
      fechaInicioServicio: '2099-01-03',
      fechaFinServicio: '2099-01-04',
      idConductor: 7, estado: 'Confirmada',
      estadoRespuestaConductor: 'Aceptada', precioEstimado: 170000,
    });
    expect(connection.query).toHaveBeenCalledWith(
      expect.stringContaining('UPDATE reserva SET'),
      expect.arrayContaining([7, 'Aceptada', 170000, 'Confirmada', 8]),
    );
  });

  describe('inicio y finalización protegidos por pago', () => {
    const colombia = (date: Date) => {
      const parts = new Intl.DateTimeFormat('en-US', {
        timeZone: 'America/Bogota', year: 'numeric', month: '2-digit',
        day: '2-digit', hour: '2-digit', minute: '2-digit',
        second: '2-digit', hourCycle: 'h23',
      }).formatToParts(date);
      const get = (part: string) => parts.find(item => item.type === part)?.value;
      return { date: `${get('year')}-${get('month')}-${get('day')}`,
        time: `${get('hour')}:${get('minute')}:${get('second')}` };
    };

    const setup = (
      estado: string, idConductor: number | null, pagos: object[],
      estadoOrden = 'Activa',
    ) => {
      const start = colombia(new Date(Date.now() - 60_000));
      const end = colombia(new Date(Date.now() + 86_400_000));
      connection.query.mockImplementation(async (sql: string) => {
        if (sql.includes('FROM reserva r')) return [[{
          estado, idConductor, idPersonaCliente: 4, idPersonaConductor: 5,
          fechaInicioServicio: start.date, horaInicioServicio: start.time,
          fechaFinServicio: end.date, horaFinServicio: end.time,
        }]];
        if (sql.includes('FROM orden_de_pago')) return [[{
          idOrdenPago: 13, estado: estadoOrden, total: '100000.00',
        }]];
        if (sql.includes('FROM pago')) return [pagos];
        if (sql.includes('UPDATE reserva')) return [{ affectedRows: 1 }];
        throw new Error(`Consulta inesperada: ${sql}`);
      });
    };

    it('solo el conductor asignado inicia con anticipo aprobado', async () => {
      setup('Confirmada', 7, [{ tipoPago: 'Anticipo', monto: '50000.00' }]);
      await expect(service.transicionarServicio(4, 8, 'iniciar'))
        .rejects.toBeInstanceOf(NotFoundException);
      expect(connection.commit).not.toHaveBeenCalled();
      expect(await service.transicionarServicio(5, 8, 'iniciar'))
        .toMatchObject({ estado: 'EnCurso' });
      expect(connection.query).toHaveBeenCalledWith(
        expect.stringContaining('UPDATE reserva SET estado'), ['EnCurso', 8],
      );
      expect(avisos.avisarReserva).toHaveBeenCalledWith(8, 'iniciada');
    });

    it('el cliente inicia sin conductor pero no sin anticipo', async () => {
      setup('Confirmada', null, []);
      await expect(service.transicionarServicio(4, 8, 'iniciar'))
        .rejects.toBeInstanceOf(BadRequestException);
      expect(connection.commit).not.toHaveBeenCalled();
      setup('Confirmada', null, [{ tipoPago: 'Anticipo', monto: '50000.00' }]);
      await expect(service.transicionarServicio(4, 8, 'iniciar'))
        .resolves.toMatchObject({ estado: 'EnCurso' });
    });

    it('no inicia con una orden no activa aunque el anticipo figure aprobado', async () => {
      setup('Confirmada', null, [
        { tipoPago: 'Anticipo', monto: '50000.00' },
      ], 'Pendiente');
      await expect(service.transicionarServicio(4, 8, 'iniciar'))
        .rejects.toBeInstanceOf(BadRequestException);
      expect(connection.commit).not.toHaveBeenCalled();
    });

    it('no finaliza hasta que el saldo aprobado cubra el total', async () => {
      setup('EnCurso', 7, [{ tipoPago: 'Anticipo', monto: '50000.00' }]);
      await expect(service.transicionarServicio(5, 8, 'finalizar'))
        .rejects.toBeInstanceOf(BadRequestException);
      setup('EnCurso', 7, [
        { tipoPago: 'Anticipo', monto: '50000.00' },
        { tipoPago: 'Restante', monto: '50000.00' },
      ]);
      await expect(service.transicionarServicio(5, 8, 'finalizar'))
        .resolves.toMatchObject({ estado: 'Finalizada' });
      expect(avisos.avisarReserva).toHaveBeenCalledWith(8, 'finalizada');
    });
  });
});
