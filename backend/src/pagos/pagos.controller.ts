import { Controller, Post, Param, ParseIntPipe, UseGuards, Req, Body, Get, BadRequestException, HttpCode, HttpStatus } from '@nestjs/common';
import { PagosService } from './pagos.service';
import { AuthGuard } from '../auth/auth.guard';
import { WompiService } from './wompi.service';
import type { EventoWompi } from './wompi.service';

interface SolicitudAutenticada {
    user: {
        idPersona: number;
    };
}

interface CrearNequiDTO {
    monto: number;
    correo: string;
    celular: string;
    acceptanceToken: string;
    personalDataToken: string;
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

    @UseGuards(AuthGuard)
    @Post('wompi/tokens')
    obtenerTokensWompi() {
        return this.wompiService.obtenerTokensAceptacion();
    }

    @UseGuards(AuthGuard)
    @Post('wompi/bancos-pse')
    obtenerBancosPSE() {
        return this.wompiService.obtenerBancosPSE();
    }

    @UseGuards(AuthGuard)
    @Post('wompi/nequi')
    crearPagoNequi(@Body() datos: CrearNequiDTO) {
        console.log('DATOS RECIBIDOS:', datos);
        return this.wompiService.crearTransaccionNequi(datos);
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
