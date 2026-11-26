import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { RutasService } from './rutas.service';

describe('RutasService', () => {
  const database = { execute: jest.fn() };
  const config = { get: jest.fn() };
  let service: RutasService;
  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [
        RutasService,
        { provide: 'DATABASE_CONNECTION', useValue: database },
        { provide: ConfigService, useValue: config },
      ],
    }).compile();
    service = module.get(RutasService);
  });

  it('solo asigna el punto físicamente disponible y no guarda coordenadas del cliente', async () => {
    database.execute.mockResolvedValueOnce([[{
      idPunto: 3, nombre: 'Centro', direccion: 'Calle 1', ciudad: 'Cartagena',
      latitud: '10.4', longitud: '-75.5',
    }]]);
    const respuesta = await service.puntoCercano(6, 10.4, -75.5);
    expect(respuesta).toMatchObject({ punto: { idPunto: 3 }, distanciaAproximadaKm: 0 });
    expect(database.execute).toHaveBeenCalledWith(
      expect.stringContaining('p.idPunto = v.idPuntoRecogida'), [6],
    );
  });

  it('rechaza coordenadas inválidas sin consultar la base', async () => {
    await expect(service.puntoCercano(6, 91, 0)).rejects.toBeInstanceOf(BadRequestException);
    expect(database.execute).not.toHaveBeenCalled();
  });

  const reserva = {
    cliente: 3, propietario: 4, conductor: 5, precioEstimado: '250000',
    recogidaId: 11, recogidaNombre: 'A', recogidaDireccion: 'A',
    recogidaLat: '10.4', recogidaLon: '-75.5',
    entregaId: 12, entregaNombre: 'B', entregaDireccion: 'B',
    entregaLat: '10.5', entregaLon: '-75.4',
  };

  it('deniega el recorrido a usuarios ajenos antes de llamar a Mapbox', async () => {
    database.execute.mockResolvedValueOnce([[reserva]]);
    await expect(service.rutaReserva(99, 1)).rejects.toBeInstanceOf(ForbiddenException);
    expect(config.get).not.toHaveBeenCalled();
  });

  it('no finge una ruta vial si falta la configuración de Mapbox', async () => {
    database.execute.mockResolvedValueOnce([[reserva]]);
    await expect(service.rutaReserva(3, 1)).resolves.toMatchObject({
      distanciaKm: null, trayectoria: [], proveedor: 'mapbox_no_configurado',
    });
  });

  it('expone solo trazado y distancia, y no modifica tarifa por kilómetros', async () => {
    database.execute.mockResolvedValueOnce([[reserva]]);
    config.get.mockReturnValue('server-token');
    const originalFetch = global.fetch;
    global.fetch = jest.fn().mockResolvedValue({
      ok: true, json: async () => ({
        code: 'Ok', routes: [{
          distance: 2000, duration: 600,
          geometry: { coordinates: [[-75.5, 10.4], [-75.4, 10.5]] },
        }],
      }),
    });
    try {
      await expect(service.rutaReserva(5, 1)).resolves.toMatchObject({
        distanciaKm: 2, duracionMinutos: 10,
        tarifa: { precioEstimado: 250000, recargoPorDistancia: 0 },
      });
      expect(global.fetch).toHaveBeenCalledWith(
        expect.objectContaining({ hostname: 'api.mapbox.com' }),
        expect.any(Object),
      );
    } finally {
      global.fetch = originalFetch;
    }
  });
});
