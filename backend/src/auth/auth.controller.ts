import { Controller, Post, Body, Get, UseGuards, Req } from "@nestjs/common";
import { AuthService } from "./auth.service";
import { LoginDto } from "./dto/login.dto";
import { AuthGuard } from "./auth.guard";
import { AdminGuard } from "./admin.guard";

@Controller('auth')
export class AuthController {
    constructor(private readonly authService: AuthService,) { }

    @Post('login')
    iniciarSesion(@Body() dto: LoginDto) {
        return this.authService.iniciarSesion(
            dto.identificador,
            dto.contrasena,
        )
    }

    @Get('admin/prueba')
    @UseGuards(AuthGuard, AdminGuard)
    probarAccesoAdmin(@Req() request: any) {
        return {
            mensaje: 'Aceeso administrativo autorizado. ',
            idPersona: request.user.idPersona,
            rol: 'Administrador'
        }
    }
}