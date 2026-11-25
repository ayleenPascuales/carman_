import { IsBoolean, IsNotEmpty, IsNumber, IsOptional, IsString, MaxLength, Min, } from "class-validator";

export class CrearEstadoTecnicoVehiculoDto {

    @IsString()
    @IsNotEmpty()
    @MaxLength(20)
    placa: string;

    @IsNumber()
    @Min(0)
    kilometraje: number;

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    estadoMotor: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    estadoFrenos: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    estadoLlantas: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    estadoBateria: string;

    @IsOptional()
    @IsString()
    @MaxLength(200)
    observaciones?: string;

    @IsBoolean()
    necesitaMantenimiento: boolean;

}