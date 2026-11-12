import { PartialType } from "@nestjs/mapped-types";
import { CrearMetodoPagoDto } from "./crearMetodoPago.dto";

export class ActualizarMetodoPagoDto extends PartialType(CrearMetodoPagoDto) { }