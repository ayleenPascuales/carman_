import { ForbiddenException } from '@nestjs/common';
import type { ConfigService } from '@nestjs/config';
import type { ReservasService } from './reservas.service';
import { MaintenanceReservasController } from './maintenance-reservas.controller';

describe('MaintenanceReservasController', () => {
  const reservas = { buscarYasignarConductor: jest.fn() };
  const config = { get: jest.fn((key: string) => key === 'CRON_SECRET' ? 'cron-test-secret' : undefined) };
  const controller = new MaintenanceReservasController(
    reservas as unknown as ReservasService, config as unknown as ConfigService,
  );

  beforeEach(() => jest.clearAllMocks());

  it('rechaza peticiones sin secreto o con valor incorrecto sin buscar reservas', async () => {
    await expect(controller.asignarConductores()).rejects.toBeInstanceOf(ForbiddenException);
    await expect(controller.asignarConductores('Bearer otro')).rejects.toBeInstanceOf(ForbiddenException);
    expect(reservas.buscarYasignarConductor).not.toHaveBeenCalled();
  });

  it('ejecuta búsqueda autenticada sin divulgar identificadores de reservas', async () => {
    reservas.buscarYasignarConductor.mockResolvedValue({
      reservasAsignadas: [{ idReserva: 8, idConductor: 3 }],
    });
    expect(await controller.asignarConductores('Bearer cron-test-secret')).toEqual({
      status: 'ok', asignadas: 1,
    });
  });
});
