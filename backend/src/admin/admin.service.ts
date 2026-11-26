import { Injectable, Inject, BadRequestException, NotFoundException } from "@nestjs/common";
import type { Pool, RowDataPacket, ResultSetHeader } from "mysql2/promise";
import { RechazarRevisionDTO } from "./dto/rechazarRevision.dto";
import { ResultadoRevisionDTO } from "./dto/resultadoRevision.dto";

@Injectable()
export class AdminService {
    constructor(@Inject('DATABASE_CONNECTION')
    private readonly database: Pool) { }

    private pagina(valor?: string): number {
        if (valor !== undefined && !/^[1-9]\d{0,3}$/.test(valor)) {
            throw new BadRequestException('La página debe estar entre 1 y 9999.');
        }
        return valor === undefined ? 1 : Number(valor);
    }

    async obtenerResumen() {
        const [usuarios] = await this.database.query<RowDataPacket[]>(
            `SELECT COUNT(*) AS total FROM persona`,
        );
        const [conductores] = await this.database.query<RowDataPacket[]>(
            `SELECT COUNT(*) AS total FROM conductor c
             INNER JOIN persona p ON p.idPersona = c.idPersona
             INNER JOIN licencia l ON l.idPersona = c.idPersona
             WHERE p.estado = 'Activo' AND c.disponibilidad = 1
             AND l.estado = 'Vigente' AND l.fechaExpiracion >= CURDATE()`,
        );
        const [vehiculos] = await this.database.query<RowDataPacket[]>(
            `SELECT COUNT(*) AS total FROM vehiculo WHERE estado = 'Activo'`,
        );
        const [revisiones] = await this.database.query<RowDataPacket[]>(
            `SELECT COUNT(*) AS total FROM vehiculo
             WHERE estado_solicitud_revision = 'Pendiente'`,
        );
        const [reservas] = await this.database.query<RowDataPacket[]>(
            `SELECT COUNT(*) AS total FROM reserva
             WHERE fechaHoraReserva >= CURDATE() AND fechaHoraReserva < CURDATE() + INTERVAL 1 DAY`,
        );
        return {
            usuarios: Number(usuarios[0].total),
            conductores: Number(conductores[0].total),
            vehiculos: Number(vehiculos[0].total),
            pendientes: Number(revisiones[0].total),
            reservasHoy: Number(reservas[0].total),
        };
    }

    async obtenerUsuarios(rol?: string, buscar?: string, estado?: string, paginaRaw?: string) {
        const pagina = this.pagina(paginaRaw);
        if (buscar !== undefined && buscar.trim().length > 80) {
            throw new BadRequestException('La búsqueda supera los 80 caracteres.');
        }
        if (estado && !['Activo', 'Suspendido', 'Inactivo'].includes(estado)) {
            throw new BadRequestException('El estado indicado no es válido.');
        }
        let condiciones = ` FROM persona p WHERE 1 = 1`;
        const parametros: string[] = [];
        if (rol) {
            const roles: Record<string, string> = {
                Cliente: 'cliente',
                Conductor: 'conductor',
                Propietario: 'propietario',
                Administrador: 'administrador',
            };
            const tabla = roles[rol];
            if (!tabla) {
                throw new BadRequestException('El rol indicado no es válido.');
            }
            condiciones += ` AND EXISTS (SELECT 1 FROM ${tabla} r
                WHERE r.idPersona = p.idPersona
                ${rol === 'Administrador' ? "AND r.estado = 'Activo'" : ''})`;
        }
        if (estado) {
            condiciones += ` AND p.estado = ?`;
            parametros.push(estado);
        }
        if (buscar?.trim()) {
            condiciones += ` AND (p.nombre LIKE ? OR p.apellido LIKE ?
                OR p.email LIKE ? OR p.usuario LIKE ?)`;
            const termino = `%${buscar.trim()}%`;
            parametros.push(termino, termino, termino, termino);
        }
        const [totales] = await this.database.query<RowDataPacket[]>(
            `SELECT COUNT(*) AS total ${condiciones}`, parametros,
        );
        const [usuarios] = await this.database.query<RowDataPacket[]>(
            `SELECT
            p.idPersona,
            p.nombre,
            p.apellido,
            p.email,
            p.ciudad,
            p.estado,
            p.fechaHoraRegistro,
            EXISTS(SELECT 1 FROM cliente c WHERE c.idPersona = p.idPersona) AS cliente,
            EXISTS(SELECT 1 FROM conductor c WHERE c.idPersona = p.idPersona) AS conductor,
            EXISTS(SELECT 1 FROM propietario pr WHERE pr.idPersona = p.idPersona) AS propietario,
            EXISTS(SELECT 1 FROM administrador a WHERE a.idPersona = p.idPersona
                AND a.estado = 'Activo') AS administrador
            ${condiciones}
            ORDER BY p.fechaHoraRegistro DESC, p.idPersona DESC
            LIMIT 21 OFFSET ${(pagina - 1) * 20}`, parametros,
        );
        return {
            mensaje: 'Usuarios obtenidos.',
            total: Number(totales[0].total),
            pagina,
            hayMas: usuarios.length > 20,
            usuarios: usuarios.slice(0, 20),
        };
    }

    async obtenerPerfil(idPersona: number) {
        const [personas] = await this.database.execute<RowDataPacket[]>(
            `SELECT 
                idPersona,
                documento,
                nombre,
                apellido,
                email,
                usuario,
                telefono,
                fechaNacimiento,
                ciudad,
                direccion,
                fotoPerfil,
                estado,
                emailVerificado,
                fechaHoraRegistro
                FROM persona WHERE idPersona = ?`, [idPersona],
        );

        if (personas.length === 0) {
            throw new NotFoundException('Usuario no encontrado.')
        }
        const [roles] = await this.database.execute<RowDataPacket[]>(
            `SELECT 
                EXISTS(SELECT 1 FROM cliente WHERE idPersona = ?) AS cliente,
                EXISTS(SELECT 1 FROM conductor WHERE idPersona = ?) AS conductor,
                EXISTS(SELECT 1 FROM propietario WHERE idPersona = ?) AS propietario,
                EXISTS(SELECT 1 FROM administrador WHERE idPersona = ? AND estado = 'Activo') AS administrador`,
            [idPersona, idPersona, idPersona, idPersona],
        );
        return {
            ...personas[0],
            roles: {
                cliente: Boolean(roles[0].cliente),
                conductor: Boolean(roles[0].conductor),
                propietario: Boolean(roles[0].propietario),
                administrador: Boolean(roles[0].administrador),
            },
        };
    }

    async suspenderUsuario(idPersona: number, actorIdPersona: number) {
        if (idPersona === actorIdPersona) {
            throw new BadRequestException('No puedes suspender tu propia cuenta administrativa.');
        }
        const connection = await this.database.getConnection();
        try {
            await connection.beginTransaction();
            const [personas] = await connection.execute<RowDataPacket[]>(
                `SELECT estado FROM persona WHERE idPersona = ? FOR UPDATE`, [idPersona],
            );
            if (!personas.length) throw new NotFoundException('Usuario no encontrado.');
            if (personas[0].estado !== 'Activo') {
                throw new BadRequestException('Solo puedes suspender una cuenta activa.');
            }
            const [administradores] = await connection.execute<RowDataPacket[]>(
                `SELECT idPersona FROM administrador WHERE idPersona = ? AND estado = 'Activo'`,
                [idPersona],
            );
            if (administradores.length) {
                throw new BadRequestException(
                    'No se puede suspender una cuenta administrativa desde esta operación.',
                );
            }
            await connection.execute(
                `UPDATE persona SET estado = 'Suspendido' WHERE idPersona = ?`, [idPersona],
            );
            await connection.commit();
            return { mensaje: 'Usuario suspendido correctamente.' };
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }
    }

    async reactivarUsuario(idPersona: number) {
        const connection = await this.database.getConnection();
        try {
            await connection.beginTransaction();
            const [personas] = await connection.execute<RowDataPacket[]>(
                `SELECT estado FROM persona WHERE idPersona = ? FOR UPDATE`, [idPersona],
            );
            if (!personas.length) throw new NotFoundException('Usuario no encontrado.');
            if (personas[0].estado !== 'Suspendido') {
                throw new BadRequestException('Solo puedes reactivar una cuenta suspendida.');
            }
            await connection.execute(
                `UPDATE persona SET estado = 'Activo', ultimaActividad = NOW()
                 WHERE idPersona = ?`, [idPersona],
            );
            await connection.commit();
            return { mensaje: 'Usuario reactivado correctamente.' };
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }
    }

    async obtenerSolicitudesRevision(estado = 'Pendiente', paginaRaw?: string) {
        if (!['Pendiente', 'Aprobada'].includes(estado)) {
            throw new BadRequestException('Solo pueden listarse revisiones pendientes o aprobadas.');
        }
        const pagina = this.pagina(paginaRaw);
        const [totales] = await this.database.query<RowDataPacket[]>(
            `SELECT COUNT(*) AS total FROM vehiculo
             WHERE estado_solicitud_revision = ?`, [estado],
        );
        const [solicitudes] = await this.database.query<RowDataPacket[]>(
            `SELECT v.idVehiculo, v.placa, v.marca, v.modelo, v.anio,
                    v.estado, v.estado_solicitud_revision,
                    v.motivo_solicitud_revision, v.fecha_aprobacion_revision,
                    p.nombre AS nombrePropietario, p.apellido AS apellidoPropietario
             FROM vehiculo v
             INNER JOIN propietario pr ON pr.idPropietario = v.idPropietario
             INNER JOIN persona p ON p.idPersona = pr.idPersona
             WHERE v.estado_solicitud_revision = ?
             ORDER BY v.idVehiculo DESC LIMIT 21 OFFSET ${(pagina - 1) * 20}`,
            [estado],
        );
        return {
            total: Number(totales[0].total),
            pagina,
            hayMas: solicitudes.length > 20,
            solicitudes: solicitudes.slice(0, 20),
        };
    }

    async obtenerRevision(idVehiculo: number) {
        const [solicitudes] = await this.database.query<RowDataPacket[]>(
            `SELECT v.idVehiculo, v.placa, v.marca, v.modelo, v.anio,
                    v.estado, v.estado_solicitud_revision,
                    v.motivo_solicitud_revision, v.motivo_rechazo_revision,
                    v.fecha_aprobacion_revision,
                    p.nombre AS nombrePropietario, p.apellido AS apellidoPropietario
             FROM vehiculo v
             INNER JOIN propietario pr ON pr.idPropietario = v.idPropietario
             INNER JOIN persona p ON p.idPersona = pr.idPersona
             WHERE v.idVehiculo = ?`, [idVehiculo],
        );
        if (!solicitudes.length) throw new NotFoundException('Vehículo no encontrado.');
        return solicitudes[0];
    }

    async aceptarSolicitudRevision(idVehiculo: number) {
        const [resultado] = await this.database.query<ResultSetHeader>(
            `UPDATE vehiculo SET estado = 'En_mantenimiento',
            estado_solicitud_revision = 'Aprobada',
            fecha_aprobacion_revision = NOW(),
            motivo_rechazo_revision = NULL
            WHERE idVehiculo = ? AND estado_solicitud_revision = 'Pendiente'
            AND estado = 'revision_pendiente'`, [idVehiculo],
        );
        if (resultado.affectedRows !== 1) {
            throw new BadRequestException(
                'La revisión ya cambió. Actualiza la lista antes de volver a actuar.',
            );
        }
        return {
            mensaje: 'Solicitud de revisión técnica aceptada. El vehiculo sera revisado por uno de nuestros mecanicos. ',
            estado: 'En_mantenimiento',
            estadoSolicitud: 'Aprobada'
        };
    }

    async rechazarSolicitudRevision(idVehiculo: number, dto: RechazarRevisionDTO) {
        const motivo = dto.motivoRechazo?.trim();
        if (!motivo || motivo.length > 500) {
            throw new BadRequestException('Indica un motivo de rechazo válido.');
        }
        const [resultado] = await this.database.query<ResultSetHeader>(
            `UPDATE vehiculo SET estado = 'inactivo',
            estado_solicitud_revision = 'Rechazada',
            motivo_rechazo_revision = ?
            WHERE idVehiculo = ? AND estado_solicitud_revision = 'Pendiente'
            AND estado = 'revision_pendiente'`, [motivo, idVehiculo],
        );
        if (resultado.affectedRows !== 1) {
            throw new BadRequestException(
                'La revisión ya cambió. Actualiza la lista antes de volver a actuar.',
            );
        }
        return {
            mensaje: 'Revisión rechazada; el vehículo queda inactivo hasta que el propietario lo reactive.',
            estado: 'inactivo',
            estadoSolicitud: 'Rechazada',
            motivoRechazo: motivo,
        };
    }

    async resultadoRevision(idVehiculo: number, dto: ResultadoRevisionDTO) {
        if (!dto.nombreTecnico?.trim() || !dto.documentoTecnico?.trim()
            || !dto.observaciones?.trim()) {
            throw new BadRequestException(
                'Indica técnico, documento y observaciones reales para finalizar.',
            );
        }
        const conexion = await this.database.getConnection();

        try {
            await conexion.beginTransaction();
            const [vehiculos] = await conexion.execute<RowDataPacket[]>(
                `SELECT estado, estado_solicitud_revision
                FROM vehiculo WHERE idVehiculo = ? FOR UPDATE`, [idVehiculo]
            );
            if (vehiculos.length === 0) {
                throw new NotFoundException('Vehiculo no encontrado.');
            }
            if (vehiculos[0].estado !== 'En_mantenimiento' || vehiculos[0].estado_solicitud_revision !== 'Aprobada') {
                throw new BadRequestException(
                    'El vehiculo no tiene una revisión aprobada para finalizar.'
                );
            }
            if (dto.necesitaMantenimiento && dto.estadoFinal === 'Activo') {
                throw new BadRequestException(
                    'El vehiculo necesita mantenimiento y no puede estar activo. '
                )
            }

            await conexion.execute(
                `INSERT INTO estado_tecnico_vehiculo(
                idVehiculo,
                kilometraje,
                estadoMotor,
                estadoFrenos,
                estadoLlantas,
                estadoBateria,
                observaciones,
                necesitaMantenimiento,
                nombreTecnico,
                documentoTecnico
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                [
                    idVehiculo,
                    dto.kilometraje ?? null,
                    dto.estadoMotor ?? null,
                    dto.estadoFrenos ?? null,
                    dto.estadoLlantas ?? null,
                    dto.estadoBateria ?? null,
                     dto.observaciones.trim(),
                     dto.necesitaMantenimiento,
                     dto.nombreTecnico.trim(),
                     dto.documentoTecnico.trim(),
                ]
            );
            await conexion.execute(
                `UPDATE vehiculo SET estado = ?, 
                estado_solicitud_revision = 'Finalizada' WHERE idvehiculo = ?`, [dto.estadoFinal, idVehiculo]
            );
            await conexion.commit();
            return {
                mensaje: 'Revision técnica finalizada correctamente. ',
                idVehiculo,
                estado: dto.estadoFinal,
                estadoSolicitud: 'Finalizada'
            };
        } catch (error) {
            await conexion.rollback();
            throw error;
        } finally {
            conexion.release();
        }
    }


}
