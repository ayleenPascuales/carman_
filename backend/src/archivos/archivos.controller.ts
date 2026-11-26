import { Controller, Get, Param, ParseIntPipe, Req, Res, UseGuards } from '@nestjs/common';
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
        @Req() request: { user: { idPersona: number } },
        @Res() respuesta: Response,
    ) {
        const documento = await this.archivosService.obtenerPDF(idDocumento, request.user.idPersona);

        respuesta.set({
            'Content-Type': 'application/pdf',
            'Content-Disposition': `inline; filename="${documento.nombreArchivo}"`,
            'Cache-Control': 'private, no-store',
        });

        return respuesta.send(documento.contenido);
    }
}
