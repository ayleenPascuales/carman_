import { CanActivate, ExecutionContext, Injectable, ForbiddenException } from "@nestjs/common";
import { AuthService } from "./auth.service";
import { Observable } from "rxjs";

@Injectable()
export class AdminGuard implements CanActivate {
    constructor(private readonly authService: AuthService) { }

    async canActivate(context: ExecutionContext): Promise<boolean> {
        const request = context.switchToHttp().getRequest();
        const idPersona = request.user?.idPersona;

        if (!idPersona) {
            throw new ForbiddenException('No se pudo identificar al administrador. ');
        }
        await this.authService.verificarAdministrador(idPersona);
        return true;
    }
}