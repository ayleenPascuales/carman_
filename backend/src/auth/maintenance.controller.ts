import { Controller, ForbiddenException, Get, Headers } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { timingSafeEqual } from 'node:crypto';
import { AuthService } from './auth.service';

@Controller('internal')
export class MaintenanceController {
  constructor(
    private readonly authService: AuthService,
    private readonly config: ConfigService,
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
    return { status: 'ok' };
  }
}
