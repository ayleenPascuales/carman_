import { Test, TestingModule } from '@nestjs/testing';
import { ReservasService } from './reservas.service';
import { PagosService } from '../pagos/pagos.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
import { NotFoundException } from '@nestjs/common';

describe('ReservasService', () => {
  let service: ReservasService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ReservasService,
        { provide: 'DATABASE_CONNECTION', useValue: {} },
        { provide: PagosService, useValue: {} },
        { provide: NotificacionesService, useValue: {} },
      ],
    }).compile();

    service = module.get<ReservasService>(ReservasService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('no devuelve el detalle de una reserva ajena', async () => {
    const query = jest.fn().mockResolvedValue([[]]);
    // La base de este test es un doble sin conexiones reales.
    (service as unknown as { database: { query: typeof query } }).database = { query };
    await expect(service.obtenerDetalleReserva(12, 5))
      .rejects.toBeInstanceOf(NotFoundException);
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining('AND r.idReserva = ?'), [12, 12, 12, 5],
    );
  });
});
