import { Controller, Post, Get, Body, UseGuards, Req, Param, Patch, Query } from '@nestjs/common';
import { PositiveIdPipe } from '../common/positive-id.pipe';
import { VehiculosService } from './vehiculos.service';
import { CrearVehiculoDto } from './dto/crearVehiculo.dto';
import { AuthGuard } from '../auth/auth.guard';
import { ActualizarVehiculoDto } from './dto/actualizarVehiculo.dto';
import { CambiarEstadoVehiculoDTO } from './dto/cambiarEstadoVehiculo.dto';
import { SolicitarRevisionDTO } from './dto/solicitarRevision.dto';
import { CatalogoQueryDto } from './dto/catalogo-query.dto';

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

    @Get('catalogo')
    catalogo(@Query() query: CatalogoQueryDto) {
        return this.vehiculosService.catalogo(query);
    }

    @Get('catalogo/:idVehiculo')
    vehiculoPublico(@Param('idVehiculo', PositiveIdPipe) idVehiculo: number) {
        return this.vehiculosService.catalogo(undefined, idVehiculo);
    }

    @UseGuards(AuthGuard)
    @Get(':idVehiculo')
    obtenerVehiculo(@Req() request: any, @Param('idVehiculo', PositiveIdPipe) idVehiculo: number) {
        return this.vehiculosService.obtenerVehiculo(
            request.user.idPersona,
            idVehiculo
        );
    }

    @UseGuards(AuthGuard)
    @Patch(':idVehiculo')
    actualizarVehiculo(@Req() request: any, @Param('idVehiculo', PositiveIdPipe) idVehiculo: number, @Body() dto: ActualizarVehiculoDto) {
        return this.vehiculosService.actualizarVehiculo(
            request.user.idPersona,
            idVehiculo,
            dto
        );
    }

    @UseGuards(AuthGuard)
    @Patch(':idVehiculo/estado')
    cambiarEstadoVehiculo(@Req() request: any, @Param('idVehiculo', PositiveIdPipe) idVehiculo: number, @Body() dto: CambiarEstadoVehiculoDTO) {
        return this.vehiculosService.cambiarEstadoVehiculo(
            request.user.idPersona,
            idVehiculo,
            dto
        );
    }

    @UseGuards(AuthGuard)
    @Post(':idVehiculo/solicitar-revision')
    solicitarRevision(@Req() request: any, @Param('idVehiculo', PositiveIdPipe) idVehiculo: number, @Body() dto: SolicitarRevisionDTO) {
        return this.vehiculosService.solicitarRevision(
            request.user.idPersona,
            idVehiculo,
            dto
        );
    }

}
