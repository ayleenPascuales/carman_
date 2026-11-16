import { Controller, Post, Body } from "@nestjs/common";
import { AuthService } from "./auth.service";
import { LoginDto } from "./dto/login.dto";

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
}