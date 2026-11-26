import { Injectable, Inject, BadRequestException, NotFoundException } from '@nestjs/common';
import type { Pool, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { CrearVehiculoDto } from './dto/crearVehiculo.dto';
import { ActualizarVehiculoDto } from './dto/actualizarVehiculo.dto';
import { CambiarEstadoVehiculoDTO } from './dto/cambiarEstadoVehiculo.dto';
import { SolicitarRevisionDTO } from './dto/solicitarRevision.dto';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
import { CatalogoQueryDto } from './dto/catalogo-query.dto';

function fechaHoraCatalogo(valor: string): string {
    const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$/.exec(valor);
    if (!match) throw new BadRequestException('Fecha de búsqueda inválida.');
    const [year, month, day, hour, minute, second] = match.slice(1).map(Number);
    const fecha = new Date(Date.UTC(year, month - 1, day, hour, minute, second));
    if (year < 2000 || year > 2100 || fecha.getUTCFullYear() !== year ||
        fecha.getUTCMonth() + 1 !== month || fecha.getUTCDate() !== day ||
        fecha.getUTCHours() !== hour || fecha.getUTCMinutes() !== minute ||
        fecha.getUTCSeconds() !== second) {
        throw new BadRequestException('Fecha de búsqueda inválida.');
    }
    return valor.replace('T', ' ');
}

@Injectable()
export class VehiculosService {
    constructor(
        @Inject('DATABASE_CONNECTION')
        private readonly database: Pool,
        private readonly notificaciones: NotificacionesService) { }

    async crearVehiculo(idPersona: number, dto: CrearVehiculoDto) {
        const connection = await this.database.getConnection();
        let registrado = false;

        try {
            await connection.beginTransaction();

            const [personas] = await connection.execute<RowDataPacket[]>(
                `SELECT idPersona FROM persona WHERE idPersona = ? FOR UPDATE`, [idPersona]
            );
            if (personas.length === 0) {
                throw new NotFoundException('El usuario no existe. ');
            }

            const [propietarios] = await connection.execute<RowDataPacket[]>(
                `SELECT idPropietario FROM propietario WHERE idPersona = ? FOR UPDATE`, [idPersona]
            );
            let idPropietario: number;
            if (propietarios.length > 0) {
                idPropietario = propietarios[0].idPropietario;
            } else {
                const [nuevoPropietario] = await connection.execute<ResultSetHeader>(
                    `INSERT INTO propietario (idPersona) VALUES (?)`, [idPersona]
                );
                idPropietario = nuevoPropietario.insertId;
            }

            const [vehiculos] = await connection.execute<RowDataPacket[]>(
                `SELECT idVehiculo FROM vehiculo WHERE placa = ?`, [dto.placa]
            );
            if (vehiculos.length > 0) {
                throw new BadRequestException('Ya existe un vehículo registrado con esta placa.');
            }

            const [puntoRecogida] = await connection.execute<RowDataPacket[]>(
                `SELECT idPunto FROM punto_autorizado WHERE idPunto = ? AND activo = TRUE`,
                [dto.idPuntoRecogida]
            );
            if (puntoRecogida.length === 0) {
                throw new NotFoundException('El punto de recogida seleccionado no existe.');
            }

            const [puntoEntrega] = await connection.execute<RowDataPacket[]>(
                `SELECT idPunto FROM punto_autorizado WHERE idPunto = ? AND activo = TRUE`,
                [dto.idPuntoEntrega]
            );
            if (puntoEntrega.length === 0) {
                throw new NotFoundException('El punto de entrega seleccionado no existe.');
            }

            const [resultado] = await connection.execute<ResultSetHeader>(
                `INSERT INTO vehiculo(
                idPropietario,
                placa,
                marca,
                modelo,
                anio,
                capacidad,
                tipoVehiculo,
                precioPorDia,
                idPuntoRecogida,
                idPuntoEntrega,
                fotos,
                descripcion,
                tarjetaPropiedad
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                [
                    idPropietario,
                    dto.placa,
                    dto.marca,
                    dto.modelo,
                    dto.anio,
                    dto.capacidad,
                    dto.tipoVehiculo,
                    dto.precioPorDia ?? null,
                    dto.idPuntoRecogida,
                    dto.idPuntoEntrega,
                    JSON.stringify(dto.fotos),
                    dto.descripcion ?? null,
                    dto.tarjetaPropiedad
                ]
            );
            await connection.commit();
            registrado = true;
            return {
                mensaje: 'vehiculo registrado existosamente. ',
                idVehiculo: resultado.insertId
            };
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
            if (registrado) {
                await this.notificaciones.avisarPersona(
                    idPersona, 'Vehiculo', 'Tu vehículo fue registrado y está disponible en tu panel.',
                );
            }
        }
    }
    // Vista pública mínima: no enviar placa, tarjeta de propiedad ni datos
    // personales del propietario. El punto es público y está autorizado.
    async catalogo(filtros: CatalogoQueryDto | string = {}, idVehiculo?: number) {
        const query = typeof filtros === 'string' ? { ciudad: filtros } : filtros;
        const ciudad = query.ciudad?.trim();
        if (ciudad !== undefined && (typeof ciudad !== 'string' || ciudad.length > 50)) {
            throw new BadRequestException('Ciudad inválida.');
        }
        const condiciones: string[] = [];
        const parametros: (string | number)[] = [];
        if (idVehiculo !== undefined) {
            condiciones.push('v.idVehiculo = ?');
            parametros.push(idVehiculo);
        }
        if (ciudad) {
            condiciones.push('p.ciudad = ?');
            parametros.push(ciudad);
        }
        if (query.texto?.trim()) {
            condiciones.push('LOWER(CONCAT(v.marca, \' \', v.modelo)) LIKE ?');
            const texto = query.texto.trim().toLowerCase().replace(/[\\%_]/g, '\\$&');
            parametros.push(`%${texto}%`);
        }
        const categorias: Record<string, string[]> = {
            electric: ['electric', 'eléctrico', 'eléctricos', 'electrico', 'electricos'],
            suv: ['suv', 'camioneta', 'camionetas'],
            sport: ['sport', 'deportivo', 'deportivos'],
            family: ['family', 'familiar', 'familiares'],
            premium: ['premium', 'lujo', 'gama alta'],
        };
        if (query.categoria && query.categoria !== 'all') {
            const tipos = categorias[query.categoria];
            if (!tipos) throw new BadRequestException('Categoría inválida.');
            condiciones.push(`LOWER(v.tipoVehiculo) IN (${tipos.map(() => '?').join(', ')})`);
            parametros.push(...tipos);
        }
        if (query.precioMaximo !== undefined) {
            const maximo = Number(query.precioMaximo);
            if (!Number.isFinite(maximo) || maximo <= 0 || maximo > 99999999.99) {
                throw new BadRequestException('Precio máximo inválido.');
            }
            condiciones.push('v.precioPorDia <= ?');
            parametros.push(maximo);
        }
        if (query.plazasMinimas !== undefined) {
            const plazas = Number(query.plazasMinimas);
            if (!Number.isSafeInteger(plazas) || plazas < 1 || plazas > 99) {
                throw new BadRequestException('Plazas mínimas inválidas.');
            }
            condiciones.push('v.capacidad >= ?');
            parametros.push(plazas);
        }
        if ((query.fechaInicio === undefined) !== (query.fechaFin === undefined)) {
            throw new BadRequestException('Indica inicio y fin para buscar disponibilidad.');
        }
        if (query.fechaInicio && query.fechaFin) {
            const inicio = fechaHoraCatalogo(query.fechaInicio);
            const fin = fechaHoraCatalogo(query.fechaFin);
            if (fin <= inicio) {
                throw new BadRequestException('El intervalo de búsqueda no es válido.');
            }
            condiciones.push(`NOT EXISTS (
                SELECT 1 FROM reserva r WHERE r.idVehiculo = v.idVehiculo
                AND r.estado IN ('Pendiente', 'Confirmada', 'EnCurso')
                AND TIMESTAMP(r.fechaInicioServicio, r.horaInicioServicio) < ?
                AND TIMESTAMP(r.fechaFinServicio, r.horaFinServicio) > ?
            )`);
            parametros.push(fin, inicio);
        }
        const ordenes: Record<string, string> = {
            relevance: 'v.idVehiculo DESC',
            priceAsc: 'v.precioPorDia ASC, v.idVehiculo DESC',
            priceDesc: 'v.precioPorDia DESC, v.idVehiculo DESC',
        };
        const orden = ordenes[query.orden ?? 'relevance'];
        if (!orden) throw new BadRequestException('Orden inválido.');
        const pagina = query.pagina === undefined ? 1 : Number(query.pagina);
        if (!Number.isSafeInteger(pagina) || pagina < 1 || pagina > 9999) {
            throw new BadRequestException('Página inválida.');
        }
        const limite = idVehiculo === undefined ? 20 : 1;
        // Una fila adicional permite saber si hay página siguiente sin
        // contar todas las reservas o exponer IDs de otras cuentas.
        const offset = idVehiculo === undefined ? (pagina - 1) * limite : 0;
        // TiDB no admite estos marcadores de LIMIT/OFFSET en el preparado.
        // Ambos valores son enteros calculados tras validar pagina y limite;
        // los filtros de usuario permanecen parametrizados.
        const filas = idVehiculo === undefined ? limite + 1 : limite;
        const [vehiculos] = await this.database.execute<RowDataPacket[]>(
            `SELECT v.idVehiculo, v.marca, v.modelo, v.anio, v.capacidad,
                    v.tipoVehiculo, v.precioPorDia, v.estado, v.fotos, v.descripcion,
                    p.idPunto, p.nombre AS puntoNombre, p.direccion AS puntoDireccion,
                    p.ciudad, p.latitud, p.longitud
             FROM vehiculo v JOIN punto_autorizado p ON p.idPunto = v.idPuntoRecogida
             WHERE v.estado = 'Activo' AND v.precioPorDia > 0 AND p.activo = 1
              ${condiciones.map(condicion => `AND ${condicion}`).join('\n')}
               ORDER BY ${orden} LIMIT ${filas} OFFSET ${offset}`,
            parametros,
        );
        const hayMas = idVehiculo === undefined && vehiculos.length > limite;
        const resultado = vehiculos.slice(0, limite).map((v) => ({
            idVehiculo: v.idVehiculo, marca: v.marca, modelo: v.modelo,
            anio: v.anio, capacidad: v.capacidad, tipoVehiculo: v.tipoVehiculo,
            precioPorDia: v.precioPorDia, estado: v.estado,
            fotos: v.fotos, descripcion: v.descripcion, ciudad: v.ciudad,
            ubicacion: v.puntoNombre,
            puntoRecogida: {
                id: v.idPunto, nombre: v.puntoNombre,
                direccion: v.puntoDireccion, ciudad: v.ciudad,
                latitud: Number(v.latitud), longitud: Number(v.longitud),
            },
        }));
        if (idVehiculo !== undefined) {
            if (resultado.length === 0) throw new NotFoundException('Vehículo no disponible.');
            return resultado[0];
        }
        return { vehiculos: resultado, pagina, hayMas };
    }
    //?OBTENER TODOS LOS VEHICULOS PANEL PROPIETARIO
    async obtenerMisVehiculos(idPersona: number) {
        const [propietarios] = await this.database.query<RowDataPacket[]>(
            `SELECT idPropietario FROM propietario WHERE idPersona = ?`, [idPersona]
        );
        if (propietarios.length === 0) {
            throw new NotFoundException('No tienes vehiculos publicados.');
        }

        const idPropietario = propietarios[0].idPropietario;
        const [vehiculos] = await this.database.query<RowDataPacket[]>(
            `SELECT v.*, punto.ciudad, punto.nombre AS ubicacion
             FROM vehiculo v
             LEFT JOIN punto_autorizado punto ON punto.idPunto = v.idPuntoRecogida
             WHERE v.idPropietario = ?`, [idPropietario]
        );
        return vehiculos;
    }

    //? OBTENER INFORMACION COMPLETA Y ESPECIFICA DE UN VEHICULO PERO SOLO 
    //? DESDE EL PANEL DE PROPIETARIO
    async obtenerVehiculo(idPersona: number, idVehiculo: number) {
        const [vehiculos] = await this.database.query<RowDataPacket[]>(
            `SELECT v.*, punto.ciudad, punto.nombre AS ubicacion FROM vehiculo v
            INNER JOIN propietario p 
            ON v.idPropietario = p.idPropietario 
            LEFT JOIN punto_autorizado punto ON punto.idPunto = v.idPuntoRecogida
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
            && dto.precioPorDia === undefined
        ) {
            throw new BadRequestException('Debes actualizar almenos un dato. ');
        }

        const vehiculoActual = await this.obtenerVehiculo(idPersona, idVehiculo);
        if (dto.idPuntoRecogida !== undefined &&
            Number(dto.idPuntoRecogida) !== Number(vehiculoActual.idPuntoRecogida)) {
            const [reservasActivas] = await this.database.execute<RowDataPacket[]>(
                `SELECT idReserva FROM reserva WHERE idVehiculo = ?
                 AND estado IN ('Pendiente', 'Confirmada', 'EnCurso') LIMIT 1`,
                [idVehiculo],
            );
            if (reservasActivas.length) {
                throw new BadRequestException(
                    'No puedes cambiar la recogida mientras existan reservas activas.',
                );
            }
        }
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
                `SELECT idPunto FROM punto_autorizado WHERE idPunto = ?
                AND activo = 1`, [dto.idPuntoEntrega]
            );
            if (punto.length === 0) {
                throw new NotFoundException(
                    'EL punto de entrega no existe o esta inactivo. '
                )

            }
        }

        await this.database.query(
            `UPDATE vehiculo SET fotos = COALESCE(?, fotos),
            descripcion = COALESCE(?, descripcion),
             idPuntoRecogida = COALESCE(?, idPuntoRecogida),
             idPuntoEntrega = COALESCE(?, idPuntoEntrega),
             precioPorDia = COALESCE(?, precioPorDia)
            WHERE idVehiculo = ?`,
            [
                dto.fotos !== undefined ? JSON.stringify(dto.fotos) : null,
                dto.descripcion !== undefined ? dto.descripcion : null,
                dto.idPuntoRecogida ?? null,
                dto.idPuntoEntrega ?? null,
                dto.precioPorDia ?? null,
                idVehiculo
            ]
        );

        return {
            mensaje: 'vehiculo actualizado correctamente.'
        }
    }

    async cambiarEstadoVehiculo(idPersona: number, idVehiculo: number, dto: CambiarEstadoVehiculoDTO) {
        const connection = await this.database.getConnection();
        try {
            await connection.beginTransaction();
            const [vehiculos] = await connection.query<RowDataPacket[]>(
                `SELECT v.estado, v.estado_solicitud_revision
                 FROM vehiculo v INNER JOIN propietario p ON p.idPropietario = v.idPropietario
                 WHERE v.idVehiculo = ? AND p.idPersona = ? FOR UPDATE`,
                [idVehiculo, idPersona],
            );
            if (!vehiculos.length) {
                throw new NotFoundException('El vehículo no existe o no pertenece a tu cuenta.');
            }
            const vehiculo = vehiculos[0];
            if (!['Activo', 'inactivo'].includes(vehiculo.estado) ||
                ['Pendiente', 'Aprobada'].includes(vehiculo.estado_solicitud_revision)) {
                throw new BadRequestException('No puedes cambiar el estado durante la revisión técnica.');
            }
            if (dto.estado === 'inactivo' && vehiculo.estado === 'Activo') {
                const [reservas] = await connection.query<RowDataPacket[]>(
                    `SELECT idReserva FROM reserva WHERE idVehiculo = ?
                     AND estado IN ('Pendiente', 'Confirmada', 'EnCurso') LIMIT 1`,
                    [idVehiculo],
                );
                if (reservas.length) {
                    throw new BadRequestException('No puedes desactivar un vehículo con reservas activas.');
                }
            }
            await connection.query(
                `UPDATE vehiculo SET estado = ? WHERE idVehiculo = ?`, [dto.estado, idVehiculo],
            );
            await connection.commit();
            return { mensaje: 'Estado del vehículo actualizado.', estado: dto.estado };
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }
    }

    async solicitarRevision(idPersona: number, idVehiculo: number, dto: SolicitarRevisionDTO) {
        const connection = await this.database.getConnection();
        try {
            await connection.beginTransaction();
            const [vehiculos] = await connection.query<RowDataPacket[]>(
                `SELECT v.estado, v.estado_solicitud_revision, v.fecha_aprobacion_revision
                 FROM vehiculo v INNER JOIN propietario p ON p.idPropietario = v.idPropietario
                 WHERE v.idVehiculo = ? AND p.idPersona = ? FOR UPDATE`,
                [idVehiculo, idPersona],
            );
            if (!vehiculos.length) {
                throw new NotFoundException('El vehículo no existe o no pertenece a tu cuenta.');
            }
            const vehiculo = vehiculos[0];
            if (vehiculo.estado_solicitud_revision === 'Pendiente') {
                throw new BadRequestException('El vehículo ya tiene una revisión pendiente.');
            }
            if (['Aprobada', 'Finalizada'].includes(vehiculo.estado_solicitud_revision)
                && vehiculo.fecha_aprobacion_revision) {
                const fechaDisponible = new Date(vehiculo.fecha_aprobacion_revision);
                fechaDisponible.setMonth(fechaDisponible.getMonth() + 6);
                if (new Date() < fechaDisponible) {
                    throw new BadRequestException(
                        `Podrás solicitar otra revisión a partir del: ${fechaDisponible.toLocaleString('es-CO')}.`,
                    );
                }
            }
            const [reservas] = await connection.query<RowDataPacket[]>(
                `SELECT idReserva FROM reserva WHERE idVehiculo = ?
                 AND estado IN ('Pendiente', 'Confirmada', 'EnCurso') LIMIT 1`,
                [idVehiculo],
            );
            if (reservas.length) {
                throw new BadRequestException(
                    'No puedes solicitar revisión con reservas activas.',
                );
            }
            await connection.query(
                `UPDATE vehiculo SET estado = 'revision_pendiente',
                 estado_solicitud_revision = 'Pendiente',
                 motivo_solicitud_revision = ?,
                 motivo_rechazo_revision = NULL
                 WHERE idVehiculo = ?`,
                [dto.motivoSolicitud, idVehiculo],
            );
            await connection.commit();
            return {
                mensaje: 'Solicitud de revisión técnica enviada.',
                estado: 'Pendiente',
            };
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }
    }

}
