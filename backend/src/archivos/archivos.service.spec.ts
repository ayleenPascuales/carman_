import { Test } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ArchivosService } from './archivos.service';

describe('ArchivosService', () => {
  const db = { execute: jest.fn(), query: jest.fn() };
  let service: ArchivosService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [
        ArchivosService,
        { provide: 'DATABASE_CONNECTION', useValue: db },
      ],
    }).compile();
    service = module.get(ArchivosService);
  });

  it('rechaza archivos sin formato PDF sin escribir en la base', async () => {
    await expect(service.guardarPDF('foto.png', 'Orden', 'orden_de_pago', 1, Buffer.from('x')))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it('guarda un PDF en documento con el identificador de origen', async () => {
    const contenido = Buffer.from('%PDF-1.4');
    db.execute.mockResolvedValue([{ insertId: 7 }]);
    await expect(service.guardarPDF('orden.pdf', 'Orden', 'orden_de_pago', 3, contenido))
      .resolves.toMatchObject({ idDocumento: 7, nombreArchivo: 'orden.pdf' });
    expect(db.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO documento'),
      ['orden.pdf', 'Orden', 'orden_de_pago', 3, contenido],
    );
  });

  it('solo descarga órdenes del cliente dueño de la reserva', async () => {
    const contenido = Buffer.from('%PDF-1.4');
    db.query.mockResolvedValueOnce([[{
      idDocumento: 7, nombreArchivo: 'orden.pdf', tipoDocumento: 'Orden_Pago', contenido,
    }]]);
    await expect(service.obtenerPDF(7, 12)).resolves.toMatchObject({ idDocumento: 7, contenido });
    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining('c.idPersona = ?'), [7, 12],
    );
    expect(db.query.mock.calls[0][0]).toContain("d.tablaOrigen = 'orden_de_pago'");
  });

  it('no revela documentos ajenos ni de otros orígenes', async () => {
    db.query.mockResolvedValueOnce([[]]);
    await expect(service.obtenerPDF(7, 13)).rejects.toBeInstanceOf(NotFoundException);
    expect(db.query).toHaveBeenCalledWith(expect.any(String), [7, 13]);
  });
});
