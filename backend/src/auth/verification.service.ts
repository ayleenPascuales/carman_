import {
  BadRequestException, ConflictException, ForbiddenException, HttpException,
  HttpStatus, Inject, Injectable, ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import type { Auth } from 'firebase-admin/auth';
import type { Pool, RowDataPacket } from 'mysql2/promise';

// Los diagnósticos solo contienen proveedor, operación y estado, nunca la
// respuesta completa de Firebase/textbee (podría incluir datos privados).
export class DeliveryError extends ServiceUnavailableException {
  constructor(message: string, readonly diagnostic: string) {
    super(message);
  }
}

interface ChallengeRow extends RowDataPacket {
  idPersona: number;
  codigoHash: Buffer | null;
  attempts: number;
  sendCount: number;
  windowSeconds: number;
  secondsSinceLastSend: number | null;
  codeValid: number;
}

function providerCode(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const code = value.split(':')[0].trim();
  return /^[A-Z][A-Z0-9_]{2,79}$/.test(code) ? code : undefined;
}

function networkDiagnostic(error: unknown): string {
  return error instanceof Error && error.name === 'TimeoutError' ? 'TIMEOUT' : 'NETWORK_ERROR';
}

// Firebase envía la activación. textbee solo pone el SMS en cola en un Android
// del titular: el OTP se genera aquí y solo se guarda como HMAC en TiDB.
@Injectable()
export class VerificationService {
  constructor(
    @Inject('DATABASE_CONNECTION') private readonly database: Pool,
    @Inject('FIREBASE_AUTH') private readonly firebaseAuth: Auth,
    private readonly config: ConfigService,
  ) {}

  comprobarConfiguracion(): void {
    const key = this.config.get<string>('TEXTBEE_API_KEY')?.trim();
    if (!key || key.startsWith('reemplazar_')) {
      throw new ServiceUnavailableException('Falta TEXTBEE_API_KEY para enviar SMS.');
    }
    if (!/^[0-9a-fA-F]{64}$/.test(this.config.get<string>('SMS_OTP_SECRET') ?? '')) {
      throw new ServiceUnavailableException('SMS_OTP_SECRET debe ser una clave aleatoria de 32 bytes en hexadecimal.');
    }
  }

  async comprobarAlmacenamiento(): Promise<void> {
    try {
      await this.database.execute('SELECT phoneHash FROM phone_verification LIMIT 0');
    } catch (error) {
      if (error && typeof error === 'object' && 'code' in error && error.code === 'ER_NO_SUCH_TABLE') {
        throw new ServiceUnavailableException('Falta la tabla phone_verification. Revisa la migración 002.');
      }
      throw new ServiceUnavailableException('No se pudo consultar la tabla de verificación telefónica.');
    }
  }

  validarTelefono(telefono: string): void {
    if (!/^\+[1-9]\d{7,14}$/.test(telefono)) {
      throw new BadRequestException('El teléfono debe estar en formato internacional E.164, por ejemplo +573001234567.');
    }
  }

  private async firebaseRequest(path: string, body: object): Promise<Record<string, unknown>> {
    const key = this.config.getOrThrow<string>('FIREBASE_API_KEY');
    try {
      const response = await fetch(
        `https://identitytoolkit.googleapis.com/v1/accounts:${path}?key=${encodeURIComponent(key)}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(path === 'sendOobCode' ? { 'X-Firebase-Locale': 'es' } : {}),
          },
          body: JSON.stringify(body),
          signal: AbortSignal.timeout(10_000),
        },
      );
      if (!response.ok) {
        const payload = await response.json().catch(() => null) as
          { error?: { message?: string } } | null;
        const code = providerCode(payload?.error?.message);
        throw new DeliveryError('No se pudo enviar el correo de activación.',
          `FIREBASE ${path} HTTP_${response.status}${code ? ` ${code}` : ''}`);
      }
      return await response.json() as Record<string, unknown>;
    } catch (error) {
      if (error instanceof DeliveryError) throw error;
      throw new DeliveryError('No se pudo enviar el correo de activación.',
        `FIREBASE ${path} ${networkDiagnostic(error)}`);
    }
  }

  async enviarCorreoInicial(uid: string, email: string, contrasena: string): Promise<void> {
    // El mismo intercambio REST que utiliza /auth/login; evita depender de
    // la firma de custom tokens solo para enviar un correo.
    const session = await this.firebaseRequest('signInWithPassword', {
      email, password: contrasena, returnSecureToken: true,
    });
    if (session.localId !== uid || typeof session.idToken !== 'string') {
      throw new DeliveryError('No se pudo enviar el correo de activación.',
        'FIREBASE signInWithPassword UID_MISMATCH');
    }
    await this.enviarCorreoConToken(session.idToken);
  }

  async enviarCorreoConToken(idToken: string): Promise<void> {
    await this.firebaseRequest('sendOobCode', { requestType: 'VERIFY_EMAIL', idToken });
  }

  private phoneHash(telefono: string): Buffer {
    return createHmac('sha256', Buffer.from(this.config.getOrThrow<string>('SMS_OTP_SECRET'), 'hex'))
      .update(`phone:${telefono}`).digest();
  }

  private codeHash(idPersona: number, telefono: string, codigo: string): Buffer {
    return createHmac('sha256', Buffer.from(this.config.getOrThrow<string>('SMS_OTP_SECRET'), 'hex'))
      .update(`otp:${idPersona}:${telefono}:${codigo}`).digest();
  }

  private async textbeeSend(telefono: string, codigo: string): Promise<void> {
    try {
      const response = await fetch('https://api.textbee.dev/api/v1/gateway/send-sms', {
        method: 'POST',
        headers: {
          'x-api-key': this.config.getOrThrow<string>('TEXTBEE_API_KEY'),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          recipients: [telefono],
          message: `Carman: tu codigo es ${codigo}. Caduca en 10 minutos. No lo compartas.`,
        }),
        signal: AbortSignal.timeout(10_000),
      });
      if (!response.ok) {
        const diagnostic = `TEXTBEE send-sms HTTP_${response.status}`;
        if (response.status === 429) {
          throw new DeliveryError('Se agotó la cuota de SMS. Espera antes de reenviar.', diagnostic);
        }
        throw new DeliveryError('No se pudo enviar el SMS desde el Android registrado en textbee.', diagnostic);
      }
      const payload = await response.json() as { data?: { success?: boolean; smsBatchId?: string } };
      if (payload.data?.success !== true || !payload.data.smsBatchId) {
        throw new DeliveryError('textbee no aceptó el SMS para su envío.',
          'TEXTBEE send-sms UNEXPECTED_RESPONSE');
      }
    } catch (error) {
      if (error instanceof DeliveryError) throw error;
      throw new DeliveryError('No se pudo contactar textbee.',
        `TEXTBEE send-sms ${networkDiagnostic(error)}`);
    }
  }

  private async telefonoRegistrado(uid: string, idPersona: number): Promise<string> {
    const [rows] = await this.database.execute<RowDataPacket[]>(
      'SELECT telefono FROM persona WHERE idPersona = ? AND uidFirebase = ? LIMIT 1',
      [idPersona, uid],
    );
    if (!rows.length) throw new BadRequestException('No existe un teléfono asociado a esta cuenta.');
    const telefono = rows[0].telefono as string;
    this.validarTelefono(telefono);
    return telefono;
  }

  async estado(uid: string, idPersona: number) {
    const user = await this.firebaseAuth.getUser(uid);
    const requiereVerificacion = user.customClaims?.requiresVerification === true;
    if (!requiereVerificacion) {
      return {
        requiereVerificacion: false, correoVerificado: user.emailVerified,
        telefonoVerificado: Boolean(user.phoneNumber), activada: true,
      };
    }
    const telefono = await this.telefonoRegistrado(uid, idPersona);
    const telefonoVerificado = user.phoneNumber === telefono;
    return {
      requiereVerificacion: true,
      correoVerificado: user.emailVerified,
      telefonoVerificado,
      activada: user.emailVerified && telefonoVerificado,
    };
  }

  async enviarCodigo(uid: string, idPersona: number): Promise<void> {
    this.comprobarConfiguracion();
    const user = await this.firebaseAuth.getUser(uid);
    if (!user.emailVerified) {
      throw new ForbiddenException('Verifica primero tu correo antes de solicitar el SMS.');
    }
    const telefono = await this.telefonoRegistrado(uid, idPersona);
    if (user.phoneNumber === telefono) return;
    if (user.phoneNumber) {
      throw new ConflictException('El número asociado a Firebase no coincide con el registrado en TiDB.');
    }
    const phoneHash = this.phoneHash(telefono);
    const codigo = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const connection = await this.database.getConnection();
    let transactionOpen = false;
    try {
      await connection.beginTransaction();
      transactionOpen = true;
      // El bloqueo se aplica al número, también si se usa otra cuenta.
      await connection.execute(
        `INSERT INTO phone_verification (phoneHash, idPersona)
         VALUES (?, ?) ON DUPLICATE KEY UPDATE phoneHash = phoneHash`,
        [phoneHash, idPersona],
      );
      const [rows] = await connection.execute<ChallengeRow[]>(
        `SELECT idPersona, sendCount,
           TIMESTAMPDIFF(SECOND, windowStart, NOW()) AS windowSeconds,
           TIMESTAMPDIFF(SECOND, lastSentAt, NOW()) AS secondsSinceLastSend
         FROM phone_verification WHERE phoneHash = ? FOR UPDATE`,
        [phoneHash],
      );
      const challenge = rows[0];
      if (!challenge) throw new ServiceUnavailableException('No se pudo preparar la verificación telefónica.');
      const resetWindow = Number(challenge.windowSeconds) >= 3600;
      if (!resetWindow && Number(challenge.idPersona) !== idPersona) {
        throw new HttpException('Espera antes de verificar este número con otra cuenta.',
          HttpStatus.TOO_MANY_REQUESTS);
      }
      if (!resetWindow && (Number(challenge.sendCount) >= 5
        || (challenge.secondsSinceLastSend !== null
          && Number(challenge.secondsSinceLastSend) < 60))) {
        throw new HttpException('Espera antes de solicitar otro código.', HttpStatus.TOO_MANY_REQUESTS);
      }
      await connection.execute(
        `UPDATE phone_verification SET idPersona = ?, codigoHash = ?,
           expiresAt = DATE_ADD(NOW(), INTERVAL 10 MINUTE), attempts = 0,
           windowStart = CASE WHEN ? THEN NOW() ELSE windowStart END,
           sendCount = ?, lastSentAt = NOW() WHERE phoneHash = ?`,
        [idPersona, this.codeHash(idPersona, telefono, codigo),
          resetWindow, resetWindow ? 1 : Number(challenge.sendCount) + 1, phoneHash],
      );
      await connection.commit();
      transactionOpen = false;
    } catch (error) {
      if (transactionOpen) await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
    // HTTP 200 significa "en cola", no que el Android o destinatario lo recibió.
    await this.textbeeSend(telefono, codigo);
  }

  async reenviarCodigo(uid: string, idPersona: number): Promise<void> {
    const status = await this.estado(uid, idPersona);
    if (!status.requiereVerificacion || status.telefonoVerificado) return;
    await this.enviarCodigo(uid, idPersona);
  }

  async confirmarCodigo(uid: string, idPersona: number, codigo: string): Promise<void> {
    this.comprobarConfiguracion();
    const telefono = await this.telefonoRegistrado(uid, idPersona);
    const user = await this.firebaseAuth.getUser(uid);
    if (user.phoneNumber === telefono) return;
    const phoneHash = this.phoneHash(telefono);
    const connection = await this.database.getConnection();
    let transactionOpen = false;
    try {
      await connection.beginTransaction();
      transactionOpen = true;
      const [rows] = await connection.execute<ChallengeRow[]>(
        `SELECT idPersona, codigoHash, attempts, expiresAt > NOW() AS codeValid
         FROM phone_verification WHERE phoneHash = ? FOR UPDATE`,
        [phoneHash],
      );
      const challenge = rows[0];
      if (!challenge || Number(challenge.idPersona) !== idPersona
        || !challenge.codigoHash || !Number(challenge.codeValid)
        || Number(challenge.attempts) >= 5) {
        throw new BadRequestException('El código es incorrecto o ha expirado.');
      }
      const expected = this.codeHash(idPersona, telefono, codigo);
      const actual = challenge.codigoHash;
      if (!Buffer.isBuffer(actual) || actual.length !== expected.length
        || !timingSafeEqual(actual, expected)) {
        await connection.execute(
          'UPDATE phone_verification SET attempts = attempts + 1 WHERE phoneHash = ?', [phoneHash],
        );
        await connection.commit();
        transactionOpen = false;
        throw new BadRequestException('El código es incorrecto o ha expirado.');
      }
      // Mantener el bloqueo hasta que Firebase confirme la asociación. Si falla,
      // la transacción se revierte y el código puede reintentarse.
      await this.firebaseAuth.updateUser(uid, { phoneNumber: telefono });
      await connection.execute(
        'UPDATE phone_verification SET codigoHash = NULL WHERE phoneHash = ?', [phoneHash],
      );
      await connection.commit();
      transactionOpen = false;
    } catch (error) {
      if (transactionOpen) await connection.rollback();
      if (error && typeof error === 'object' && 'code' in error
        && error.code === 'auth/phone-number-already-exists') {
        throw new ConflictException('El número ya pertenece a otra cuenta.');
      }
      if (error instanceof HttpException) throw error;
      throw new ServiceUnavailableException('No se pudo guardar la verificación del teléfono.');
    } finally {
      connection.release();
    }
  }
}
