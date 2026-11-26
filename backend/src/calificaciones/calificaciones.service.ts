import { BadRequestException, ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import type { Pool, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { CrearCalificacionDto, TipoObjetivoCalificacion } from './dto/crearCalificacion.dto';

@Injectable()
export class CalificacionesService {
  constructor(@Inject('DATABASE_CONNECTION') private readonly db: Pool) { }

  async crearCalificacion(idPersona: number, idReserva: number, dto: CrearCalificacionDto) {
    const connection = await this.db.getConnection();
    try {
    await connection.beginTransaction();
    const [reservas] = await connection.query<RowDataPacket[]>(
      `SELECT r.idReserva, r.estado, r.idCliente, r.idVehiculo, r.idConductor
       FROM reserva r INNER JOIN cliente c ON c.idCliente = r.idCliente
       WHERE r.idReserva = ? AND c.idPersona = ? FOR UPDATE`,
      [idReserva, idPersona],
    );
    if (reservas.length === 0) {
      throw new NotFoundException('La reserva no existe o no pertenece a tu cuenta.');
    }
    const reserva = reservas[0];
    if (reserva.estado !== 'Finalizada') {
      throw new BadRequestException('Solo puedes calificar reservas finalizadas.');
    }

    const esVehiculo = dto.tipoObjetivo === TipoObjetivoCalificacion.VEHICULO;
    if (!esVehiculo && !reserva.idConductor) {
      throw new BadRequestException('Esta reserva no tuvo un conductor asignado.');
    }

      const [resultado] = await connection.execute<ResultSetHeader>(
        `INSERT INTO calificacion
         (idReserva, idCliente, idVehiculo, idConductor, puntuacion, comentario)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          idReserva, reserva.idCliente,
          esVehiculo ? reserva.idVehiculo : null,
          esVehiculo ? null : reserva.idConductor,
          dto.puntuacion, dto.comentario?.trim() || null,
        ],
      );
      if (!esVehiculo) {
        await connection.execute(
          `UPDATE conductor SET calificacion = (
             SELECT ROUND(AVG(puntuacion), 2) FROM calificacion WHERE idConductor = ?
           ) WHERE idConductor = ?`,
          [reserva.idConductor, reserva.idConductor],
        );
      }
      await connection.commit();
      return {
        mensaje: 'Calificación registrada.',
        idCalificacion: resultado.insertId,
        idReserva,
        tipoObjetivo: dto.tipoObjetivo,
        puntuacion: dto.puntuacion,
      };
    } catch (error) {
      await connection.rollback();
      if ((error as { code?: string }).code === 'ER_DUP_ENTRY') {
        throw new ConflictException('Ya calificaste ese elemento en esta reserva.');
      }
      throw error;
    } finally {
      connection.release();
    }
  }

  async consultarCalificacionesVehiculo(idVehiculo: number) {
    const [vehiculos] = await this.db.query<RowDataPacket[]>(
      'SELECT idVehiculo FROM vehiculo WHERE idVehiculo = ?',
      [idVehiculo],
    );
    if (!vehiculos.length) throw new NotFoundException('El vehículo no existe.');
    return this.resumen('idVehiculo', idVehiculo);
  }

  async consultarCalificacionesConductor(idConductor: number) {
    const [conductores] = await this.db.query<RowDataPacket[]>(
      'SELECT idConductor FROM conductor WHERE idConductor = ?',
      [idConductor],
    );
    if (!conductores.length) throw new NotFoundException('El conductor no existe.');
    return this.resumen('idConductor', idConductor);
  }

  private async resumen(campo: 'idVehiculo' | 'idConductor', id: number) {
    const [totales] = await this.db.query<RowDataPacket[]>(
      `SELECT ROUND(AVG(puntuacion), 2) AS promedio, COUNT(*) AS totalCalificaciones
       FROM calificacion WHERE ${campo} = ?`,
      [id],
    );
    const [calificaciones] = await this.db.query<RowDataPacket[]>(
      `SELECT puntuacion FROM calificacion
       WHERE ${campo} = ? ORDER BY fechaHoraComentario DESC, idCalificacion DESC LIMIT 50`,
      [id],
    );
    // Una reseña sin moderación no debe publicar identidades, IDs de reserva,
    // trayectos ni texto libre que pueda incluir datos personales.
    return {
      [campo]: id,
      promedio: Number(totales[0]?.promedio ?? 0),
      totalCalificaciones: Number(totales[0]?.totalCalificaciones ?? 0),
      calificaciones,
    };
  }
}
