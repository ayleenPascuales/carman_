import { PartialType } from '@nestjs/mapped-types';
import { CrearPersonaDto } from './crearPersona.dto';

export class ActualizarPersonaDto extends PartialType(CrearPersonaDto) { }