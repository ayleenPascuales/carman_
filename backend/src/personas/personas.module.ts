import { Module } from '@nestjs/common';
import { PersonasController } from './personas.controller';
import { PersonasService } from './personas.service';
import { DatabaseModule } from '../database/database.module';
import { AuthModule } from '../auth/auth.module';
import { ReservasModule } from '../reservas/reservas.module';

@Module({
  imports: [DatabaseModule, AuthModule, ReservasModule],
  controllers: [PersonasController],
  providers: [PersonasService]
})
export class PersonasModule { }
