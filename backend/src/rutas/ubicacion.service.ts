import {
  BadRequestException, ForbiddenException, Inject, Injectable, NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Pool, RowDataPacket } from 'mysql2/promise';
import { CompartirUbicacionDto } from './dto/compartir-ubicacion.dto';

@Injectable()
export class UbicacionService {
  constructor(
    @Inject('DATABASE_CONNECTION') private readonly database: Pool,
    private readonly config: ConfigService,
  ) {}

  private get habilitada() {
    // Solo habilitar tras aplicar de forma controlada la migración optativa.
    return this.config.get<string>('TRIP_LOCATION_ENABLED') === 'true';
  }

  private async participante(idPersona: number, idReserva: number) {
    if (!Number.isSafeInteger(idReserva) || idReserva <= 0) {
      throw new BadRequestException('Reserva inválida.');
    }
    const [rows] = await this.database.execute<RowDataPacket[]>(
      `SELECT r.estado, pc.idPersona AS cliente, pd.idPersona AS conductor,
              pc.fechaNacimiento <= DATE_SUB(CURDATE(), INTERVAL 18 YEAR) AS clienteAdulto,
              pd.fechaNacimiento <= DATE_SUB(CURDATE(), INTERVAL 18 YEAR) AS conductorAdulto
       FROM reserva r JOIN cliente c ON c.idCliente = r.idCliente
       JOIN persona pc ON pc.idPersona = c.idPersona
       LEFT JOIN conductor d ON d.idConductor = r.idConductor
       LEFT JOIN persona pd ON pd.idPersona = d.idPersona
       WHERE r.idReserva = ?`,
      [idReserva],
    );
    if (!rows.length) throw new NotFoundException('La reserva no existe.');
    if (![rows[0].cliente, rows[0].conductor].some(id => Number(id) === idPersona)) {
      // El propietario ve el recorrido previsto, pero no la posición precisa.
      throw new ForbiddenException('Solo cliente y conductor pueden consultar esta ubicación.');
    }
    // No habilitar el intercambio de ubicación precisa de menores.
    if (Number(rows[0].clienteAdulto) !== 1 ||
        (rows[0].conductor !== null && Number(rows[0].conductorAdulto) !== 1)) {
      throw new ForbiddenException('El seguimiento preciso no está disponible para esta reserva.');
    }
    return rows[0];
  }

  async consultar(idPersona: number, idReserva: number) {
    const reserva = await this.participante(idPersona, idReserva);
    if (!this.habilitada) {
      return { disponible: false, compartiendo: false, posiciones: [] };
    }
    // Eliminar posiciones caducadas y las de viajes finalizados/cancelados.
    // No se devuelve información anterior a dos minutos.
    await this.database.execute(
      `DELETE FROM ubicacion_compartida
       WHERE compartidaEn < NOW() - INTERVAL 2 MINUTE
       OR idReserva IN (SELECT idReserva FROM reserva WHERE estado <> 'EnCurso')`,
    );
    if (reserva.estado !== 'EnCurso') {
      return { disponible: true, compartiendo: false, posiciones: [] };
    }
    const [rows] = await this.database.execute<RowDataPacket[]>(
      `SELECT idPersona, latitud, longitud, compartidaEn
       FROM ubicacion_compartida WHERE idReserva = ?
       AND idPersona IN (?, ?) AND compartidaEn >= NOW() - INTERVAL 2 MINUTE`,
      [idReserva, Number(reserva.cliente), Number(reserva.conductor) || -1],
    );
    return {
      disponible: true,
      compartiendo: rows.some(row => Number(row.idPersona) === idPersona),
      posiciones: rows.map(row => ({
        rol: Number(row.idPersona) === Number(reserva.cliente) ? 'Cliente' : 'Conductor',
        latitud: Number(row.latitud), longitud: Number(row.longitud),
        compartidaEn: row.compartidaEn,
      })),
    };
  }

  async compartir(idPersona: number, idReserva: number, dto: CompartirUbicacionDto) {
    const reserva = await this.participante(idPersona, idReserva);
    if (!this.habilitada) {
      throw new ServiceUnavailableException('El seguimiento voluntario aún no está habilitado.');
    }
    if (reserva.estado !== 'EnCurso') {
      throw new ForbiddenException('Solo puedes compartir ubicación durante un viaje en curso.');
    }
    if (dto.consentimiento !== true ||
        typeof dto.latitud !== 'number' || typeof dto.longitud !== 'number' ||
        !Number.isFinite(dto.latitud) || !Number.isFinite(dto.longitud) ||
        Math.abs(dto.latitud) > 90 || Math.abs(dto.longitud) > 180) {
      throw new BadRequestException('Ubicación o consentimiento inválidos.');
    }
    await this.database.execute(
      `INSERT INTO ubicacion_compartida (idReserva, idPersona, latitud, longitud, compartidaEn)
       VALUES (?, ?, ?, ?, NOW()) ON DUPLICATE KEY UPDATE
       latitud = VALUES(latitud), longitud = VALUES(longitud), compartidaEn = NOW()`,
      [idReserva, idPersona, dto.latitud, dto.longitud],
    );
    return { compartiendo: true, caducaEnSegundos: 120 };
  }

  async detener(idPersona: number, idReserva: number) {
    // Permitir detener incluso si el viaje terminó o el conductor cambió.
    if (!Number.isSafeInteger(idReserva) || idReserva <= 0) {
      throw new BadRequestException('Reserva inválida.');
    }
    if (this.habilitada) {
      await this.database.execute(
        'DELETE FROM ubicacion_compartida WHERE idReserva = ? AND idPersona = ?',
        [idReserva, idPersona],
      );
    }
    return { compartiendo: false };
  }
}
