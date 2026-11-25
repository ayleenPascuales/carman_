import { BadRequestException, ForbiddenException, HttpException, ServiceUnavailableException } from '@nestjs/common';
import type { ConfigService } from '@nestjs/config';
import type { Auth } from 'firebase-admin/auth';
import type { Pool } from 'mysql2/promise';
import { DeliveryError, VerificationService } from './verification.service';

describe('VerificationService Firebase + textbee', () => {
  const settings: Record<string, string> = {
    FIREBASE_API_KEY: 'api-key-for-tests',
    TEXTBEE_API_KEY: 'textbee-key-for-tests',
    SMS_OTP_SECRET: 'ab'.repeat(32),
  };
  let storedHash: Buffer | null;
  let sentCode: string;
  const connection = {
    beginTransaction: jest.fn(),
    commit: jest.fn(),
    rollback: jest.fn(),
    release: jest.fn(),
    execute: jest.fn(async (sql: string, params?: unknown[]) => {
      if (sql.includes('AS secondsSinceLastSend')) {
        return [[{
          idPersona: 4, sendCount: 0, windowSeconds: 0,
          secondsSinceLastSend: null,
        }]];
      }
      if (sql.includes('AS codeValid')) {
        return [[{ idPersona: 4, codigoHash: storedHash, codeValid: 1, attempts: 0 }]];
      }
      if (sql.startsWith('UPDATE phone_verification SET idPersona')) {
        storedHash = params?.[1] as Buffer;
      }
      return [{ affectedRows: 1 }];
    }),
  };
  const database = {
    execute: jest.fn(async (sql: string) => sql.includes('FROM persona')
      ? [[{ telefono: '+573001234567' }]] : [[]]),
    getConnection: jest.fn().mockResolvedValue(connection),
  };
  const config = {
    get: jest.fn((key: string) => settings[key]),
    getOrThrow: jest.fn((key: string) => settings[key]),
  };
  const firebase = {
    getUser: jest.fn().mockResolvedValue({
      emailVerified: true, phoneNumber: undefined,
      customClaims: { requiresVerification: true },
    }),
    updateUser: jest.fn(),
  };
  const service = new VerificationService(
    database as unknown as Pool,
    firebase as unknown as Auth,
    config as unknown as ConfigService,
  );
  const originalFetch = global.fetch;

  beforeEach(() => {
    jest.clearAllMocks();
    storedHash = null;
    sentCode = '';
    firebase.getUser.mockResolvedValue({
      emailVerified: true, phoneNumber: undefined,
      customClaims: { requiresVerification: true },
    });
    connection.execute.mockImplementation(async (sql: string, params?: unknown[]) => {
      if (sql.includes('AS secondsSinceLastSend')) {
        return [[{ idPersona: 4, sendCount: 0, windowSeconds: 0, secondsSinceLastSend: null }]];
      }
      if (sql.includes('AS codeValid')) {
        return [[{ idPersona: 4, codigoHash: storedHash, codeValid: 1, attempts: 0 }]];
      }
      if (sql.startsWith('UPDATE phone_verification SET idPersona')) storedHash = params?.[1] as Buffer;
      return [{ affectedRows: 1 }];
    });
    global.fetch = jest.fn(async (_url: string, options: RequestInit) => {
      const body = JSON.parse(options.body as string) as { message: string };
      sentCode = body.message.match(/\b\d{6}\b/)?.[0] ?? '';
      return {
        ok: true, status: 200,
        json: async () => ({ data: { success: true, smsBatchId: 'batch-test' } }),
      } as Response;
    }) as typeof global.fetch;
  });
  afterAll(() => { global.fetch = originalFetch; });

  it('envía el correo con el login Firebase y la plantilla VERIFY_EMAIL', async () => {
    (global.fetch as jest.Mock)
      .mockResolvedValueOnce({ ok: true, json: async () => ({
        localId: 'uid-123', idToken: 'firebase-id-token',
      }) })
      .mockResolvedValueOnce({ ok: true, json: async () => ({ email: 'test@example.com' }) });
    await service.enviarCorreoInicial('uid-123', 'test@example.com', 'secret-pass');
    expect(global.fetch).toHaveBeenNthCalledWith(1,
      expect.stringContaining('accounts:signInWithPassword'),
      expect.objectContaining({
        body: JSON.stringify({
          email: 'test@example.com', password: 'secret-pass', returnSecureToken: true,
        }),
      }),
    );
    expect(global.fetch).toHaveBeenNthCalledWith(2,
      expect.stringContaining('accounts:sendOobCode'),
      expect.objectContaining({
        headers: expect.objectContaining({ 'X-Firebase-Locale': 'es' }),
        body: JSON.stringify({ requestType: 'VERIFY_EMAIL', idToken: 'firebase-id-token' }),
      }),
    );
  });

  it('permite reenviar correo con el ID token y registra errores Firebase sin datos privados', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false, status: 400,
      json: async () => ({ error: { message: 'INVALID_ID_TOKEN: token-privado' } }),
    });
    await expect(service.enviarCorreoConToken('token-privado')).rejects.toMatchObject({
      diagnostic: 'FIREBASE sendOobCode HTTP_400 INVALID_ID_TOKEN',
    } satisfies Partial<DeliveryError>);
    expect(global.fetch).toHaveBeenCalledTimes(1);
  });

  it('no envía correo si Identity Toolkit devuelve un UID distinto', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true, json: async () => ({ localId: 'another-user', idToken: 'token' }),
    });
    await expect(service.enviarCorreoInicial('uid-123', 'test@example.com', 'pass'))
      .rejects.toMatchObject({ diagnostic: 'FIREBASE signInWithPassword UID_MISMATCH' });
    expect(global.fetch).toHaveBeenCalledTimes(1);
  });

  it('envía SMS E.164 con textbee sin devolver el código ni guardarlo en claro', async () => {
    await service.enviarCodigo('uid-123', 4);
    expect(global.fetch).toHaveBeenCalledWith(
      'https://api.textbee.dev/api/v1/gateway/send-sms',
      expect.objectContaining({
        headers: expect.objectContaining({ 'x-api-key': settings.TEXTBEE_API_KEY }),
      }),
    );
    expect(sentCode).toMatch(/^\d{6}$/);
    expect(storedHash).toBeInstanceOf(Buffer);
    expect(storedHash?.toString('hex')).not.toContain(sentCode);
    expect(connection.commit).toHaveBeenCalled();
    expect(() => service.validarTelefono('3001234567')).toThrow(BadRequestException);
  });

  it('no envía SMS hasta que Firebase confirme el correo', async () => {
    firebase.getUser.mockResolvedValueOnce({
      emailVerified: false, phoneNumber: undefined,
      customClaims: { requiresVerification: true },
    });
    await expect(service.enviarCodigo('uid-123', 4)).rejects.toBeInstanceOf(ForbiddenException);
    expect(global.fetch).not.toHaveBeenCalled();
    expect(database.getConnection).not.toHaveBeenCalled();
  });

  it('no vuelve a enviar SMS a un teléfono ya verificado', async () => {
    firebase.getUser.mockResolvedValueOnce({
      emailVerified: true, phoneNumber: '+573001234567',
      customClaims: { requiresVerification: true },
    });
    await service.enviarCodigo('uid-123', 4);
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('limita reenvíos en la base (no solo en el temporizador del cliente)', async () => {
    connection.execute.mockResolvedValueOnce([{}]).mockResolvedValueOnce([[{
      idPersona: 4, sendCount: 1, windowSeconds: 10, secondsSinceLastSend: 12,
    }]]);
    await expect(service.enviarCodigo('uid-123', 4)).rejects.toBeInstanceOf(HttpException);
    expect(connection.rollback).toHaveBeenCalled();
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('vincula el teléfono a Firebase solo con un código válido no vencido', async () => {
    await service.enviarCodigo('uid-123', 4);
    await service.confirmarCodigo('uid-123', 4, sentCode);
    expect(firebase.updateUser).toHaveBeenCalledWith('uid-123', { phoneNumber: '+573001234567' });
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('SET codigoHash = NULL'), expect.any(Array),
    );
  });

  it('incrementa intentos fallidos y no marca el teléfono verificado', async () => {
    await service.enviarCodigo('uid-123', 4);
    const incorrecto = sentCode === '000000' ? '000001' : '000000';
    await expect(service.confirmarCodigo('uid-123', 4, incorrecto))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('SET attempts = attempts + 1'), expect.any(Array),
    );
    expect(firebase.updateUser).not.toHaveBeenCalled();
  });

  it('no acepta un código caducado aunque coincida', async () => {
    await service.enviarCodigo('uid-123', 4);
    connection.execute.mockImplementationOnce(async () => [[{
      idPersona: 4, codigoHash: storedHash, attempts: 0, codeValid: 0,
    }]]);
    await expect(service.confirmarCodigo('uid-123', 4, sentCode))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(firebase.updateUser).not.toHaveBeenCalled();
  });

  it('registra solo estado de error seguro si textbee rechaza la solicitud', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false, status: 401, json: async () => ({ error: 'secreto o teléfono privado' }),
    });
    await expect(service.enviarCodigo('uid-123', 4)).rejects.toMatchObject({
      diagnostic: 'TEXTBEE send-sms HTTP_401',
    } satisfies Partial<DeliveryError>);
  });

  it('rechaza configuración incompleta o tabla ausente antes del alta', async () => {
    const key = settings.TEXTBEE_API_KEY;
    delete settings.TEXTBEE_API_KEY;
    try {
      expect(() => service.comprobarConfiguracion()).toThrow(ServiceUnavailableException);
    } finally {
      settings.TEXTBEE_API_KEY = key;
    }
    database.execute.mockRejectedValueOnce({ code: 'ER_NO_SUCH_TABLE' });
    await expect(service.comprobarAlmacenamiento()).rejects.toThrow('phone_verification');
  });
});
