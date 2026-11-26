import { Injectable, Inject, BadRequestException, NotFoundException } from '@nestjs/common';
import type { Pool } from 'mysql2/promise';
import type { ResultSetHeader, RowDataPacket } from 'mysql2';
import { CrearReservaDto } from './dto/crearReserva.dto';
import { RespuestaConductorDTO } from './dto/respuestaConductor.dto';
import { DecisionSinConductorDTO } from './dto/desicionSinConductor.dto';

@Injectable()
export class ReservasService {

    constructor(
        @Inject('DATABASE_CONNECTION')
        private readonly database: Pool) {

    }

    async crearReserva(idPersona: number, idVehiculo: number, dto: CrearReservaDto) {
        const [clientes] = await this.database.query<RowDataPacket[]>(
            `SELECT idCliente FROM cliente WHERE idPersona = ?`, [idPersona]
        );
        let idCliente: number;
        if (clientes.length === 0) {
            const [resulatoCliente] = await this.database.query<ResultSetHeader>(
                `INSERT INTO cliente (idPersona) VALUES (?)`, [idPersona]
            );
            idCliente = resulatoCliente.insertId;
        } else {
            idCliente = clientes[0].idCliente;
        }

        const [vehiculos] = await this.database.query<RowDataPacket[]>(
            `SELECT idVehiculo, estado, estado_solicitud_revision,
            idPuntoRecogida, idPuntoEntrega FROM vehiculo WHERE idVehiculo = ?`, [idVehiculo]
        );
        if (vehiculos.length === 0) {
            throw new NotFoundException('El vehiculo no existe. ')
        }
        const vehiculo = vehiculos[0];
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
        const [puntos] = await this.database.query<RowDataPacket[]>(
            `SELECT idPunto FROM punto_autorizado 
            WHERE idPunto IN (?, ?) AND activo = 1`, [vehiculo.idPuntoRecogida, vehiculo.idPuntoEntrega]
        );
        if (puntos.length !== 2) {
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

        const [reservasExistentes] = await this.database.query<RowDataPacket[]>(
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
            const [conductores] = await this.database.query<RowDataPacket[]>(
                `SELECT c.idConductor FROM conductor c
                INNER JOIN licencia l ON l.idPersona = c.idPersona
                WHERE c.disponibilidad = 1 AND l.estado = 'Vigente'
                AND l.fechaExpiracion >= CURDATE() AND NOT EXISTS(
                SELECT 1 FROM reserva r WHERE r.idConductor = c.idConductor
                AND r.estado IN ('Pendiente', 'Confirmada', 'EnCurso')
                AND TIMESTAMP(r.fechaInicioServicio, r.horaInicioServicio) < TIMESTAMP(?, ?)
                AND TIMESTAMP (r.fechaFinServicio, r.horaFinServicio) > TIMESTAMP(?, ?))
                ORDER BY c.calificacion DESC, c.idConductor DESC LIMIT 1`,
                [
                    dto.fechaFinServicio,
                    horaFin,
                    dto.fechaInicioServicio,
                    horaInicio
                ]
            );
            if (conductores.length > 0) {
                idConductor = Number(conductores[0].idConductor);
            }
        }

        const [resultado] = await this.database.query<ResultSetHeader>(
            `INSERT INTO reserva(
            idCliente,
            idVehiculo,
            idConductor,
            fechaInicioServicio,
            horaInicioServicio,
            fechaFinServicio,
            horaFinServicio,
            estado,
            idPuntoRecogida,
            idPuntoEntrega,
            estadoRespuestaConductor
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                idCliente,
                idVehiculo,
                idConductor,
                dto.fechaInicioServicio,
                horaInicio,
                dto.fechaFinServicio,
                horaFin,
                'Pendiente',
                vehiculo.idPuntoRecogida,
                vehiculo.idPuntoEntrega,
                idConductor !== null
                    ? 'Pendiente' : dto.solicitarConductor === true
                        ? 'Sin_conductor' : null
            ]
        );
        return {
            mensaje: 'Solicitud de reserva creada correctamente.',
            idReserva: resultado.insertId,
            estado: 'Pendiente',
            requiereDecisionConductor:
                dto.solicitarConductor === true && idConductor === null
        };

    }

    async responderReserva(idPersona: number, idReserva: number, dto: RespuestaConductorDTO) {
        const connection = await this.database.getConnection();

        try {
            await connection.beginTransaction();
            const [conductores] = await connection.query<RowDataPacket[]>(
                `SELECT idConductor FROM conductor WHERE idPersona = ?`, [idPersona],
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
                horaFinServicio
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
            if (dto.aceptar) {
                await connection.query(
                    `UPDATE reserva SET estadoRespuestaConductor = 'Aceptada'
                    WHERE idReserva = ?`, [idReserva],
                );
                await connection.commit();
                return {
                    mensaje: 'Has aceptado el servicio.',
                    idReserva,
                    idConductor,
                    estado: 'Pendiente',
                    estadoRespuestaConductor: 'Aceptada',
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
                    WHERE c.disponibilidad = 1 AND l.estado = 'Vigente' 
                    AND l.fechaExpiracion >= CURDATE()
    
                    AND c.idConductor NOT IN (${placeholders})
                    AND NOT EXISTS (
                    SELECT 1 FROM reserva r WHERE r.idConductor = c.idConductor
                    AND r.estado IN ('Pendiente', 'Confirmada', 'EnCurso')
                    AND TIMESTAMP(r.fechaInicioServicio, r.horaInicioServicio) < TIMESTAMP(?, ?)
                    AND TIMESTAMP(r.fechaFinServicio, r.horaFinServicio) > TIMESTAMP(?, ?))
                    ORDER BY 
                    c.calificacion DESC,
                    c.idConductor DESC LIMIT 1`,
                [
                    ...rechazados,
                    reserva.fechaFinServicio,
                    reserva.horaFinServicio,
                    reserva.fechaInicioServicio,
                    reserva.horaInicioServicio,
                ],
            );
            if (nuevosConductores.length === 0) {
                await connection.query(
                    `UPDATE reserva SET idConductor = NULL,
                    estadoRespuestaConductor = 'Sin_conductor',
                    conductoresRechazados = ?, decisionSinConductor = NULL
                    WHERE idReserva = ?`, [JSON.stringify(rechazados), idReserva]
                );
                await connection.commit();
                return {
                    mensaje: 'No hay conductores disponibles para la reserva.',
                    idReserva,
                    estado: 'Pendiente',
                    estadoRespuestaConductor: 'Sin_conductor',
                    conductoresRechazados: rechazados,
                };
            }

            const nuevoIdConductor = Number(nuevosConductores[0].idConductor,);
            await connection.query(
                `UPDATE reserva SET idConductor = ?, 
                estadoRespuestaConductor = 'Pendiente', conductoresRechazados = ?,
                decisionSinConductor = NULL WHERE idReserva = ?`,
                [nuevoIdConductor, JSON.stringify(rechazados), idReserva,],
            );
            await connection.commit();
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
        }
    }

    async decidirSinConductor(idPersona: number, idReserva: number, dto: DecisionSinConductorDTO) {
        const connection = await this.database.getConnection();

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
            await connection.query(
                `UPDATE reserva SET decisionSinConductor = ? 
                WHERE idReserva = ?`, [dto.decision, idReserva],
            );
            await connection.commit();
            return {
                mensaje: dto.decision === 'Esperar'
                    ? 'La reserva queda pendiente mientras se busca un conductor. '
                    : 'Has decidido continuar con la reserva sin conductor. ',
                idReserva,
                decisionSinConductor: dto.decision,
                estado: 'Pendiente',
            };
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }
    }

    async buscarYasignarConductor() {
        const connection = await this.database.getConnection();

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
                    WHERE c.disponibilidad = 1 AND l.estado = 'Vigente'
                    AND l.fechaExpiracion >= CURDATE() ${filtroRechazados}
                    AND NOT EXISTS ( SELECT 1
                    FROM reserva r WHERE r.idConductor = c.idConductor
                    AND r.estado IN ('Pendiente', 'Confirmada', 'EnCurso')
                    AND TIMESTAMP(r.fechaInicioServicio, r.horaInicioServicio) < TIMESTAMP(?, ?)
                    AND TIMESTAMP(r.fechaFinServicio, r.horaFinServicio) > TIMESTAMP(?, ?))
                    ORDER BY c.calificacion DESC, c.idConductor DESC LIMIT 1`,
                    [
                        ...rechazados,
                        reserva.fechaFinServicio,
                        reserva.horaFinServicio,
                        reserva.fechaInicioServicio,
                        reserva.horaInicioServicio
                    ]
                );
                if (disponibles.length === 0) {
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

            return {
                mensaje: 'Búsqueda de conductores finalizada.',
                reservasAsignadas
            };

        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }
    }

    async obtenerMisReservas(idPersona: number) {
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
            
            v.idVehiculo,
            v.placa,
            v.marca,
            v.modelo,
            v.anio,
            v.tipoVehiculo,

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
            LEFT JOIN conductor co ON co.idConductor = r.idConductor
            LEFT JOIN persona pd ON pd.idPersona = co.idPersona
            WHERE pc.idPersona = ? 
                OR pd.idPersona = ?
                OR pp.idPersona = ?
            ORDER BY r.fechaHoraReserva DESC`,
            [idPersona, idPersona, idPersona]
        );
        return {
            mensaje: 'Reservas consultadas correctamente.',
            total: reservas.length,
            reservas: reservas.map(reserva => ({
                ...reserva,
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
}



