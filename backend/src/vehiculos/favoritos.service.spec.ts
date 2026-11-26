import { BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import type { Pool } from 'mysql2/promise';
import { FavoritosService } from './favoritos.service';

describe('FavoritosService', () => {
  const query = jest.fn();
  const service = new FavoritosService({ query } as unknown as Pool);

  beforeEach(() => query.mockReset());

  it('valida las páginas sin interpolar texto del usuario', async () => {
    await expect(service.listar(2, '1 OR 1=1')).rejects.toBeInstanceOf(BadRequestException);
    expect(query).not.toHaveBeenCalled();
  });

  it('informa que falta habilitar el esquema en vez de fingir favoritos vacíos', async () => {
    query.mockRejectedValueOnce({ code: 'ER_NO_SUCH_TABLE' });
    await expect(service.listar(2)).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('filtra la lista exclusivamente por la identidad autenticada', async () => {
    query.mockResolvedValueOnce([[{ idVehiculo: 17 }]]);
    await expect(service.listar(42)).resolves.toEqual({
      pagina: 1, hayMas: false, ids: [17],
    });
    expect(query.mock.calls[0][1]).toEqual([42]);
  });
});
