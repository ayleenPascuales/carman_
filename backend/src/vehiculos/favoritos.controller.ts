import { Controller, Delete, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard';
import { PositiveIdPipe } from '../common/positive-id.pipe';
import { FavoritosService } from './favoritos.service';

@Controller('vehiculos/favoritos')
@UseGuards(AuthGuard)
export class FavoritosController {
  constructor(private readonly favoritos: FavoritosService) {}

  @Get()
  listar(@Req() request: { user: { idPersona: number } }, @Query('pagina') pagina?: string) {
    return this.favoritos.listar(request.user.idPersona, pagina);
  }

  @Post(':idVehiculo')
  guardar(@Req() request: { user: { idPersona: number } },
    @Param('idVehiculo', PositiveIdPipe) idVehiculo: number) {
    return this.favoritos.guardar(request.user.idPersona, idVehiculo);
  }

  @Delete(':idVehiculo')
  eliminar(@Req() request: { user: { idPersona: number } },
    @Param('idVehiculo', PositiveIdPipe) idVehiculo: number) {
    return this.favoritos.eliminar(request.user.idPersona, idVehiculo);
  }
}
