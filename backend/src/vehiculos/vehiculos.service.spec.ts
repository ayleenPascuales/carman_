import { Test, TestingModule } from '@nestjs/testing';
import { VehiculosService } from './vehiculos.service';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { NotificacionesService } from '../notificaciones/notificaciones.service';

describe('VehiculosService', () => {
  let service: VehiculosService;
  const connection = {
    beginTransaction: jest.fn(),
    execute: jest.fn(),
    query: jest.fn(),
    commit: jest.fn(),
    rollback: jest.fn(),
    release: jest.fn(),
  };
  const database = {
    query: jest.fn(),
    execute: jest.fn(),
    getConnection: jest.fn().mockResolvedValue(connection),
  };
  const vehiculo = {
    placa: 'ABC123', marca: 'Toyota', modelo: 'Corolla', anio: 2022,
    capacidad: 4, tipoVehiculo: 'Sedan', precioPorDia: 120.5,
    fotos: ['https://example.com/carro.jpg'],
    tarjetaPropiedad: 'https://example.com/tarjeta.jpg',
    idPuntoRecogida: 1, idPuntoEntrega: 2,
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    connection.query.mockResolvedValue([[]]);
    connection.execute.mockImplementation(async (sql: string, params: number[]) => {
      if (sql.includes('FROM persona WHERE')) return [[{ idPersona: 10 }]];
      if (sql.includes('FROM propietario WHERE')) return [[{ idPropietario: 4 }]];
      if (sql.includes('FROM vehiculo WHERE placa')) return [[]];
      if (sql.includes('FROM punto_autorizado')) return [[{ idPunto: params[0] }]];
      if (sql.includes('INSERT INTO vehiculo')) return [{ insertId: 18 }];
      return [[]];
    });
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        VehiculosService,
        { provide: 'DATABASE_CONNECTION', useValue: database },
        { provide: NotificacionesService, useValue: {
          avisarPersona: jest.fn().mockResolvedValue(undefined),
        } },
      ],
    }).compile();

    service = module.get<VehiculosService>(VehiculosService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('devuelve insertId de MySQL al registrar un vehículo', async () => {
    const result = await service.crearVehiculo(10, vehiculo);
    expect(result.idVehiculo).toBe(18);
    expect(connection.execute).toHaveBeenLastCalledWith(
      expect.stringContaining('INSERT INTO vehiculo'),
      expect.arrayContaining(['ABC123']),
    );
    expect(connection.execute.mock.lastCall?.[0]).not.toContain('RETURNING');
    expect(connection.execute.mock.lastCall?.[0]).toContain('precioPorDia');
    expect(connection.execute.mock.lastCall?.[1]).toContain(120.5);
    expect(connection.commit).toHaveBeenCalledTimes(1);
    expect(connection.rollback).not.toHaveBeenCalled();
    expect(connection.release).toHaveBeenCalledTimes(1);
    expect(database.query).not.toHaveBeenCalled();
  });

  it('crea el rol de propietario en la misma transacción si no existe', async () => {
    connection.execute.mockImplementation(async (sql: string, params: number[]) => {
      if (sql.includes('FROM persona WHERE')) return [[{ idPersona: 10 }]];
      if (sql.includes('FROM propietario WHERE') || sql.includes('FROM vehiculo WHERE')) return [[]];
      if (sql.includes('INSERT INTO propietario')) return [{ insertId: 4 }];
      if (sql.includes('FROM punto_autorizado')) return [[{ idPunto: params[0] }]];
      if (sql.includes('INSERT INTO vehiculo')) return [{ insertId: 18 }];
      return [[]];
    });
    await expect(service.crearVehiculo(10, vehiculo)).resolves.toMatchObject({ idVehiculo: 18 });
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO propietario'), [10],
    );
    expect(connection.execute.mock.lastCall?.[1]?.[0]).toBe(4);
    expect(connection.commit).toHaveBeenCalledTimes(1);
  });

  it('revierte la creación si el punto de recogida está inactivo', async () => {
    connection.execute.mockImplementation(async (sql: string) => {
      if (sql.includes('FROM persona WHERE')) return [[{ idPersona: 10 }]];
      if (sql.includes('FROM propietario WHERE')) return [[]];
      if (sql.includes('INSERT INTO propietario')) return [{ insertId: 4 }];
      return [[]];
    });
    await expect(service.crearVehiculo(10, vehiculo)).rejects.toBeInstanceOf(NotFoundException);
    expect(connection.execute).not.toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO vehiculo'), expect.anything(),
    );
    expect(connection.commit).not.toHaveBeenCalled();
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.release).toHaveBeenCalledTimes(1);
  });

  it('obtiene la ciudad real del punto de recogida, conservando vehículos sin punto', async () => {
    database.query.mockResolvedValueOnce([[{ idPropietario: 4 }]])
      .mockResolvedValueOnce([[{ idVehiculo: 18, ciudad: 'Ciudad de prueba' }]]);
    expect(await service.obtenerMisVehiculos(10)).toEqual([
      { idVehiculo: 18, ciudad: 'Ciudad de prueba' },
    ]);
    const sql = database.query.mock.lastCall?.[0] as string;
    expect(sql).toContain('LEFT JOIN punto_autorizado');
    expect(sql).toContain('punto.ciudad');
  });

  it('el catálogo público omite placa, documentos e identidad del propietario', async () => {
    database.execute.mockResolvedValueOnce([[{
      idVehiculo: 18, marca: 'Marca', modelo: 'Modelo',
      precioPorDia: '120.00', estado: 'Activo', placa: 'NO_PUBLICAR',
      tarjetaPropiedad: 'NO_PUBLICAR', idPunto: 7,
      puntoNombre: 'Punto autorizado', puntoDireccion: 'Vía pública',
      ciudad: 'Ciudad', latitud: '10.4', longitud: '-75.5',
    }]]);
    const resultado = await service.catalogo('Ciudad');
    expect(resultado).toMatchObject({
      vehiculos: [{
        idVehiculo: 18,
        puntoRecogida: { id: 7, latitud: 10.4, longitud: -75.5 },
      }],
    });
    expect(JSON.stringify(resultado)).not.toContain('NO_PUBLICAR');
    expect(database.execute).toHaveBeenCalledWith(
      expect.stringContaining("v.estado = 'Activo'"), ['Ciudad'],
    );
  });

  it('filtra ciudad, precio, plazas, categoría y disponibilidad sin leer datos privados', async () => {
    database.execute.mockResolvedValueOnce([[]]);
    await service.catalogo({
      ciudad: 'Ciudad', categoria: 'suv', texto: 'Marca', precioMaximo: '90000',
      plazasMinimas: '5', orden: 'priceAsc',
      fechaInicio: '2027-02-10T10:00:00', fechaFin: '2027-02-12T10:00:00',
    });
    const [sql, params] = database.execute.mock.lastCall as [string, unknown[]];
    expect(sql).toContain('NOT EXISTS');
    expect(sql).toContain("r.estado IN ('Pendiente', 'Confirmada', 'EnCurso')");
    expect(sql).toContain('v.precioPorDia ASC');
    expect(sql).not.toContain('v.placa');
    expect(sql).not.toContain('tarjetaPropiedad');
    expect(params).toEqual([
      'Ciudad', '%marca%', 'suv', 'camioneta', 'camionetas', 90000, 5,
      '2027-02-12 10:00:00', '2027-02-10 10:00:00',
    ]);
  });

  it('pagina resultados públicos con orden estable y sin inventar totales', async () => {
    const rows = Array.from({ length: 21 }, (_, index) => ({
      idVehiculo: index + 1, precioPorDia: '10000.00',
    }));
    database.execute.mockResolvedValueOnce([rows]);
    const result = await service.catalogo({ pagina: '2', orden: 'priceDesc' });
    expect(result).toMatchObject({ pagina: 2, hayMas: true });
    expect(result.vehiculos).toHaveLength(20);
    expect(database.execute.mock.lastCall?.[0]).toContain('LIMIT 21 OFFSET 20');
    expect(database.execute.mock.lastCall?.[1]).toEqual([]);
  });

  it('rechaza ventanas incompletas, invertidas y parámetros fuera de rango', async () => {
    await expect(service.catalogo({ fechaInicio: '2027-02-10T10:00:00' }))
      .rejects.toBeInstanceOf(BadRequestException);
    await expect(service.catalogo({
      fechaInicio: '2027-02-12T10:00:00', fechaFin: '2027-02-10T10:00:00',
    })).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.catalogo({ precioMaximo: '0' }))
      .rejects.toBeInstanceOf(BadRequestException);
    await expect(service.catalogo({
      fechaInicio: '2027-02-31T10:00:00', fechaFin: '2027-03-10T10:00:00',
    })).rejects.toBeInstanceOf(BadRequestException);
    expect(database.execute).not.toHaveBeenCalled();
  });

  it('impide que un tercero cambie el estado de un vehículo ajeno', async () => {
    await expect(service.cambiarEstadoVehiculo(99, 18, { estado: 'inactivo' }))
      .rejects.toBeInstanceOf(NotFoundException);
    expect(connection.query).toHaveBeenCalledWith(
      expect.stringContaining('p.idPersona = ? FOR UPDATE'), [18, 99],
    );
    expect(connection.query).not.toHaveBeenCalledWith(
      expect.stringContaining('UPDATE vehiculo'), expect.anything(),
    );
    expect(connection.rollback).toHaveBeenCalledTimes(1);
  });

  it('no pausa un vehículo con reservas activas ni anuncia un cambio falso', async () => {
    connection.query.mockResolvedValueOnce([[{
      estado: 'Activo', estado_solicitud_revision: 'Sin_solicitud',
    }]]).mockResolvedValueOnce([[{ idReserva: 7 }]]);
    await expect(service.cambiarEstadoVehiculo(10, 18, { estado: 'inactivo' }))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(connection.commit).not.toHaveBeenCalled();
    expect(connection.query).not.toHaveBeenCalledWith(
      expect.stringContaining('UPDATE vehiculo'), expect.anything(),
    );
  });

  it('rechaza la revisión repetida sin modificar el vehículo', async () => {
    connection.query.mockResolvedValueOnce([[{
      idVehiculo: 18, estado_solicitud_revision: 'Pendiente',
    }]]);
    await expect(service.solicitarRevision(10, 18,
      { motivoSolicitud: 'Revisar frenos' }))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(connection.query).toHaveBeenCalledWith(
      expect.stringContaining('p.idPersona = ?'), [18, 10],
    );
    expect(connection.query).toHaveBeenCalledTimes(1);
    expect(connection.rollback).toHaveBeenCalledTimes(1);
  });

  it('no solicita revisión mientras hay reservas activas', async () => {
    connection.query.mockResolvedValueOnce([[{
      idVehiculo: 18, estado: 'Activo',
      estado_solicitud_revision: 'Sin_solicitud',
    }]]).mockResolvedValueOnce([[{ idReserva: 7 }]]);
    await expect(service.solicitarRevision(10, 18,
      { motivoSolicitud: 'Revisar frenos' }))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(connection.query).not.toHaveBeenCalledWith(
      expect.stringContaining('UPDATE vehiculo'), expect.anything(),
    );
    expect(connection.commit).not.toHaveBeenCalled();
  });

  it('bloquea el vehículo y registra el motivo en una transacción', async () => {
    connection.query.mockResolvedValueOnce([[{
      idVehiculo: 18, estado: 'Activo',
      estado_solicitud_revision: 'Sin_solicitud',
    }]]).mockResolvedValueOnce([[]]);
    await expect(service.solicitarRevision(10, 18,
      { motivoSolicitud: 'Revisar frenos' }))
      .resolves.toMatchObject({ estado: 'Pendiente' });
    expect(connection.query).toHaveBeenCalledWith(
      expect.stringContaining("estado = 'revision_pendiente'"),
      ['Revisar frenos', 18],
    );
    expect(connection.commit).toHaveBeenCalledTimes(1);
  });
});
