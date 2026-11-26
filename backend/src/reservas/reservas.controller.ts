import { Controller, Post, Body, UseGuards, Req, Param, Patch, Get, Query } from '@nestjs/common';
import { ReservasService } from './reservas.service';
import { CrearReservaDto } from './dto/crearReserva.dto';
import { AuthGuard } from '../auth/auth.guard';
import { RespuestaConductorDTO } from './dto/respuestaConductor.dto';
import { ActualizarReservaDto } from './dto/actualizarReserva.dto';
import { DecisionSinConductorDTO } from './dto/desicionSinConductor.dto';
import { PositiveIdPipe } from '../common/positive-id.pipe';

@Controller('reservas')
export class ReservasController {
    constructor(private readonly reservasService: ReservasService) { }

    @UseGuards(AuthGuard)
    @Post('vehiculo/:idVehiculo')
    crearReserva(@Req() request: any, @Param('idVehiculo', PositiveIdPipe) idVehiculo: number, @Body() dto: CrearReservaDto) {
        return this.reservasService.crearReserva(request.user.idPersona, idVehiculo, dto);
    }

    @UseGuards(AuthGuard)
    @Patch(':idReserva/respuesta-conductor')
    responderReserva(@Req() request: any, @Param('idReserva', PositiveIdPipe) idReserva: number, @Body() dto: RespuestaConductorDTO) {
        return this.reservasService.responderReserva(request.user.idPersona, idReserva, dto);
    }

    @UseGuards(AuthGuard)
    @Patch(':idReserva/decision-sin-conductor')
    decidirSinConductor(
        @Req() request: any, @Param('idReserva', PositiveIdPipe) idReserva: number,
        @Body() dto: DecisionSinConductorDTO,
    ) {
        return this.reservasService.decidirSinConductor(request.user.idPersona, idReserva, dto);
    }

    @UseGuards(AuthGuard)
    @Patch(':idReserva/iniciar')
    iniciarServicio(@Req() request: any, @Param('idReserva', PositiveIdPipe) idReserva: number) {
        return this.reservasService.transicionarServicio(request.user.idPersona, idReserva, 'iniciar');
    }

    @UseGuards(AuthGuard)
    @Patch(':idReserva/finalizar')
    finalizarServicio(@Req() request: any, @Param('idReserva', PositiveIdPipe) idReserva: number) {
        return this.reservasService.transicionarServicio(request.user.idPersona, idReserva, 'finalizar');
    }

    @UseGuards(AuthGuard)
    @Get('mis-reservas')
    obtenerMisReservas(@Req() request: any) {
        return this.reservasService.obtenerMisReservas(request.user.idPersona);
    }

    @UseGuards(AuthGuard)
    @Get('conductor/servicios')
    obtenerServiciosConductor(
        @Req() request: any, @Query('pagina') pagina?: string,
    ) {
        return this.reservasService.obtenerServiciosConductor(request.user.idPersona, pagina);
    }

    @UseGuards(AuthGuard)
    @Get(':idReserva')
    obtenerDetalle(@Req() request: any, @Param('idReserva', PositiveIdPipe) idReserva: number) {
        return this.reservasService.obtenerDetalleReserva(request.user.idPersona, idReserva);
    }

    @UseGuards(AuthGuard)
    @Patch(':idReserva')
    actualizarReserva(@Req() request: any, @Param('idReserva', PositiveIdPipe) idReserva: number, @Body() dto: ActualizarReservaDto) {
        return this.reservasService.actualizarReserva(request.user.idPersona, idReserva, dto);
    }

    @UseGuards(AuthGuard)
    @Patch(':idReserva/cancelar')
    cancelarReserva(@Req() request: any, @Param('idReserva', PositiveIdPipe) idReserva: number,) {
        return this.reservasService.cancelarReserva(request.user.idPersona, idReserva);
    }
}
