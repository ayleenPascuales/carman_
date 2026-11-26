import { Controller, Get, Query, UseGuards, Param, Patch, Body, Req } from "@nestjs/common";
import { AdminService } from './admin.service';
import { AuthGuard } from "../auth/auth.guard";
import { AdminGuard } from "../auth/admin.guard";
import { ResultadoRevisionDTO } from "./dto/resultadoRevision.dto";
import { RechazarRevisionDTO } from "./dto/rechazarRevision.dto";
import { PositiveIdPipe } from "../common/positive-id.pipe";

@Controller('admin')
@UseGuards(AuthGuard, AdminGuard)
export class AdminController {
    constructor(private readonly adminService: AdminService) { }

    @Get('resumen')
    obtenerResumen() {
        return this.adminService.obtenerResumen();
    }

    @Get('usuarios')
    obtenerUsuarios(
        @Query('rol') rol?: string,
        @Query('buscar') buscar?: string,
        @Query('estado') estado?: string,
        @Query('pagina') pagina?: string) {
        return this.adminService.obtenerUsuarios(rol, buscar, estado, pagina);
    }

    @Get('usuarios/:idPersona')
    obtenerPerfilUsuario(@Param('idPersona', PositiveIdPipe) idPersona: number) {
        return this.adminService.obtenerPerfil(idPersona);
    }

    @Patch('usuarios/:idPersona/suspender')
    suspenderUsuario(@Req() request: any, @Param('idPersona', PositiveIdPipe) idPersona: number) {
        return this.adminService.suspenderUsuario(idPersona, request.user.idPersona);
    }

    @Patch('usuarios/:idPersona/reactivar')
    reactivarUsuario(@Param('idPersona', PositiveIdPipe) idPersona: number) {
        return this.adminService.reactivarUsuario(idPersona);
    }

    @Get('revisiones')
    obtenerSolicitudesRevision(@Query('estado') estado?: string, @Query('pagina') pagina?: string) {
        return this.adminService.obtenerSolicitudesRevision(estado, pagina);
    }

    @Get('revisiones/:idVehiculo')
    obtenerRevision(@Param('idVehiculo', PositiveIdPipe) idVehiculo: number) {
        return this.adminService.obtenerRevision(idVehiculo);
    }

    @Patch('revisiones/:idVehiculo/aceptar')
    aceptarSolicitudRevision(@Param('idVehiculo', PositiveIdPipe) idVehiculo: number) {
        return this.adminService.aceptarSolicitudRevision(idVehiculo);
    }

    @Patch('revisiones/:idVehiculo/rechazar')
    rechazarSolicitudRevision(@Param('idVehiculo', PositiveIdPipe) idVehiculo: number, @Body() dto: RechazarRevisionDTO) {
        return this.adminService.rechazarSolicitudRevision(idVehiculo, dto);
    }

    @Patch('revisiones/:idVehiculo/finalizar')
    resultadoRevision(@Param('idVehiculo', PositiveIdPipe) idVehiculo: number, @Body() dto: ResultadoRevisionDTO) {
        return this.adminService.resultadoRevision(idVehiculo, dto);
    }

}
