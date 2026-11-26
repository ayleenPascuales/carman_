import { BadRequestException, NotFoundException } from '@nestjs/common';
import type { Pool } from 'mysql2/promise';
import { ReservasService } from './reservas.service';
import type { PagosService } from '../pagos/pagos.service';
import type { NotificacionesService } from '../notificaciones/notificaciones.service';

describe('Servicios del conductor M4 (dobles, sin base)', () => {
    const connection = {
        query: jest.fn(), beginTransaction: jest.fn(), commit: jest.fn(),
        rollback: jest.fn(), release: jest.fn(),
    };
    const db = {
        query: jest.fn(), getConnection: jest.fn().mockResolvedValue(connection),
    };
    const pagos = { prepararActualizacionOrdenPago: jest.fn() };
    const avisos = { avisarReserva: jest.fn() };
    const service = new ReservasService(
        db as unknown as Pool, pagos as unknown as PagosService,
        avisos as unknown as NotificacionesService,
    );
    beforeEach(() => {
        jest.clearAllMocks();
        db.getConnection.mockResolvedValue(connection);
    });

    it('valida la paginación antes de consultar la base', async () => {
        await expect(service.obtenerServiciosConductor(3, '0'))
            .rejects.toBeInstanceOf(BadRequestException);
        await expect(service.obtenerServiciosConductor(3, '2 OR 1=1'))
            .rejects.toBeInstanceOf(BadRequestException);
        expect(db.query).not.toHaveBeenCalled();
    });

    it('rechaza el listado de una cuenta sin rol de conductor', async () => {
        db.query.mockResolvedValueOnce([[]]);
        await expect(service.obtenerServiciosConductor(3))
            .rejects.toBeInstanceOf(NotFoundException);
        expect(db.query).toHaveBeenCalledWith(
            expect.stringContaining('c.idPersona = ?'), [3],
        );
        expect(db.query).toHaveBeenCalledTimes(1);
    });

    it('lista solo asignaciones propias; no expone teléfono, precio ni documento', async () => {
        db.query.mockResolvedValueOnce([[{
            idConductor: 6, disponibilidad: 1, licenciaVigente: 1,
        }]]).mockResolvedValueOnce([[{
            idReserva: 42, estado: 'Pendiente', estadoRespuestaConductor: 'Pendiente',
            nombreCliente: 'Ana', apellidoCliente: 'López',
            placa: 'PRIVADA', telefono: 'NO_PUBLICAR', precioEstimado: 123456,
            idVehiculo: 8, marca: 'Toyota', modelo: 'Corolla',
        }]]);
        const result = await service.obtenerServiciosConductor(3, '2');
        expect(db.query).toHaveBeenLastCalledWith(
            expect.stringContaining('WHERE c.idPersona = ?'), [3],
        );
        expect(db.query.mock.calls[1][0]).toContain('LIMIT 21 OFFSET 20');
        expect(result.servicios).toHaveLength(1);
        expect(result.pagina).toBe(2);
        expect(result.hayMas).toBe(false);
        expect(JSON.stringify(result)).not.toMatch(/PRIVADA|NO_PUBLICAR|123456/);
    });

    it('no acepta si la licencia caduca antes de acabar el servicio', async () => {
        connection.query
            .mockResolvedValueOnce([[{ idConductor: 7, disponibilidad: 1 }]])
            .mockResolvedValueOnce([[{
                idReserva: 8, idConductor: 7, estado: 'Pendiente',
                estadoRespuestaConductor: 'Pendiente',
                fechaInicioServicio: '2099-01-01', horaInicioServicio: '08:00:00',
                fechaFinServicio: '2099-01-03', precioEstimado: '100000',
            }]])
            .mockResolvedValueOnce([[]]);
        await expect(service.responderReserva(3, 8, { aceptar: true }))
            .rejects.toBeInstanceOf(BadRequestException);
        expect(connection.query).toHaveBeenCalledWith(
            expect.stringContaining('fechaExpiracion >= ?'),
            [3, '2099-01-03'],
        );
        expect(pagos.prepararActualizacionOrdenPago).not.toHaveBeenCalled();
        expect(connection.commit).not.toHaveBeenCalled();
    });

    it('una segunda aceptación no añade dos veces el recargo', async () => {
        connection.query
            .mockResolvedValueOnce([[{ idConductor: 7, disponibilidad: 1 }]])
            .mockResolvedValueOnce([[{
                idReserva: 8, idConductor: 7, estado: 'Confirmada',
                estadoRespuestaConductor: 'Aceptada',
                fechaInicioServicio: '2099-01-01', horaInicioServicio: '08:00:00',
            }]]);
        await expect(service.responderReserva(3, 8, { aceptar: true }))
            .rejects.toBeInstanceOf(BadRequestException);
        expect(pagos.prepararActualizacionOrdenPago).not.toHaveBeenCalled();
        expect(connection.commit).not.toHaveBeenCalled();
        expect(connection.rollback).toHaveBeenCalledTimes(1);
    });

    it('no permite responder a un conductor no asignado', async () => {
        connection.query
            .mockResolvedValueOnce([[{ idConductor: 7, disponibilidad: 1 }]])
            .mockResolvedValueOnce([[{
                idReserva: 8, idConductor: 9, estado: 'Pendiente',
                estadoRespuestaConductor: 'Pendiente',
            }]]);
        await expect(service.responderReserva(3, 8, { aceptar: false }))
            .rejects.toBeInstanceOf(BadRequestException);
        expect(connection.query).toHaveBeenCalledTimes(2);
        expect(connection.commit).not.toHaveBeenCalled();
    });
});
