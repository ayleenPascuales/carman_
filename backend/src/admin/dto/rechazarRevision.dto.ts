import { IsNotEmpty, IsString, MaxLength } from "class-validator";

export class RechazarRevisionDTO {

    @IsString()
    @IsNotEmpty({ message: 'debes indicar el motivo del rechazo. ' })
    @MaxLength(500)
    motivoRechazo: string;
}