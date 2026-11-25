import { IsDateString, IsNotEmpty, IsString, IsUrl, MaxLength } from "class-validator";

export class CrearLicenciaDto {

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    numeroDocumento: string;

    @IsNotEmpty()
    @IsDateString()
    fechaExpiracion: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    tipoLicencia: string;

    @IsUrl()
    @IsNotEmpty()
    @MaxLength(500)
    fotoLicencia: string;

}