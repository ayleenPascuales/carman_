import { IsInt, IsString, IsOptional, MaxLength, Min, Max, IsEnum, } from "class-validator";

export enum TipoObjetivoCalificacion {
    VEHICULO = 'Vehiculo',
    CONDUCTOR = 'Conductor',
}

export class CrearCalificacionDto {

    @IsEnum(TipoObjetivoCalificacion)
    tipoObjetivo: TipoObjetivoCalificacion;

    @IsInt()
    @Min(1)
    @Max(5)
    puntuacion: number;

    @IsOptional()
    @IsString()
    @MaxLength(500)
    comentario?: string;


}