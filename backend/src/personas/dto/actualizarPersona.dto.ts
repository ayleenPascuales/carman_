import { OmitType, PartialType } from '@nestjs/mapped-types';
import { CrearPersonaDto } from './crearPersona.dto';

export class ActualizarPersonaDto extends PartialType(
    OmitType(CrearPersonaDto, [
        'documento',
        'email',
        'usuario',
        'contrasena'
    ] as const)) { }