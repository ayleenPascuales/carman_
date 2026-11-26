import { IsIn, IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export class CatalogoQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(50)
  ciudad?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  texto?: string;

  @IsOptional()
  @IsIn(['all', 'electric', 'suv', 'sport', 'family', 'premium'])
  categoria?: string;

  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/)
  fechaInicio?: string;

  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/)
  fechaFin?: string;

  @IsOptional()
  @Matches(/^\d{1,8}(?:\.\d{1,2})?$/)
  precioMaximo?: string;

  @IsOptional()
  @Matches(/^[1-9]\d?$/)
  plazasMinimas?: string;

  @IsOptional()
  @IsIn(['relevance', 'priceAsc', 'priceDesc'])
  orden?: string;

  @IsOptional()
  @Matches(/^[1-9]\d{0,3}$/)
  pagina?: string;
}
