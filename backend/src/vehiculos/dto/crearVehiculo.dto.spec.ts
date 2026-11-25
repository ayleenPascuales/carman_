import { validate } from 'class-validator';
import { CrearVehiculoDto } from './crearVehiculo.dto';

describe('CrearVehiculoDto / precioPorDia DECIMAL(10,2)', () => {
  function vehiculo(precioPorDia?: number): CrearVehiculoDto {
    return Object.assign(new CrearVehiculoDto(), {
      placa: 'PRB123', marca: 'Marca de prueba', modelo: 'Modelo de prueba',
      anio: 2024, capacidad: 4, tipoVehiculo: 'SUV', idPuntoRecogida: 7,
      idPuntoEntrega: 8, fotos: ['https://example.com/foto.jpg'],
      tarjetaPropiedad: 'https://example.com/tarjeta.jpg', precioPorDia,
    });
  }

  it('admite NULL y dos decimales, pero rechaza valores fuera del esquema', async () => {
    expect(await validate(vehiculo())).toHaveLength(0);
    expect(await validate(vehiculo(120.5))).toHaveLength(0);
    for (const value of [0, -1, 120.123, 100000000]) {
      const errors = await validate(vehiculo(value));
      expect(errors.some((error) => error.property === 'precioPorDia')).toBe(true);
    }
  });
});
