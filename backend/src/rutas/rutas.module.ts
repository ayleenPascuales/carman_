import { Module } from '@nestjs/common';
import { RutasController } from './rutas.controller';
import { RutasService } from './rutas.service';
import { AuthModule } from '../auth/auth.module';
import { DatabaseModule } from '../database/database.module';
import { UbicacionService } from './ubicacion.service';

@Module({
  imports: [AuthModule, DatabaseModule],
  controllers: [RutasController],
  providers: [RutasService, UbicacionService],
})
export class RutasModule {}
