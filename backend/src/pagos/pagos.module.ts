import { Module } from '@nestjs/common';
import { PagosController } from './pagos.controller';
import { WompiService } from './wompi.service';
import { PagosService } from './pagos.service';
import { DatabaseModule } from '../database/database.module';
import { ArchivosModule } from '../archivos/archivos.module';
import { AuthModule } from '../auth/auth.module';
import { NotificacionesModule } from '../notificaciones/notificaciones.module';

@Module({
  imports: [DatabaseModule, ArchivosModule, AuthModule, NotificacionesModule],
  controllers: [PagosController],
  providers: [PagosService, WompiService],
  exports: [PagosService, WompiService]
})
export class PagosModule { }
