import { Controller, Post, Body, Get, UseGuards, Req, Logger } from "@nestjs/common";
import { AuthService } from "./auth.service";
import { LoginDto } from "./dto/login.dto";
import { AuthGuard } from "./auth.guard";
import { AdminGuard } from "./admin.guard";
import { DeliveryError, VerificationService } from './verification.service';
import { AllowUnverified } from './allow-unverified.decorator';
import { ConfirmarTelefonoDto } from './dto/confirmar-telefono.dto';
import { SolicitarRecuperacionDto } from './dto/solicitar-recuperacion.dto';

@Controller('auth')
export class AuthController {
    private readonly logger = new Logger(AuthController.name);
    constructor(
        private readonly authService: AuthService,
        private readonly verification: VerificationService,
    ) { }

    private async registrarFalloEnvio<T>(operation: () => Promise<T>): Promise<T> {
        try {
            return await operation();
        } catch (error) {
            if (error instanceof DeliveryError) this.logger.warn(error.diagnostic);
            throw error;
        }
    }

    @Post('login')
    iniciarSesion(@Body() dto: LoginDto) {
        return this.authService.iniciarSesion(
            dto.identificador,
            dto.contrasena,
        )
    }

    @Post('password/solicitar-recuperacion')
    async solicitarRecuperacion(@Body() dto: SolicitarRecuperacionDto) {
        await this.registrarFalloEnvio(() =>
            this.verification.solicitarRecuperacion(dto.email));
        return { mensaje: 'Si existe una cuenta para ese correo, se enviará un enlace de recuperación.' };
    }

    @Get('verificacion')
    @UseGuards(AuthGuard)
    @AllowUnverified()
    estadoVerificacion(@Req() request: any) {
        return this.verification.estado(request.user.uid, request.user.idPersona);
    }

    @Post('correo/reenviar')
    @UseGuards(AuthGuard)
    @AllowUnverified()
    async reenviarCorreo(@Req() request: any) {
        const status = await this.verification.estado(request.user.uid, request.user.idPersona);
        if (!status.correoVerificado && status.requiereVerificacion) {
            await this.registrarFalloEnvio(() =>
                this.verification.enviarCorreoConToken(request.headers.authorization.slice(7)));
        }
        return { mensaje: 'Si falta verificar el correo, se enviará un enlace de activación.' };
    }

    @Post('telefono/reenviar')
    @UseGuards(AuthGuard)
    @AllowUnverified()
    async reenviarTelefono(@Req() request: any) {
        await this.registrarFalloEnvio(() =>
            this.verification.reenviarCodigo(request.user.uid, request.user.idPersona));
        return { mensaje: 'Si falta verificar el teléfono, se enviará un código.' };
    }

    @Post('telefono/confirmar')
    @UseGuards(AuthGuard)
    @AllowUnverified()
    async confirmarTelefono(@Req() request: any, @Body() dto: ConfirmarTelefonoDto) {
        await this.verification.confirmarCodigo(request.user.uid, request.user.idPersona, dto.codigo);
        return this.verification.estado(request.user.uid, request.user.idPersona);
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
