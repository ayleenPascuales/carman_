import { Module } from '@nestjs/common';
import { ArchivosController } from './archivos.controller';
import { ArchivosService } from './archivos.service';
import { DatabaseModule } from '../database/database.module';
import { AuthModule } from '../auth/auth.module';

@Module({
    imports: [DatabaseModule, AuthModule],
    controllers: [ArchivosController],
    providers: [ArchivosService],
    exports: [ArchivosService],
})
export class ArchivosModule { }