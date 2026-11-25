import { Controller, Post, Body, UseGuards, Req, Param, Patch, Get } from '@nestjs/common';
import { ReservasService } from './reservas.service';
import { CrearReservaDto } from './dto/crearReserva.dto';
import { AuthGuard } from '../auth/auth.guard';
import { RespuestaConductorDTO } from './dto/respuestaConductor.dto';
import { ActualizarReservaDto } from './dto/actualizarReserva.dto';

@Controller('reservas')
export class ReservasController {
    constructor(private readonly reservasService: ReservasService) { }

    @UseGuards(AuthGuard)
    @Post('vehiculo/:idVehiculo')
    crearReserva(@Req() request: any, @Param('idVehiculo') idVehiculo: string, @Body() dto: CrearReservaDto) {
        return this.reservasService.crearReserva(request.user.idPersona, Number(idVehiculo), dto);
    }

    @UseGuards(AuthGuard)
    @Patch(':idReserva/respuesta-conductor')
    responderReserva(@Req() request: any, @Param('idReserva') idReserva: string, @Body() dto: RespuestaConductorDTO) {
        return this.reservasService.responderReserva(request.user.idPersona, Number(idReserva), dto);
    }

    @UseGuards(AuthGuard)
    @Get('mis-reservas')
    obtenerMisReservas(@Req() request: any) {
        return this.reservasService.obtenerMisReservas(request.user.idPersona);
    }

    @UseGuards(AuthGuard)
    @Patch(':idReserva')
    actualizarReserva(@Req() request: any, @Param('idReserva') idReserva: string, @Body() dto: ActualizarReservaDto) {
        return this.reservasService.actualizarReserva(request.user.idPersona, Number(idReserva), dto);
    }

    @UseGuards(AuthGuard)
    @Patch(':idReserva/cancelar')
    cancelarReserva(@Req() request: any, @Param('idReserva') idReserva: string,) {
        return this.reservasService.cancelarReserva(request.user.idPersona, Number(idReserva),);
    }
}
