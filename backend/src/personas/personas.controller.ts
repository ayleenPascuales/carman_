import { Controller, Get, Post, Put, Body, Param, ParseIntPipe, UseGuards, Req } from '@nestjs/common';
import { PersonasService } from './personas.service';
import { RegistroInicialDto } from './dto/registroInicial.dto';
import { AgregarRolDto } from './dto/agregarRol.dto';
import { CrearLicenciaDto } from './dto/crearLicencia.dto';
import { AuthGuard } from '../auth/auth.guard';


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
    @Get('perfil')
    obtenerPerfil(@Req() request: any) {
        return this.personasService.obtenerPerfil(request.user.idPersona);
    }
}
