import { IsNotEmpty, IsString, MaxLength } from "class-validator";

export class SolicitarRevisionDTO {

    @IsString()
    @IsNotEmpty()
    @MaxLength(500)
    motivoSolicitud: string;

}