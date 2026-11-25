import { Controller, Post, Get, Body, UseGuards, Req, Param, Patch } from '@nestjs/common';
import { VehiculosService } from './vehiculos.service';
import { CrearVehiculoDto } from './dto/crearVehiculo.dto';
import { AuthGuard } from '../auth/auth.guard';
import { ActualizarVehiculoDto } from './dto/actualizarVehiculo.dto';
import { CambiarEstadoVehiculoDTO } from './dto/cambiarEstadoVehiculo.dto';
import { SolicitarRevisionDTO } from './dto/solicitarRevision.dto';

@Controller('vehiculos')
export class VehiculosController {
    constructor(private readonly vehiculosService: VehiculosService) { }

    @UseGuards(AuthGuard)
    @Post()
    crearVehiculo(@Req() request: any, @Body() dto: CrearVehiculoDto) {
        return this.vehiculosService.crearVehiculo(
            request.user.idPersona, dto
        );
    }

    @UseGuards(AuthGuard)
    @Get('mis-vehiculos')
    obtenerMisVehiculos(@Req() request: any) {
        return this.vehiculosService.obtenerMisVehiculos(
            request.user.idPersona
        )
    }

    @UseGuards(AuthGuard)
    @Get(':idVehiculo')
    obtenerVehiculo(@Req() request: any, @Param('idVehiculo') idVehiculo: string) {
        return this.vehiculosService.obtenerVehiculo(
            request.user.idPersona,
            Number(idVehiculo)
        );
    }

    @UseGuards(AuthGuard)
    @Patch(':idVehiculo')
    actualizarVehiculo(@Req() request: any, @Param('idVehiculo') idVehiculo: string, @Body() dto: ActualizarVehiculoDto) {
        return this.vehiculosService.actualizarVehiculo(
            request.user.idPersona,
            Number(idVehiculo),
            dto
        );
    }

    @UseGuards(AuthGuard)
    @Patch(':idVehiculo/estado')
    cambiarEstadoVehiculo(@Req() request: any, @Param('idVehiculo') idVehiculo: string, @Body() dto: CambiarEstadoVehiculoDTO) {
        return this.vehiculosService.cambiarEstadoVehiculo(
            request.user.idPersona,
            Number(idVehiculo),
            dto
        );
    }

    @UseGuards(AuthGuard)
    @Post(':idVehiculo/solicitar-revision')
    solicitarRevision(@Req() request: any, @Param('idVehiculo') idVehiculo: string, @Body() dto: SolicitarRevisionDTO) {
        return this.vehiculosService.solicitarRevision(
            request.user.idPersona,
            Number(idVehiculo),
            dto
        );
    }

}
