import { BadRequestException, Injectable, PipeTransform } from '@nestjs/common';

@Injectable()
export class PositiveIdPipe implements PipeTransform<string, number> {
  transform(value: string): number {
    if (!/^[1-9]\d*$/.test(value)) {
      throw new BadRequestException('El identificador debe ser un entero positivo.');
    }
    const id = Number(value);
    if (!Number.isSafeInteger(id)) {
      throw new BadRequestException('El identificador está fuera del rango permitido.');
    }
    return id;
  }
}
