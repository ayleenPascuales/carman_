import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { PuntosController } from './puntos.controller';

@Module({
  imports: [DatabaseModule],
  controllers: [PuntosController],
})
export class PuntosModule {}
