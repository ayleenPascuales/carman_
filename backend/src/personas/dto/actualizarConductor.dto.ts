import { IsBoolean } from "class-validator";

export class ActualizarConductorDto {

    @IsBoolean()
    disponibilidad: boolean;

}