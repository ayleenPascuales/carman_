import { BadRequestException } from '@nestjs/common';
import type { Pool } from 'mysql2/promise';
import { PuntosController } from './puntos.controller';

describe('PuntosController / esquema carmandb', () => {
  const database = { query: jest.fn() };
  const controller = new PuntosController(database as unknown as Pool);

  beforeEach(() => database.query.mockReset());

  it('lista puntos activos con las columnas del export actualizado', async () => {
    database.query.mockResolvedValue([[{
      idPunto: 7, nombre: 'Punto de prueba', direccion: 'Calle de prueba',
      ciudad: null, latitud: '4.600000', longitud: '-74.100000',
    }]]);

    expect(await controller.listar()).toEqual([{
      idPunto: 7, nombre: 'Punto de prueba', ciudad: null,
      direccion: 'Calle de prueba', latitud: '4.600000', longitud: '-74.100000',
    }]);
    const [sql, params] = database.query.mock.calls[0];
    expect(sql).toContain('SELECT idPunto, nombre, ciudad, direccion, latitud, longitud');
    expect(sql).toContain('WHERE activo = TRUE');
    expect(sql).toContain('ORDER BY ciudad, nombre, idPunto');
    expect(params).toEqual([]);
  });

  it('filtra por ciudad con parámetros, sin inventar puntos', async () => {
    database.query.mockResolvedValue([[{
      idPunto: 8, nombre: 'Otro punto', ciudad: 'Ciudad de prueba',
      direccion: 'Otra calle', latitud: 1, longitud: 2,
    }]]);
    expect(await controller.listar(' Ciudad de prueba ')).toEqual([{
      idPunto: 8, nombre: 'Otro punto', ciudad: 'Ciudad de prueba',
      direccion: 'Otra calle', latitud: 1, longitud: 2,
    }]);
    expect(database.query.mock.calls[0][0]).toContain('AND ciudad = ?');
    expect(database.query.mock.calls[0][1]).toEqual(['Ciudad de prueba']);
    await expect(controller.listar('x'.repeat(51))).rejects.toBeInstanceOf(BadRequestException);
    expect(database.query).toHaveBeenCalledTimes(1);
  });
});
