import { Test } from '@nestjs/testing';
import { CalificacionesController } from './calificaciones.controller';
import { CalificacionesService } from './calificaciones.service';
import { TipoObjetivoCalificacion } from './dto/crearCalificacion.dto';
import { AuthGuard } from '../auth/auth.guard';

describe('CalificacionesController', () => {
  const calificaciones = {
    crearCalificacion: jest.fn(),
    consultarCalificacionesVehiculo: jest.fn(),
    consultarCalificacionesConductor: jest.fn(),
  };
  let controller: CalificacionesController;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      controllers: [CalificacionesController],
      providers: [{ provide: CalificacionesService, useValue: calificaciones }],
    }).overrideGuard(AuthGuard).useValue({ canActivate: () => true }).compile();
    controller = module.get(CalificacionesController);
  });

  it('atribuye una calificación a la sesión autenticada, no al cuerpo', async () => {
    const dto = { tipoObjetivo: TipoObjetivoCalificacion.VEHICULO, puntuacion: 5 };
    calificaciones.crearCalificacion.mockResolvedValue({ idCalificacion: 3 });
    await expect(controller.crearCalificacion({ user: { idPersona: 8 } }, 12, dto))
      .resolves.toEqual({ idCalificacion: 3 });
    expect(calificaciones.crearCalificacion).toHaveBeenCalledWith(8, 12, dto);
  });

  it('expone únicamente las consultas de valoraciones', async () => {
    await controller.consultarVehiculo(3);
    await controller.consultarConductor(4);
    expect(calificaciones.consultarCalificacionesVehiculo).toHaveBeenCalledWith(3);
    expect(calificaciones.consultarCalificacionesConductor).toHaveBeenCalledWith(4);
  });
});
