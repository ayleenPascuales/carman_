import { Controller, ForbiddenException, Get, Headers } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { timingSafeEqual } from 'node:crypto';
import { ReservasService } from './reservas.service';

@Controller('internal')
export class MaintenanceReservasController {
  constructor(
    private readonly reservas: ReservasService,
    private readonly config: ConfigService,
  ) {}

  @Get('assign-drivers')
  async asignarConductores(@Headers('authorization') authorization?: string) {
    const secret = this.config.get<string>('CRON_SECRET');
    const received = authorization?.startsWith('Bearer ') ? authorization.slice(7) : '';
    const actual = Buffer.from(received);
    const expected = Buffer.from(secret ?? '');
    if (!secret || !received || actual.length !== expected.length ||
        !timingSafeEqual(actual, expected)) {
      throw new ForbiddenException();
    }
    const result = await this.reservas.buscarYasignarConductor();
    return { status: 'ok', asignadas: result.reservasAsignadas.length };
  }
}
