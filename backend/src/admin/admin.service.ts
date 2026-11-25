import { Injectable, Inject, BadRequestException, NotFoundException } from "@nestjs/common";
import type { Pool, RowDataPacket } from "mysql2/promise";
import { RechazarRevisionDTO } from "./dto/rechazarRevision.dto";
import { ResultadoRevisionDTO } from "./dto/resultadoRevision.dto";

@Injectable()
export class AdminService {
    constructor(@Inject('DATABASE_CONNECTION')
    private readonly database: Pool) { }

    async obtenerUsuarios(rol?: string, buscar?: string) {
        let consulta = ` SELECT
            p.idPersona,
            p.documento,
            p.nombre,
            p.apellido,
            p.email,
            p.usuario,
            p.telefono,
            p.ciudad,
            p.estado,
            p.fechaHoraRegistro,
        
            EXISTS (SELECT 1 FROM cliente c WHERE c.idPersona = p.idPersona
            ) AS cliente,
            EXISTS (SELECT 1 FROM conductor co WHERE co.idPersona = p.idPersona
            ) AS conductor,
            EXISTS (SELECT 1 FROM propietario pr WHERE pr.idPersona = p.idPersona
            ) AS propietario
            FROM persona p WHERE 1 = 1` ;

        const parametros: any[] = [];

        if (rol) {
            const roles: Record<string, string> = {
                Cliente: 'cliente',
                Conductor: 'conductor',
                Propietario: 'propietario'
            };

            const tabla = roles[rol];
            if (!tabla) {
                throw new BadRequestException('El rol indicado no es valido.');
            }
            consulta += ` AND EXISTS (SELECT 1 FROM ${tabla} r WHERE r.idPersona = p.idPersona)`;
        }

        if (buscar) {
            consulta += ` AND (
                p.documento LIKE ?
                OR p.nombre LIKE ?
                OR p.apellido LIKE ?
                OR p.email LIKE ?
                OR p.usuario LIKE ?)`;

            const termino = `%${buscar}%`;
            parametros.push(
                termino,
                termino,
                termino,
                termino,
                termino
            );
        }
        consulta += ` ORDER BY p.fechaHoraRegistro DESC`;
        const [usuarios] = await this.database.query<RowDataPacket[]>(
            consulta, parametros
        );

        return {
            mensaje: 'Usuarios obtenidos.',
            total: usuarios.length,
            usuarios
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

    async suspenderUsuario(idPersona: number) {
        const [personas] = await this.database.execute<RowDataPacket[]>(
            `SELECT estado FROM persona WHERE idPersona = ? LIMIT 1`, [idPersona]
        );

        if (personas.length === 0) {
            throw new NotFoundException('Usuario no encontrado. ')
        }
        if (personas[0].estado === 'Suspendido') {
            throw new BadRequestException('El usuario ya está suspendido.')
        }
        await this.database.execute(
            `UPDATE persona SET estado = 'Suspendido' WHERE idPersona = ?`, [idPersona]
        );
        return {
            mensaje: 'Ususario suspendido correctamente. '
        }
    }

    async reactivarUsuario(idPersona: number) {
        const [personas] = await this.database.execute<RowDataPacket[]>(
            `SELECT estado FROM persona WHERE idPersona = ? LIMIT 1`, [idPersona]
        );
        if (personas.length === 0) {
            throw new NotFoundException('Usuario no encontrado. ')
        }
        if (personas[0].estado === 'Activo') {
            throw new BadRequestException('El usuario ya esta activo.')
        }
        await this.database.execute(
            `UPDATE persona SET estado = 'Activo',
            ultimaActividad = NOW() WHERE idPersona = ?`, [idPersona]
        );
        return {
            mensaje: 'usuario reactivado correctamente. '
        }
    }

    async obtenerSolicitudesRevision() {
        const [solicitudes] = await this.database.query<RowDataPacket[]>(
            `SELECT 
            v.idVehiculo,
            v.placa,
            v.marca,
            v.modelo,
            v.anio,
            v.estado,
            v.estado_solicitud_revision,
            v.motivo_solicitud_revision,
            
            p.idPersona,
            p.documento,
            p.nombre,
            p.apellido,
            p.email,
            p.telefono
            
            FROM vehiculo v INNER JOIN propietario pr
            ON v.idPropietario = pr.idPropietario 
            INNER JOIN persona p ON
            pr.idPersona = p.idPersona 
            
            WHERE v.estado_solicitud_revision = 'Pendiente'
            ORDER BY v.idVehiculo DESC`
        );
        return {
            mensaje: 'Solicitudes de revision obtenidas correctamente.',
            total: solicitudes.length,
            solicitudes
        };
    }

    async aceptarSolicitudRevision(idVehiculo: number) {
        const [vehiculos] = await this.database.query<RowDataPacket[]>(
            `SELECT estado_solicitud_revision FROM vehiculo WHERE idVehiculo = ?`, [idVehiculo]
        );

        if (vehiculos.length === 0) {
            throw new NotFoundException('vehiculo no encontrado. ')
        }
        if (vehiculos[0].estado_solicitud_revision !== 'Pendiente') {
            throw new BadRequestException(
                'Solo se pueden aceptar solicitudes que esten pendientes. '
            );
        }
        await this.database.query(
            `UPDATE vehiculo SET estado = 'En_mantenimiento',
            estado_solicitud_revision = 'Aprobada',
            fecha_aprobacion_revision = NOW(),
            motivo_rechazo_revision = NULL WHERE idVehiculo = ?`, [idVehiculo]
        );
        return {
            mensaje: 'Solicitud de revisión técnica aceptada. El vehiculo sera revisado por uno de nuestros mecanicos. ',
            estado: 'En_mantenimiento',
            estadoSolicitud: 'Aprobada'
        };
    }

    async rechazarSolicitudRevision(idVehiculo: number, dto: RechazarRevisionDTO) {
        const [vehiculos] = await this.database.query<RowDataPacket[]>(
            `SELECT estado_solicitud_revision FROM vehiculo WHERE idVehiculo = ?`, [idVehiculo]
        );
        if (vehiculos.length === 0) {
            throw new NotFoundException('Vehiculo no encontrado. ');
        }
        if (vehiculos[0].estado_solicitud_revision !== 'Pendiente') {
            throw new BadRequestException(
                'Solo se pueden rechazar solicitudes que esten pendientes. '
            );
        }
        await this.database.query(
            `UPDATE vehiculo SET estado = 'Activo',
            estado_solicitud_revision = 'Rechazada',
            motivo_rechazo_revision = ? WHERE idVehiculo = ?`, [dto.motivoRechazo, idVehiculo]
        );
        return {
            mensaje: 'Solicitud de revisión técnica rechazada. El vehiculo vuelve a estar disponible para reservas. ',
            estado: 'Activo',
            estadoSolicitud: 'Rechazada',
            motivoRechazo: dto.motivoRechazo
        };
    }

    async resultadoRevision(idVehiculo: number, dto: ResultadoRevisionDTO) {
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
                    dto.observaciones ?? null,
                    dto.necesitaMantenimiento,
                    dto.nombreTecnico,
                    dto.documentoTecnico
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
