import { IsArray, IsOptional, IsString, IsUrl, ArrayNotEmpty, Max, MaxLength, Min, IsInt, IsNumber } from "class-validator";

export class ActualizarVehiculoDto {

    @IsOptional()
    @IsNumber({ maxDecimalPlaces: 2 })
    @Min(0.01)
    @Max(99999999.99)
    precioPorDia?: number;

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
