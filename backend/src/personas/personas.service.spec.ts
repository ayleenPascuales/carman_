import { Test, TestingModule } from '@nestjs/testing';
import { PersonasService } from './personas.service';
import { AuthService } from '../auth/auth.service';
import { ConflictException } from '@nestjs/common';
import { ServiceUnavailableException } from '@nestjs/common';
import { Rol, type RegistroInicialDto } from './dto/registroInicial.dto';
import { VerificationService } from '../auth/verification.service';

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
    connection.execute.mockResolvedValue([{ insertId: 42 }]);
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PersonasService,
        { provide: 'DATABASE_CONNECTION', useValue: database },
        { provide: AuthService, useValue: auth },
        { provide: VerificationService, useValue: verification },
      ],
    }).compile();

    service = module.get<PersonasService>(PersonasService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
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
      .mockResolvedValueOnce([[{ cliente: 1, propietario: 0, conductor: 0, administrador: 1 }]]);
    expect(await service.obtenerPerfil(42)).toMatchObject({
      roles: { cliente: true, propietario: false, conductor: false, administrador: true },
    });
  });
});
