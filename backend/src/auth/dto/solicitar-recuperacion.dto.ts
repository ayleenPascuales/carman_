import { IsEmail, MaxLength } from 'class-validator';

export class SolicitarRecuperacionDto {
  @IsEmail()
  @MaxLength(254)
  email: string;
}
