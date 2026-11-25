import { IsArray, IsOptional, IsString, IsUrl, ArrayNotEmpty, MaxLength, Min, IsInt } from "class-validator";

export class ActualizarVehiculoDto {

    @IsOptional()
    @IsArray()
    @ArrayNotEmpty()
    @IsUrl({}, { each: true })
    fotos?: string[];

    @IsOptional()
    @IsString()
    @MaxLength(200)
    descripcion?: string;

    @IsOptional()
    @IsInt()
    @Min(1)
    idPuntoRecogida?: number;

    @IsOptional()
    @IsInt()
    @Min(1)
    idPuntoEntrega?: number;

}