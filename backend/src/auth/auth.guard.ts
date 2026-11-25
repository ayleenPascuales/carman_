import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { Reflector } from '@nestjs/core';
import { ForbiddenException } from '@nestjs/common';
import { VerificationService } from './verification.service';
import { ALLOW_UNVERIFIED } from './allow-unverified.decorator';


@Injectable()
export class AuthGuard implements CanActivate {

  constructor(
    private readonly authService: AuthService,
    private readonly verification: VerificationService,
    private readonly reflector: Reflector,
  ) { }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();

    const autorizacion = request.headers.authorization;
    if (!autorizacion || !autorizacion.startsWith('Bearer ')) {
      throw new UnauthorizedException(
        'Debes iniciar sesion paea acceder a este recurso.'
      );
    }

    const token = autorizacion.split(' ')[1];
    const usuario = await this.authService.verificarToken(token);
    const idPersona = await this.authService.obtenerIdPersona(usuario.uid,);
    await this.authService.verificarEstadoCuenta(idPersona);
    if (usuario.requiresVerification === true) {
      const status = await this.verification.estado(usuario.uid, idPersona);
      if (!status.activada && !this.reflector.getAllAndOverride<boolean>(
        ALLOW_UNVERIFIED, [context.getHandler(), context.getClass()],
      )) {
        throw new ForbiddenException('Verifica tu correo y teléfono para activar la cuenta.');
      }
      await this.authService.sincronizarEmailVerificado(idPersona, status.correoVerificado);
    } else {
      await this.authService.sincronizarEmailVerificado(idPersona, usuario.email_verified === true);
    }
    await this.authService.registrarActividad(idPersona);
    request.user = { ...usuario, idPersona, };
    return true;
  }

}
