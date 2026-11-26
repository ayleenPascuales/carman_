import { Test, TestingModule } from '@nestjs/testing';
import { PagosController } from './pagos.controller';
import { PagosService } from './pagos.service';
import { WompiService } from './wompi.service';
import { AuthGuard } from '../auth/auth.guard';

describe('PagosController', () => {
  let controller: PagosController;
  const pagos = { obtenerHistorialPagos: jest.fn() };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [PagosController],
      providers: [
        { provide: PagosService, useValue: pagos },
        { provide: WompiService, useValue: {} },
      ],
    }).overrideGuard(AuthGuard).useValue({ canActivate: () => true }).compile();

    controller = module.get<PagosController>(PagosController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('consulta solo los movimientos del titular del token', async () => {
    pagos.obtenerHistorialPagos.mockResolvedValueOnce({ pagos: [] });
    await expect(controller.obtenerHistorialPagos({ user: { idPersona: 14 } }))
      .resolves.toEqual({ pagos: [] });
    expect(pagos.obtenerHistorialPagos).toHaveBeenCalledWith(14);
  });
});
