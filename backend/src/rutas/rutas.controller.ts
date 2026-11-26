import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard';
import { RutasService } from './rutas.service';
import { UbicacionService } from './ubicacion.service';
import { CompartirUbicacionDto } from './dto/compartir-ubicacion.dto';
import { CoordenadasCercaniaDto } from './dto/coordenadas-cercania.dto';

@Controller('rutas')
export class RutasController {
  constructor(private readonly rutas: RutasService, private readonly ubicacion: UbicacionService) {}

  @Get('vehiculos/:idVehiculo/punto-cercano')
  puntoCercano(@Param('idVehiculo', ParseIntPipe) idVehiculo: number) {
    return this.rutas.puntoCercano(idVehiculo);
  }

  @Post('vehiculos/:idVehiculo/punto-cercano')
  puntoCercanoDesdePosicion(
    @Param('idVehiculo', ParseIntPipe) idVehiculo: number,
    @Body() dto: CoordenadasCercaniaDto,
  ) {
    // No poner coordenadas precisas en la URL ni escribirlas en logs.
    return this.rutas.puntoCercano(idVehiculo, dto.latitud, dto.longitud);
  }

  @Get('reservas/:idReserva')
  @UseGuards(AuthGuard)
  rutaReserva(
    @Req() request: { user: { idPersona: number } },
    @Param('idReserva', ParseIntPipe) idReserva: number,
  ) {
    return this.rutas.rutaReserva(request.user.idPersona, idReserva);
  }

  @Get('reservas/:idReserva/ubicacion')
  @UseGuards(AuthGuard)
  consultarUbicacion(
    @Req() request: { user: { idPersona: number } },
    @Param('idReserva', ParseIntPipe) idReserva: number,
  ) {
    return this.ubicacion.consultar(request.user.idPersona, idReserva);
  }

  @Post('reservas/:idReserva/ubicacion')
  @UseGuards(AuthGuard)
  compartirUbicacion(
    @Req() request: { user: { idPersona: number } },
    @Param('idReserva', ParseIntPipe) idReserva: number,
    @Body() dto: CompartirUbicacionDto,
  ) {
    return this.ubicacion.compartir(request.user.idPersona, idReserva, dto);
  }

  @Delete('reservas/:idReserva/ubicacion')
  @UseGuards(AuthGuard)
  detenerUbicacion(
    @Req() request: { user: { idPersona: number } },
    @Param('idReserva', ParseIntPipe) idReserva: number,
  ) {
    return this.ubicacion.detener(request.user.idPersona, idReserva);
  }
}
