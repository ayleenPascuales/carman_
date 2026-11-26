import { Module } from '@nestjs/common';
import { ReservasController } from './reservas.controller';
import { ReservasService } from './reservas.service';
import { DatabaseModule } from '../database/database.module';
import { AuthModule } from '../auth/auth.module';
import { TareasReservasService } from './tareas-reservas/tareas-reservas.service';
import { PagosModule } from '../pagos/pagos.module';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';
import { MaintenanceReservasController } from './maintenance-reservas.controller';

@Module({
  imports: [DatabaseModule, AuthModule, PagosModule, NotificacionesModule],
  controllers: [ReservasController, MaintenanceReservasController],
  providers: [ReservasService, TareasReservasService],
  exports: [ReservasService]
})
export class ReservasModule { }
