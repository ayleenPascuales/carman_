import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';


@Injectable()
export class AuthGuard implements CanActivate {

  constructor(private readonly authService: AuthService) { }

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
    request.user = { ...usuario, idPersona, };
    return true;
  }

}
