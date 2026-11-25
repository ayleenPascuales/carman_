import { Controller, Get, Query, UseGuards, Param, ParseIntPipe, Patch, Body } from "@nestjs/common";
import { AdminService } from './admin.service';
import { AuthGuard } from "../auth/auth.guard";
import { AdminGuard } from "../auth/admin.guard";
import { ResultadoRevisionDTO } from "./dto/resultadoRevision.dto";
import { RechazarRevisionDTO } from "./dto/rechazarRevision.dto";

@Controller('admin')
@UseGuards(AuthGuard, AdminGuard)
export class AdminController {
    constructor(private readonly adminService: AdminService) { }

    @Get('usuarios')
    obtenerUsuarios(
        @Query('rol') rol?: string,
        @Query('buscar') buscar?: string) {
        return this.adminService.obtenerUsuarios(rol, buscar);
    }

    @Get('usuarios/:idPersona')
    obtenerPerfilUsuario(@Param('idPersona', ParseIntPipe) idPersona: number) {
        return this.adminService.obtenerPerfil(idPersona);
    }

    @Patch('usuarios/:idPersona/suspender')
    suspenderUsuario(@Param('idPersona', ParseIntPipe) idPersona: number) {
        return this.adminService.suspenderUsuario(idPersona);
    }

    @Patch('usuarios/:idPersona/reactivar')
    reactivarUsuario(@Param('idPersona', ParseIntPipe) idPersona: number) {
        return this.adminService.reactivarUsuario(idPersona);
    }

    @Get('revisiones')
    obtenerSolicitudesRevision() {
        return this.adminService.obtenerSolicitudesRevision();
    }

    @Patch('revisiones/:idVehiculo/aceptar')
    aceptarSolicitudRevision(@Param('idVehiculo', ParseIntPipe) idVehiculo: number) {
        return this.adminService.aceptarSolicitudRevision(idVehiculo);
    }

    @Patch('revisiones/:idVehiculo/rechazar')
    rechazarSolicitudRevision(@Param('idVehiculo', ParseIntPipe) idVehiculo: number, @Body() dto: RechazarRevisionDTO) {
        return this.adminService.rechazarSolicitudRevision(idVehiculo, dto);
    }

    @Patch('revisiones/:idVehiculo/finalizar')
    resultadoRevision(@Param('idVehiculo', ParseIntPipe) idVehiculo: number, @Body() dto: ResultadoRevisionDTO) {
        return this.adminService.resultadoRevision(idVehiculo, dto);
    }

}