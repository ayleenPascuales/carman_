import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import type { Pool } from 'mysql2/promise';
import { CalificacionesService } from './calificaciones.service';
import { TipoObjetivoCalificacion } from './dto/crearCalificacion.dto';

describe('CalificacionesService', () => {
  const db = {
    query: jest.fn(), execute: jest.fn(),
    getConnection: jest.fn().mockImplementation(async () => connection),
  };
  const connection = {
    query: (...args: unknown[]) => db.query(...args),
    execute: (...args: unknown[]) => db.execute(...args),
    beginTransaction: jest.fn(),
    commit: jest.fn(),
    rollback: jest.fn(),
    release: jest.fn(),
  };
  const service = new CalificacionesService(db as unknown as Pool);
  const finalizada = {
    idReserva: 9, idCliente: 3, idVehiculo: 5, idConductor: null, estado: 'Finalizada',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    db.query.mockReset();
    db.execute.mockReset();
  });

  it('no permite calificar la reserva ajena o inexistente', async () => {
    db.query.mockResolvedValue([[]]);
    await expect(service.crearCalificacion(2, 9, {
      tipoObjetivo: TipoObjetivoCalificacion.VEHICULO, puntuacion: 5,
    })).rejects.toBeInstanceOf(NotFoundException);
    expect(db.query.mock.calls[0][1]).toEqual([9, 2]);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it('no acepta reservas sin finalizar ni conductor inexistente', async () => {
    db.query.mockResolvedValueOnce([[{ ...finalizada, estado: 'Pendiente' }]])
      .mockResolvedValueOnce([[finalizada]]);
    await expect(service.crearCalificacion(2, 9, {
      tipoObjetivo: TipoObjetivoCalificacion.VEHICULO, puntuacion: 4,
    })).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.crearCalificacion(2, 9, {
      tipoObjetivo: TipoObjetivoCalificacion.CONDUCTOR, puntuacion: 4,
    })).rejects.toBeInstanceOf(BadRequestException);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it('registra una sola valoración del vehículo sin inventar conductor', async () => {
    db.query.mockResolvedValue([[finalizada]]);
    db.execute.mockResolvedValue([{ insertId: 11 }]);
    const response = await service.crearCalificacion(2, 9, {
      tipoObjetivo: TipoObjetivoCalificacion.VEHICULO,
      puntuacion: 5, comentario: '  Correcto  ',
    });
    expect(db.execute.mock.calls[0][1]).toEqual([9, 3, 5, null, 5, 'Correcto']);
    expect(response).toEqual(expect.objectContaining({ idCalificacion: 11, puntuacion: 5 }));
    expect(connection.commit).toHaveBeenCalledTimes(1);
  });

  it('actualiza la nota del conductor en la misma transacción que la reseña', async () => {
    db.query.mockResolvedValue([[{ ...finalizada, idConductor: 7 }]]);
    db.execute.mockResolvedValueOnce([{ insertId: 12 }])
      .mockResolvedValueOnce([{ affectedRows: 1 }]);
    await service.crearCalificacion(2, 9, {
      tipoObjetivo: TipoObjetivoCalificacion.CONDUCTOR, puntuacion: 4,
    });
    expect(db.execute).toHaveBeenNthCalledWith(2,
      expect.stringContaining('UPDATE conductor SET calificacion'), [7, 7]);
    expect(connection.commit).toHaveBeenCalledTimes(1);
  });

  it('revierte la reseña si no puede recalcular la nota del conductor', async () => {
    db.query.mockResolvedValue([[{ ...finalizada, idConductor: 7 }]]);
    db.execute.mockResolvedValueOnce([{ insertId: 12 }])
      .mockRejectedValueOnce(new Error('No se puede actualizar'));
    await expect(service.crearCalificacion(2, 9, {
      tipoObjetivo: TipoObjetivoCalificacion.CONDUCTOR, puntuacion: 4,
    })).rejects.toThrow('No se puede actualizar');
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.commit).not.toHaveBeenCalled();
  });

  it('traduce duplicados de la base a conflicto', async () => {
    db.query.mockResolvedValue([[finalizada]]);
    db.execute.mockRejectedValue({ code: 'ER_DUP_ENTRY' });
    await expect(service.crearCalificacion(2, 9, {
      tipoObjetivo: TipoObjetivoCalificacion.VEHICULO, puntuacion: 5,
    })).rejects.toBeInstanceOf(ConflictException);
  });

  it('devuelve puntuaciones públicas minimizadas, sin comentarios ni reservas', async () => {
    db.query.mockResolvedValueOnce([[{ idVehiculo: 5 }]])
      .mockResolvedValueOnce([[{ promedio: '4.5', totalCalificaciones: 2 }]])
      .mockResolvedValueOnce([[{ puntuacion: 5 }]]);
    expect(await service.consultarCalificacionesVehiculo(5)).toEqual({
      idVehiculo: 5, promedio: 4.5, totalCalificaciones: 2,
      calificaciones: [{ puntuacion: 5 }],
    });
    expect(db.query.mock.calls[2][0]).not.toContain('comentario,');
    expect(db.query.mock.calls[2][1]).toEqual([5]);
  });
});
