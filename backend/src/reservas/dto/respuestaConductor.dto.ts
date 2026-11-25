import { IsBoolean } from "class-validator";

export class RespuestaConductorDTO {

    @IsBoolean()
    aceptar: boolean;

}