import { Injectable, Inject, BadRequestException, NotFoundException } from '@nestjs/common';
import type { Pool, PoolConnection } from 'mysql2/promise';
import type { ResultSetHeader, RowDataPacket } from 'mysql2';
import { CrearReservaDto } from './dto/crearReserva.dto';
import { RespuestaConductorDTO } from './dto/respuestaConductor.dto';
import { DecisionSinConductorDTO } from './dto/desicionSinConductor.dto';
import { PagosService } from '../pagos/pagos.service';
import { ActualizarReservaDto } from './dto/actualizarReserva.dto';
import { EventoReserva, NotificacionesService } from '../notificaciones/notificaciones.service';

function fechaBogota(valor: Date | string): string {
    if (typeof valor === 'string') {
        if (!/^\d{4}-\d{2}-\d{2}$/.test(valor)) {
            throw new BadRequestException('La fecha guardada no es válida.');
        }
        return valor;
    }
    if (!(valor instanceof Date) || !Number.isFinite(valor.getTime())) {
        throw new BadRequestException('La fecha guardada no es válida.');
    }
    const partes = new Intl.DateTimeFormat('en-US', {
        timeZone: 'America/Bogota', year: 'numeric', month: '2-digit', day: '2-digit',
    }).formatToParts(valor);
    const campo = (tipo: string) => partes.find(parte => parte.type === tipo)?.value;
    return `${campo('year')}-${campo('month')}-${campo('day')}`;
}

function validarInicioFuturo(fecha: string, hora: string): void {
    const inicio = new Date(`${fecha}T${hora}-05:00`);
    if (!Number.isFinite(inicio.getTime()) || inicio.getTime() <= Date.now()) {
        throw new BadRequestException('El inicio de la reserva debe ser futuro (hora de Colombia).');
    }
}

@Injectable()
export class ReservasService {

    constructor(
        @Inject('DATABASE_CONNECTION')
        private readonly database: Pool,
        private readonly pagosService: PagosService,
        private readonly notificaciones: NotificacionesService) {

    }

    private async conductorSinCruce(
        connection: PoolConnection, idConductor: number,
        fechaInicio: string, horaInicio: string, fechaFin: string, horaFin: string,
        excluirReserva = 0,
    ): Promise<boolean> {
        // Lectura bloqueante actual después del lock del conductor: una
        // lectura consistente previa podría no observar la otra transacción.
        const [ocupadas] = await connection.query<RowDataPacket[]>(
            `SELECT idReserva FROM reserva WHERE idConductor = ?
             AND idReserva <> ? AND estado IN ('Pendiente', 'Confirmada', 'EnCurso')
             AND TIMESTAMP(fechaInicioServicio, horaInicioServicio) < TIMESTAMP(?, ?)
             AND TIMESTAMP(fechaFinServicio, horaFinServicio) > TIMESTAMP(?, ?)
             LIMIT 1 FOR UPDATE`,
            [idConductor, excluirReserva, fechaFin, horaFin, fechaInicio, horaInicio],
        );
        return ocupadas.length === 0;
    }

    private async exigirLicenciaCliente(
        connection: PoolConnection, idPersona: number, fechaFin: string,
    ): Promise<void> {
        const [licencias] = await connection.query<RowDataPacket[]>(
            `SELECT idLicencia FROM licencia WHERE idPersona = ?
             AND estado = 'Vigente' AND fechaExpiracion >= ? LIMIT 1`,
            [idPersona, fechaFin],
        );
        if (!licencias.length) {
            throw new BadRequestException(
                'Para conducir sin conductor necesitas una licencia vigente durante toda la reserva.',
            );
        }
    }

    async crearReserva(idPersona: number, idVehiculo: number, dto: CrearReservaDto) {
        if (!Number.isSafeInteger(idVehiculo) || idVehiculo <= 0) {
            throw new BadRequestException('El vehículo no es válido.');
        }
        const connection = await this.database.getConnection();
        try {
        await connection.beginTransaction();
        // Serializa también la creación implícita del rol cliente cuando la
        // misma persona intenta reservar dos vehículos simultáneamente.
        const [personas] = await connection.query<RowDataPacket[]>(
            'SELECT idPersona FROM persona WHERE idPersona = ? FOR UPDATE',
            [idPersona],
        );
        if (!personas.length) {
            throw new NotFoundException('La persona no existe.');
        }
        // La fila del vehículo serializa las reservas concurrentes del mismo
        // vehículo incluso cuando aún no existe ninguna reserva para el intervalo.
        const [vehiculos] = await connection.query<RowDataPacket[]>(
            `SELECT idVehiculo, estado, estado_solicitud_revision,
            idPuntoRecogida, idPuntoEntrega, precioPorDia
            FROM vehiculo WHERE idVehiculo = ? FOR UPDATE`, [idVehiculo]
        );
        if (vehiculos.length === 0) {
            throw new NotFoundException('El vehiculo no existe.');
        }
        const [clientes] = await connection.query<RowDataPacket[]>(
            `SELECT idCliente FROM cliente WHERE idPersona = ?`, [idPersona]
        );
        let idCliente: number;
        if (clientes.length === 0) {
            const [resulatoCliente] = await connection.query<ResultSetHeader>(
                `INSERT INTO cliente (idPersona) VALUES (?)`, [idPersona]
            );
            idCliente = resulatoCliente.insertId;
        } else {
            idCliente = clientes[0].idCliente;
        }

        const vehiculo = vehiculos[0];
        if (vehiculo.precioPorDia === null || vehiculo.precioPorDia === undefined ||
            !Number.isFinite(Number(vehiculo.precioPorDia))
            || Number(vehiculo.precioPorDia) <= 0) {
            throw new BadRequestException('El vehiculo no tiene un precio de alquiler válido.');
        }
        if (vehiculo.estado !== 'Activo') {
            throw new BadRequestException('El vehiculo no está disponible para reservar.');
        }
        if (vehiculo.estado_solicitud_revision === 'Pendiente') {
            throw new BadRequestException(
                'El vehículo tiene una revisión técncica pendiente y no puede reservarse. '
            );
        }

        if (!vehiculo.idPuntoRecogida || !vehiculo.idPuntoEntrega) {
            throw new BadRequestException(
                'El vehiculo no tiene configurados sus puntos autorizados. '
            );
        }
        const [puntos] = await connection.query<RowDataPacket[]>(
            `SELECT idPunto FROM punto_autorizado 
            WHERE idPunto IN (?, ?) AND activo = 1`, [vehiculo.idPuntoRecogida, vehiculo.idPuntoEntrega]
        );
        if (puntos.length !== new Set([vehiculo.idPuntoRecogida, vehiculo.idPuntoEntrega]).size) {
            throw new BadRequestException(
                'Uno de los puntos autorizados del vehiculo está inactivo.'
            );
        }
        const horas: Record<string, string> = {
            '08:00 AM': '08:00:00',
            '09:00 AM': '09:00:00',
            '10:00 AM': '10:00:00',
            '11:00 AM': '11:00:00',
            '2:00 PM': '14:00:00',
            '3:00 PM': '15:00:00',
            '4:00 PM': '16:00:00',
            '5:00 PM': '17:00:00',
            '6:00 PM': '18:00:00'
        };
        const horaInicio = horas[dto.horaInicioServicio];
        const horaFin = horas[dto.horaFinServicio];
        if (!horaInicio || !horaFin) {
            throw new BadRequestException('La hora seleccionada no esta permitida. ');
        }

        const inicio = `${dto.fechaInicioServicio} ${horaInicio}`;
        const fin = `${dto.fechaFinServicio} ${horaFin}`;
        if (fin <= inicio) {
            throw new BadRequestException(
                'La fecha y hora de finalizacion deben ser posteriores al inicio. '
            );
        }
        validarInicioFuturo(dto.fechaInicioServicio, horaInicio);
        if (dto.solicitarConductor !== true) {
            await this.exigirLicenciaCliente(connection, idPersona, dto.fechaFinServicio);
        }
        const fechaInicio = new Date(
            `${dto.fechaInicioServicio}T00:00:00`
        );
        const fechaFin = new Date(
            `${dto.fechaFinServicio}T00:00:00`
        );
        const cantidadDias = Math.max(1, Math.ceil(
            (fechaFin.getTime() - fechaInicio.getTime()) / (1000 * 60 * 60 * 24))
        );
        const precioEstimado = (vehiculo.precioPorDia) * cantidadDias

        const [reservasExistentes] = await connection.query<RowDataPacket[]>(
            `SELECT idReserva FROM reserva WHERE idVehiculo = ?
            AND estado IN ('Pendiente', 'Confirmada', 'EnCurso')
            AND TIMESTAMP(fechaInicioServicio, horaInicioServicio) < TIMESTAMP(?, ?)
            AND TIMESTAMP(fechaFinServicio, horaFinServicio) > TIMESTAMP(?, ?)`,
            [
                idVehiculo,
                dto.fechaFinServicio,
                horaFin,
                dto.fechaInicioServicio,
                horaInicio
            ]
        );
        if (reservasExistentes.length > 0) {
            throw new BadRequestException('El vehiculo ya tiene una reserva en este horario.');
        }
        let idConductor: number | null = null;
        if (dto.solicitarConductor === true) {
            const [conductores] = await connection.query<RowDataPacket[]>(
                `SELECT c.idConductor FROM conductor c
                INNER JOIN licencia l ON l.idPersona = c.idPersona
                INNER JOIN persona p ON p.idPersona = c.idPersona AND p.estado = 'Activo'
                WHERE c.disponibilidad = 1 AND l.estado = 'Vigente'
                AND l.fechaExpiracion >= ? AND NOT EXISTS(
                SELECT 1 FROM reserva r WHERE r.idConductor = c.idConductor
                AND r.estado IN ('Pendiente', 'Confirmada', 'EnCurso')
                AND TIMESTAMP(r.fechaInicioServicio, r.horaInicioServicio) < TIMESTAMP(?, ?)
                AND TIMESTAMP (r.fechaFinServicio, r.horaFinServicio) > TIMESTAMP(?, ?))
                ORDER BY c.calificacion DESC, c.idConductor DESC LIMIT 1 FOR UPDATE`,
                [
                    dto.fechaFinServicio,
                    dto.fechaFinServicio,
                    horaFin,
                    dto.fechaInicioServicio,
                    horaInicio
                ]
            );
            if (conductores.length > 0) {
                const candidato = Number(conductores[0].idConductor);
                if (await this.conductorSinCruce(connection, candidato,
                    dto.fechaInicioServicio, horaInicio, dto.fechaFinServicio, horaFin)) {
                    idConductor = candidato;
                }
            }
        }
        const estadoReserva = dto.solicitarConductor === true
            ? 'Pendiente'
            : 'Confirmada';

        const [resultado] = await connection.query<ResultSetHeader>(
            `INSERT INTO reserva(
            idCliente,
            idVehiculo,
            idConductor,
            fechaInicioServicio,
            horaInicioServicio,
            fechaFinServicio,
            horaFinServicio,
            estado,
            precioEstimado,
            idPuntoRecogida,
            idPuntoEntrega,
            estadoRespuestaConductor
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                idCliente,
                idVehiculo,
                idConductor,
                dto.fechaInicioServicio,
                horaInicio,
                dto.fechaFinServicio,
                horaFin,
                estadoReserva,
                precioEstimado,
                vehiculo.idPuntoRecogida,
                vehiculo.idPuntoEntrega,
                idConductor !== null
                    ? 'Pendiente' : dto.solicitarConductor === true
                        ? 'Sin_conductor' : null
            ]
        );
        await connection.commit();
        try {
            await this.notificaciones.avisarReserva(
                resultado.insertId, estadoReserva === 'Confirmada' ? 'confirmada' : 'solicitada',
            );
        } catch {
            // La reserva ya está confirmada: fallar la respuesta induciría un
            // reintento que crearía otra reserva.
        }
        return {
            mensaje: 'Solicitud de reserva creada correctamente.',
            idReserva: resultado.insertId,
            estado: estadoReserva,
            requiereDecisionConductor:
                dto.solicitarConductor === true && idConductor === null
        };
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }
    }

    async responderReserva(idPersona: number, idReserva: number, dto: RespuestaConductorDTO) {
        const connection = await this.database.getConnection();
        let aviso: EventoReserva | null = null;
        let ordenActualizada: {
            idOrdenPago: number;
            idReserva: number;
            total: number;
        } | null = null;

        try {
            await connection.beginTransaction();
            const [conductores] = await connection.query<RowDataPacket[]>(
                `SELECT idConductor, disponibilidad FROM conductor WHERE idPersona = ?`, [idPersona],
            );
            if (conductores.length === 0) {
                throw new BadRequestException(
                    'Esta cuenta no pertenece a un conductor. ',
                );
            }
            const idConductor = Number(conductores[0].idConductor);

            const [reservas] = await connection.query<RowDataPacket[]>(
                `SELECT
                idReserva,
                idConductor,
                estado,
                estadoRespuestaConductor,
                conductoresRechazados,
                fechaInicioServicio,
                horaInicioServicio,
                fechaFinServicio,
                horaFinServicio,
                DATEDIFF(fechaFinServicio, fechaInicioServicio) AS cantidadDias,
                precioEstimado
                FROM reserva WHERE idReserva = ? FOR UPDATE`, [idReserva],
            );
            if (reservas.length === 0) {
                throw new NotFoundException('La reserva no existe.');
            }
            const reserva = reservas[0];
            if (Number(reserva.idConductor) !== idConductor) {
                throw new BadRequestException('No estas asignado a esta reserva. ');
            }

            if (reserva.estado !== 'Pendiente' || reserva.estadoRespuestaConductor !== 'Pendiente') {
                throw new BadRequestException('Esta reserva ya no esta pendiente de respuesta. ');
            }
            validarInicioFuturo(
                fechaBogota(reserva.fechaInicioServicio),
                String(reserva.horaInicioServicio).slice(0, 8),
            );
            if (dto.aceptar) {
                if (!conductores[0].disponibilidad) {
                    throw new BadRequestException('Activa tu disponibilidad antes de aceptar.');
                }
                const [licencias] = await connection.query<RowDataPacket[]>(
                    `SELECT idLicencia FROM licencia WHERE idPersona = ?
                     AND estado = 'Vigente' AND fechaExpiracion >= ?
                     LIMIT 1`, [idPersona, fechaBogota(reserva.fechaFinServicio)],
                );
                if (!licencias.length) {
                    throw new BadRequestException(
                        'Necesitas una licencia vigente hasta el final del servicio.',
                    );
                }

                const cantidadDias = Math.max(1, Number(reserva.cantidadDias));
                const precioConductor = 70000 * cantidadDias;
                const precioActual = Number(reserva.precioEstimado);
                if (reserva.precioEstimado === null ||
                    reserva.precioEstimado === undefined ||
                    !Number.isFinite(precioActual)) {
                    throw new BadRequestException('La reserva no tiene un precio estimado.')
                }
                const nuevoPrecioEstimado = precioActual + precioConductor;
                ordenActualizada = await this.pagosService.prepararActualizacionOrdenPago(
                    connection,
                    idReserva,
                    nuevoPrecioEstimado,
                );

                await connection.query(
                    `UPDATE reserva SET estado = 'Confirmada', estadoRespuestaConductor = 'Aceptada',
                    precioEstimado = ? WHERE idReserva = ?`,
                    [nuevoPrecioEstimado, idReserva],
                );
                await connection.commit();
                aviso = 'conductorAcepto';
                let pdfActualizado = null;
                if (ordenActualizada) {
                    try {
                        pdfActualizado = await this.pagosService.actualizarPDFOrdenPago(
                            ordenActualizada.idOrdenPago,
                            idReserva,
                            nuevoPrecioEstimado,
                        );
                    } catch {
                        pdfActualizado = {
                            advertencia: 'El conductor aceptó, pero no se pudo regenerar el PDF.',
                        };
                    }
                }
                return {
                    mensaje: 'Has aceptado el servicio.',
                    idReserva,
                    idConductor,
                    estado: 'Confirmada',
                    estadoRespuestaConductor: 'Aceptada',
                    precioEstimado: nuevoPrecioEstimado,
                    pdfActualizado,
                };
            }
            let rechazados: number[] = [];
            if (reserva.conductoresRechazados) {
                rechazados = typeof reserva.conductoresRechazados === 'string'
                    ? JSON.parse(reserva.conductoresRechazados)
                    : reserva.conductoresRechazados;
            }
            if (!rechazados.includes(idConductor)) {
                rechazados.push(idConductor);
            }

            const placeholders = rechazados.map(() => '?').join(', ');
            const [nuevosConductores] = await connection.query<RowDataPacket[]>(
                `SELECT c.idConductor FROM conductor c
                    INNER JOIN licencia l ON l.idPersona = c.idPersona
                    INNER JOIN persona p ON p.idPersona = c.idPersona AND p.estado = 'Activo'
                    WHERE c.disponibilidad = 1 AND l.estado = 'Vigente' 
                    AND l.fechaExpiracion >= CURDATE()
                    AND l.fechaExpiracion >= ?
    
                    AND c.idConductor NOT IN (${placeholders})
                    AND NOT EXISTS (
                    SELECT 1 FROM reserva r WHERE r.idConductor = c.idConductor
                    AND r.estado IN ('Pendiente', 'Confirmada', 'EnCurso')
                    AND TIMESTAMP(r.fechaInicioServicio, r.horaInicioServicio) < TIMESTAMP(?, ?)
                    AND TIMESTAMP(r.fechaFinServicio, r.horaFinServicio) > TIMESTAMP(?, ?))
                    ORDER BY 
                    c.calificacion DESC,
                    c.idConductor DESC LIMIT 1 FOR UPDATE`,
                [
                    fechaBogota(reserva.fechaFinServicio),
                    ...rechazados,
                    reserva.fechaFinServicio,
                    reserva.horaFinServicio,
                    reserva.fechaInicioServicio,
                    reserva.horaInicioServicio,
                ],
            );
            const candidato = nuevosConductores.length
                ? Number(nuevosConductores[0].idConductor) : null;
            const disponible = candidato !== null && await this.conductorSinCruce(
                connection, candidato, fechaBogota(reserva.fechaInicioServicio),
                reserva.horaInicioServicio, fechaBogota(reserva.fechaFinServicio),
                reserva.horaFinServicio, idReserva,
            );
            if (!disponible) {
                await connection.query(
                    `UPDATE reserva SET idConductor = NULL,
                    estadoRespuestaConductor = 'Sin_conductor',
                    conductoresRechazados = ?, decisionSinConductor = NULL
                    WHERE idReserva = ?`, [JSON.stringify(rechazados), idReserva]
                );
                await connection.commit();
                aviso = 'sinConductor';
                return {
                    mensaje: 'No hay conductores disponibles para la reserva.',
                    idReserva,
                    estado: 'Pendiente',
                    estadoRespuestaConductor: 'Sin_conductor',
                    conductoresRechazados: rechazados,
                };
            }

            const nuevoIdConductor = candidato!;
            await connection.query(
                `UPDATE reserva SET idConductor = ?, 
                estadoRespuestaConductor = 'Pendiente', conductoresRechazados = ?,
                decisionSinConductor = NULL WHERE idReserva = ?`,
                [nuevoIdConductor, JSON.stringify(rechazados), idReserva,],
            );
            await connection.commit();
            aviso = 'conductorAsignado';
            return {
                mensaje: 'El conductor rechazo. se asignara otro automaticamente.',
                idReserva,
                nuevoIdConductor,
                estado: 'Pendiente',
                estadoRespuestaConductor: 'Pendiente',
                conductoresRechazados: rechazados,
            };
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
            if (aviso) await this.notificaciones.avisarReserva(idReserva, aviso);
        }
    }

    async decidirSinConductor(idPersona: number, idReserva: number, dto: DecisionSinConductorDTO) {
        const connection = await this.database.getConnection();
        let avisar = false;

        try {
            await connection.beginTransaction();

            const [reservas] = await connection.query<RowDataPacket[]>(
                `SELECT
                r.idReserva,
                r.idCliente,
                r.idConductor,
                r.estado,
                r.estadoRespuestaConductor,
                r.decisionSinConductor,
                r.fechaInicioServicio,
                r.horaInicioServicio,
                r.fechaFinServicio,
                c.idPersona
                FROM reserva r INNER JOIN cliente c 
                ON c.idCliente = r.idCliente WHERE r.idReserva = ? FOR UPDATE`,
                [idReserva],
            );

            if (reservas.length === 0) {
                throw new NotFoundException('La reserva no existe. ')
            }
            const reserva = reservas[0];
            if (Number(reserva.idPersona) !== idPersona) {
                throw new BadRequestException('Esta reserva no pertenece a tu cuenta. ',);
            }
            if (reserva.estado !== 'Pendiente' || reserva.idConductor !== null
                || reserva.estadoRespuestaConductor !== 'Sin_conductor'
                || reserva.decisionSinConductor !== null
            ) {
                throw new BadRequestException(
                    'Esta reserva no está esperando una desición sobre el conductor. ',
                );
            }
            validarInicioFuturo(
                fechaBogota(reserva.fechaInicioServicio),
                String(reserva.horaInicioServicio).slice(0, 8),
            );
            if (dto.decision === 'Continuar') {
                await this.exigirLicenciaCliente(
                    connection, idPersona, fechaBogota(reserva.fechaFinServicio),
                );
            }
            await connection.query(
                `UPDATE reserva SET decisionSinConductor = ?,
                estado = CASE WHEN ? = 'Continuar' THEN 'Confirmada' ELSE estado END
                WHERE idReserva = ?`, [dto.decision, dto.decision, idReserva],
            );
            await connection.commit();
            avisar = true;
            return {
                mensaje: dto.decision === 'Esperar'
                    ? 'La reserva queda pendiente mientras se busca un conductor. '
                    : 'Has decidido continuar con la reserva sin conductor. ',
                idReserva,
                decisionSinConductor: dto.decision,
                estado: dto.decision === 'Continuar' ? 'Confirmada' : 'Pendiente',
            };
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
            if (avisar) await this.notificaciones.avisarReserva(idReserva, 'actualizada');
        }
    }

    async buscarYasignarConductor() {
        const connection = await this.database.getConnection();
        let confirmado = false;

        const reservasAsignadas: {
            idReserva: number,
            idConductor: number;
        }[] = [];

        try {
            await connection.beginTransaction();
            const [reservas] = await connection.execute<RowDataPacket[]>(
                `SELECT 
                idReserva,
                fechaInicioServicio,
                horaInicioServicio,
                fechaFinServicio,
                horaFinServicio,
                conductoresRechazados 
                FROM reserva WHERE estado = 'Pendiente'
                AND idConductor IS NULL 
                AND estadoRespuestaConductor = 'Sin_conductor'
                AND decisionSinConductor = 'Esperar'
                AND TIMESTAMP(fechaInicioServicio, horaInicioServicio) > NOW()
                ORDER BY fechaHoraReserva ASC FOR UPDATE`
            );
            for (const reserva of reservas) {
                let rechazados: number[] = [];

                if (reserva.conductoresRechazados) {
                    const datosRechazados = typeof reserva.conductoresRechazados === 'string'
                        ? JSON.parse(reserva.conductoresRechazados)
                        : reserva.conductoresRechazados;

                    rechazados = Array.isArray(datosRechazados)
                        ? datosRechazados.map(Number)
                        : [];
                }

                const filtroRechazados = rechazados.length > 0
                    ? `AND c.idConductor NOT IN (${rechazados.map(() => '?').join(', ')})`
                    : '';

                const [disponibles] = await connection.execute<RowDataPacket[]>(
                    `SELECT c.idConductor FROM conductor c 
                    INNER JOIN licencia l ON l.idPersona = c.idPersona
                    INNER JOIN persona p ON p.idPersona = c.idPersona AND p.estado = 'Activo'
                    WHERE c.disponibilidad = 1 AND l.estado = 'Vigente'
                    AND l.fechaExpiracion >= ? ${filtroRechazados}
                    AND NOT EXISTS ( SELECT 1
                    FROM reserva r WHERE r.idConductor = c.idConductor
                    AND r.estado IN ('Pendiente', 'Confirmada', 'EnCurso')
                    AND TIMESTAMP(r.fechaInicioServicio, r.horaInicioServicio) < TIMESTAMP(?, ?)
                    AND TIMESTAMP(r.fechaFinServicio, r.horaFinServicio) > TIMESTAMP(?, ?))
                    ORDER BY c.calificacion DESC, c.idConductor DESC LIMIT 1 FOR UPDATE`,
                    [
                        fechaBogota(reserva.fechaFinServicio),
                        ...rechazados,
                        reserva.fechaFinServicio,
                        reserva.horaFinServicio,
                        reserva.fechaInicioServicio,
                        reserva.horaInicioServicio
                    ]
                );
                if (disponibles.length === 0 || !await this.conductorSinCruce(
                    connection, Number(disponibles[0].idConductor),
                    fechaBogota(reserva.fechaInicioServicio), reserva.horaInicioServicio,
                    fechaBogota(reserva.fechaFinServicio), reserva.horaFinServicio,
                    Number(reserva.idReserva),
                )) {
                    continue;
                }
                const idConductor = Number(disponibles[0].idConductor);
                await connection.execute(
                    `UPDATE reserva SET idConductor = ?,
                    estadoRespuestaConductor = 'Pendiente',
                    decisionSinConductor = NULL
                    WHERE idReserva = ?`, [idConductor, reserva.idReserva]
                );

                reservasAsignadas.push({
                    idReserva: Number(reserva.idReserva),
                    idConductor
                });
            }

            await connection.commit();
            confirmado = true;

            return {
                mensaje: 'Búsqueda de conductores finalizada.',
                reservasAsignadas
            };

        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
            if (confirmado) {
                for (const reserva of reservasAsignadas) {
                    await this.notificaciones.avisarReserva(reserva.idReserva, 'conductorAsignado');
                }
            }
        }
    }

    async obtenerMisReservas(idPersona: number, idReserva?: number) {
        const [reservas] = await this.database.query<RowDataPacket[]>(
            `SELECT 
            r.idReserva,
            r.fechaHoraReserva,
            r.fechaInicioServicio,
            r.horaInicioServicio,
            r.fechaFinServicio,
            r.horaFinServicio,
            r.estado,
            r.precioEstimado,
            r.idConductor,
            r.estadoRespuestaConductor,
            r.decisionSinConductor,
            r.idPuntoRecogida,
            r.idPuntoEntrega,
            EXISTS (
              SELECT 1 FROM calificacion cal
              WHERE cal.idReserva = r.idReserva
                AND cal.idCliente = r.idCliente
                AND cal.idVehiculo = r.idVehiculo
            ) AS resenado,
            
            v.idVehiculo,
            v.placa,
            v.marca,
            v.modelo,
            v.anio,
            v.tipoVehiculo,
            v.capacidad,
            v.precioPorDia,
            v.estado AS estadoVehiculo,
            v.fotos,
            prp.nombre AS nombrePuntoRecogida,
            prp.direccion AS direccionPuntoRecogida,
            prp.ciudad AS ciudadPuntoRecogida,
            prp.latitud AS latitudPuntoRecogida,
            prp.longitud AS longitudPuntoRecogida,
            pep.nombre AS nombrePuntoEntrega,
            pep.direccion AS direccionPuntoEntrega,
            pep.ciudad AS ciudadPuntoEntrega,
            pep.latitud AS latitudPuntoEntrega,
            pep.longitud AS longitudPuntoEntrega,

            pc.nombre AS nombreCliente,
            pc.apellido AS apellidoCliente,
            pc.idPersona AS idPersonaCliente,

            pd.nombre AS nombreConductor,
            pd.apellido AS apellidoConductor,
            pd.idPersona AS idPersonaConductor,

            pp.idPersona AS idPersonaPropietario

            FROM reserva r
            INNER JOIN cliente c ON c.idCliente = r.idCliente
            INNER JOIN persona pc ON pc.idPersona = c.idPersona
            INNER JOIN vehiculo v ON v.idVehiculo = r.idVehiculo
            INNER JOIN propietario pr ON pr.idPropietario = v.idPropietario
            INNER JOIN persona pp ON pp.idPersona = pr.idPersona
            LEFT JOIN punto_autorizado prp ON prp.idPunto = r.idPuntoRecogida
            LEFT JOIN punto_autorizado pep ON pep.idPunto = r.idPuntoEntrega
            LEFT JOIN conductor co ON co.idConductor = r.idConductor
            LEFT JOIN persona pd ON pd.idPersona = co.idPersona
            WHERE (pc.idPersona = ?
                OR pd.idPersona = ?
                OR pp.idPersona = ?)
                ${idReserva !== undefined ? 'AND r.idReserva = ?' : ''}
            ORDER BY r.fechaHoraReserva DESC`,
            [idPersona, idPersona, idPersona,
                ...(idReserva !== undefined ? [idReserva] : [])]
        );
        return {
            mensaje: 'Reservas consultadas correctamente.',
            total: reservas.length,
            reservas: reservas.map(reserva => ({
                ...reserva,
                vehiculo: {
                    idVehiculo: reserva.idVehiculo,
                    marca: reserva.marca, modelo: reserva.modelo, anio: reserva.anio,
                    tipoVehiculo: reserva.tipoVehiculo, capacidad: reserva.capacidad,
                    precioPorDia: reserva.precioPorDia, estado: reserva.estadoVehiculo,
                    fotos: reserva.fotos,
                },
                puntoRecogida: {
                    idPunto: reserva.idPuntoRecogida, nombre: reserva.nombrePuntoRecogida,
                    direccion: reserva.direccionPuntoRecogida, ciudad: reserva.ciudadPuntoRecogida,
                    latitud: reserva.latitudPuntoRecogida, longitud: reserva.longitudPuntoRecogida,
                },
                puntoEntrega: {
                    idPunto: reserva.idPuntoEntrega, nombre: reserva.nombrePuntoEntrega,
                    direccion: reserva.direccionPuntoEntrega, ciudad: reserva.ciudadPuntoEntrega,
                    latitud: reserva.latitudPuntoEntrega, longitud: reserva.longitudPuntoEntrega,
                },
                rolesRelacionados: [
                    ...(Number(reserva.idPersonaCliente) === idPersona
                        ? ['Cliente'] : []),
                    ...(Number(reserva.idPersonaConductor) === idPersona
                        ? ['Conductor'] : []),
                    ...(Number(reserva.idPersonaPropietario) === idPersona
                        ? ['Propietario'] : [])
                ]
            }))
        };
    }

    async obtenerDetalleReserva(idPersona: number, idReserva: number) {
        const resultado = await this.obtenerMisReservas(idPersona, idReserva);
        if (resultado.reservas.length === 0) {
            throw new NotFoundException('La reserva no existe para esta cuenta.');
        }
        return resultado.reservas[0];
    }

    async obtenerServiciosConductor(idPersona: number, paginaRaw?: string) {
        if (paginaRaw !== undefined && !/^[1-9]\d{0,3}$/.test(paginaRaw)) {
            throw new BadRequestException('La página debe estar entre 1 y 9999.');
        }
        const pagina = paginaRaw === undefined ? 1 : Number(paginaRaw);
        const limit = 20;
        const offset = (pagina - 1) * limit;
        const [conductores] = await this.database.query<RowDataPacket[]>(
            `SELECT c.idConductor, c.disponibilidad,
                    EXISTS (SELECT 1 FROM licencia l WHERE l.idPersona = c.idPersona
                        AND l.estado = 'Vigente' AND l.fechaExpiracion >= CURDATE())
                        AS licenciaVigente
             FROM conductor c WHERE c.idPersona = ?`, [idPersona],
        );
        if (!conductores.length) {
            throw new NotFoundException('Esta cuenta no tiene rol de conductor.');
        }
        const [servicios] = await this.database.query<RowDataPacket[]>(
            `SELECT r.idReserva, r.estado, r.estadoRespuestaConductor,
                    DATE_FORMAT(r.fechaInicioServicio, '%Y-%m-%d') AS fechaInicioServicio,
                    TIME_FORMAT(r.horaInicioServicio, '%H:%i:%s') AS horaInicioServicio,
                    DATE_FORMAT(r.fechaFinServicio, '%Y-%m-%d') AS fechaFinServicio,
                    TIME_FORMAT(r.horaFinServicio, '%H:%i:%s') AS horaFinServicio,
                    v.idVehiculo, v.marca, v.modelo, v.anio, v.tipoVehiculo,
                    v.capacidad, v.precioPorDia, v.fotos,
                    pc.nombre AS nombreCliente, pc.apellido AS apellidoCliente,
                    pr.nombre AS nombrePuntoRecogida, pr.direccion AS direccionPuntoRecogida,
                    pe.nombre AS nombrePuntoEntrega, pe.direccion AS direccionPuntoEntrega
             FROM reserva r
             INNER JOIN conductor c ON c.idConductor = r.idConductor
             INNER JOIN cliente cl ON cl.idCliente = r.idCliente
             INNER JOIN persona pc ON pc.idPersona = cl.idPersona
             INNER JOIN vehiculo v ON v.idVehiculo = r.idVehiculo
             LEFT JOIN punto_autorizado pr ON pr.idPunto = r.idPuntoRecogida
             LEFT JOIN punto_autorizado pe ON pe.idPunto = r.idPuntoEntrega
             WHERE c.idPersona = ?
             ORDER BY CASE
                 WHEN r.estado IN ('Confirmada', 'EnCurso') THEN 0
                 WHEN r.estado = 'Pendiente' THEN 1 ELSE 2 END,
                 r.fechaInicioServicio DESC, r.horaInicioServicio DESC, r.idReserva DESC
             LIMIT ${limit + 1} OFFSET ${offset}`, [idPersona],
        );
        return {
            disponibilidad: Boolean(conductores[0].disponibilidad),
            licenciaVigente: Boolean(conductores[0].licenciaVigente),
            pagina,
            hayMas: servicios.length > limit,
            servicios: servicios.slice(0, limit).map(servicio => ({
                idReserva: servicio.idReserva,
                estado: servicio.estado,
                estadoRespuestaConductor: servicio.estadoRespuestaConductor,
                fechaInicioServicio: servicio.fechaInicioServicio,
                horaInicioServicio: servicio.horaInicioServicio,
                fechaFinServicio: servicio.fechaFinServicio,
                horaFinServicio: servicio.horaFinServicio,
                cliente: {
                    nombre: [servicio.nombreCliente, servicio.apellidoCliente]
                        .filter(Boolean).join(' '),
                },
                vehiculo: {
                    idVehiculo: servicio.idVehiculo, marca: servicio.marca,
                    modelo: servicio.modelo, anio: servicio.anio,
                    tipoVehiculo: servicio.tipoVehiculo, capacidad: servicio.capacidad,
                    precioPorDia: servicio.precioPorDia, fotos: servicio.fotos,
                },
                origen: [servicio.nombrePuntoRecogida, servicio.direccionPuntoRecogida]
                    .filter(Boolean).join(' · '),
                destino: [servicio.nombrePuntoEntrega, servicio.direccionPuntoEntrega]
                    .filter(Boolean).join(' · '),
            })),
        };
    }

    async transicionarServicio(
        idPersona: number, idReserva: number, accion: 'iniciar' | 'finalizar',
    ) {
        const connection = await this.database.getConnection();
        let confirmado = false;
        try {
            await connection.beginTransaction();
            const [reservas] = await connection.query<RowDataPacket[]>(
                `SELECT r.estado, r.idConductor, r.fechaInicioServicio,
                        r.horaInicioServicio, r.fechaFinServicio, r.horaFinServicio,
                        c.idPersona AS idPersonaCliente,
                        co.idPersona AS idPersonaConductor
                 FROM reserva r
                 INNER JOIN cliente c ON c.idCliente = r.idCliente
                 LEFT JOIN conductor co ON co.idConductor = r.idConductor
                 WHERE r.idReserva = ? FOR UPDATE`, [idReserva],
            );
            if (!reservas.length) {
                throw new NotFoundException('La reserva no existe.');
            }
            const reserva = reservas[0];
            const actor = reserva.idConductor === null
                ? Number(reserva.idPersonaCliente)
                : Number(reserva.idPersonaConductor);
            if (actor !== idPersona) {
                throw new NotFoundException('La reserva no existe para esta cuenta.');
            }
            const estadoEsperado = accion === 'iniciar' ? 'Confirmada' : 'EnCurso';
            if (reserva.estado !== estadoEsperado) {
                throw new BadRequestException(`Solo puedes ${accion} una reserva ${estadoEsperado}.`);
            }
            if (accion === 'iniciar') {
                const inicio = new Date(
                    `${fechaBogota(reserva.fechaInicioServicio)}T${String(reserva.horaInicioServicio).slice(0, 8)}-05:00`,
                );
                const fin = new Date(
                    `${fechaBogota(reserva.fechaFinServicio)}T${String(reserva.horaFinServicio).slice(0, 8)}-05:00`,
                );
                if (!Number.isFinite(inicio.getTime()) || !Number.isFinite(fin.getTime())
                    || Date.now() < inicio.getTime() || Date.now() > fin.getTime()) {
                    throw new BadRequestException(
                        'El servicio solo puede iniciarse dentro del horario acordado (Colombia).',
                    );
                }
            }
            const [ordenes] = await connection.query<RowDataPacket[]>(
                `SELECT idOrdenPago, total, estado FROM orden_de_pago
                 WHERE idReserva = ? FOR UPDATE`, [idReserva],
            );
            const orden = ordenes[0];
            if (!orden || orden.estado !== 'Activa' ||
                !Number.isFinite(Number(orden.total)) || Number(orden.total) <= 0) {
                throw new BadRequestException('La reserva necesita una orden de pago válida.');
            }
            const [pagos] = await connection.query<RowDataPacket[]>(
                `SELECT tipoPago, monto FROM pago
                 WHERE idOrdenPago = ? AND estado = 'Aprobado' FOR UPDATE`,
                [orden.idOrdenPago],
            );
            const total = Number(orden.total);
            const montos = pagos.map(pago => Number(pago.monto));
            if (montos.some(monto => !Number.isFinite(monto) || monto <= 0)) {
                throw new BadRequestException('Los pagos aprobados no son válidos.');
            }
            const totalCentavos = Math.round(total * 100);
            const aprobadoCentavos = montos.reduce(
                (sum, monto) => sum + Math.round(monto * 100), 0,
            );
            if (accion === 'iniciar') {
                const anticipoCentavos = pagos
                    .filter(pago => pago.tipoPago === 'Anticipo' || pago.tipoPago === 'Completo')
                    .reduce((sum, pago) => sum + Math.round(Number(pago.monto) * 100), 0);
                if (anticipoCentavos < Math.round(totalCentavos / 2)) {
                    throw new BadRequestException('El anticipo debe estar aprobado antes de iniciar.');
                }
            } else if (aprobadoCentavos < totalCentavos) {
                throw new BadRequestException('El saldo debe estar aprobado antes de finalizar.');
            }
            const estado = accion === 'iniciar' ? 'EnCurso' : 'Finalizada';
            await connection.query(
                `UPDATE reserva SET estado = ? WHERE idReserva = ?`,
                [estado, idReserva],
            );
            await connection.commit();
            confirmado = true;
            return { mensaje: `Servicio ${accion === 'iniciar' ? 'iniciado' : 'finalizado'}.`,
                idReserva, estado };
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
            if (confirmado) {
                await this.notificaciones.avisarReserva(
                    idReserva, accion === 'iniciar' ? 'iniciada' : 'finalizada',
                );
            }
        }
    }

    async actualizarReserva(idPersona: number, idReserva: number, dto: ActualizarReservaDto,) {
        if (Object.values(dto).every(valor => valor === undefined)) {
            throw new BadRequestException('Debes modificar al menos un dato de la reserva.');
        }
        const connection = await this.database.getConnection();
        let avisar = false;
        let ordenActualizada: {
            idOrdenPago: number;
            idReserva: number;
            total: number;
        } | null = null;

        try {
            await connection.beginTransaction();
            // Mismo orden de bloqueos que crearReserva: primero vehículo,
            // después reserva. Los cambios de intervalo serializan por vehículo.
            const [vehiculos] = await connection.query<RowDataPacket[]>(
                `SELECT v.idVehiculo FROM vehiculo v
                 INNER JOIN reserva r ON r.idVehiculo = v.idVehiculo
                 WHERE r.idReserva = ? FOR UPDATE`, [idReserva],
            );
            if (!vehiculos.length) {
                throw new NotFoundException('La reserva no existe.');
            }
            const [reservas] = await connection.query<RowDataPacket[]>(
                `SELECT r.*,
                c.idPersona,
                v.precioPorDia
                FROM reserva r
                INNER JOIN cliente c ON c.idCliente = r.idCliente
                INNER JOIN vehiculo v ON v.idVehiculo = r.idVehiculo
                WHERE r.idReserva = ? FOR UPDATE`, [idReserva],
            );
            if (reservas.length === 0) {
                throw new NotFoundException('La reserva no existe. ')
            }
            const reserva = reservas[0];
            if (Number(reserva.idPersona) !== idPersona) {
                throw new BadRequestException(
                    'Esta reserva no pertecene a tu cuenta.',
                );
            }
            if (!['Pendiente', 'Confirmada'].includes(reserva.estado)) {
                throw new BadRequestException(
                    'No puedes editar una reserva que ya está cancelada o en curso.',
                );
            }
            const fechaInicio = dto.fechaInicioServicio ??
                fechaBogota(reserva.fechaInicioServicio);
            const fechaFin = dto.fechaFinServicio ??
                fechaBogota(reserva.fechaFinServicio);

            const horas: Record<string, string> = {
                '08:00 AM': '08:00:00',
                '09:00 AM': '09:00:00',
                '10:00 AM': '10:00:00',
                '11:00 AM': '11:00:00',
                '2:00 PM': '14:00:00',
                '3:00 PM': '15:00:00',
                '4:00 PM': '16:00:00',
                '5:00 PM': '17:00:00',
                '6:00 PM': '18:00:00',
            };
            const obtenerHoraFormulario = (horaBD: string): string => {
                const hora = String(horaBD).slice(0, 8);
                return Object.keys(horas).find(
                    (key) => horas[key] === hora,
                ) ?? '';
            };
            const horaInicioFormulario = dto.horaInicioServicio ??
                obtenerHoraFormulario(reserva.horaInicioServicio);

            const horaFinFormulario = dto.horaFinServicio ??
                obtenerHoraFormulario(reserva.horaFinServicio);

            const horaInicio = horas[horaInicioFormulario];
            const horaFin = horas[horaFinFormulario];

            if (!horaInicio || !horaFin) {
                throw new BadRequestException('La hora seleccionada no está permitida.',);
            }
            const inicio = `${fechaInicio} ${horaInicio}`;
            const fin = `${fechaFin} ${horaFin}`;

            if (fin <= inicio) {
                throw new BadRequestException(
                    'La fecha y hora de finalización deben ser posteriores al inicio.',
                );
            }
            validarInicioFuturo(fechaInicio, horaInicio);
            const fechaInicioDate = new Date(`${fechaInicio}T00:00:00`);
            const fechaFinDate = new Date(`${fechaFin}T00:00:00`);

            const cantidadDias = Math.max(
                1,
                Math.ceil(
                    (fechaFinDate.getTime() - fechaInicioDate.getTime()) /
                    (1000 * 60 * 60 * 24),
                ),
            );

            const precioPorDia = Number(reserva.precioPorDia);

            if (!Number.isFinite(precioPorDia) || precioPorDia <= 0) {
                throw new BadRequestException(
                    'El vehículo no tiene un precio de alquiler válido.',
                );
            }

            const precioBase = precioPorDia * cantidadDias;
            const intervaloIgual = fechaInicio === fechaBogota(reserva.fechaInicioServicio)
                && fechaFin === fechaBogota(reserva.fechaFinServicio)
                && horaInicio === String(reserva.horaInicioServicio).slice(0, 8)
                && horaFin === String(reserva.horaFinServicio).slice(0, 8);
            const conductorAntes = reserva.idConductor !== null ||
                (reserva.estadoRespuestaConductor === 'Sin_conductor' &&
                 reserva.decisionSinConductor !== 'Continuar');
            if (intervaloIgual &&
                (dto.solicitarConductor === undefined || dto.solicitarConductor === conductorAntes)) {
                throw new BadRequestException('La reserva no tiene cambios efectivos.');
            }

            const [reservasExistentes] = await connection.query<RowDataPacket[]>(
                `SELECT idReserva FROM reserva WHERE idVehiculo = ?
                AND idReserva <> ? AND estado IN ('Pendiente', 'Confirmada', 'EnCurso')
                AND TIMESTAMP(fechaInicioServicio, horaInicioServicio) < TIMESTAMP(?, ?)
                AND TIMESTAMP(fechaFinServicio, horaFinServicio) > TIMESTAMP(?, ?)`,
                [
                    reserva.idVehiculo,
                    idReserva,
                    fechaFin,
                    horaFin,
                    fechaInicio,
                    horaInicio,
                ],
            );

            if (reservasExistentes.length > 0) {
                throw new BadRequestException(
                    'El vehículo ya tiene una reserva en ese horario.',
                );
            }

            const solicitarConductor = dto.solicitarConductor ??
                (
                    reserva.idConductor !== null || (
                        reserva.estadoRespuestaConductor === 'Sin_conductor'
                        && reserva.decisionSinConductor !== 'Continuar'
                    )
                );
            if (!solicitarConductor) {
                await this.exigirLicenciaCliente(connection, idPersona, fechaFin);
            }

            let idConductor: number | null = null;
            let estadoRespuestaConductor: string | null = null;
            let estadoReserva = 'Confirmada';
            let precioEstimadoFinal = precioBase;

            if (solicitarConductor && dto.solicitarConductor === undefined && reserva.idConductor !== null) {
                const conductorActual = Number(reserva.idConductor);
                const [conductor] = await connection.query<RowDataPacket[]>(
                    `SELECT c.idConductor FROM conductor c
                     INNER JOIN licencia l ON l.idPersona = c.idPersona
                     INNER JOIN persona p ON p.idPersona = c.idPersona
                     WHERE c.idConductor = ? AND c.disponibilidad = 1
                     AND p.estado = 'Activo' AND l.estado = 'Vigente'
                     AND l.fechaExpiracion >= ? FOR UPDATE`,
                    [conductorActual, fechaFin],
                );
                if (!conductor.length || !await this.conductorSinCruce(
                    connection, conductorActual, fechaInicio, horaInicio,
                    fechaFin, horaFin, idReserva,
                )) {
                    throw new BadRequestException('El conductor asignado no está disponible para el nuevo horario.');
                }
                idConductor = conductorActual;
                estadoRespuestaConductor = reserva.estadoRespuestaConductor;
                estadoReserva = reserva.estado;
                if (estadoRespuestaConductor === 'Aceptada') {
                    precioEstimadoFinal += 70000 * cantidadDias;
                }
            } else if (solicitarConductor) {
                let rechazados: number[] = [];

                if (reserva.conductoresRechazados) {
                    const datos = typeof reserva.conductoresRechazados === 'string'
                        ? JSON.parse(reserva.conductoresRechazados)
                        : reserva.conductoresRechazados;

                    rechazados = Array.isArray(datos)
                        ? datos.map(Number)
                        : [];
                }

                const filtroRechazados = rechazados.length > 0
                    ? `AND c.idConductor NOT IN (${rechazados.map(() => '?').join(', ')})`
                    : '';

                const [conductores] = await connection.query<RowDataPacket[]>(
                    `SELECT c.idConductor FROM conductor c
                    INNER JOIN licencia l ON l.idPersona = c.idPersona
                    INNER JOIN persona p ON p.idPersona = c.idPersona AND p.estado = 'Activo'
                    WHERE c.disponibilidad = 1 AND l.estado = 'Vigente'
                    AND l.fechaExpiracion >= ? ${filtroRechazados}
                    AND NOT EXISTS (
                    SELECT 1
                    FROM reserva r
                    WHERE r.idConductor = c.idConductor
                    AND r.idReserva <> ?
                    AND r.estado IN ('Pendiente', 'Confirmada', 'EnCurso')
                    AND TIMESTAMP(r.fechaInicioServicio, r.horaInicioServicio) < TIMESTAMP(?, ?)
                    AND TIMESTAMP(r.fechaFinServicio, r.horaFinServicio) > TIMESTAMP(?, ?)
                    ) ORDER BY c.calificacion DESC, c.idConductor DESC LIMIT 1 FOR UPDATE`,
                    [
                        fechaFin,
                        ...rechazados,
                        idReserva,
                        fechaFin,
                        horaFin,
                        fechaInicio,
                        horaInicio,
                    ],
                );

                if (conductores.length > 0 && await this.conductorSinCruce(
                    connection, Number(conductores[0].idConductor),
                    fechaInicio, horaInicio, fechaFin, horaFin, idReserva,
                )) {
                    idConductor = Number(conductores[0].idConductor);
                    estadoRespuestaConductor = 'Pendiente';
                } else {
                    estadoRespuestaConductor = 'Sin_conductor';
                }

                estadoReserva = 'Pendiente';
            }

            ordenActualizada = await this.pagosService.prepararActualizacionOrdenPago(
                connection,
                idReserva,
                precioEstimadoFinal,
            );

            await connection.query(
                `UPDATE reserva SET
                fechaInicioServicio = ?,
                horaInicioServicio = ?,
                fechaFinServicio = ?,
                horaFinServicio = ?,
                idConductor = ?,
                estadoRespuestaConductor = ?,
                decisionSinConductor = NULL,
                precioEstimado = ?,
                estado = ?
                WHERE idReserva = ?`,
                [
                    fechaInicio,
                    horaInicio,
                    fechaFin,
                    horaFin,
                    idConductor,
                    estadoRespuestaConductor,
                    precioEstimadoFinal,
                    estadoReserva,
                    idReserva,
                ],
            );

            await connection.commit();
            avisar = true;

            let pdfActualizado = null;

            if (ordenActualizada) {
                try {
                    pdfActualizado =
                        await this.pagosService.actualizarPDFOrdenPago(
                            ordenActualizada.idOrdenPago,
                            idReserva,
                            precioEstimadoFinal,
                        );
                } catch {
                    pdfActualizado = {
                        advertencia: 'La reserva se actualizó, pero no se pudo regenerar el PDF.',
                    };
                }
            }

            return {
                mensaje: 'Reserva actualizada correctamente.',
                idReserva,
                fechaInicioServicio: fechaInicio,
                horaInicioServicio: horaInicioFormulario,
                fechaFinServicio: fechaFin,
                horaFinServicio: horaFinFormulario,
                solicitarConductor,
                idConductor,
                estadoRespuestaConductor,
                estado: estadoReserva,
                precioEstimado: precioEstimadoFinal,
                pdfActualizado,
            };

        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
            if (avisar) await this.notificaciones.avisarReserva(idReserva, 'actualizada');
        }
    }

    async cancelarReserva(idPersona: number, idReserva: number) {
        const connection = await this.database.getConnection();
        let avisar = false;

        try {
            await connection.beginTransaction();
            const [reservas] = await connection.query<RowDataPacket[]>(
                `SELECT 
                r.idReserva,
                r.estado,
                c.idPersona FROM reserva r
                INNER JOIN cliente c ON c.idCliente = r.idCliente
                WHERE r.idReserva = ? FOR UPDATE`, [idReserva],
            );
            if (reservas.length === 0) {
                throw new NotFoundException('La reserva no existe.');
            }
            const reserva = reservas[0];
            if (Number(reserva.idPersona) !== idPersona) {
                throw new BadRequestException('Esta reserva no pertenece a tu cuenta.');
            }
            if (!['Pendiente', 'Confirmada'].includes(reserva.estado)) {
                throw new BadRequestException(
                    'No puedes cancelar una reserva que ya esta en curso, finalizada o cancelada. ',
                );
            }
            await this.pagosService.prepararCancelacionOrdenPago(connection, idReserva);
            await connection.query(
                `UPDATE reserva SET estado = 'Cancelada'
                WHERE idReserva = ?`, [idReserva],
            );
            await connection.commit();
            avisar = true;
            return {
                mensaje: 'Reserva cancelada con exito.',
                idReserva,
                estado: 'Cancelada',
            };
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
            if (avisar) await this.notificaciones.avisarReserva(idReserva, 'cancelada');
        }
    }
}
