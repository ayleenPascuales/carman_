
import { PartialType } from '@nestjs/mapped-types';
import { CrearVehiculoDto } from './crearVehiculo.dto';

export class ActualizarVehiculoDto extends PartialType(CrearVehiculoDto) { }
