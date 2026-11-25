import { Injectable, Inject, NotFoundException, BadRequestException } from '@nestjs/common';
import type { Pool, RowDataPacket, ResultSetHeader } from 'mysql2/promise';
import { ArchivosService } from '../archivos/archivos.service';
import PDFDocument from 'pdfkit';
import { WompiService } from './wompi.service';
import { randomUUID } from 'crypto';
import type { EventoWompi } from './wompi.service';

interface ReservaPago extends RowDataPacket {
    idReserva: number;
    precioEstimado: number | string | null;
    estado: string;
}

export interface OrdenPago extends RowDataPacket {
    idOrdenPago: number;
    total: number | string;
    estado: string;
    rutaPdf: string | null;
}

interface OrdenCheckout extends RowDataPacket {
    idOrdenPago: number;
    idReserva: number;
    total: number | string;
    estado: string;
    estadoReserva: string;
    fechaInicioServicio: string | Date;
    horaInicioServicio: string;
    fechaFinServicio: string | Date;
    horaFinServicio: string;
    antesInicioServicio: number;
    duranteReserva: number;
}

interface PagoWebhook extends RowDataPacket {
    idPago: number;
    idOrdenPago: number;
    monto: number | string;
    estado: string;
    idTransaccionWompi: string | null;
    estadoOrden: string;
    tipoPago: string;
}

interface PagoExistente extends RowDataPacket {
    idPago: number;
    idOrdenPago: number;
    monto: number | string;
    estado: string;
    referenciaWompi: string | null;
    tipoPago: string;
}

@Injectable()
export class PagosService {
    constructor(
        @Inject('DATABASE_CONNECTION')
        private readonly db: Pool,
        private readonly archivosService: ArchivosService,
        private readonly wompiService: WompiService,) { }


    async generarOrdenPago(idPersona: number, idReserva: number) {
        const conexion = await this.db.getConnection();
        let transaccionActiva = false;

        try {
            await conexion.beginTransaction();
            transaccionActiva = true;

            const [reservas] = await conexion.query<ReservaPago[]>(
                `SELECT r.idReserva, r.precioEstimado, r.estado FROM reserva r
            INNER JOIN cliente c ON r.idCliente = c.idCliente
            WHERE r.idReserva = ? AND c.idPersona = ? FOR UPDATE`,
                [idReserva, idPersona],
            );

            if (reservas.length === 0) {
                throw new NotFoundException('La reserva no existe.');
            }

            const reserva = reservas[0];

            if (reserva.estado !== 'Confirmada') {
                throw new BadRequestException(
                    'Solo se pueden generar órdenes de reservas confirmadas.',
                );
            }

            const [ordenes] = await conexion.query<OrdenPago[]>(
                `SELECT idOrdenPago, total, estado, rutaPdf FROM orden_de_pago
            WHERE idReserva = ? FOR UPDATE`, [idReserva],
            );

            if (ordenes.length > 0) {
                const orden = ordenes[0];

                if (orden.estado === 'Anulada') {
                    throw new BadRequestException('La orden de pago de esta reserva fue anulada.')
                }

                await conexion.commit();
                transaccionActiva = false;

                let rutaPdf = orden.rutaPdf;

                if (!rutaPdf) {
                    rutaPdf = await this.guardarPDFOrdenPago(
                        orden.idOrdenPago,
                        idReserva,
                        Number(orden.total),
                    );
                }

                return {
                    mensaje: 'La orden de pago ya existía.',
                    ordenPago: {
                        ...orden,
                        rutaPdf,
                    },
                };
            }

            if (reserva.precioEstimado === null) {
                throw new BadRequestException(
                    'La reserva todavía no tiene un precio estimado.',
                );
            }

            const total = Number(reserva.precioEstimado);

            if (!Number.isFinite(total) || total <= 0) {
                throw new BadRequestException(
                    'El precio de la reserva no es válido.',
                );
            }

            const [resultado] = await conexion.execute<ResultSetHeader>(
                `INSERT INTO orden_de_pago (
                idReserva,
                total,
                detalles,
                estado
            ) VALUES (?, ?, ?, 'Activa')`,
                [
                    idReserva,
                    total,
                    'Orden generada automáticamente al confirmar la reserva.',
                ],
            );

            await conexion.commit();
            transaccionActiva = false;

            const idOrdenPago = resultado.insertId;
            const rutaPdf = await this.guardarPDFOrdenPago(
                idOrdenPago,
                idReserva,
                total,
            );

            return {
                mensaje: 'Orden de pago generada correctamente.',
                ordenPago: {
                    idOrdenPago,
                    idReserva,
                    total,
                    estado: 'Activa',
                    rutaPdf,
                },
            };

        } catch (error) {
            if (transaccionActiva) {
                await conexion.rollback();
            }

            throw error;

        } finally {
            conexion.release();
        }
    }


    private generarPDFOrdenPago(idOrdenPago: number, idReserva: number,
        total: number,): Promise<Buffer> {
        return new Promise((resolve, reject) => {
            const pdf = new PDFDocument({
                size: 'A4',
                margin: 50,
            });

            const partes: Buffer[] = [];

            pdf.on('data', (parte: Buffer) => {
                partes.push(parte);
            });

            pdf.on('end', () => {
                resolve(Buffer.concat(partes));
            });

            pdf.on('error', reject);

            pdf.fontSize(22)
                .text('CARMAN', { align: 'center' });

            pdf.moveDown();

            pdf.fontSize(18)
                .text('ORDEN DE PAGO', { align: 'center' });

            pdf.moveDown(2);

            pdf.fontSize(12)
                .text(`Orden de pago: ${idOrdenPago}`);

            pdf.text(`Reserva: ${idReserva}`);

            pdf.text(`Fecha de emisión: ${new Date().toLocaleString('es-CO')}`);

            pdf.moveDown();

            pdf.fontSize(14)
                .text(`Total: $${total.toLocaleString('es-CO')}`);

            pdf.moveDown();

            pdf.fontSize(11)
                .text('Estado: Activa');

            pdf.text(
                'Documento generado automáticamente por el sistema CARMAN.',
            );

            pdf.end();
        });
    }

    async iniciarPago(idPersona: number, idOrdenPago: number) {
        const conexion = await this.db.getConnection();
        let transaccionActiva = false;

        try {
            await conexion.beginTransaction();
            transaccionActiva = true;

            const [ordenes] = await conexion.query<OrdenCheckout[]>(
                `SELECT op.idOrdenPago, op.idReserva, op.total, 
                op.estado, r.estado AS estadoReserva, r.fechaInicioServicio,
                r.horaInicioServicio, r.fechaFinServicio, r.horaFinServicio,
                (CONVERT_TZ(UTC_TIMESTAMP(), '+00:00', '-05:00') 
                < TIMESTAMP(r.fechaInicioServicio, r.horaInicioServicio))
                AS antesInicioServicio,
                (CONVERT_TZ(UTC_TIMESTAMP(), '+00:00', '-05:00') BETWEEN 
                TIMESTAMP(r.fechaInicioServicio, r.horaInicioServicio)
                AND TIMESTAMP(r.fechaFinServicio, r.horaFinServicio))
                AS duranteReserva
             FROM orden_de_pago op
             INNER JOIN reserva r ON op.idReserva = r.idReserva
             INNER JOIN cliente c ON r.idCliente = c.idCliente
             WHERE op.idOrdenPago = ? AND c.idPersona = ?
             FOR UPDATE`,
                [idOrdenPago, idPersona],
            );

            if (ordenes.length === 0) {
                throw new NotFoundException('La orden de pago no existe.');
            }

            const orden = ordenes[0];

            if (orden.estado !== 'Activa') {
                throw new BadRequestException(
                    'La orden de pago no está activa.',
                );
            }

            const total = Number(orden.total);

            if (!Number.isFinite(total) || total <= 0) {
                throw new BadRequestException(
                    'El monto de la orden no es válido.',
                );
            }

            const montoAnticipo = Math.round(total * 50) / 100;

            const [pagosRealizados] = await conexion.query<
                (RowDataPacket & { totalAprobado: number | string | null })[]
            >(
                `SELECT SUM(monto) AS totalAprobado FROM pago
                WHERE idOrdenPago = ? AND estado = 'Aprobado'`,
                [idOrdenPago],
            );

            const totalAprobado = Number(pagosRealizados[0].totalAprobado ?? 0);
            const montoRestante = Math.max(0, total - totalAprobado);
            if (montoRestante <= 0) {
                throw new BadRequestException(
                    'Esta orden de pago ya está completamente pagada.'
                )
            }


            let tipoPago: 'Anticipo' | 'Restante';
            let montoPago: number;

            if (orden.antesInicioServicio) {
                tipoPago = 'Anticipo';
                montoPago = Math.min(montoAnticipo, montoRestante);
            } else if (orden.duranteReserva) {
                tipoPago = 'Restante';
                montoPago = montoRestante;
            } else {
                throw new BadRequestException(
                    'El periodo permitido para realizar pagos ha finalizado.',
                );
            }
            if (
                orden.estadoReserva !== 'Confirmada' &&
                orden.estadoReserva !== 'EnCurso'
            ) {
                throw new BadRequestException(
                    'La reserva no está en un estado válido para realizar pagos.',
                );
            }

            const [anticiposAprobados] = await conexion.query<PagoExistente[]>(
                `SELECT idPago, idOrdenPago, monto, estado,
                tipoPago, referenciaWompi FROM pago
                WHERE idOrdenPago = ? AND tipoPago = 'Anticipo'
                AND estado = 'Aprobado' LIMIT 1 FOR UPDATE`,
                [idOrdenPago],
            );

            if (tipoPago === 'Restante' && anticiposAprobados.length === 0) {
                throw new BadRequestException(
                    'Primero debes tener el anticipo aprobado antes de pagar el restante.',
                );
            }

            const [pagosAprobados] = await conexion.query<PagoExistente[]>(
                `SELECT idPago, idOrdenPago, monto, estado,
                tipoPago, referenciaWompi FROM pago
                WHERE idOrdenPago = ? AND tipoPago = ?
                AND estado = 'Aprobado' LIMIT 1 FOR UPDATE`,
                [idOrdenPago, tipoPago],
            );

            if (pagosAprobados.length > 0) {
                throw new BadRequestException(
                    `El pago correspondiente al ${tipoPago.toLowerCase()} ya fue aprobado.`,
                );
            }

            const [pagosPendientes] = await conexion.query<PagoExistente[]>(
                `SELECT idPago, idOrdenPago, monto, estado,
                tipoPago, referenciaWompi
                FROM pago WHERE idOrdenPago = ?
                AND tipoPago = ? AND estado IN ('Pendiente', 'En_proceso')
                ORDER BY idPago DESC LIMIT 1 FOR UPDATE`,
                [idOrdenPago, tipoPago],
            );

            let referencia: string;

            if (pagosPendientes.length > 0) {
                const pagoExistente = pagosPendientes[0];

                if (!pagoExistente.referenciaWompi) {
                    throw new BadRequestException(
                        'El pago pendiente no tiene referencia de Wompi.',
                    );
                }

                if (
                    Math.round(Number(pagoExistente.monto) * 100) !==
                    Math.round(montoPago * 100)
                ) {
                    throw new BadRequestException(
                        'El monto del pago pendiente no coincide con la orden.',
                    );
                }

                referencia = pagoExistente.referenciaWompi;

            } else {
                referencia = `CARMAN-${idOrdenPago}-${randomUUID()}`;

                await conexion.execute(
                    `INSERT INTO pago (
                    idReserva,
                    idOrdenPago,
                    idMetodoPago,
                    monto,
                    referenciaTransaccion,
                    estado,
                    tipoPago,
                    referenciaWompi
                    ) VALUES (?, ?, NULL, ?, ?, 'Pendiente', ?, ?)`,
                    [
                        orden.idReserva,
                        orden.idOrdenPago,
                        montoPago,
                        referencia,
                        tipoPago,
                        referencia,
                    ],
                );
            }

            await conexion.commit();
            transaccionActiva = false;
            const checkout = await this.wompiService.crearCheckout(
                montoPago,
                referencia,
            );

            return {
                mensaje: 'Checkout de Wompi generado correctamente.',
                pago: {
                    idOrdenPago: orden.idOrdenPago,
                    idReserva: orden.idReserva,
                    monto: montoPago,
                    tipoPago,
                    estado: 'Pendiente',
                    referencia,
                },
                checkoutUrl: checkout.checkoutUrl,
            };

        } catch (error) {
            if (transaccionActiva) {
                await conexion.rollback();
            }

            throw error;

        } finally {
            conexion.release();
        }
    }

    private async guardarPDFOrdenPago(idOrdenPago: number, idReserva: number,
        total: number,): Promise<string> {

        const contenido = await this.generarPDFOrdenPago(
            idOrdenPago,
            idReserva,
            total,
        );

        const documento = await this.archivosService.guardarPDF(
            `orden_pago_${idOrdenPago}.pdf`,
            'Orden_Pago',
            'orden_de_pago',
            idOrdenPago,
            contenido,
        );

        const rutaPdf = `/archivos/${documento.idDocumento}`;

        await this.db.execute(
            `UPDATE orden_de_pago SET rutaPdf = ? 
            WHERE idOrdenPago = ?`, [rutaPdf, idOrdenPago],
        );

        return rutaPdf;
    }

    async procesarEventoWompi(evento: EventoWompi) {
        if (evento.event !== 'transaction.updated') {
            return { mensaje: 'Evento ignorado.' };
        }

        if (evento.environment !== 'test') {
            throw new BadRequestException('Solo se aceptan eventos de Sandbox.');
        }

        const transaccion = evento.data?.transaction;

        if (
            !transaccion?.reference ||
            !transaccion.id ||
            transaccion.currency !== 'COP' ||
            !Number.isInteger(transaccion.amount_in_cents) || transaccion.amount_in_cents <= 0
        ) {
            throw new BadRequestException('Datos de transacción inválidos.');
        }

        const estados: Record<string, string> = {
            PENDING: 'Pendiente',
            APPROVED: 'Aprobado',
            DECLINED: 'Rechazado',
            VOIDED: 'Cancelado',
            ERROR: 'Fallido',
        };

        const nuevoEstado = estados[transaccion.status];

        if (!nuevoEstado) {
            throw new BadRequestException('Estado de Wompi no reconocido.');
        }

        const conexion = await this.db.getConnection();
        let transaccionActiva = false;

        try {
            await conexion.beginTransaction();
            transaccionActiva = true;

            const [pagos] = await conexion.query<PagoWebhook[]>(
                `SELECT
                p.idPago,
                p.idOrdenPago,
                p.monto,
                p.estado,
                p.idTransaccionWompi,
                p.tipoPago,
                op.estado AS estadoOrden
                FROM pago p INNER JOIN orden_de_pago op
                ON p.idOrdenPago = op.idOrdenPago
                WHERE p.referenciaWompi = ? FOR UPDATE`,
                [transaccion.reference],
            );
            if (pagos.length === 0) {
                throw new NotFoundException('No existe un pago con esa referencia.');
            }

            const pago = pagos[0];
            const montoEsperado = Math.round(Number(pago.monto) * 100);

            if (montoEsperado !== transaccion.amount_in_cents) {
                throw new BadRequestException('El monto recibido no coincide.');
            }

            if (
                pago.idTransaccionWompi &&
                pago.idTransaccionWompi !== transaccion.id
            ) {
                throw new BadRequestException('La transacción no coincide con el pago.');
            }
            const estadosFinales = [
                'Aprobado',
                'Rechazado',
                'Cancelado',
                'Fallido',
            ];

            if (estadosFinales.includes(pago.estado)) {
                await conexion.commit();
                transaccionActiva = false;

                return {
                    mensaje: 'El pago ya tiene un estado final.',
                    estado: pago.estado,
                };
            }

            if (pago.estado === nuevoEstado &&
                pago.idTransaccionWompi === transaccion.id) {
                await conexion.commit();
                transaccionActiva = false;

                return {
                    mensaje: 'El evento ya había sido procesado.',
                    estado: pago.estado,
                };
            }

            await conexion.execute(
                `UPDATE pago
             SET estado = ?, idTransaccionWompi = ?
             WHERE idPago = ?`,
                [nuevoEstado, transaccion.id, pago.idPago],
            );
            if (pago.estadoOrden === 'Anulada') {
                await conexion.commit();
                transaccionActiva = false;

                return {
                    mensaje: nuevoEstado === 'Aprobado'
                        ? 'El pago fue aprobado por Wompi, pero la orden está anulada. Requiere revision administrativa.'
                        : 'El evento fue registrado, pero la orden permanece anulada.',
                    estado: nuevoEstado,
                    estadoOrden: 'Anulada',
                };
            }

            const [ordenes] = await conexion.query<
                (RowDataPacket & { total: number | string })[]
            >(
                `SELECT total FROM orden_de_pago WHERE idOrdenPago = ?
             FOR UPDATE`, [pago.idOrdenPago],
            );

            if (ordenes.length === 0) {
                throw new NotFoundException('No existe la orden de pago.');
            }

            const [sumas] = await conexion.query<
                (RowDataPacket & { totalAprobado: number | string | null })[]
            >(
                `SELECT SUM(monto) AS totalAprobado FROM pago
             WHERE idOrdenPago = ? AND estado = 'Aprobado'`,
                [pago.idOrdenPago],
            );

            const totalAprobado = Number(sumas[0].totalAprobado ?? 0);
            const totalOrden = Number(ordenes[0].total);

            if (totalAprobado > totalOrden) {
                await conexion.commit();
                transaccionActiva = false;

                return {
                    mensaje: 'El pago fue aprobado por Wompi, pero el total de pagos supera la orden. Requiere revisión administrativa.',
                    estado: nuevoEstado,
                    estadoOrden: 'Activa',
                    requiereRevision: true,
                };
            }

            if (totalAprobado >= totalOrden) {
                await conexion.execute(
                    `UPDATE orden_de_pago
                 SET estado = 'Pagada'
                 WHERE idOrdenPago = ?`,
                    [pago.idOrdenPago],
                );
            }

            await conexion.commit();
            transaccionActiva = false;

            return {
                mensaje: 'Evento de Wompi procesado correctamente.',
                estado: nuevoEstado,
            };

        } catch (error) {
            if (transaccionActiva) {
                await conexion.rollback();
            }
            throw error;
        } finally {
            conexion.release();
        }
    }
}
