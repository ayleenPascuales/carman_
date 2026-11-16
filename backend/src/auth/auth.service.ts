import { Injectable, Inject, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApp, getApps, initializeApp } from 'firebase-admin';
import { getAuth, type DecodedIdToken } from 'firebase-admin/auth';
import { readFileSync } from 'fs';
import { resolve } from 'path';
import type { Pool, RowDataPacket } from 'mysql2/promise';

@Injectable()
export class AuthService {
    private readonly firebaseAuth;

    constructor(
        @Inject('DATABASE_CONNECTION')
        private readonly database: Pool,
        private readonly configService: ConfigService,) {

        const rutaCredenciales = resolve(
            process.cwd(), 'firebase', 'serviceAccountKey.json',
        );

        const credenciales = JSON.parse(
            readFileSync(rutaCredenciales, 'utf8'),
        );

        const firebaseApp = getApps().length > 0
            ? getApp() : initializeApp({
                credential: cert(credenciales),
            });
        this.firebaseAuth = getAuth(firebaseApp);

    }

    async verificarToken(token: string): Promise<DecodedIdToken> {
        try {
            return await this.firebaseAuth.verifyIdToken(token);
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
        return usuario.uid;
    }

    async eliminarCuenta(uid: string): Promise<void> {
        await this.firebaseAuth.deleteUser(uid);
    }

    async iniciarSesion(identificador: string, contrasena: string) {
        let email = identificador;

        if (!identificador.includes('@')) {
            const [personas] = await this.database.query<RowDataPacket[]>(
                'SELECT email FROM persona WHERE usuario = ? LIMIT 1', [identificador],
            );

            const persona = personas[0] as { email: string } | undefined;
            if (!persona) {
                throw new UnauthorizedException('Credenciales incorrectas. ',);
            }
            email = persona.email
        }

        const apiKey = this.configService.getOrThrow<string>(
            'FIREBASE_API_KEY',
        );

        const respuesta = await fetch(
            `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', },
                body: JSON.stringify({
                    email, password: contrasena, returnSecureToken: true,
                }),
            },
        );
        if (!respuesta.ok) {
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

}
