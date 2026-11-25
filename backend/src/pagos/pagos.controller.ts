import { Controller, Post, Param, ParseIntPipe, UseGuards, Req, Body, BadRequestException, HttpCode, HttpStatus } from '@nestjs/common';
import { PagosService } from './pagos.service';
import { AuthGuard } from '../auth/auth.guard';
import { WompiService } from './wompi.service';
import type { EventoWompi } from './wompi.service';

interface SolicitudAutenticada {
    user: {
        idPersona: number;
    };
}

@Controller('pagos')
export class PagosController {
    constructor(private readonly pagosService: PagosService,
        private readonly wompiService: WompiService,
    ) { }

    @UseGuards(AuthGuard)
    @Post('reservas/:idReserva/orden')
    generarOrdenPago(@Req() request: any, @Param('idReserva', ParseIntPipe) idReserva: number) {
        return this.pagosService.generarOrdenPago(request.user.idPersona, idReserva);
    }

    @UseGuards(AuthGuard)
    @Post('ordenes/:idOrdenPago/checkout')
    iniciarCheckout(@Req() request: SolicitudAutenticada, @Param('idOrdenPago', ParseIntPipe) idOrdenPago: number,) {
        return this.pagosService.iniciarPago(request.user.idPersona, idOrdenPago,);
    }

    @HttpCode(HttpStatus.OK)
    @Post('wompi/eventos')
    async recibirEventoWompi(@Body() evento: EventoWompi) {
        const firmaValida = this.wompiService.validarFirmaEvento(evento);

        if (!firmaValida) {
            throw new BadRequestException('Firma del evento inválida.');
        }

        return this.pagosService.procesarEventoWompi(evento);
    }


}
