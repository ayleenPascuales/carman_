import { Controller, Get, Post, Put, Body, Patch, Param, ParseIntPipe, UseGuards, Req } from '@nestjs/common';
import { PersonasService } from './personas.service';
import { RegistroInicialDto } from './dto/registroInicial.dto';
import { AgregarRolDto } from './dto/agregarRol.dto';
import { CrearLicenciaDto } from './dto/crearLicencia.dto';
import { AuthGuard } from '../auth/auth.guard';
import { ActualizarPersonaDto } from './dto/actualizarPersona.dto';
import { ActualizarConductorDto } from './dto/actualizarConductor.dto';
import { AllowUnverified } from '../auth/allow-unverified.decorator';


@Controller('personas')
export class PersonasController {
    constructor(
        private readonly personasService: PersonasService,
    ) { }

    @Post('registro')
    registroInicial(@Body() dto: RegistroInicialDto) {
        return this.personasService.registroInicial(dto);
    }

    @UseGuards(AuthGuard)
    @Post('roles')
    agregarRol(@Req() request: any, @Body() dto: AgregarRolDto,) {
        return this.personasService.agregarRol(request.user.idPersona, dto);
    }

    @UseGuards(AuthGuard)
    @Post('licencia')
    crearLicencia(@Req() request: any, @Body() dto: CrearLicenciaDto,) {
        return this.personasService.crearLicencia(request.user.idPersona, dto);
    }

    @UseGuards(AuthGuard)
    @Put('licencia')
    actualizarLicencia(@Req() request: any, @Body() dto: CrearLicenciaDto,) {
        return this.personasService.actualizarLicencia(request.user.idPersona, dto);
    }

    @UseGuards(AuthGuard)
    @AllowUnverified()
    @Get('perfil')
    obtenerPerfil(@Req() request: any) {
        return this.personasService.obtenerPerfil(request.user.idPersona);
    }

    @UseGuards(AuthGuard)
    @Patch('perfil')
    actualizarPersona(@Req() request: any, @Body() dto: ActualizarPersonaDto) {
        return this.personasService.actualizarPersona(request.user.idPersona, dto);
    }

    @UseGuards(AuthGuard)
    @Patch('conductor/disponibilidad')
    actualizarDisponibilidad(@Req() request: any, @Body() dto: ActualizarConductorDto) {
        return this.personasService.actualizarDisponibilidadConductor(
            request.user.idPersona, dto
        );
    }
}
