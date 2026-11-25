import { IsString, MaxLength, } from "class-validator";

export class crearRutaDto {

    @IsString()
    @MaxLength(100)
    origen: string;

    @IsString()
    @MaxLength(100)
    destino: string;

}