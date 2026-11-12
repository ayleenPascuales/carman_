import { Controller, Get, Post, Put, Body, Param, ParseIntPipe } from '@nestjs/common';
import { PersonasService } from './personas.service';
import { RegistroInicialDto } from './dto/registroInicial.dto';
import { AgregarRolDto } from './dto/agregarRol.dto';
import { CrearLicenciaDto } from './dto/crearLicencia.dto';

@Controller('personas')
export class PersonasController {
    constructor(
        private readonly personasService: PersonasService,
    ) { }

    @Post('registro')
    registroInicial(@Body() dto: RegistroInicialDto) {
        return this.personasService.registroInicial(dto);
    }

    @Post(':idPersona/roles')
    agregarRol(@Param('idPersona', ParseIntPipe) idPersona: number, @Body() dto: AgregarRolDto,) {
        return this.personasService.agregarRol(idPersona, dto);
    }

    @Post(':idPersona/licencia')
    crearLicencia(@Param('idPersona', ParseIntPipe) idPersona: number, @Body() dto: CrearLicenciaDto,) {
        return this.personasService.crearLicencia(idPersona, dto);
    }

    @Put(':idPersona/licencia')
    actualizarLicencia(@Param('idPersona', ParseIntPipe) idPersona: number, @Body() dto: CrearLicenciaDto,) {
        return this.personasService.actualizarLicencia(idPersona, dto);
    }

    @Get(':idPersona')
    obtenerPerfil(@Param('idPersona', ParseIntPipe) idPersona: number,) {
        return this.personasService.obtenerPerfil(idPersona);
    }
}
