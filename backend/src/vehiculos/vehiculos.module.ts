import { Module } from '@nestjs/common';
import { VehiculosController } from './vehiculos.controller';
import { VehiculosService } from './vehiculos.service';
import { DatabaseModule } from '../database/database.module';
import { AuthModule } from '../auth/auth.module';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';

@Module({
    imports: [DatabaseModule, AuthModule, NotificacionesModule],
  controllers: [VehiculosController],
  providers: [VehiculosService]
})
export class VehiculosModule { }
