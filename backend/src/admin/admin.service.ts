import { Injectable, Inject } from "@nestjs/common";
import type { Pool, RowDataPacket } from "mysql2/promise";

@Injectable()
export class AdminService {
    constructor(@Inject('DATABASE_CONNECTION')
    private readonly database: Pool) { }

    async obtenerUsuarios() {
        const [usuarios] = await this.database.query<RowDataPacket[]>(
            `SELECT p.idPersona,
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
            FROM persona p ORDER BY p.fechaHoraRegistro DESC`
        );
        return {
            mensaje: 'Usuarios obtenidos.',
            total: usuarios.length,
            usuarios
        };
    }

}