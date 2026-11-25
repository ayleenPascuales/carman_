import { Test, TestingModule } from '@nestjs/testing';
import { VehiculosService } from './vehiculos.service';

describe('VehiculosService', () => {
  let service: VehiculosService;
  const database = { query: jest.fn() };

  beforeEach(async () => {
    database.query.mockReset();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        VehiculosService,
        { provide: 'DATABASE_CONNECTION', useValue: database },
      ],
    }).compile();

    service = module.get<VehiculosService>(VehiculosService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('devuelve insertId de MySQL al registrar un vehículo', async () => {
    database.query.mockResolvedValueOnce([[{ idPropietario: 4 }]])
      .mockResolvedValueOnce([[]])
      .mockResolvedValueOnce([[{ idPunto: 1 }]])
      .mockResolvedValueOnce([[{ idPunto: 2 }]])
      .mockResolvedValueOnce([{ insertId: 18 }]);
    const result = await service.crearVehiculo(10, {
      placa: 'ABC123', marca: 'Toyota', modelo: 'Corolla', anio: 2022,
      capacidad: 4, tipoVehiculo: 'Sedan',
      fotos: ['https://example.com/carro.jpg'],
      tarjetaPropiedad: 'https://example.com/tarjeta.jpg',
      idPuntoRecogida: 1, idPuntoEntrega: 2,
    });
    expect(result.idVehiculo).toBe(18);
    expect(database.query).toHaveBeenLastCalledWith(
      expect.stringContaining('INSERT INTO vehiculo'),
      expect.arrayContaining(['ABC123']),
    );
    expect(database.query.mock.lastCall?.[0]).not.toContain('RETURNING');
  });
});
