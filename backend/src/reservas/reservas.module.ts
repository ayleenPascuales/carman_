import { Module } from '@nestjs/common';
import { ReservasController } from './reservas.controller';
import { ReservasService } from './reservas.service';
import { DatabaseModule } from '../database/database.module';
import { AuthModule } from '../auth/auth.module';
import { TareasReservasService } from './tareas-reservas/tareas-reservas.service';
import { PagosModule } from '../pagos/pagos.module';

@Module({
  imports: [DatabaseModule, AuthModule, PagosModule],
  controllers: [ReservasController],
  providers: [ReservasService, TareasReservasService],
  exports: [ReservasService]
})
export class ReservasModule { }
