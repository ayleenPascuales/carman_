import { Controller, Get, Inject } from '@nestjs/common';
import type { Pool } from 'mysql2/promise';

// Tablas históricas del export TiDB; el código solo accede a las que usa.
// Este diagnóstico es de solo lectura y solo verifica acceso a cada tabla.
const TABLAS_ESPERADAS = [
  'administrador', 'calificacion', 'cliente', 'conductor', 'contrato_alquiler',
  'documento', 'estado_tecnico_vehiculo', 'licencia', 'metodo_pago',
  'notificacion', 'orden_de_pago', 'pago', 'persona', 'phone_verification',
  'propietario', 'punto_autorizado', 'reserva', 'ruta', 'telemetria',
  'vehiculo',
];

@Controller('health')
export class HealthController {
  constructor(@Inject('DATABASE_CONNECTION') private readonly database: Pool) {}

  @Get()
  async check() {
    await this.database.query('SELECT 1');
    return { status: 'ok', database: 'ok' };
  }

  @Get('tablas')
  async tablas() {
    // Solo comprobamos accesibilidad con SHOW COLUMNS; así evitamos depender
    // de que cada tabla tenga filas y seguimos sin consultar ningún dato.
    const resultado: { tabla: string; accesible: boolean; detalle?: string }[] = [];
    for (const tabla of TABLAS_ESPERADAS) {
      try {
        const [rows] = await this.database.query(
          `SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?`,
          [process.env.DB_NAME, tabla],
        );
        if ((rows as Array<Record<string, unknown>>).length === 0) {
          resultado.push({ tabla, accesible: false, detalle: 'no_existe' });
        } else {
          resultado.push({ tabla, accesible: true });
        }
      } catch (error) {
        const codigo = error && typeof error === 'object' && 'code' in error
          ? String((error as { code?: string }).code ?? '') : '';
        // Solo devolvemos el código; nunca incluimos datos ni credenciales.
        resultado.push({ tabla, accesible: false, detalle: codigo || 'error' });
      }
    }
    return { tablas: resultado, total: resultado.length };
  }
}
