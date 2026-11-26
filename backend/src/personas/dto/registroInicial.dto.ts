import { IsArray, IsDefined, IsEnum, IsObject, IsOptional, ValidateNested, } from "class-validator";
import { Type } from 'class-transformer';
import { CrearPersonaDto } from "./crearPersona.dto";
import { CrearVehiculoDto } from "../../vehiculos/dto/crearVehiculo.dto";
import { CrearLicenciaDto } from "./crearLicencia.dto";

export enum Rol {
    CLIENTE = 'Cliente',
    CONDUCTOR = 'Conductor',
    PROPIETARIO = 'Propietario',
}

export class RegistroInicialDto {
    @IsDefined()
    @IsObject()
    @ValidateNested()
    @Type(() => CrearPersonaDto)
    persona: CrearPersonaDto;

    @IsEnum(Rol)
    roles: Rol;

    @IsOptional()
    @ValidateNested()
    @Type(() => CrearLicenciaDto)
    licencia?: CrearLicenciaDto;

    @IsOptional()
    @IsArray()
    @ValidateNested({ each: true })
    @Type(() => CrearVehiculoDto)
    vehiculos?: CrearVehiculoDto[];

}
