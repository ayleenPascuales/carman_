import { PartialType } from "@nestjs/mapped-types";
import { CrearReservaDto } from "./crearReserva.dto";

export class ActualizarReservaDto extends PartialType(CrearReservaDto) { }
