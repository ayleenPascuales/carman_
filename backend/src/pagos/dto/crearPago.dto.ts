import { IsInt, IsNumber, IsEnum, Min } from "class-validator";

export enum TipoPago {
    ANTICIPO = 'Anticipo',
    RESTANTE = 'Restante',
    COMPLETO = 'Completo'
}

export class CrearPagoDto {

    @IsInt()
    @Min(1)
    idMetodoPago: number;

    @IsEnum(TipoPago)
    tipoPago: TipoPago;

}