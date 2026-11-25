import { ConfigService } from '@nestjs/config';
import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import type { Auth } from 'firebase-admin/auth';
import type { Pool } from 'mysql2/promise';
import { AuthService } from './auth.service';

describe('AuthService + Firebase', () => {
  const database = {
    query: jest.fn(),
    execute: jest.fn().mockResolvedValue([{}]),
  };
  const firebase = {
    verifyIdToken: jest.fn().mockResolvedValue({ uid: 'uid-123' }),
    createUser: jest.fn().mockResolvedValue({ uid: 'uid-123' }),
    setCustomUserClaims: jest.fn(),
    deleteUser: jest.fn(),
  };
  const config = { getOrThrow: jest.fn().mockReturnValue('web-api-key') };
  const service = new AuthService(
    database as unknown as Pool,
    config as unknown as ConfigService,
    firebase as unknown as Auth,
  );
  const originalFetch = global.fetch;

  beforeEach(() => {
    jest.clearAllMocks();
    firebase.verifyIdToken.mockResolvedValue({ uid: 'uid-123' });
    database.query.mockResolvedValue([[{
      idPersona: 5, uidFirebase: 'uid-123', email: 'user@example.com', estado: 'Activo',
    }]]);
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        localId: 'uid-123', idToken: 'id-token', refreshToken: 'refresh', expiresIn: '3600',
      }),
    });
  });
  afterAll(() => { global.fetch = originalFetch; });

  it('verifica revocación de token y crea usuarios con Admin SDK', async () => {
    expect(await service.verificarToken('token')).toEqual({ uid: 'uid-123' });
    expect(firebase.verifyIdToken).toHaveBeenCalledWith('token', true);
    expect(await service.crearCuenta('user@example.com', 'password123')).toBe('uid-123');
    expect(firebase.setCustomUserClaims).toHaveBeenCalledWith('uid-123', { requiresVerification: true });
  });

  it('no deja usuarios huérfanos si falla la activación de verificaciones', async () => {
    firebase.setCustomUserClaims.mockRejectedValueOnce(new Error('claims'));
    await expect(service.crearCuenta('user@example.com', 'password123')).rejects.toThrow('claims');
    expect(firebase.deleteUser).toHaveBeenCalledWith('uid-123');
  });

  it('conecta contraseña Firebase con el UID guardado en TiDB', async () => {
    const result = await service.iniciarSesion('user@example.com', 'password123');
    expect(result).toMatchObject({ uid: 'uid-123', idToken: 'id-token' });
    expect(global.fetch).toHaveBeenCalledWith(
      expect.stringContaining('identitytoolkit.googleapis.com'),
      expect.objectContaining({ method: 'POST' }),
    );
    expect(database.execute).toHaveBeenCalledWith(
      expect.stringContaining('ultimaActividad = NOW()'), [5],
    );
    expect(database.execute).toHaveBeenCalledWith(
      expect.stringContaining('emailVerificado = ?'), [false, 5, false],
    );
  });

  it('impide asociar una identidad Firebase de otro usuario', async () => {
    firebase.verifyIdToken.mockResolvedValue({ uid: 'uid-different' });
    await expect(service.iniciarSesion('user@example.com', 'password123'))
      .rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rechaza cuentas suspendidas antes de llamar a Firebase', async () => {
    database.query.mockResolvedValue([[{ estado: 'Suspendido' }]]);
    await expect(service.iniciarSesion('user@example.com', 'password123'))
      .rejects.toBeInstanceOf(ForbiddenException);
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('interpreta el TINYINT de inactividad devuelto por TiDB MySQL', async () => {
    database.query.mockResolvedValue([[{ estado: 'Activo', superoInactividad: 1 }]]);
    await service.verificarEstadoCuenta(5);
    expect(database.execute).toHaveBeenCalledWith(
      expect.stringContaining("estado = 'Inactivo'"), [5],
    );

    database.execute.mockClear();
    database.query.mockResolvedValue([[{ estado: 'Activo', superoInactividad: 0 }]]);
    await service.verificarEstadoCuenta(5);
    expect(database.execute).not.toHaveBeenCalled();
  });
});
