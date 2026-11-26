import { Injectable, Inject, BadRequestException, NotFoundException, ConflictException } from '@nestjs/common';
import type { Pool, RowDataPacket, ResultSetHeader } from 'mysql2/promise';
import { CrearCalificacionDto, TipoObjetivoCalificacion } from './dto/crearCalificacion.dto';

@Injectable()
export class CalificacionesService {
    constructor(
        @Inject('DATABASE_CONNECTION')
        private readonly database: Pool,) { }

    async crearCalificacion(idPersona: number, idReserva: number, dto: CrearCalificacionDto) {
        const [reservas] = await this.database.query<RowDataPacket[]>(
            `SELECT 
                r.idReserva,
                r.estado,
                r.idVehiculo,
                r.idConductor,
                r.idCliente FROM reserva r 
                INNER JOIN cliente c ON c.idCliente = r.idCliente
                WHERE r.idReserva = ? AND c.idPersona = ?`, [idReserva, idPersona],
        );
        if (reservas.length === 0) {
            throw new NotFoundException('La reserva no existe o no pertenece a tu cuenta.',);
        }

        const reserva = reservas[0];
        if (reserva.estado !== 'Finalizada') {
            throw new BadRequestException('Solo puedes calificar reservas finalizadas. ',);
        }

        let idVehiculo: number | null = null;
        let idConductor: number | null = null;
        if (dto.tipoObjetivo === TipoObjetivoCalificacion.VEHICULO) {
            idVehiculo = reserva.idVehiculo;
        } else if (dto.tipoObjetivo === TipoObjetivoCalificacion.CONDUCTOR) {
            if (reserva.idConductor === null) {
                throw new BadRequestException(
                    'No puedes calificar un conductor porque esta reserva no tuvo uno.'
                );
            }
            idConductor = reserva.idConductor;
        }

        let resultado: ResultSetHeader;

        try {
            const [insertado] = await this.database.execute<ResultSetHeader>(
                `INSERT INTO calificacion(
                idReserva,
                idCliente,
                idVehiculo,
                idConductor,
                puntuacion,
                comentario
                ) VALUES (?, ?, ?, ?, ?, ?)`,
                [
                    idReserva,
                    reserva.idCliente,
                    idVehiculo,
                    idConductor,
                    dto.puntuacion,
                    dto.comentario ?? null,
                ],
            );

            resultado = insertado;
        } catch (error) {
            if ((error as { code?: string }).code === 'ER_DUP_ENTRY') {
                throw new ConflictException(
                    'Ya has calificado este elemento para esta reserva.',
                );
            }

            throw error;
        }

        return {
            mensaje: 'Calificación registrada correctamente.',
            idCalificacion: resultado.insertId,
            idReserva,
            tipoObjetivo: dto.tipoObjetivo,
            puntuacion: dto.puntuacion,
        };
    }

    async consultarCalificacionesConductor(idConductor: number) {
        const [conductor] = await this.database.query<RowDataPacket[]>(
            `SELECT idConductor FROM conductor WHERE idConductor = ?`, [idConductor],
        );
        if (conductor.length === 0) {
            throw new NotFoundException('El conductor no existe.');
        }
        const [calificaciones] = await this.database.query<RowDataPacket[]>(
            `SELECT 
            idCalificacion,
            idReserva,
            puntuacion,
            comentario,
            fechaHoraComentario
            FROM calificacion WHERE idConductor = ?
            ORDER BY fechaHoraComentario DESC`, [idConductor],
        );
        const [promedio] = await this.database.query<RowDataPacket[]>(
            `SELECT ROUND(AVG(puntuacion), 2) AS promedio,
            COUNT(*) AS totalCalificaciones FROM calificacion
            WHERE idConductor = ?`, [idConductor],
        );
        return {
            idConductor,
            promedio: Number(promedio[0].promedio ?? 0),
            totalCalificaciones: Number(promedio[0].totalCalificaciones),
            calificaciones,
        };
    }

    async consultarCalificacionesVehiculo(idVehiculo: number) {
        const [vehiculo] = await this.database.query<RowDataPacket[]>(
            `SELECT idVehiculo FROM vehiculo WHERE idVehiculo = ?`, [idVehiculo],
        );
        if (vehiculo.length === 0) {
            throw new NotFoundException('El vehículo no existe.');
        }
        const [calificaciones] = await this.database.query<RowDataPacket[]>(
            `SELECT 
            idCalificacion,
            idReserva,
            puntuacion,
            comentario,
            fechaHoraComentario
            FROM calificacion WHERE idVehiculo = ?
            ORDER BY fechaHoraComentario DESC`, [idVehiculo],
        );
        const [promedio] = await this.database.query<RowDataPacket[]>(
            `SELECT ROUND(AVG(puntuacion), 2) AS promedio,
            COUNT(*) AS totalCalificaciones FROM calificacion
            WHERE idVehiculo = ?`, [idVehiculo],
        );
        return {
            idVehiculo,
            promedio: Number(promedio[0].promedio ?? 0),
            totalCalificaciones: Number(promedio[0].totalCalificaciones),
            calificaciones,
        };
    }

}
