import { Module } from '@nestjs/common';
import { VehiculosController } from './vehiculos.controller';
import { VehiculosService } from './vehiculos.service';
import { DatabaseModule } from '../database/database.module';
import { AuthModule } from '../auth/auth.module';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';
import { FavoritosController } from './favoritos.controller';
import { FavoritosService } from './favoritos.service';

@Module({
    imports: [DatabaseModule, AuthModule, NotificacionesModule],
  controllers: [FavoritosController, VehiculosController],
  providers: [VehiculosService, FavoritosService]
})
export class VehiculosModule { }
