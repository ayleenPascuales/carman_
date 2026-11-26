import { IsBoolean, IsIn, IsNotEmpty, IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class ResultadoRevisionDTO {

    @IsOptional()
    @IsNumber({ maxDecimalPlaces: 2 })
    @Min(0)
    kilometraje?: number;

    @IsOptional()
    @IsString()
    @MaxLength(50)
    estadoMotor?: string;

    @IsOptional()
    @IsString()
    @MaxLength(50)
    estadoFrenos?: string;

    @IsOptional()
    @IsString()
    @MaxLength(50)
    estadoLlantas?: string;

    @IsOptional()
    @IsString()
    @MaxLength(50)
    estadoBateria?: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(200)
    observaciones: string;

    @IsBoolean()
    necesitaMantenimiento: boolean;

    @IsString()
    @IsNotEmpty()
    @MaxLength(100)
    nombreTecnico: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(20)
    documentoTecnico: string;

    @IsIn(['Activo', 'inactivo'])
    estadoFinal: string;
}
