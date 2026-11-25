import { Controller, Get, Inject } from '@nestjs/common';
import type { Pool } from 'mysql2/promise';

@Controller('health')
export class HealthController {
  constructor(@Inject('DATABASE_CONNECTION') private readonly database: Pool) {}

  @Get()
  async check() {
    await this.database.query('SELECT 1');
    return { status: 'ok', database: 'ok' };
  }
}
