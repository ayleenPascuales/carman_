import { Controller, Get, Param, ParseIntPipe, Patch, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard';
import { NotificacionesService } from './notificaciones.service';

@Controller('notificaciones')
@UseGuards(AuthGuard)
export class NotificacionesController {
  constructor(private readonly notificaciones: NotificacionesService) {}

  @Get()
  listar(@Req() request: { user: { idPersona: number } }) {
    return this.notificaciones.listar(request.user.idPersona);
  }

  @Patch('leidas')
  marcarTodasLeidas(@Req() request: { user: { idPersona: number } }) {
    return this.notificaciones.marcarTodasLeidas(request.user.idPersona);
  }

  @Patch(':id/leida')
  marcarLeida(
    @Req() request: { user: { idPersona: number } },
    @Param('id', ParseIntPipe) idNotificacion: number,
  ) {
    return this.notificaciones.marcarLeida(request.user.idPersona, idNotificacion);
  }
}
