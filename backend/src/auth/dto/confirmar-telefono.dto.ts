import { IsString, Matches } from 'class-validator';

export class ConfirmarTelefonoDto {
  @IsString()
  @Matches(/^\d{6}$/, { message: 'El código debe tener 6 dígitos.' })
  codigo: string;
}
