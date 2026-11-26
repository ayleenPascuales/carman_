import { Body, Controller, Get, Param, ParseIntPipe, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard';
import { CrearCalificacionDto } from './dto/crearCalificacion.dto';
import { CalificacionesService } from './calificaciones.service';

@Controller('calificaciones')
export class CalificacionesController {
  constructor(private readonly calificaciones: CalificacionesService) { }

  @UseGuards(AuthGuard)
  @Post('reservas/:idReserva')
  crearCalificacion(
    @Req() request: { user: { idPersona: number } },
    @Param('idReserva', ParseIntPipe) idReserva: number,
    @Body() dto: CrearCalificacionDto,
  ) {
    return this.calificaciones.crearCalificacion(request.user.idPersona, idReserva, dto);
  }

  @Get('vehiculo/:idVehiculo')
  consultarVehiculo(@Param('idVehiculo', ParseIntPipe) idVehiculo: number) {
    return this.calificaciones.consultarCalificacionesVehiculo(idVehiculo);
  }

  @Get('conductores/:idConductor')
  consultarConductor(@Param('idConductor', ParseIntPipe) idConductor: number) {
    return this.calificaciones.consultarCalificacionesConductor(idConductor);
  }
}
