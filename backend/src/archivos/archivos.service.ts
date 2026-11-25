import { Injectable, Inject, NotFoundException, BadRequestException, ForbiddenException } from "@nestjs/common";
import type { Pool, ResultSetHeader, RowDataPacket } from "mysql2/promise";

interface Documento extends RowDataPacket {
    idDocumento: number;
    nombreArchivo: string;
    tipoDocumento: string;
    contenido: Buffer;
    tablaOrigen: string | null;
    idOrigen: number | null;
}

@Injectable()
export class ArchivosService {
    constructor(
        @Inject('DATABASE_CONNECTION')
        private readonly db: Pool,
    ) { }

    async guardarPDF(nombreArchivo: string, tipoDocumento: string,
        tablaOrigen: string, idOrigen: number, contenido: Buffer) {
        if (!nombreArchivo.toLowerCase().endsWith('.pdf')) {
            throw new BadRequestException('El archivo debe ser PDF.');
        }
        if (!contenido || contenido.length === 0) {
            throw new BadRequestException('El documento esta vacío.');
        }
        if (!tipoDocumento || !tablaOrigen || !Number.isInteger(idOrigen)
            || idOrigen < 0) {
            throw new BadRequestException('Los datos internos del documento no son válidos.',);
        }
        const [resultado] = await this.db.execute<ResultSetHeader>(
            `INSERT INTO documento (
                nombreArchivo,
                tipoDocumento,
                tablaOrigen,
                idOrigen,
                contenido
                ) VALUES (?, ?, ?, ?, ?)`,
            [
                nombreArchivo,
                tipoDocumento,
                tablaOrigen,
                idOrigen,
                contenido,
            ],
        );
        return {
            mensaje: 'Documento PDF guardado correctamente.',
            idDocumento: resultado.insertId,
            nombreArchivo,
            tipoDocumento,
        };
    }

    async obtenerPDF(idDocumento: number) {
        const [documentos] = await this.db.query<Documento[]>(
            `SELECT idDocumento, nombreArchivo, tipoDocumento,
            contenido, tablaOrigen, idOrigen FROM documento
            WHERE idDocumento = ?`, [idDocumento],
        );
        if (documentos.length === 0) {
            throw new NotFoundException('El documento no existe.');
        }
        const documento = documentos[0];
        return {
            idDocumento: documento.idDocumento,
            nombreArchivo: documento.nombreArchivo,
            tipoDocumento: documento.tipoDocumento,
            contenido: documento.contenido,
        };
    }

    async listarDocumentos(tablaOrigen: string, idOrigen: number,) {
        const [documentos] = await this.db.query<RowDataPacket[]>(
            `SELECT idDocumento, nombreArchivo, tipoDocumento, fechaCreacion
            FROM documento WHERE tablaOrigen = ? AND idOrigen = ?
            ORDER BY fechaCreacion DESC`, [tablaOrigen, idOrigen],
        );
        return documentos;
    }
}