import { Equals, IsNumber, Max, Min } from 'class-validator';

export class CompartirUbicacionDto {
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitud: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  longitud: number;

  // El navegador exige permiso; la API exige una acción explícita adicional.
  @Equals(true)
  consentimiento: true;
}
