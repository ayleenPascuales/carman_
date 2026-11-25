import { Injectable, Inject, UnauthorizedException, ForbiddenException, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Auth, DecodedIdToken } from 'firebase-admin/auth';
import type { Pool, RowDataPacket } from 'mysql2/promise';
import { Cron, CronExpression } from '@nestjs/schedule';

@Injectable()
export class AuthService {
    constructor(
        @Inject('DATABASE_CONNECTION')
        private readonly database: Pool,
        private readonly configService: ConfigService,
        @Inject('FIREBASE_AUTH') private readonly firebaseAuth: Auth,
    ) {}

    async verificarToken(token: string): Promise<DecodedIdToken> {
        try {
            return await this.firebaseAuth.verifyIdToken(token, true);
        } catch {
            throw new UnauthorizedException(
                'El token de autenticación no es válido o ha expirado. '
            )
        }
    }

    async crearCuenta(email: string, contrasena: string): Promise<string> {
        const usuario = await this.firebaseAuth.createUser({
            email, password: contrasena,
        });
        try {
            await this.firebaseAuth.setCustomUserClaims(usuario.uid, { requiresVerification: true });
        } catch (error) {
            await this.firebaseAuth.deleteUser(usuario.uid);
            throw error;
        }
        return usuario.uid;
    }

    async eliminarCuenta(uid: string): Promise<void> {
        await this.firebaseAuth.deleteUser(uid);
    }

    async iniciarSesion(identificador: string, contrasena: string) {
        const [personas] = await this.database.query<RowDataPacket[]>(
            `SELECT email, estado, uidFirebase, idPersona FROM persona
            WHERE ${identificador.includes('@') ? 'email' : 'usuario'} = ?
            LIMIT 1`, [identificador]
        );

        const persona = personas[0] as {
            email: string; estado: string; uidFirebase: string; idPersona: number;
        } | undefined;

        if (!persona) {
            throw new UnauthorizedException('Credenciales incorrectas. ')
        }
        if (persona.estado === 'Suspendido') {
            throw new ForbiddenException(
                'Tu cuenta ha sido suspendida. Contacta con administracion. '
            );
        }
        const apiKey = this.configService.getOrThrow<string>(
            'FIREBASE_API_KEY',
        );

        let respuesta: Response;
        try {
            respuesta = await fetch(
                `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(apiKey)}`,
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        email: persona.email, password: contrasena, returnSecureToken: true,
                    }),
                    signal: AbortSignal.timeout(10_000),
                },
            );
        } catch {
            throw new ServiceUnavailableException('No se pudo contactar con Firebase Authentication.');
        }
        if (!respuesta.ok) {
            if (respuesta.status >= 500 || respuesta.status === 429) {
                throw new ServiceUnavailableException('Firebase Authentication no está disponible en este momento.');
            }
            throw new UnauthorizedException(
                'Credenciales incorrectas. '
            );
        }
        const datos = await respuesta.json() as {
            localId: string;
            idToken: string;
            refreshToken: string;
            expiresIn: string;
        };
        const verified = await this.verificarToken(datos.idToken);
        if (datos.localId !== persona.uidFirebase || verified.uid !== persona.uidFirebase) {
            throw new UnauthorizedException('La cuenta de Firebase no coincide con el usuario registrado.');
        }
        await this.registrarActividad(persona.idPersona);
        await this.sincronizarEmailVerificado(persona.idPersona, verified.email_verified === true);

        return {
            uid: datos.localId,
            idToken: datos.idToken,
            refreshToken: datos.refreshToken,
            expiresIn: datos.expiresIn,
        };
    }

    async obtenerIdPersona(uid: string): Promise<number> {
        const [personas] = await this.database.query<RowDataPacket[]>(
            'SELECT idPersona FROM persona WHERE uidFirebase = ? LIMIT 1', [uid],
        );

        const persona = personas[0] as { idPersona: number } | undefined;
        if (!persona) {
            throw new UnauthorizedException(
                'No existe una persona asociada a esta cuenta. '
            );
        }
        return persona.idPersona;
    }

    async verificarAdministrador(idPersona: number): Promise<void> {
        const [administradores] = await this.database.query<RowDataPacket[]>(
            `SELECT idAdministrador FROM administrador 
            WHERE idPersona = ? AND estado = 'Activo' LIMIT 1`, [idPersona]
        );

        if (administradores.length === 0) {
            throw new ForbiddenException('No tienes permisos para acceder a esta sección. ');
        }
    }

    async verificarEstadoCuenta(idPersona: number): Promise<void> {
        const [personas] = await this.database.query<RowDataPacket[]>(
            `SELECT estado,
            ultimaActividad,
            (COALESCE(ultimaActividad, fechaHoraRegistro)
            <= DATE_SUB(NOW(), INTERVAL 180 DAY))
            AS superoInactividad FROM persona
            WHERE idpersona = ? LIMIT 1`, [idPersona]
        );

        const persona = personas[0] as {
            estado: string;
            ultimaActividad: Date | null;
            superoInactividad: number;
        } | undefined;

        if (!persona) {
            throw new UnauthorizedException(
                'No existe una persona asociada a etsa cuenta.'
            );
        }
        if (persona.estado === 'Suspendido')
            throw new ForbiddenException(
                'Tu cuenta ha sido suspendida. Contacta con administracion. '
            );
        if (persona.estado === 'Activo' && Number(persona.superoInactividad) === 1) {
            await this.database.execute(
                `UPDATE persona SET estado = 'Inactivo' WHERE idPersona = ?`, [idPersona]
            );
        }
    }

    @Cron(CronExpression.EVERY_DAY_AT_2AM, {
        timeZone: 'America/Bogota',
    })
    async actualizarCuentasInactivas(): Promise<void> {
        await this.database.execute(
            `UPDATE persona SET estado = 'Inactivo' WHERE estado = 'Activo'
            AND COALESCE(ultimaActividad, fechaHoraRegistro)
            <= DATE_SUB(NOW(), INTERVAL 180 DAY)`
        );
    }

    async registrarActividad(idPersona: number): Promise<void> {
        await this.database.execute(
            `UPDATE persona SET estado = 'Activo', ultimaActividad = NOW()
            WHERE idPersona = ? AND estado IN ('Activo', 'Inactivo')
            AND (estado = 'Inactivo' OR ultimaActividad IS NULL
            OR ultimaActividad < DATE_SUB(NOW(), INTERVAL 1 DAY))`, [idPersona]
        );
    }

    async sincronizarEmailVerificado(idPersona: number, verificado: boolean): Promise<void> {
        await this.database.execute(
            `UPDATE persona SET emailVerificado = ?
            WHERE idPersona = ? AND emailVerificado <> ?`,
            [verificado, idPersona, verificado],
        );
    }
}
