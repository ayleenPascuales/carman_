import { Injectable, Inject, BadRequestException, NotFoundException } from '@nestjs/common';
import type { Pool, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { CrearVehiculoDto } from './dto/crearVehiculo.dto';
import { ActualizarVehiculoDto } from './dto/actualizarVehiculo.dto';
import { CambiarEstadoVehiculoDTO } from './dto/cambiarEstadoVehiculo.dto';
import { SolicitarRevisionDTO } from './dto/solicitarRevision.dto';

@Injectable()
export class VehiculosService {
    constructor(
        @Inject('DATABASE_CONNECTION')
        private readonly database: Pool) { }

    async crearVehiculo(idPersona: number, dto: CrearVehiculoDto) {

        const [propietarios] = await this.database.query<RowDataPacket[]>(
            `SELECT idPropietario FROM propietario WHERE idPersona = ?`, [idPersona]
        );
        if (propietarios.length === 0) {
            throw new NotFoundException('Actualmente no eres un propietario.');
        }
        const idPropietario = propietarios[0].idPropietario;

        const [vehiculos] = await this.database.query<RowDataPacket[]>(
            `SELECT idVehiculo FROM vehiculo WHERE placa = ?`, [dto.placa]
        );
        if (vehiculos.length > 0) {
            throw new BadRequestException('Ya existe un vehiculo registrado con esa placa. ');
        }

        const [puntoRecogida] = await this.database.query<RowDataPacket[]>(
            `SELECT idPunto FROM punto_autorizado WHERE idPunto = ? AND activo = TRUE`, [dto.idPuntoRecogida]
        );
        if (puntoRecogida.length === 0) {
            throw new NotFoundException('El punto de recogida seleccionado no existe. ')
        }

        const [puntoEntrega] = await this.database.query<RowDataPacket[]>(
            `SELECT idPunto FROM punto_autorizado WHERE idPunto = ? AND activo = TRUE`, [dto.idPuntoEntrega]
        );
        if (puntoEntrega.length === 0) {
            throw new NotFoundException('El punto de entrega seleccionado no existe. ')
        }

        const [resultado] = await this.database.query<ResultSetHeader>(
            `INSERT INTO vehiculo(
            idPropietario,
            placa,
            marca,
            modelo,
            anio,
            capacidad,
            tipoVehiculo,
            idPuntoRecogida,
            idPuntoEntrega,
            fotos, 
            descripcion,
            tarjetaPropiedad
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                idPropietario,
                dto.placa,
                dto.marca,
                dto.modelo,
                dto.anio,
                dto.capacidad,
                dto.tipoVehiculo,
                dto.idPuntoRecogida,
                dto.idPuntoEntrega,
                JSON.stringify(dto.fotos),
                dto.descripcion ?? null,
                dto.tarjetaPropiedad
            ]
        );
        return {
            mensaje: 'vehiculo registrado existosamente. ',
            idVehiculo: resultado.insertId
        }
    }

    //?OBTENER TODOS LOS VEHICULOS
    async obtenerMisVehiculos(idPersona: number) {
        const [propietarios] = await this.database.query<RowDataPacket[]>(
            `SELECT idPropietario FROM propietario WHERE idPersona = ?`, [idPersona]
        );
        if (propietarios.length === 0) {
            throw new NotFoundException('No tienes habilitada la función de propietario en tu cuenta. ');
        }
        const idPropietario = propietarios[0].idPropietario;

        const [vehiculos] = await this.database.query<RowDataPacket[]>(
            `SELECT * FROM vehiculo WHERE idPropietario = ?`, [idPropietario]
        );

        return vehiculos;
    }

    //? OBTENER INFORMACION COMPLETA Y ESPECIFICA DE UN VEHICULO PERO SOLO 
    //? DESDE EL PANEL DE PROPIETARIO
    async obtenerVehiculo(idPersona: number, idVehiculo: number) {
        const [vehiculos] = await this.database.query<RowDataPacket[]>(
            `SELECT v.* FROM vehiculo v
            INNER JOIN propietario p 
            ON v.idPropietario = p.idPropietario 
            WHERE v.idVehiculo = ? AND p.idPersona = ?`, [idVehiculo, idPersona]
        );
        if (vehiculos.length === 0) {
            throw new NotFoundException('El vehiculo no existe o no esta asociado a tu cuenta. ');
        }

        return vehiculos[0];
    }

    async actualizarVehiculo(idPersona: number, idVehiculo: number, dto: ActualizarVehiculoDto) {

        if (dto.fotos === undefined && dto.descripcion === undefined
            && dto.idPuntoRecogida === undefined && dto.idPuntoEntrega === undefined
        ) {
            throw new BadRequestException('Debes actualizar almenos un dato. ');
        }

        await this.obtenerVehiculo(idPersona, idVehiculo);
        if (dto.idPuntoRecogida !== undefined) {
            const [punto] = await this.database.query<RowDataPacket[]>(
                `SELECT idPunto FROM punto_autorizado 
                WHERE idPunto = ? AND activo = TRUE`, [dto.idPuntoRecogida]
            );
            if (punto.length === 0) {
                throw new NotFoundException('El punto de recogida no existe o esta inactivo. ');
            }
        }
        if (dto.idPuntoEntrega !== undefined) {
            const [punto] = await this.database.query<RowDataPacket[]>(
                `SELECT idPunto FROM punto_autorizado
                WHERE idPunto = ? AND activo = TRUE`, [dto.idPuntoEntrega]
            );
            if (punto.length === 0) {
                throw new NotFoundException('El punto de entrega no existe o esta inactivo.');
            }
        }

        await this.database.query(
            `UPDATE vehiculo SET fotos = COALESCE(?, fotos),
            descripcion = COALESCE(?, descripcion),
            idPuntoRecogida = COALESCE(?, idPuntoRecogida),
            idPuntoEntrega = COALESCE(?, idPuntoEntrega)
            WHERE idVehiculo = ?`,
            [
                dto.fotos !== undefined ? JSON.stringify(dto.fotos) : null,
                dto.descripcion !== undefined ? dto.descripcion : null,
                dto.idPuntoRecogida ?? null,
                dto.idPuntoEntrega ?? null,
                idVehiculo
            ]
        );

        return {
            mensaje: 'vehiculo actualizado correctamente.'
        }
    }

    async cambiarEstadoVehiculo(idPersona: number, idVehiculo: number, dto: CambiarEstadoVehiculoDTO) {
        await this.obtenerVehiculo(idPersona, idVehiculo);

        await this.database.query(
            `UPDATE vehiculo SET estado = ? WHERE idVehiculo = ?`, [dto.estado, idVehiculo]
        );

        return {
            mensaje: 'Estado del vehiculo actualizado. ',
            estado: dto.estado
        };
    }

    async solicitarRevision(idPersona: number, idVehiculo: number, dto: SolicitarRevisionDTO) {

        const vehiculo = await this.obtenerVehiculo(idPersona, idVehiculo);
        const estado = vehiculo.estado_solicitud_revision;
        if (estado === 'Pendiente') {
            throw new BadRequestException(
                'El vehículo ya tiene una solicitud de revisión pendiente. '
            );
        }
        if (estado === 'Aprobada' || estado === 'Finalizada') {
            if (vehiculo.fecha_aprobacion_revision) {
                const fechaAprobacion = new Date(vehiculo.fecha_aprobacion_revision);
                const fechaDisponible = new Date(fechaAprobacion);
                fechaDisponible.setMonth(fechaDisponible.getMonth() + 6);

                if (new Date() < fechaDisponible) {
                    throw new BadRequestException(
                        `Podrás solicitar otra revisión a partir del: ${fechaDisponible.toLocaleString('es-CO')}.`
                    );
                }
            }
        }

        await this.database.query(
            `UPDATE vehiculo SET estado = 'revision_pendiente',
            estado_solicitud_revision = 'Pendiente',
            motivo_solicitud_revision = ?,
            motivo_rechazo_revision = NULL
            WHERE idVehiculo = ?`, [dto.motivoSolicitud, idVehiculo]
        );
        return {
            mensaje: 'Solicitud de revisión técnica enviada. ',
            estado: 'Pendiente'
        };
    }

}
