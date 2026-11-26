import {
  BadRequestException, ForbiddenException, Inject, Injectable,
  NotFoundException, ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Pool, RowDataPacket } from 'mysql2/promise';

interface Punto extends RowDataPacket {
  idPunto: number;
  nombre: string;
  direccion: string;
  ciudad: string;
  latitud: string | number;
  longitud: string | number;
}

function coordenadas(latitud: number, longitud: number) {
  if (!Number.isFinite(latitud) || latitud < -90 || latitud > 90 ||
      !Number.isFinite(longitud) || longitud < -180 || longitud > 180) {
    throw new BadRequestException('Coordenadas inválidas.');
  }
}

function distanciaKm(aLat: number, aLon: number, bLat: number, bLon: number) {
  const rad = Math.PI / 180;
  const deltaLat = (bLat - aLat) * rad;
  const deltaLon = (bLon - aLon) * rad;
  const h = Math.sin(deltaLat / 2) ** 2 +
    Math.cos(aLat * rad) * Math.cos(bLat * rad) * Math.sin(deltaLon / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.min(1, Math.sqrt(h)));
}

@Injectable()
export class RutasService {
  constructor(
    @Inject('DATABASE_CONNECTION') private readonly database: Pool,
    private readonly config: ConfigService,
  ) {}

  // Solo el punto de recogida físicamente configurado para este vehículo es
  // elegible. No se promete reubicación a otro punto sin confirmación.
  async puntoCercano(idVehiculo: number, latitud?: number, longitud?: number) {
    if (!Number.isSafeInteger(idVehiculo) || idVehiculo <= 0) {
      throw new BadRequestException('Vehículo inválido.');
    }
    if ((latitud === undefined) !== (longitud === undefined)) {
      throw new BadRequestException('Indica ambas coordenadas o ninguna.');
    }
    if (latitud !== undefined && longitud !== undefined) {
      coordenadas(latitud, longitud);
    }
    const [rows] = await this.database.execute<Punto[]>(
      `SELECT p.idPunto, p.nombre, p.direccion, p.ciudad, p.latitud, p.longitud
       FROM vehiculo v INNER JOIN punto_autorizado p ON p.idPunto = v.idPuntoRecogida
       WHERE v.idVehiculo = ? AND v.estado = 'Activo' AND p.activo = 1`,
      [idVehiculo],
    );
    if (!rows.length) throw new NotFoundException('No hay punto de recogida disponible para este vehículo.');
    const punto = rows[0];
    return {
      punto: {
        idPunto: punto.idPunto,
        nombre: punto.nombre,
        direccion: punto.direccion,
        ciudad: punto.ciudad,
        latitud: Number(punto.latitud),
        longitud: Number(punto.longitud),
      },
      distanciaAproximadaKm: latitud === undefined || longitud === undefined ? null :
        Math.round(distanciaKm(latitud, longitud, Number(punto.latitud), Number(punto.longitud)) * 100) / 100,
      criterio: 'punto_fisico_del_vehiculo',
    };
  }

  async rutaReserva(idPersona: number, idReserva: number) {
    if (!Number.isSafeInteger(idReserva) || idReserva <= 0) {
      throw new BadRequestException('Reserva inválida.');
    }
    const [rows] = await this.database.execute<RowDataPacket[]>(
      `SELECT r.idReserva, r.estado, r.precioEstimado,
              pc.idPersona AS cliente, pp.idPersona AS propietario,
              pd.idPersona AS conductor,
              pr.idPunto AS recogidaId, pr.nombre AS recogidaNombre,
              pr.direccion AS recogidaDireccion, pr.latitud AS recogidaLat, pr.longitud AS recogidaLon,
              pe.idPunto AS entregaId, pe.nombre AS entregaNombre,
              pe.direccion AS entregaDireccion, pe.latitud AS entregaLat, pe.longitud AS entregaLon
       FROM reserva r
       JOIN cliente c ON c.idCliente = r.idCliente
       JOIN persona pc ON pc.idPersona = c.idPersona
       JOIN vehiculo v ON v.idVehiculo = r.idVehiculo
       JOIN propietario p ON p.idPropietario = v.idPropietario
       JOIN persona pp ON pp.idPersona = p.idPersona
       LEFT JOIN conductor d ON d.idConductor = r.idConductor
       LEFT JOIN persona pd ON pd.idPersona = d.idPersona
       JOIN punto_autorizado pr ON pr.idPunto = r.idPuntoRecogida
       JOIN punto_autorizado pe ON pe.idPunto = r.idPuntoEntrega
       WHERE r.idReserva = ?`,
      [idReserva],
    );
    if (!rows.length) throw new NotFoundException('La reserva no existe.');
    const row = rows[0];
    if (![row.cliente, row.propietario, row.conductor].some(id => Number(id) === idPersona)) {
      throw new ForbiddenException('No participas en esta reserva.');
    }
    const origen = {
      idPunto: Number(row.recogidaId), nombre: row.recogidaNombre,
      direccion: row.recogidaDireccion,
      latitud: Number(row.recogidaLat), longitud: Number(row.recogidaLon),
    };
    const destino = {
      idPunto: Number(row.entregaId), nombre: row.entregaNombre,
      direccion: row.entregaDireccion,
      latitud: Number(row.entregaLat), longitud: Number(row.entregaLon),
    };
    const base = {
      idReserva,
      origen, destino,
      tarifa: { precioEstimado: Number(row.precioEstimado), moneda: 'COP', recargoPorDistancia: 0 },
    };
    if (origen.idPunto === destino.idPunto) {
      return { ...base, distanciaKm: 0, duracionMinutos: 0,
        trayectoria: [[origen.longitud, origen.latitud]], proveedor: 'mismo_punto' };
    }
    const token = this.config.get<string>('MAPBOX_ACCESS_TOKEN')?.trim();
    if (!token) return {
      ...base, distanciaKm: null, duracionMinutos: null, trayectoria: [],
      proveedor: 'mapbox_no_configurado',
    };
    const url = new URL(`https://api.mapbox.com/directions/v5/mapbox/driving/` +
      `${origen.longitud},${origen.latitud};${destino.longitud},${destino.latitud}`);
    url.searchParams.set('access_token', token);
    url.searchParams.set('geometries', 'geojson');
    url.searchParams.set('overview', 'full');
    url.searchParams.set('alternatives', 'false');
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(8000) });
      if (!response.ok) throw new Error('Proveedor no disponible');
      const body = await response.json() as {
        code?: string;
        routes?: { distance?: number; duration?: number;
          geometry?: { coordinates?: number[][] } }[];
      };
      const ruta = body.routes?.[0];
      const trayectoria = ruta?.geometry?.coordinates;
      if (body.code !== 'Ok' || !Number.isFinite(ruta?.distance) ||
          !Number.isFinite(ruta?.duration) ||
          !Array.isArray(trayectoria) || !trayectoria.length || trayectoria.length > 20000 ||
          trayectoria.some(coord => !Array.isArray(coord) || coord.length !== 2 ||
            !Number.isFinite(coord[0]) || !Number.isFinite(coord[1]))) {
        throw new Error('Ruta inválida');
      }
      return {
        ...base,
        distanciaKm: Math.round(ruta!.distance! / 10) / 100,
        duracionMinutos: Math.ceil(ruta!.duration! / 60),
        trayectoria,
        proveedor: 'mapbox_directions',
      };
    } catch {
      // Nunca incluir URL, respuesta o token Mapbox en logs/errores.
      throw new ServiceUnavailableException('No se pudo calcular la ruta vial en este momento.');
    }
  }
}
