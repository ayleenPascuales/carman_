import { BadRequestException } from '@nestjs/common';
import type { Pool } from 'mysql2/promise';
import { AdminService } from './admin.service';

describe('AdminService: continuidad administrativa', () => {
  const connection = {
    execute: jest.fn(), beginTransaction: jest.fn(), commit: jest.fn(),
    rollback: jest.fn(), release: jest.fn(),
  };
  const db = {
    query: jest.fn(), getConnection: jest.fn().mockResolvedValue(connection),
    execute: jest.fn(),
  };
  const service = new AdminService(db as unknown as Pool);

  beforeEach(() => {
    jest.clearAllMocks();
    db.getConnection.mockResolvedValue(connection);
  });

  it('impide autosuspenderse sin consultar ni modificar la cuenta', async () => {
    await expect(service.suspenderUsuario(3, 3)).rejects.toBeInstanceOf(BadRequestException);
    expect(db.getConnection).not.toHaveBeenCalled();
  });

  it('impide suspender otra cuenta con rol administrador activo', async () => {
    connection.execute.mockResolvedValueOnce([[{ estado: 'Activo' }]])
      .mockResolvedValueOnce([[{ idPersona: 4 }]]);
    await expect(service.suspenderUsuario(4, 3)).rejects.toBeInstanceOf(BadRequestException);
    expect(connection.execute).toHaveBeenCalledTimes(2);
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.commit).not.toHaveBeenCalled();
  });

  it('una segunda suspensión no aplica un UPDATE repetido', async () => {
    connection.execute.mockResolvedValueOnce([[{ estado: 'Suspendido' }]]);
    await expect(service.suspenderUsuario(4, 3)).rejects.toBeInstanceOf(BadRequestException);
    expect(connection.execute).toHaveBeenCalledTimes(1);
  });

  it('rechaza filtros y paginación inválidos antes de consultar usuarios', async () => {
    await expect(service.obtenerUsuarios('Administrador', '', '', '0'))
      .rejects.toBeInstanceOf(BadRequestException);
    await expect(service.obtenerUsuarios('Supervisor'))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(db.query).not.toHaveBeenCalled();
  });

  it('lista usuarios acotados sin enviar documento ni teléfono', async () => {
    db.query.mockResolvedValueOnce([[{ total: 21 }]])
      .mockResolvedValueOnce([[{ idPersona: 8, nombre: 'Ada' }]]);
    const result = await service.obtenerUsuarios('Cliente', 'Ada', 'Activo', '2');
    expect(result.pagina).toBe(2);
    expect(result.total).toBe(21);
    expect(db.query.mock.calls[1][0]).toContain('LIMIT 21 OFFSET 20');
    expect(db.query.mock.calls[1][0]).not.toMatch(/p\.documento|p\.telefono/);
    expect(db.query.mock.calls[1][1]).toEqual(['Activo', '%Ada%', '%Ada%', '%Ada%', '%Ada%']);
  });

  it('CAS impide aprobar dos veces una misma revisión', async () => {
    db.query.mockResolvedValueOnce([{ affectedRows: 0 }]);
    await expect(service.aceptarSolicitudRevision(8))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining("estado_solicitud_revision = 'Pendiente'"), [8],
    );
    expect(db.query).toHaveBeenCalledTimes(1);
  });

  it('rechazar no publica automáticamente el vehículo', async () => {
    db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);
    await expect(service.rechazarSolicitudRevision(8, { motivoRechazo: 'Falta revisión' }))
      .resolves.toMatchObject({ estado: 'inactivo', estadoSolicitud: 'Rechazada' });
    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining("estado = 'inactivo'"), ['Falta revisión', 8],
    );
  });

  it('informe técnico incompleto nunca entra a transacción', async () => {
    await expect(service.resultadoRevision(8, {
      nombreTecnico: '', documentoTecnico: '', observaciones: '',
      necesitaMantenimiento: false, estadoFinal: 'Activo',
    })).rejects.toBeInstanceOf(BadRequestException);
    expect(db.getConnection).not.toHaveBeenCalled();
  });

  it('aprobadas se listan y pueden finalizarse con informe real', async () => {
    db.query.mockResolvedValueOnce([[{ total: 1 }]])
      .mockResolvedValueOnce([[{ idVehiculo: 8, estado_solicitud_revision: 'Aprobada' }]]);
    const list = await service.obtenerSolicitudesRevision('Aprobada', '1');
    expect(list.solicitudes).toHaveLength(1);
    connection.execute.mockResolvedValueOnce([[{
      estado: 'En_mantenimiento', estado_solicitud_revision: 'Aprobada',
    }]]);
    await expect(service.resultadoRevision(8, {
      nombreTecnico: 'Técnico', documentoTecnico: 'DOC', observaciones: 'Frenos revisados',
      necesitaMantenimiento: false, estadoFinal: 'Activo',
    })).resolves.toMatchObject({ estadoSolicitud: 'Finalizada' });
    expect(connection.commit).toHaveBeenCalledTimes(1);
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO estado_tecnico_vehiculo'),
      expect.arrayContaining([8, 'Frenos revisados', 'Técnico', 'DOC']),
    );
  });
});
