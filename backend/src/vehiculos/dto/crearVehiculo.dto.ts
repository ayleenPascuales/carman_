import { ArrayNotEmpty, IsArray, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, IsUrl, MaxLength, Min, } from "class-validator";


export class CrearVehiculoDto {

    @IsString()
    @IsNotEmpty()
    @MaxLength(20)
    placa: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    marca: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    modelo: string;

    @IsInt()
    @Min(1900)
    anio: number;

    @IsInt()
    @Min(1)
    capacidad: number;

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    tipoVehiculo: string;

    @IsNumber({ maxDecimalPlaces: 2 })
    @Min(1)
    precioPorDia: number;

    @IsInt()
    @Min(1)
    idPuntoRecogida: number;

    @IsInt()
    @Min(1)
    idPuntoEntrega: number;

    @IsArray()
    @ArrayNotEmpty()
    @IsUrl({}, { each: true })
    fotos: string[];

    @IsOptional()
    @IsString()
    @MaxLength(200)
    descripcion?: string;

    @IsUrl()
    @IsNotEmpty()
    @MaxLength(500)
    tarjetaPropiedad: string;

}