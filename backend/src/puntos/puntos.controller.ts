import { BadRequestException, Controller, Get, Inject, Query } from '@nestjs/common';
import type { Pool, RowDataPacket } from 'mysql2/promise';

@Controller('puntos-autorizados')
export class PuntosController {
  constructor(@Inject('DATABASE_CONNECTION') private readonly database: Pool) {}

  @Get()
  async listar(@Query('ciudad') ciudad?: string) {
    if (ciudad !== undefined && (typeof ciudad !== 'string' || ciudad.length > 50)) {
      throw new BadRequestException('La ciudad no es válida.');
    }
    const filtro = ciudad?.trim();
    const [puntos] = await this.database.query<RowDataPacket[]>(
      `SELECT idPunto, nombre, ciudad, direccion, latitud, longitud
       FROM punto_autorizado WHERE activo = TRUE
       ${filtro ? 'AND ciudad = ?' : ''}
       ORDER BY ciudad, nombre, idPunto`,
      filtro ? [filtro] : [],
    );
    return puntos;
  }
}
