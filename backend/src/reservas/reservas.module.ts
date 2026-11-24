import { Module } from '@nestjs/common';
import { ReservasController } from './reservas.controller';
import { ReservasService } from './reservas.service';
import { DatabaseModule } from '../database/database.module';
import { AuthModule } from '../auth/auth.module';
import { TareasReservasService } from './tareas-reservas/tareas-reservas.service';

@Module({
  imports: [DatabaseModule, AuthModule],
  controllers: [ReservasController],
  providers: [ReservasService, TareasReservasService],
  exports: [ReservasService]
})
export class ReservasModule { }
