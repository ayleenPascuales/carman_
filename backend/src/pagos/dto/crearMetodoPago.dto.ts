import { IsString, IsNotEmpty, IsOptional, MaxLength, IsBoolean, Max } from "class-validator";

export class CrearMetodoPagoDto {

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    nombre: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(100)
    proveedor: string;

    @IsOptional()
    @IsString()
    @MaxLength(200)
    descripcion?: string;

    @IsOptional()
    @IsBoolean()
    activo?: boolean;

}

