import { IsNotEmpty, IsString, MinLength } from "class-validator";

export class LoginDto {

    @IsString()
    @IsNotEmpty()
    identificador: string;

    @IsString()
    @IsNotEmpty()
    @MinLength(8)
    contrasena: string;

}