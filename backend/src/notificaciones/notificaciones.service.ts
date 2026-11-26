import { Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Pool, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { VerificationService } from '../auth/verification.service';

export type EventoReserva =
  | 'solicitada' | 'actualizada' | 'cancelada' | 'conductorAsignado'
  | 'conductorAcepto' | 'sinConductor' | 'confirmada'
  | 'pagoAprobado' | 'pagoRechazado' | 'pagoCancelado'
  | 'iniciada' | 'finalizada';

interface DestinatariosReserva extends RowDataPacket {
  cliente: number;
  propietario: number;
  conductor: number | null;
}

@Injectable()
export class NotificacionesService {
  private readonly logger = new Logger(NotificacionesService.name);

  constructor(
    @Inject('DATABASE_CONNECTION') private readonly database: Pool,
    private readonly config: ConfigService,
    private readonly verification: VerificationService,
  ) {}

  async listar(idPersona: number) {
    const [notificaciones] = await this.database.execute<RowDataPacket[]>(
      `SELECT idNotificacion, idReserva, idPago, tipo, mensaje, fechaHoraEnvio, leida
       FROM notificacion WHERE idPersonaDestino = ?
       ORDER BY fechaHoraEnvio DESC, idNotificacion DESC LIMIT 100`,
      [idPersona],
    );
    return {
      notificaciones: notificaciones.map((item) => ({
        ...item,
        leida: Boolean(item.leida),
        rutaAccion: item.idReserva ? `/trip/${item.idReserva}` : null,
      })),
    };
  }

  async marcarLeida(idPersona: number, idNotificacion: number) {
    const [resultado] = await this.database.execute<ResultSetHeader>(
      `UPDATE notificacion SET leida = 1
       WHERE idNotificacion = ? AND idPersonaDestino = ?`,
      [idNotificacion, idPersona],
    );
    if (!resultado.affectedRows) {
      throw new NotFoundException('La notificación no existe.');
    }
    return { mensaje: 'Notificación leída.' };
  }

  async marcarTodasLeidas(idPersona: number) {
    await this.database.execute(
      'UPDATE notificacion SET leida = 1 WHERE idPersonaDestino = ? AND leida = 0',
      [idPersona],
    );
    return { mensaje: 'Notificaciones leídas.' };
  }

  // Los avisos se envían después de confirmar la operación principal. Un fallo
  // externo no revierte una reserva/pago ni expone teléfono, token o respuesta.
  async avisarPersona(
    idPersona: number, tipo: string, mensaje: string,
    opciones: { idReserva?: number; idPago?: number; sms?: boolean } = {},
  ): Promise<void> {
    try {
      await this.database.execute(
        `INSERT INTO notificacion (idPersonaDestino, idReserva, idPago, tipo, mensaje)
         VALUES (?, ?, ?, ?, ?)`,
        [idPersona, opciones.idReserva ?? null, opciones.idPago ?? null, tipo, mensaje],
      );
      if (opciones.sms) {
        await this.enviarSmsVerificado(idPersona, mensaje);
      }
    } catch {
      this.logger.warn('No se pudo registrar o entregar un aviso; la operación principal se conserva.');
    }
  }

  async avisarReserva(
    idReserva: number, evento: EventoReserva, idPago?: number,
  ): Promise<void> {
    try {
      const [rows] = await this.database.execute<DestinatariosReserva[]>(
        `SELECT c.idPersona AS cliente, pr.idPersona AS propietario,
                co.idPersona AS conductor
         FROM reserva r
         INNER JOIN cliente c ON c.idCliente = r.idCliente
         INNER JOIN vehiculo v ON v.idVehiculo = r.idVehiculo
         INNER JOIN propietario pr ON pr.idPropietario = v.idPropietario
         LEFT JOIN conductor co ON co.idConductor = r.idConductor
         WHERE r.idReserva = ?`,
        [idReserva],
      );
      if (!rows.length) return;
      const { cliente, propietario, conductor } = rows[0];
      const avisos: { id: number; texto: string; sms?: boolean }[] = [];
      switch (evento) {
        case 'solicitada':
          avisos.push(
            { id: cliente, texto: `Recibimos tu solicitud de reserva #${idReserva}.` },
            { id: propietario, texto: `Hay una nueva solicitud para la reserva #${idReserva}.` },
          );
          if (conductor) avisos.push({ id: conductor, texto: `Tienes una solicitud de conducción para la reserva #${idReserva}.` });
          break;
        case 'actualizada':
          avisos.push(
            { id: cliente, texto: `Se actualizó tu reserva #${idReserva}.` },
            { id: propietario, texto: `Se actualizó la reserva #${idReserva}.` },
          );
          if (conductor) avisos.push({ id: conductor, texto: `Se actualizó el servicio de la reserva #${idReserva}.` });
          break;
        case 'cancelada':
          avisos.push(
            { id: cliente, texto: `Tu reserva #${idReserva} fue cancelada. Consulta su estado en la app.`, sms: true },
            { id: propietario, texto: `La reserva #${idReserva} fue cancelada.` },
          );
          if (conductor) avisos.push({ id: conductor, texto: `La reserva #${idReserva} fue cancelada.` });
          break;
        case 'conductorAsignado':
          if (conductor) avisos.push({ id: conductor, texto: `Tienes una solicitud de conducción para la reserva #${idReserva}.` });
          avisos.push({ id: cliente, texto: `Se asignó un conductor a tu reserva #${idReserva}.` });
          break;
        case 'conductorAcepto':
          avisos.push({ id: cliente, texto: `El conductor aceptó tu reserva #${idReserva}.` });
          break;
        case 'sinConductor':
          avisos.push({ id: cliente, texto: `No hay conductor disponible para la reserva #${idReserva}. Revisa tus opciones en la app.`, sms: true });
          break;
        case 'confirmada':
          avisos.push(
            { id: cliente, texto: `Tu reserva #${idReserva} está confirmada. Consulta los detalles en la app.`, sms: true },
            { id: propietario, texto: `La reserva #${idReserva} está confirmada.` },
          );
          break;
        case 'iniciada':
          avisos.push(
            { id: cliente, texto: `Tu reserva #${idReserva} está en curso.` },
            { id: propietario, texto: `La reserva #${idReserva} inició.` },
          );
          if (conductor) avisos.push({ id: conductor, texto: `Iniciaste el servicio de la reserva #${idReserva}.` });
          break;
        case 'finalizada':
          avisos.push(
            { id: cliente, texto: `La reserva #${idReserva} finalizó. Ya puedes calificar el servicio.` },
            { id: propietario, texto: `La reserva #${idReserva} finalizó.` },
          );
          if (conductor) avisos.push({ id: conductor, texto: `Finalizaste el servicio de la reserva #${idReserva}.` });
          break;
        case 'pagoAprobado':
          avisos.push({ id: cliente, texto: `Se aprobó un pago de la reserva #${idReserva}. Consulta el detalle en la app.`, sms: true });
          break;
        case 'pagoRechazado':
          avisos.push({ id: cliente, texto: `No se aprobó un pago de la reserva #${idReserva}. Revisa el estado en la app.`, sms: true });
          break;
        case 'pagoCancelado':
          avisos.push({ id: cliente, texto: `Se canceló un pago de la reserva #${idReserva}. Revisa el estado en la app.`, sms: true });
          break;
      }
      const ids = new Set<number>();
      for (const aviso of avisos) {
        const id = Number(aviso.id);
        if (!Number.isInteger(id) || ids.has(id)) continue;
        ids.add(id);
        await this.avisarPersona(id, evento.startsWith('pago') ? 'Pago' : 'Reserva',
          aviso.texto, { idReserva, idPago, sms: aviso.sms });
      }
    } catch {
      this.logger.warn('No se pudo preparar un aviso de reserva.');
    }
  }

  private async enviarSmsVerificado(idPersona: number, mensaje: string): Promise<void> {
    const apiKey = this.config.get<string>('TEXTBEE_API_KEY')?.trim();
    if (!apiKey || apiKey.startsWith('reemplazar_')) return;
    const [personas] = await this.database.execute<RowDataPacket[]>(
      'SELECT uidFirebase, telefono FROM persona WHERE idPersona = ? AND estado = ? LIMIT 1',
      [idPersona, 'Activo'],
    );
    const persona = personas[0];
    if (!persona?.uidFirebase || !/^\+[1-9]\d{7,14}$/.test(persona.telefono)) return;
    if (!await this.verification.telefonoConfirmadoParaAvisos(
      persona.uidFirebase, persona.telefono,
    )) return;
    const respuesta = await fetch('https://api.textbee.dev/api/v1/gateway/send-sms', {
      method: 'POST',
      headers: { 'x-api-key': apiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({ recipients: [persona.telefono], message: `Carman: ${mensaje}` }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!respuesta.ok) throw new Error('No se pudo poner el SMS en cola.');
    const resultado = await respuesta.json().catch(() => null) as
      { data?: { success?: boolean; smsBatchId?: string } } | null;
    if (resultado?.data?.success !== true || !resultado.data.smsBatchId) {
      throw new Error('El proveedor no aceptó el SMS.');
    }
  }
}
