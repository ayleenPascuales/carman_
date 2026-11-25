import { IsIn } from "class-validator";

export class CambiarEstadoVehiculoDTO {

    @IsIn(['Activo', 'inactivo'])
    estado: string;
}