import { AuthGuard } from './auth.guard';
import type { AuthService } from './auth.service';
import type { VerificationService } from './verification.service';
import type { Reflector } from '@nestjs/core';
import { ForbiddenException } from '@nestjs/common';

describe('AuthGuard', () => {
  it('should be defined', () => {
    expect(new AuthGuard({} as AuthService, {} as VerificationService, {} as Reflector)).toBeDefined();
  });

  it('bloquea las rutas protegidas hasta verificar correo y teléfono', async () => {
    const auth = {
      verificarToken: jest.fn().mockResolvedValue({ uid: 'uid', requiresVerification: true }),
      obtenerIdPersona: jest.fn().mockResolvedValue(4),
      verificarEstadoCuenta: jest.fn(),
      sincronizarEmailVerificado: jest.fn(),
      registrarActividad: jest.fn(),
    };
    const verification = {
      estado: jest.fn().mockResolvedValue({
        activada: false, correoVerificado: false, telefonoVerificado: false,
      }),
    };
    const reflector = { getAllAndOverride: jest.fn().mockReturnValue(false) };
    const context = {
      switchToHttp: () => ({ getRequest: () => ({
        headers: { authorization: 'Bearer id-token' },
      }) }),
      getHandler: () => function handler() {},
      getClass: () => class Controller {},
    };
    const guard = new AuthGuard(
      auth as unknown as AuthService,
      verification as unknown as VerificationService,
      reflector as unknown as Reflector,
    );
    await expect(guard.canActivate(context as never)).rejects.toBeInstanceOf(ForbiddenException);
    reflector.getAllAndOverride.mockReturnValueOnce(true);
    await expect(guard.canActivate(context as never)).resolves.toBe(true);
  });
});
