import { Injectable, Inject, BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import type { Pool, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import * as bcrypt from 'bcrypt';
import { RegistroInicialDto, Rol } from './dto/registroInicial.dto';
import { AgregarRolDto, RolAdicional } from './dto/agregarRol.dto';
import { CrearLicenciaDto } from './dto/crearLicencia.dto';
import { AuthService } from '../auth/auth.service';

@Injectable()
export class PersonasService {
    constructor(
        @Inject('DATABASE_CONNECTION')
        private readonly database: Pool,
        private readonly authService: AuthService,
    ) { }

    async registroInicial(dto: RegistroInicialDto) {
        const esCliente = dto.roles === Rol.CLIENTE;
        const esConductor = dto.roles === Rol.CONDUCTOR;
        const esPropietario = dto.roles === Rol.PROPIETARIO;

        if (esConductor && !dto.licencia) {
            throw new BadRequestException(
                'Para registrarte como conductor debes proporcionar tu licencia.'
            );
        }
        if (dto.licencia) {
            const fechaExpiracion = new Date(
                `${dto.licencia.fechaExpiracion}T00:00:00`
            );
            const hoy = new Date();
            hoy.setHours(0, 0, 0, 0);

            if (fechaExpiracion < hoy) {
                throw new BadRequestException(
                    'No puedes registrar una licencia vencida. '
                );
            }
        }
        if (esPropietario && (!dto.vehiculos || dto.vehiculos.length === 0)) {
            throw new BadRequestException(
                'Para registrarte como propietario debes registrar por lo menos un vehiculo.'
            )
        }
        if (!esPropietario && dto.vehiculos?.length) {
            throw new BadRequestException(
                'No puede registrar vehiculos. Solo el propietario puede hacerlo.'
            )
        }

        const nacimiento = new Date(`${dto.persona.fechaNacimiento}T00:00:00`,);
        const hoy = new Date();
        let edad = hoy.getFullYear() - nacimiento.getFullYear();

        if (hoy.getMonth() < nacimiento.getMonth() ||
            (hoy.getMonth() === nacimiento.getMonth() &&
                hoy.getDate() < nacimiento.getDate())) {
            edad--;
        }

        if (edad < 18 || nacimiento > hoy) {
            throw new BadRequestException(
                'Debes tener al menos 18 años para registrarte. ',
            );
        }

        const connection = await this.database.getConnection();

        let uidFirebase: string | undefined;
        let transaccionIniciada = false;
        let registroConfirmado = false;

        try {
            uidFirebase = await this.authService.crearCuenta(
                dto.persona.email,
                dto.persona.contrasena
            );

            const contrasenaHash = await bcrypt.hash(
                dto.persona.contrasena,
                10
            );

            await connection.beginTransaction();
            transaccionIniciada = true;

            const [resultadoPersona] = await connection.execute<ResultSetHeader>(
                `INSERT INTO persona (
                documento,
                nombre,
                apellido,
                email,
                usuario,
                contrasenaHash,
                uidFirebase,
                telefono,
                fechaNacimiento,
                ciudad,
                direccion,
                fotoPerfil
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                [
                    dto.persona.documento,
                    dto.persona.nombre,
                    dto.persona.apellido,
                    dto.persona.email,
                    dto.persona.usuario,
                    contrasenaHash,
                    uidFirebase,
                    dto.persona.telefono,
                    dto.persona.fechaNacimiento,
                    dto.persona.ciudad,
                    dto.persona.direccion,
                    dto.persona.fotoPerfil,
                ],
            );
            const idPersona = resultadoPersona.insertId;
            let idPropietario: number | undefined;

            if (esCliente) {
                await connection.execute(
                    `INSERT INTO cliente (idPersona) VALUES (?)`, [idPersona],
                );
            }
            if (esConductor) {
                await connection.execute(
                    `INSERT INTO conductor (idPersona) VALUES (?)`, [idPersona],
                );
            }
            if (esPropietario) {
                const [resultadoPropietario] = await connection.execute<ResultSetHeader>(
                    `INSERT INTO propietario (idPersona) VALUES (?)`, [idPersona],
                );
                idPropietario = resultadoPropietario.insertId;
            }

            if (dto.licencia) {
                const fechaActual = new Date();
                const fechaExpiracion = new Date(`${dto.licencia.fechaExpiracion}T00:00:00`,);

                const estado = fechaExpiracion < new Date(
                    fechaActual.getFullYear(), fechaActual.getMonth(), fechaActual.getDate(),
                )
                    ? 'Vencida'
                    : 'Vigente';

                await connection.execute(
                    `INSERT INTO licencia(
                    idPersona,
                    numeroDocumento,
                    fechaExpiracion,
                    estado,
                    tipoLicencia,
                    fotoLicencia
                    ) VALUES (?, ?, ?, ?, ?, ?)`,
                    [
                        idPersona,
                        dto.licencia.numeroDocumento,
                        dto.licencia.fechaExpiracion,
                        estado,
                        dto.licencia.tipoLicencia,
                        dto.licencia.fotoLicencia,
                    ],
                );
            }

            if (esPropietario && idPropietario !== undefined) {
                for (const vehiculo of dto.vehiculos!) {
                    await connection.execute(
                        `INSERT INTO vehiculo(
                            idPropietario,
                            placa,
                            marca,
                            modelo,
                            anio,
                            capacidad,
                            tipoVehiculo,
                            fotos,
                            descripcion,
                            idPuntoRecogida,
                            idPuntoEntrega,
                            tarjetaPropiedad
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                        [
                            idPropietario,
                            vehiculo.placa,
                            vehiculo.marca,
                            vehiculo.modelo,
                            vehiculo.anio,
                            vehiculo.capacidad,
                            vehiculo.tipoVehiculo,
                            JSON.stringify(vehiculo.fotos),
                            vehiculo.descripcion ?? null,
                            vehiculo.idPuntoRecogida,
                            vehiculo.idPuntoEntrega,
                            vehiculo.tarjetaPropiedad,
                        ],
                    );
                }
            }

            await connection.commit();
            registroConfirmado = true;

            return {
                mensaje: 'Registro realizado correctamente. ',
                idPersona, rol: dto.roles,
            };

        } catch (error) {
            if (transaccionIniciada && !registroConfirmado) {
                try {
                    await connection.rollback();
                } catch {
                    //!se conserva el error
                }
            }

            if (uidFirebase && !registroConfirmado) {
                try {
                    await this.authService.eliminarCuenta(uidFirebase);
                } catch {
                    //!se conserva el error
                }
            }
            const codigoError = error && typeof error === 'object'
                && 'code' in error
                ? error.code : undefined;

            if (codigoError === 'ER_DUP_ENTRY' ||
                codigoError === 'auth/email-already-exists') {
                throw new ConflictException(
                    'El correo, documento, usuario, licencia o placa ya se encuentran registrados.'
                );
            }
            throw error;

        } finally {
            connection.release();
        }

    }

    async agregarRol(idPersona: number, dto: AgregarRolDto) {
        const esCliente = dto.roles === RolAdicional.CLIENTE;
        const esConductor = dto.roles === RolAdicional.CONDUCTOR;
        const esPropietario = dto.roles === RolAdicional.PROPIETARIO;

        if (esPropietario && (!dto.vehiculos || dto.vehiculos.length === 0)) {
            throw new BadRequestException(
                'Para ser propietario debes añadir por lo menos un vehiculo. ',
            );
        }
        if (!esPropietario && dto.vehiculos?.length) {
            throw new BadRequestException(
                'Solo el propietario puede registrar vehiculos. ',
            );
        }

        const connection = await this.database.getConnection();
        try {
            await connection.beginTransaction();

            const [personas] = await connection.execute<RowDataPacket[]>(
                `SELECT idPersona FROM persona WHERE idPersona = ? FOR UPDATE`, [idPersona],
            );
            if (personas.length === 0) {
                throw new NotFoundException('El usuario no existe. ')
            }

            const tablaRol = esCliente ? 'cliente'
                : esConductor ? 'conductor'
                    : 'propietario';

            const [rolesExistentes] = await connection.execute<RowDataPacket[]>(
                `SELECT idPersona FROM ${tablaRol} WHERE idPersona = ?`, [idPersona],
            );
            if (rolesExistentes.length > 0) {
                throw new ConflictException(
                    'El usuario ya tiene este rol registrado. '
                );
            }

            const [licencias] = await connection.execute<RowDataPacket[]>(
                `SELECT idLicencia, numeroDocumento, estado, 
                DATE_FORMAT(fechaExpiracion, '%Y-%m-%d') AS fechaExpiracion
                FROM  licencia WHERE idPersona = ? LIMIT 1 FOR UPDATE`, [idPersona],);

            const licenciaExistente = licencias[0];
            let licenciaVigente = false;

            if (licenciaExistente) {
                const fechaExpiracion = new Date(`${(licenciaExistente.fechaExpiracion).slice(0, 10)}T00:00:00`);
                const hoy = new Date();
                hoy.setHours(0, 0, 0, 0);
                licenciaVigente = licenciaExistente.estado === 'Vigente' && fechaExpiracion >= hoy;
            }
            if (licenciaExistente?.estado === 'Suspendida' && dto.licencia) {
                throw new BadRequestException(
                    'Tu licencia esta suspendida. Contacta con la administracion de CARMAN para autorizar el registro de una nueva licencia valida. '
                );
            }

            if (esConductor && !licenciaVigente && !dto.licencia) {
                throw new BadRequestException(
                    'Para ser conductor necesitas tener la licencia vigente. ',
                );
            }

            if (dto.licencia) {
                const fechaExpiracion = new Date(`${dto.licencia.fechaExpiracion}T00:00:00`,);
                const hoy = new Date();
                hoy.setHours(0, 0, 0, 0);

                if (fechaExpiracion < hoy) {
                    throw new BadRequestException(
                        'No puedes registrar una licencia vencida. '
                    )
                }
                if (licenciaExistente) {
                    const [licenciasRegistradas] = await connection.execute<RowDataPacket[]>(
                        `SELECT idLicencia FROM licencia WHERE numeroDocumento = ? AND idLicencia <> ?`
                        , [dto.licencia.numeroDocumento, licenciaExistente.idLicencia,],
                    );
                    if (licenciasRegistradas.length > 0) {
                        throw new ConflictException('Esta licencia ya se encuentra registrada. ');
                    }
                    const nuevoEstado = licenciaExistente.estado === 'Suspendida'
                        ? 'Suspendida' : 'Vigente';

                    await connection.execute(
                        `UPDATE licencia SET numeroDocumento = ?, fechaExpiracion = ?,
                        estado = ?, tipoLicencia = ?, fotoLicencia = ?
                        WHERE idLicencia = ?`,
                        [
                            dto.licencia.numeroDocumento,
                            dto.licencia.fechaExpiracion,
                            nuevoEstado,
                            dto.licencia.tipoLicencia,
                            dto.licencia.fotoLicencia,
                            licenciaExistente.idLicencia,
                        ],
                    );
                } else {
                    const [licenciasRegistradas] = await connection.execute<RowDataPacket[]>(
                        `SELECT idLicencia FROM licencia WHERE numeroDocumento = ?`, [dto.licencia.numeroDocumento],
                    );
                    if (licenciasRegistradas.length > 0) {
                        throw new ConflictException('Esta licencia ya se encuentra registrada. ');
                    }
                    await connection.execute(
                        `INSERT INTO licencia(
                        idPersona,
                        numeroDocumento,
                        fechaExpiracion,
                        estado,
                        tipoLicencia,
                        fotoLicencia
                        ) VALUES (?, ?, ?, 'Vigente', ?, ?)`,
                        [
                            idPersona,
                            dto.licencia.numeroDocumento,
                            dto.licencia.fechaExpiracion,
                            dto.licencia.tipoLicencia,
                            dto.licencia.fotoLicencia
                        ],
                    );
                }
            }

            let idPropietario: number | undefined;

            if (esCliente) {
                await connection.execute(
                    `INSERT INTO cliente (idPersona) VALUES (?)`, [idPersona],
                );
            }
            if (esConductor) {
                await connection.execute(
                    `INSERT INTO conductor (idPersona) VALUES (?)`, [idPersona],
                );
            }
            if (esPropietario) {
                const [resultadoPropietario] = await connection.execute<ResultSetHeader>(
                    `INSERT INTO propietario (idPersona) VALUES (?)`, [idPersona],
                );
                idPropietario = resultadoPropietario.insertId;
            }
            if (esPropietario && idPropietario !== undefined) {
                for (const vehiculo of dto.vehiculos!) {
                    await connection.execute(
                        `INSERT INTO vehiculo (
                        idPropietario,
                        placa,
                        marca,
                        modelo,
                        anio,
                        capacidad,
                        tipoVehiculo,
                        fotos,
                        descripcion,
                        idPuntoRecogida,
                        idPuntoEntrega,
                        tarjetaPropiedad
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                        [
                            idPropietario,
                            vehiculo.placa,
                            vehiculo.marca,
                            vehiculo.modelo,
                            vehiculo.anio,
                            vehiculo.capacidad,
                            vehiculo.tipoVehiculo,
                            JSON.stringify(vehiculo.fotos),
                            vehiculo.descripcion ?? null,
                            vehiculo.idPuntoRecogida,
                            vehiculo.idPuntoEntrega,
                            vehiculo.tarjetaPropiedad,
                        ],
                    );
                }
            }

            await connection.commit();
            return {
                mensaje: 'Rol agregado correctamente. ', idPersona, rol: dto.roles,
            };
        } catch (error) {
            await connection.rollback();

            if (error && typeof error === 'object' && 'code' in error &&
                error.code === 'ER_DUP_ENTRY') {
                throw new ConflictException(
                    'La licencia, placa o rol ya se encuentran registrados.',
                );
            }
            throw error;
        } finally {
            connection.release();
        }
    }

    async crearLicencia(idPersona: number, dto: CrearLicenciaDto) {
        const connection = await this.database.getConnection();

        try {
            await connection.beginTransaction();

            const [personas] = await connection.execute<RowDataPacket[]>(
                `SELECT idPersona FROM persona WHERE idPersona = ? FOR UPDATE`, [idPersona],
            );
            if (personas.length === 0) {
                throw new NotFoundException('El usuario no existe.')
            }

            const [licencias] = await connection.execute<RowDataPacket[]>(
                `SELECT idLicencia FROM licencia WHERE idPersona = ? LIMIT 1 FOR UPDATE`, [idPersona],
            );
            if (licencias.length > 0) {
                throw new ConflictException('Este usuario ya tiene una licencia registrada. ');
            }

            const [licenciasRegistradas] = await connection.execute<RowDataPacket[]>(
                `SELECT idLicencia FROM licencia WHERE numeroDocumento = ?`, [dto.numeroDocumento],
            );
            if (licenciasRegistradas.length > 0) {
                throw new ConflictException('Esta licencia ya se encuentra registrada. ');
            }

            const fechaExpiracion = new Date(`${dto.fechaExpiracion}T00:00:00`,);
            const hoy = new Date();
            hoy.setHours(0, 0, 0, 0);
            if (fechaExpiracion < hoy) {
                throw new BadRequestException(
                    'La fecha de expiracion de la licencia no puede estar vencida. '
                );
            }

            const [resultado] = await connection.execute<ResultSetHeader>(
                `INSERT INTO licencia(
                idPersona,
                numeroDocumento,
                fechaExpiracion,
                estado,
                tipoLicencia,
                fotoLicencia
                ) VALUES (?, ?, ?, 'Vigente', ?, ?)`,
                [
                    idPersona,
                    dto.numeroDocumento,
                    dto.fechaExpiracion,
                    dto.tipoLicencia,
                    dto.fotoLicencia
                ],
            );
            await connection.commit();
            return {
                mensaje: 'Licencia registrada correctamente.', idPersona, idLicencia: resultado.insertId,
            };

        } catch (error) {
            await connection.rollback();
            if (
                error &&
                typeof error === 'object' && 'code' in error &&
                error.code === 'ER_DUP_ENTRY'
            ) {
                throw new ConflictException('Esta licencia ya se encuentra registrada.',);
            }
            throw error;

        } finally {
            connection.release();
        }
    }

    async actualizarLicencia(idPersona: number, dto: CrearLicenciaDto) {
        const connection = await this.database.getConnection();

        try {
            await connection.beginTransaction();

            const [personas] = await connection.execute<RowDataPacket[]>(
                `SELECT idPersona FROM persona WHERE idPersona = ? FOR UPDATE`, [idPersona],
            );
            if (personas.length === 0) {
                throw new NotFoundException('El usuario no existe.')
            }

            const [licencias] = await connection.execute<RowDataPacket[]>(
                `SELECT idLicencia, estado FROM licencia WHERE idPersona = ? LIMIT 1 FOR UPDATE`, [idPersona],
            );
            if (licencias.length === 0) {
                throw new NotFoundException('Este usuario no tiene licencia registrada.');
            }

            const idLicencia = licencias[0].idLicencia;
            const estadoAnterior = licencias[0].estado;
            if (estadoAnterior === 'Suspendida') {
                throw new BadRequestException(
                    'Tu licencia esta suspendida. Contacta con la administracion de CARMAN para autorizar el registro de una nueva licencia valida. '
                )
            }
            const nuevoEstado = 'Vigente';
            const [licenciasRegistradas] = await connection.execute<RowDataPacket[]>(
                `SELECT idLicencia FROM licencia WHERE numeroDocumento = ? AND idLicencia <> ?`,
                [dto.numeroDocumento, idLicencia],
            );
            if (licenciasRegistradas.length > 0) {
                throw new ConflictException('Esta licencia ya se encuentra registrada. ')
            }

            const fechaExpiracion = new Date(`${dto.fechaExpiracion}T00:00:00`,);
            const hoy = new Date();
            hoy.setHours(0, 0, 0, 0);
            if (fechaExpiracion < hoy) {
                throw new BadRequestException(
                    'La nueva fecha de expiracion no puede estar vencida. '
                );
            }
            await connection.execute(
                `UPDATE licencia SET numeroDocumento = ?, fechaExpiracion = ?,
                        estado = ?, tipoLicencia = ?, fotoLicencia = ?
                        WHERE idLicencia = ?`,
                [
                    dto.numeroDocumento,
                    dto.fechaExpiracion,
                    nuevoEstado,
                    dto.tipoLicencia,
                    dto.fotoLicencia,
                    idLicencia,
                ],
            );
            await connection.commit();
            return {
                mensaje: 'Licencia actualizada correctamente', idPersona, idLicencia,
            };
        } catch (error) {
            await connection.rollback();
            if (
                error &&
                typeof error === 'object' &&
                'code' in error &&
                error.code === 'ER_DUP_ENTRY'
            ) {
                throw new ConflictException(
                    'Esta licencia ya se encuentra registrada.',
                );
            }
            throw error;

        } finally {
            connection.release();
        }
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
            EXISTS(SELECT 1 FROM propietario WHERE idPersona = ?) AS propietario`,
            [idPersona, idPersona, idPersona],
        );
        return {
            ...personas[0],
            roles: {
                cliente: Boolean(roles[0].cliente),
                conductor: Boolean(roles[0].conductor),
                propietario: Boolean(roles[0].propietario),
            },
        };
    }
}