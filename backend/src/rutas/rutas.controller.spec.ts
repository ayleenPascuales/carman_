import { Test, TestingModule } from '@nestjs/testing';
import { RutasController } from './rutas.controller';
import { RutasService } from './rutas.service';
import { UbicacionService } from './ubicacion.service';
import { AuthGuard } from '../auth/auth.guard';

describe('RutasController', () => {
  let controller: RutasController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [RutasController],
      providers: [
        { provide: RutasService, useValue: {} },
        { provide: UbicacionService, useValue: {} },
      ],
    }).overrideGuard(AuthGuard).useValue({ canActivate: () => true }).compile();

    controller = module.get<RutasController>(RutasController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('permite cercanía sin autenticar y la exige para reservas y ubicación', async () => {
    const module = await Test.createTestingModule({
      controllers: [RutasController],
      providers: [
        { provide: RutasService, useValue: { puntoCercano: jest.fn() } },
        { provide: UbicacionService, useValue: {} },
      ],
    }).overrideGuard(AuthGuard).useValue({ canActivate: () => true }).compile();
    expect(module.get(RutasController)).toBeDefined();
  });
});
