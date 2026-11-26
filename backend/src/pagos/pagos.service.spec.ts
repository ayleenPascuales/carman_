import { Test, TestingModule } from '@nestjs/testing';
import { PagosService } from './pagos.service';
import { ArchivosService } from '../archivos/archivos.service';
import { WompiService } from './wompi.service';
import { NotFoundException } from '@nestjs/common';
import { NotificacionesService } from '../notificaciones/notificaciones.service';

describe('PagosService', () => {
  let service: PagosService;
  const conexion = {
    beginTransaction: jest.fn(),
    query: jest.fn(),
    execute: jest.fn(),
    commit: jest.fn(),
    rollback: jest.fn(),
    release: jest.fn(),
  };
  const db = {
    getConnection: jest.fn().mockResolvedValue(conexion),
    execute: jest.fn(),
    query: jest.fn(),
  };
  const archivos = { guardarPDF: jest.fn() };
  const wompi = {
    verificarConfiguracionCheckout: jest.fn(),
    crearCheckout: jest.fn().mockResolvedValue({ checkoutUrl: 'https://checkout.wompi.co/p/' }),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    conexion.query.mockResolvedValue([[]]);
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PagosService,
        { provide: 'DATABASE_CONNECTION', useValue: db },
        { provide: ArchivosService, useValue: archivos },
        { provide: WompiService, useValue: wompi },
        { provide: NotificacionesService, useValue: {
          avisarPersona: jest.fn().mockResolvedValue(undefined),
          avisarReserva: jest.fn().mockResolvedValue(undefined),
        } },
      ],
    }).compile();

    service = module.get<PagosService>(PagosService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('no genera una orden para una reserva ajena o inexistente', async () => {
    await expect(service.generarOrdenPago(12, 34)).rejects.toBeInstanceOf(NotFoundException);
    expect(conexion.query).toHaveBeenCalledWith(
      expect.stringContaining('c.idPersona = ?'), [34, 12],
    );
    expect(conexion.rollback).toHaveBeenCalledTimes(1);
    expect(conexion.release).toHaveBeenCalledTimes(1);
  });

  it('no escribe pagos pendientes cuando Wompi no está configurado', async () => {
    conexion.query
      .mockResolvedValueOnce([[{
        idOrdenPago: 34, idReserva: 5, total: 100, estado: 'Activa',
      }]])
      .mockResolvedValueOnce([[{ totalAprobado: 0 }]]);
    wompi.verificarConfiguracionCheckout.mockImplementationOnce(() => {
      throw new Error('Wompi no configurado');
    });
    await expect(service.iniciarPago(12, 34)).rejects.toThrow('Wompi no configurado');
    expect(conexion.rollback).toHaveBeenCalledTimes(1);
    expect(conexion.release).toHaveBeenCalledTimes(1);
    expect(conexion.query).toHaveBeenCalledTimes(2);
  });

  it('permite pagar el restante de una reserva EnCurso aunque termine el horario previsto', async () => {
    conexion.query
      .mockResolvedValueOnce([[{
        idOrdenPago: 34, idReserva: 5, total: '100000.00',
        estado: 'Activa', estadoReserva: 'EnCurso',
        antesInicioServicio: 0, duranteReserva: 0,
      }]])
      .mockResolvedValueOnce([[{ totalAprobado: '50000.00' }]])
      .mockResolvedValueOnce([[{ idPago: 3, tipoPago: 'Anticipo', estado: 'Aprobado' }]])
      .mockResolvedValueOnce([[]])
      .mockResolvedValueOnce([[]]);
    await expect(service.iniciarPago(12, 34)).resolves.toMatchObject({
      pago: { tipoPago: 'Restante', monto: 50000 },
    });
    expect(conexion.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO pago'),
      expect.arrayContaining([50000, 'Restante']),
    );
    expect(conexion.commit).toHaveBeenCalledTimes(1);
  });

  it('devuelve la ruta pública correcta del PDF en Vercel', async () => {
    conexion.query
      .mockResolvedValueOnce([[{ idReserva: 5, precioEstimado: 100, estado: 'Confirmada' }]])
      .mockResolvedValueOnce([[]]);
    conexion.execute.mockResolvedValueOnce([{ insertId: 34 }]);
    archivos.guardarPDF.mockResolvedValueOnce({ idDocumento: 7 });
    const anterior = process.env.VERCEL;
    process.env.VERCEL = '1';
    try {
      await expect(service.generarOrdenPago(12, 5)).resolves.toMatchObject({
        ordenPago: { rutaPdf: '/api/archivos/7' },
      });
      expect(db.execute).toHaveBeenCalledWith(
        expect.stringContaining('UPDATE orden_de_pago SET rutaPdf'), ['/api/archivos/7', 34],
      );
    } finally {
      if (anterior === undefined) delete process.env.VERCEL;
      else process.env.VERCEL = anterior;
    }
  });

  it('limita el historial al cliente autenticado y no consulta datos personales', async () => {
    db.query.mockResolvedValueOnce([[{
      idPago: 7, monto: 120, estadoPago: 'Aprobado', idReserva: 9,
    }]]);
    await expect(service.obtenerHistorialPagos(12)).resolves.toMatchObject({
      totalMostrados: 1,
      pagos: [{ idPago: 7, monto: 120 }],
    });
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toContain('c.idPersona = ?');
    expect(sql).toContain('LIMIT 100');
    expect(sql).not.toContain('v.placa');
    expect(sql).not.toContain('nombrePropietario');
    expect(params).toEqual([12]);
  });

  it('consulta saldo y anticipo aprobados de la orden del cliente sin referencias del proveedor', async () => {
    db.execute.mockResolvedValueOnce([[{
      idOrdenPago: 34, idReserva: 5, total: '100000.00',
      estado: 'Activa', estadoReserva: 'Confirmada',
      rutaPdf: '/archivos/7', totalAprobado: '50000.00',
      anticipoAprobado: '50000.00', pagosEnProceso: '0',
    }]]);
    await expect(service.consultarOrdenReserva(12, 5)).resolves.toEqual({
      idOrdenPago: 34, idReserva: 5, total: 100000, estado: 'Activa',
      estadoReserva: 'Confirmada', rutaPdf: '/archivos/7',
      totalAprobado: 50000, anticipoAprobado: 50000,
      saldoPendiente: 50000, pagosEnProceso: 0,
    });
    expect(db.execute).toHaveBeenCalledWith(
      expect.stringContaining('c.idPersona = ?'), [5, 12],
    );
    expect(db.execute.mock.calls[0][0]).not.toContain('referenciaWompi');
  });

  it('no permite consultar la orden de otra cuenta', async () => {
    db.execute.mockResolvedValueOnce([[]]);
    await expect(service.consultarOrdenReserva(12, 5))
      .rejects.toBeInstanceOf(NotFoundException);
  });
});
