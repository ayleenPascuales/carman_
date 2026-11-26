import { Test, TestingModule } from '@nestjs/testing';
import { NotificacionesController } from './notificaciones.controller';
import { NotificacionesService } from './notificaciones.service';
import { AuthGuard } from '../auth/auth.guard';

describe('NotificacionesController', () => {
  let controller: NotificacionesController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [NotificacionesController],
      providers: [{ provide: NotificacionesService, useValue: {} }],
    }).overrideGuard(AuthGuard).useValue({ canActivate: () => true }).compile();

    controller = module.get<NotificacionesController>(NotificacionesController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
