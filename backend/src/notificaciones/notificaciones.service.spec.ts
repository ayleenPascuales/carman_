import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { NotFoundException } from '@nestjs/common';
import { VerificationService } from '../auth/verification.service';
import { NotificacionesService } from './notificaciones.service';

describe('NotificacionesService', () => {
  const database = { execute: jest.fn() };
  const verification = { telefonoConfirmadoParaAvisos: jest.fn() };
  const config = { get: jest.fn() };
  let service: NotificacionesService;

  beforeEach(async () => {
    jest.resetAllMocks();
    config.get.mockReturnValue(undefined);
    const module = await Test.createTestingModule({
      providers: [
        NotificacionesService,
        { provide: 'DATABASE_CONNECTION', useValue: database },
        { provide: ConfigService, useValue: config },
        { provide: VerificationService, useValue: verification },
      ],
    }).compile();
    service = module.get(NotificacionesService);
  });

  it('limita la bandeja al propietario autenticado', async () => {
    database.execute.mockResolvedValueOnce([[{
      idNotificacion: 7, idReserva: 10, leida: 0, mensaje: 'Prueba',
    }]]);
    await expect(service.listar(12)).resolves.toMatchObject({
      notificaciones: [{ leida: false, rutaAccion: '/trip/10' }],
    });
    expect(database.execute).toHaveBeenCalledWith(
      expect.stringContaining('WHERE idPersonaDestino = ?'), [12],
    );
  });

  it('no permite marcar leída una notificación ajena', async () => {
    database.execute.mockResolvedValueOnce([{ affectedRows: 0 }]);
    await expect(service.marcarLeida(12, 7)).rejects.toBeInstanceOf(NotFoundException);
    expect(database.execute).toHaveBeenCalledWith(
      expect.stringContaining('idPersonaDestino = ?'), [7, 12],
    );
  });

  it('avisa a cliente, propietario y conductor sin duplicar destinatarios', async () => {
    database.execute.mockResolvedValueOnce([[{ cliente: 12, propietario: 12, conductor: 15 }]])
      .mockResolvedValue([{ insertId: 1 }]);
    await service.avisarReserva(10, 'solicitada');
    const inserts = database.execute.mock.calls.filter(([sql]: [string]) =>
      sql.includes('INSERT INTO notificacion'));
    expect(inserts).toHaveLength(2);
    expect(inserts.map(([, params]: [string, unknown[]]) => params[0])).toEqual([12, 15]);
  });

  it('sin proveedor configurado solo deja el aviso en la bandeja', async () => {
    database.execute.mockResolvedValueOnce([{ insertId: 1 }]);
    await service.avisarPersona(12, 'Pago', 'Un aviso', { idReserva: 10, sms: true });
    expect(verification.telefonoConfirmadoParaAvisos).not.toHaveBeenCalled();
  });

  it('no envía SMS al teléfono de una persona no verificada', async () => {
    config.get.mockReturnValue('clave-de-prueba');
    database.execute.mockResolvedValueOnce([{ insertId: 1 }])
      .mockResolvedValueOnce([[{ uidFirebase: 'uid-de-prueba', telefono: '+573000000000' }]]);
    verification.telefonoConfirmadoParaAvisos.mockResolvedValueOnce(false);
    const envio = jest.spyOn(global, 'fetch');
    try {
      await service.avisarPersona(12, 'Reserva', 'Aviso de prueba', { sms: true });
      expect(envio).not.toHaveBeenCalled();
    } finally {
      envio.mockRestore();
    }
  });

  it('envía SMS crítico solo si el teléfono verificado y textbee acepta el lote', async () => {
    config.get.mockReturnValue('clave-de-prueba');
    database.execute.mockResolvedValueOnce([{ insertId: 1 }])
      .mockResolvedValueOnce([[{ uidFirebase: 'uid-de-prueba', telefono: '+573000000000' }]]);
    verification.telefonoConfirmadoParaAvisos.mockResolvedValueOnce(true);
    const envio = jest.spyOn(global, 'fetch').mockResolvedValueOnce({
      ok: true,
      json: async () => ({ data: { success: true, smsBatchId: 'lote-de-prueba' } }),
    } as Response);
    try {
      await service.avisarPersona(12, 'Reserva', 'Aviso de prueba', { sms: true });
      expect(envio).toHaveBeenCalledWith(
        'https://api.textbee.dev/api/v1/gateway/send-sms',
        expect.objectContaining({ method: 'POST' }),
      );
    } finally {
      envio.mockRestore();
    }
  });
});
