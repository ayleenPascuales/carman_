import { Test, TestingModule } from '@nestjs/testing';
import { VehiculosController } from './vehiculos.controller';
import { VehiculosService } from './vehiculos.service';
import { AuthService } from '../auth/auth.service';
import { VerificationService } from '../auth/verification.service';

describe('VehiculosController', () => {
  let controller: VehiculosController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [VehiculosController],
      providers: [
        { provide: VehiculosService, useValue: {} },
        { provide: AuthService, useValue: {} },
        { provide: VerificationService, useValue: {} },
      ],
    }).compile();

    controller = module.get<VehiculosController>(VehiculosController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
