import { IsObject, IsOptional, ValidateNested } from "class-validator";
import { Type } from 'class-transformer';
import { CrearLicenciaDto } from "./crearLicencia.dto";


export class AgregarRolDto {

    @IsObject()
    @IsOptional()
    @ValidateNested()
    @Type(() => CrearLicenciaDto)
    licencia?: CrearLicenciaDto;

}