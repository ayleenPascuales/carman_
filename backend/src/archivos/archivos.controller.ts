import { Controller, Get, Param, ParseIntPipe, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { ArchivosService } from './archivos.service';
import { AuthGuard } from '../auth/auth.guard';

@Controller('archivos')
@UseGuards(AuthGuard)
export class ArchivosController {
    constructor(
        private readonly archivosService: ArchivosService,
    ) { }

    @Get(':idDocumento')
    async obtenerPDF(
        @Param('idDocumento', ParseIntPipe) idDocumento: number,
        @Res() respuesta: Response,
    ) {
        const documento = await this.archivosService.obtenerPDF(idDocumento);

        respuesta.set({
            'Content-Type': 'application/pdf',
            'Content-Disposition': `inline; filename="${documento.nombreArchivo}"`,
        });

        return respuesta.send(documento.contenido);
    }
}