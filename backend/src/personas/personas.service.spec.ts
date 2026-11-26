import { Test, TestingModule } from '@nestjs/testing';
import { PersonasService } from './personas.service';
import { AuthService } from '../auth/auth.service';
import { ConflictException } from '@nestjs/common';
import { ServiceUnavailableException } from '@nestjs/common';
import { Rol, RegistroInicialDto } from './dto/registroInicial.dto';
import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { VerificationService } from '../auth/verification.service';
import { ReservasService } from '../reservas/reservas.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';

describe('PersonasService', () => {
  let service: PersonasService;
  const connection = {
    beginTransaction: jest.fn(),
    execute: jest.fn(),
    commit: jest.fn(),
    rollback: jest.fn(),
    release: jest.fn(),
  };
  const database = {
    getConnection: jest.fn().mockResolvedValue(connection),
    execute: jest.fn(),
  };
  const auth = {
    crearCuenta: jest.fn().mockResolvedValue('firebase-uid'),
    eliminarCuenta: jest.fn(),
  };
  const verification = {
    validarTelefono: jest.fn(),
    comprobarConfiguracion: jest.fn(),
    comprobarAlmacenamiento: jest.fn(),
    enviarCorreoInicial: jest.fn().mockResolvedValue(undefined),
    enviarCodigo: jest.fn().mockResolvedValue(undefined),
  };
  const reservas = {
    buscarYasignarConductor: jest.fn().mockResolvedValue({ reservasAsignadas: [] }),
  };
  const notificaciones = {
    avisarPersona: jest.fn().mockResolvedValue(undefined),
  };
  const registration: RegistroInicialDto = {
    roles: Rol.CLIENTE,
    persona: {
      documento: '12345678', nombre: 'Ada', apellido: 'Lovelace',
      email: 'ada@example.com', usuario: 'ada', contrasena: 'password123',
       telefono: '+573000000000', fechaNacimiento: '1990-01-01', ciudad: 'Bogotá',
      direccion: 'Calle 1', fotoPerfil: 'https://example.com/avatar.jpg',
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    database.execute.mockResolvedValue([[]]);
    connection.execute.mockImplementation(async (sql: string) =>
      sql.includes('FROM punto_autorizado')
        ? [[{ idPunto: 7 }, { idPunto: 8 }]]
        : [{ insertId: 42 }],
    );
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PersonasService,
        { provide: 'DATABASE_CONNECTION', useValue: database },
        { provide: AuthService, useValue: auth },
        { provide: VerificationService, useValue: verification },
        { provide: ReservasService, useValue: reservas },
        { provide: NotificacionesService, useValue: notificaciones },
      ],
    }).compile();

    service = module.get<PersonasService>(PersonasService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('rechaza sin crear cuenta registros sin persona o con persona nula, array o vacía', () => {
    for (const persona of [undefined, null, [], {}]) {
      const body = plainToInstance(RegistroInicialDto, { roles: Rol.CLIENTE, persona });
      expect(validateSync(body).length).toBeGreaterThan(0);
    }
    expect(auth.crearCuenta).not.toHaveBeenCalled();
  });

  it('no divulga reservas asignadas a otros conductores al activar disponibilidad', async () => {
    connection.execute.mockImplementation(async (sql: string) => {
      if (sql.includes('FROM conductor WHERE')) return [[{ idConductor: 7 }]];
      if (sql.includes('FROM licencia WHERE')) return [[{ idLicencia: 3 }]];
      return [{ affectedRows: 1 }];
    });
    database.execute.mockResolvedValueOnce([[{ idConductor: 7 }]]);
    reservas.buscarYasignarConductor.mockResolvedValueOnce({
      reservasAsignadas: [
        { idReserva: 8, idConductor: 7 },
        { idReserva: 9, idConductor: 11 },
      ],
    });
    await expect(service.actualizarDisponibilidadConductor(4, {
      disponibilidad: true,
    })).resolves.toMatchObject({ reservasAsignadas: [8] });
  });

  it('informa éxito del cambio aunque falle la búsqueda posterior al commit', async () => {
    connection.execute.mockImplementation(async (sql: string) => {
      if (sql.includes('FROM conductor WHERE')) return [[{ idConductor: 7 }]];
      if (sql.includes('FROM licencia WHERE')) return [[{ idLicencia: 3 }]];
      return [{ affectedRows: 1 }];
    });
    reservas.buscarYasignarConductor.mockRejectedValueOnce(new Error('búsqueda fallida'));
    await expect(service.actualizarDisponibilidadConductor(4, {
      disponibilidad: true,
    })).resolves.toMatchObject({
      disponibilidad: true, reservasAsignadas: [],
      advertencia: expect.any(String),
    });
    expect(connection.commit).toHaveBeenCalledTimes(1);
  });

  it('registra el UID Firebase y confirma TiDB en la misma operación lógica', async () => {
    const result = await service.registroInicial(registration);
    expect(result).toMatchObject({ idPersona: 42, rol: Rol.CLIENTE });
    expect(auth.crearCuenta).toHaveBeenCalledWith('ada@example.com', 'password123');
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO persona'),
      expect.arrayContaining(['firebase-uid']),
    );
    expect(connection.commit).toHaveBeenCalled();
    expect(verification.comprobarAlmacenamiento).toHaveBeenCalled();
    expect(verification.enviarCorreoInicial).toHaveBeenCalledWith(
      'firebase-uid', 'ada@example.com', 'password123',
    );
    expect(result.smsEnviado).toBe(false);
    expect(verification.enviarCodigo).not.toHaveBeenCalled();
    expect(auth.eliminarCuenta).not.toHaveBeenCalled();
    expect(connection.release).toHaveBeenCalled();
  });

  it('guarda precioPorDia al registrar un propietario con vehículo', async () => {
    await service.registroInicial({
      ...registration,
      roles: Rol.PROPIETARIO,
      vehiculos: [{
        placa: 'PRB123', marca: 'Marca de prueba', modelo: 'Modelo de prueba',
        anio: 2024, capacidad: 4, tipoVehiculo: 'SUV',
        idPuntoRecogida: 7, idPuntoEntrega: 8, precioPorDia: 120.5,
        fotos: ['https://example.com/foto.jpg'],
        tarjetaPropiedad: 'https://example.com/tarjeta.jpg',
      }],
    });
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO vehiculo'),
      expect.arrayContaining([120.5]),
    );
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('AND activo = TRUE'), [7, 8],
    );
  });

  it('no registra un vehículo con puntos inactivos durante el alta', async () => {
    connection.execute.mockImplementation(async (sql: string) =>
      sql.includes('FROM punto_autorizado')
        ? [[{ idPunto: 7 }]]
        : [{ insertId: 42 }],
    );
    await expect(service.registroInicial({
      ...registration,
      roles: Rol.PROPIETARIO,
      vehiculos: [{
        placa: 'PRB123', marca: 'Marca', modelo: 'Modelo', anio: 2024,
        capacidad: 4, tipoVehiculo: 'SUV', idPuntoRecogida: 7, idPuntoEntrega: 8,
        fotos: ['https://example.com/foto.jpg'],
        tarjetaPropiedad: 'https://example.com/tarjeta.jpg',
      }],
    })).rejects.toThrow('Selecciona puntos de recogida y entrega activos.');
    expect(connection.rollback).toHaveBeenCalled();
    expect(auth.eliminarCuenta).toHaveBeenCalledWith('firebase-uid');
    expect(connection.execute).not.toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO vehiculo'), expect.anything(),
    );
  });

  it('permite perfil sin imagen ni dirección inventadas según el esquema', async () => {
    await service.registroInicial({
      ...registration,
      persona: { ...registration.persona, direccion: undefined, fotoPerfil: undefined },
    });
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO persona'),
      expect.arrayContaining([null, '']),
    );
  });

  it('deshace TiDB y elimina el UID si falla el registro', async () => {
    connection.execute.mockRejectedValueOnce({ code: 'ER_DUP_ENTRY' });
    await expect(service.registroInicial(registration)).rejects.toBeInstanceOf(ConflictException);
    expect(connection.rollback).toHaveBeenCalled();
    expect(auth.eliminarCuenta).toHaveBeenCalledWith('firebase-uid');
    expect(verification.enviarCodigo).not.toHaveBeenCalled();
  });

  it('no crea cuentas si la configuración de envíos no está lista', async () => {
    verification.comprobarConfiguracion.mockImplementationOnce(() => {
      throw new ServiceUnavailableException('textbee no configurado');
    });
    await expect(service.registroInicial(registration)).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(auth.crearCuenta).not.toHaveBeenCalled();
    expect(database.getConnection).not.toHaveBeenCalled();
  });

  it('no duplica correos de personas anteriores aunque el esquema no tenga UNIQUE(email)', async () => {
    database.execute.mockResolvedValueOnce([[{ idPersona: 9 }]]);
    await expect(service.registroInicial(registration)).rejects.toBeInstanceOf(ConflictException);
    expect(database.execute).toHaveBeenCalledWith(
      expect.stringContaining('LOWER(email) = LOWER(?)'), ['ada@example.com'],
    );
    expect(auth.crearCuenta).not.toHaveBeenCalled();
    expect(database.getConnection).not.toHaveBeenCalled();
  });

  it('no crea una cuenta irrecuperable si falta la tabla de OTP', async () => {
    verification.comprobarAlmacenamiento.mockRejectedValueOnce(
      new ServiceUnavailableException('Falta phone_verification'),
    );
    await expect(service.registroInicial(registration)).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(auth.crearCuenta).not.toHaveBeenCalled();
    expect(database.getConnection).not.toHaveBeenCalled();
  });

  it('conserva la cuenta y permite reenvío si falla el correo después del commit', async () => {
    verification.enviarCorreoInicial.mockRejectedValueOnce(new Error('Firebase no disponible'));
    await expect(service.registroInicial(registration)).resolves.toMatchObject({
      correoEnviado: false, smsEnviado: false,
    });
    expect(auth.eliminarCuenta).not.toHaveBeenCalled();
    expect(connection.rollback).not.toHaveBeenCalled();
  });

  it('incluye el rol administrador activo en el perfil del cliente', async () => {
    database.execute.mockResolvedValueOnce([[{ idPersona: 42, nombre: 'Ada' }]])
      .mockResolvedValueOnce([[{ cliente: 1, propietario: 0, conductor: 0, administrador: 1 }]])
      .mockResolvedValueOnce([[{ estado: 'Vigente' }]]);
    expect(await service.obtenerPerfil(42)).toMatchObject({
      licenciaEstado: 'Vigente',
      roles: { cliente: true, propietario: false, conductor: false, administrador: true },
    });
  });

  it('agrega únicamente el rol de conductor con la licencia vigente existente', async () => {
    connection.execute.mockImplementation(async (sql: string) => {
      if (sql.includes('FROM persona WHERE')) return [[{ idPersona: 42 }]];
      if (sql.includes('FROM conductor WHERE')) return [[]];
      if (sql.includes('FROM licencia WHERE idPersona')) {
        return [[{ idLicencia: 7, estado: 'Vigente', fechaExpiracion: '2099-01-01' }]];
      }
      return [{ insertId: 18 }];
    });

    await expect(service.agregarRol(42, {})).resolves.toMatchObject({
      idPersona: 42, idConductor: 18, rol: 'Conductor',
    });
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO conductor'), [42],
    );
    expect(connection.execute).not.toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO cliente'), expect.anything(),
    );
    expect(connection.execute).not.toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO vehiculo'), expect.anything(),
    );
    expect(connection.commit).toHaveBeenCalledTimes(1);
    expect(connection.release).toHaveBeenCalledTimes(1);
  });

  it('registra la licencia antes de agregar el rol conductor', async () => {
    connection.execute.mockImplementation(async (sql: string) => {
      if (sql.includes('FROM persona WHERE')) return [[{ idPersona: 42 }]];
      if (sql.includes('FROM conductor WHERE') || sql.includes('FROM licencia WHERE')) return [[]];
      return [{ insertId: 18 }];
    });

    await service.agregarRol(42, {
      licencia: {
        numeroDocumento: 'LIC123', fechaExpiracion: '2099-01-01',
        tipoLicencia: 'B1', fotoLicencia: 'https://example.com/licencia.jpg',
      },
    });
    const sentencias = connection.execute.mock.calls.map(([sql]: [string]) => sql);
    expect(sentencias.findIndex((sql: string) => sql.includes('INSERT INTO licencia')))
      .toBeLessThan(sentencias.findIndex((sql: string) => sql.includes('INSERT INTO conductor')));
    expect(connection.commit).toHaveBeenCalledTimes(1);
  });

  it('no agrega el rol conductor con licencia suspendida', async () => {
    connection.execute.mockImplementation(async (sql: string) => {
      if (sql.includes('FROM persona WHERE')) return [[{ idPersona: 42 }]];
      if (sql.includes('FROM conductor WHERE')) return [[]];
      if (sql.includes('FROM licencia WHERE idPersona')) {
        return [[{ idLicencia: 7, estado: 'Suspendida', fechaExpiracion: '2099-01-01' }]];
      }
      return [[]];
    });

    await expect(service.agregarRol(42, {})).rejects.toThrow('licencia esta suspendida');
    expect(connection.commit).not.toHaveBeenCalled();
    expect(connection.rollback).toHaveBeenCalledTimes(1);
    expect(connection.release).toHaveBeenCalledTimes(1);
  });
});
