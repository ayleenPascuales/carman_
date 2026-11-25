import { IsEmail, IsDateString, IsNotEmpty, IsOptional, IsString, MaxLength, MinLength, IsUrl, Matches, } from "class-validator";

export class CrearPersonaDto {

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    documento: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(100)
    nombre: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(100)
    apellido: string;

    @IsEmail()
    @IsNotEmpty()
    @MaxLength(100)
    email: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    usuario: string;

    @IsString()
    @IsNotEmpty()
    @MinLength(8)
    contrasena: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(20)
    @Matches(/^\+[1-9]\d{7,14}$/, { message: 'El teléfono debe incluir indicativo: +573001234567.' })
    telefono: string;

    @IsNotEmpty()
    @IsDateString()
    fechaNacimiento: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    ciudad: string;

    @IsOptional()
    @IsString()
    @MaxLength(200)
    direccion?: string;

    @IsOptional()
    @IsUrl()
    @MaxLength(500)
    fotoPerfil?: string;

}
