import { IsEmail, IsDateString, IsNotEmpty, IsString, MaxLength, MinLength, IsUrl, } from "class-validator";

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
    telefono: string;

    @IsNotEmpty()
    @IsDateString()
    fechaNacimiento: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(50)
    ciudad: string;

    @IsString()
    @IsNotEmpty()
    @MaxLength(200)
    direccion: string;

    @IsUrl()
    @IsNotEmpty()
    @MaxLength(500)
    fotoPerfil: string;

}