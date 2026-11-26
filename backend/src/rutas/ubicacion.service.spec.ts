import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { UbicacionService } from './ubicacion.service';

describe('UbicacionService', () => {
  const database = { execute: jest.fn() };
  let service: UbicacionService;
  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [
        UbicacionService,
        { provide: 'DATABASE_CONNECTION', useValue: database },
        { provide: ConfigService, useValue: { get: () => 'true' } },
      ],
    }).compile();
    service = module.get(UbicacionService);
  });

  it('requiere pertenencia al viaje incluso para leer posiciones', async () => {
    database.execute.mockResolvedValueOnce([[{ estado: 'EnCurso', cliente: 1, conductor: 2, clienteAdulto: 1, conductorAdulto: 1 }]]);
    await expect(service.consultar(3, 12)).rejects.toBeInstanceOf(ForbiddenException);
    expect(database.execute).toHaveBeenCalledTimes(1);
  });

  it('rechaza compartir sin consentimiento y no almacena coordenadas', async () => {
    database.execute.mockResolvedValueOnce([[{ estado: 'EnCurso', cliente: 1, conductor: 2, clienteAdulto: 1, conductorAdulto: 1 }]]);
    await expect(service.compartir(1, 12, {
      latitud: 10.4, longitud: -75.4, consentimiento: false,
    } as never)).rejects.toBeInstanceOf(BadRequestException);
    expect(database.execute).toHaveBeenCalledTimes(1);
  });

  it('no permite enviar ubicación antes o después de un viaje en curso', async () => {
    database.execute.mockResolvedValueOnce([[{ estado: 'Finalizada', cliente: 1, conductor: 2, clienteAdulto: 1, conductorAdulto: 1 }]]);
    await expect(service.compartir(1, 12, {
      latitud: 10.4, longitud: -75.4, consentimiento: true,
    })).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('elimina únicamente la ubicación del solicitante, incluso después del viaje', async () => {
    database.execute.mockResolvedValueOnce([{}]);
    await service.detener(1, 12);
    expect(database.execute).toHaveBeenCalledWith(
      expect.stringContaining('WHERE idReserva = ? AND idPersona = ?'), [12, 1],
    );
  });

  it('devuelve solo posiciones frescas de cliente y conductor durante el viaje', async () => {
    database.execute.mockResolvedValueOnce([[{ estado: 'EnCurso', cliente: 1, conductor: 2, clienteAdulto: 1, conductorAdulto: 1 }]])
      .mockResolvedValueOnce([{}]).mockResolvedValueOnce([[{
        idPersona: 2, latitud: '10.4', longitud: '-75.4', compartidaEn: new Date(),
      }]]);
    await expect(service.consultar(1, 12)).resolves.toMatchObject({
      compartiendo: false, posiciones: [{ rol: 'Conductor', latitud: 10.4 }],
    });
    expect(database.execute.mock.calls[2][1]).toEqual([12, 1, 2]);
  });

  it('bloquea seguimiento si alguno de los participantes es menor', async () => {
    database.execute.mockResolvedValueOnce([[{
      estado: 'EnCurso', cliente: 1, conductor: 2, clienteAdulto: 0, conductorAdulto: 1,
    }]]);
    await expect(service.consultar(2, 12)).rejects.toBeInstanceOf(ForbiddenException);
    expect(database.execute).toHaveBeenCalledTimes(1);
  });

  it('no toca la tabla opcional si aún no se ha habilitado la migración', async () => {
    const disabled = new UbicacionService(
      database as never, { get: () => undefined } as never,
    );
    database.execute.mockResolvedValueOnce([[{
      estado: 'EnCurso', cliente: 1, conductor: null, clienteAdulto: 1,
    }]]);
    await expect(disabled.consultar(1, 12)).resolves.toEqual({
      disponible: false, compartiendo: false, posiciones: [],
    });
    expect(database.execute).toHaveBeenCalledTimes(1);
  });
});
