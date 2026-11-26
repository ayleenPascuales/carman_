import { Controller, Post, Get, Param, ParseIntPipe, UseGuards, Req, Body } from '@nestjs/common';
import { CalificacionesService } from './calificaciones.service';
import { AuthGuard } from '../auth/auth.guard';
import { CrearCalificacionDto } from './dto/crearCalificacion.dto';

interface SolicitudAutenticada {
    user: {
        idPersona: number
    };
}

@Controller('calificaciones')
export class CalificacionesController {
    constructor(private readonly calificacionesService: CalificacionesService,) { }

    @UseGuards(AuthGuard)
    @Post('reservas/:idReserva')
    crearCalificacion(@Req() request: SolicitudAutenticada, @Param('idReserva', ParseIntPipe) idReserva: number, @Body() dto: CrearCalificacionDto,) {
        return this.calificacionesService.crearCalificacion(request.user.idPersona, idReserva, dto,);
    }

    @Get('conductores/:idConductor')
    consultarCalificacionesConductor(@Param('idConductor', ParseIntPipe) idConductor: number,) {
        return this.calificacionesService.consultarCalificacionesConductor(idConductor,);
    }

    @Get('vehiculo/:idVehiculo')
    consultarCalificacionesVehiculo(@Param('idVehiculo', ParseIntPipe) idVehiculo: number,) {
        return this.calificacionesService.consultarCalificacionesVehiculo(idVehiculo,);
    }

}
