import { IsEnum, IsOptional, IsArray, ValidateNested } from "class-validator";
import { Type } from 'class-transformer';
import { CrearLicenciaDto } from "./crearLicencia.dto";
import { CrearVehiculoDto } from "../../vehiculos/dto/crearVehiculo.dto";

export enum RolAdicional {
    CLIENTE = 'Cliente',
    CONDUCTOR = 'Conductor',
    PROPIETARIO = 'Propietario',
}

export class AgregarRolDto {

    @IsEnum(RolAdicional)
    roles: RolAdicional;

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