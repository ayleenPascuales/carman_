import { Controller, Get, Inject } from '@nestjs/common';
import type { Pool, RowDataPacket } from 'mysql2/promise';

@Controller('puntos-autorizados')
export class PuntosController {
  constructor(@Inject('DATABASE_CONNECTION') private readonly database: Pool) {}

  @Get()
  async listar() {
    const [puntos] = await this.database.query<RowDataPacket[]>(
      `SELECT idPunto, nombre, ciudad, direccion, latitud, longitud
       FROM punto_autorizado WHERE activo = TRUE ORDER BY ciudad, nombre`,
    );
    return puntos;
  }
}
