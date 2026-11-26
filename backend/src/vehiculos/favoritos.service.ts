import { BadRequestException, Inject, Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import type { Pool, RowDataPacket } from 'mysql2/promise';

@Injectable()
export class FavoritosService {
  constructor(@Inject('DATABASE_CONNECTION') private readonly database: Pool) {}

  private unavailable(error: unknown): never {
    if (error && typeof error === 'object' && 'code' in error &&
        (error as { code?: string }).code === 'ER_NO_SUCH_TABLE') {
      throw new ServiceUnavailableException(
        'Los favoritos sincronizados todavía no están habilitados.',
      );
    }
    throw error;
  }

  async listar(idPersona: number, paginaRaw?: string) {
    if (paginaRaw !== undefined && !/^[1-9]\d{0,3}$/.test(paginaRaw)) {
      throw new BadRequestException('La página debe estar entre 1 y 9999.');
    }
    const pagina = paginaRaw === undefined ? 1 : Number(paginaRaw);
    try {
      const [filas] = await this.database.query<RowDataPacket[]>(
        `SELECT idVehiculo FROM favorito WHERE idPersona = ?
         ORDER BY fechaHoraRegistro DESC, idVehiculo DESC
         LIMIT 21 OFFSET ${(pagina - 1) * 20}`,
        [idPersona],
      );
      return { pagina, hayMas: filas.length > 20,
        ids: filas.slice(0, 20).map((fila) => Number(fila.idVehiculo)) };
    } catch (error) {
      this.unavailable(error);
    }
  }

  async guardar(idPersona: number, idVehiculo: number) {
    const [vehiculos] = await this.database.query<RowDataPacket[]>(
      `SELECT v.idVehiculo FROM vehiculo v
       JOIN punto_autorizado p ON p.idPunto = v.idPuntoRecogida
       WHERE v.idVehiculo = ? AND v.estado = 'Activo'
       AND v.precioPorDia > 0 AND p.activo = 1 LIMIT 1`, [idVehiculo],
    );
    if (!vehiculos.length) throw new NotFoundException('Vehículo no disponible.');
    try {
      await this.database.query(
        `INSERT INTO favorito (idPersona, idVehiculo) VALUES (?, ?)
         ON DUPLICATE KEY UPDATE idVehiculo = VALUES(idVehiculo)`,
        [idPersona, idVehiculo],
      );
      return { idVehiculo, guardado: true };
    } catch (error) {
      this.unavailable(error);
    }
  }

  async eliminar(idPersona: number, idVehiculo: number) {
    try {
      await this.database.query(
        'DELETE FROM favorito WHERE idPersona = ? AND idVehiculo = ?',
        [idPersona, idVehiculo],
      );
      return { idVehiculo, guardado: false };
    } catch (error) {
      this.unavailable(error);
    }
  }
}
