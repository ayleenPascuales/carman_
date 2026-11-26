import { Controller, ForbiddenException, Get, Headers, Inject } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { timingSafeEqual } from 'node:crypto';
import type { Pool } from 'mysql2/promise';
import { AuthService } from './auth.service';

@Controller('internal')
export class MaintenanceController {
  constructor(
    private readonly authService: AuthService,
    private readonly config: ConfigService,
    @Inject('DATABASE_CONNECTION') private readonly database: Pool,
  ) {}

  @Get('inactive-accounts')
  async updateInactiveAccounts(@Headers('authorization') authorization?: string) {
    const secret = this.config.get<string>('CRON_SECRET');
    const received = authorization?.startsWith('Bearer ') ? authorization.slice(7) : '';
    const actual = Buffer.from(received);
    const expected = Buffer.from(secret ?? '');
    if (!secret || !received || actual.length !== expected.length ||
        !timingSafeEqual(actual, expected)) {
      throw new ForbiddenException();
    }
    await this.authService.actualizarCuentasInactivas();
    if (this.config.get<string>('TRIP_LOCATION_ENABLED') === 'true') {
      await this.database.execute(
        `DELETE FROM ubicacion_compartida
         WHERE compartidaEn < NOW() - INTERVAL 2 MINUTE
         OR idReserva IN (SELECT idReserva FROM reserva WHERE estado <> 'EnCurso')`,
      );
    }
    return { status: 'ok' };
  }
}
