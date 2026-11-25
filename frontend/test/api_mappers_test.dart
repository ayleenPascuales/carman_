import 'package:carman_app/data/models/booking.dart';
import 'package:carman_app/data/models/owner_models.dart';
import 'package:carman_app/data/remote/api_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vehicleJson = <String, dynamic>{
    'idVehiculo': 10,
    'marca': 'Tesla',
    'modelo': 'Model Y',
    'anio': 2023,
    'tipoVehiculo': 'suv',
    'capacidad': 5,
    'precioHora': 18,
    'precioDia': 75,
    'rating': 4.98,
    'fotos': ['https://example.com/car.jpg'],
    'ubicacion': 'Bocagrande',
    'ciudad': 'Cartagena',
  };

  group('ApiMappers', () {
    test('maps a reservation with a backend cost breakdown', () {
      final reservation = ApiMappers.reservation({
        'reserva': {
          'idReserva': 55,
          'codigo': 'CRMN-4821',
          'estado': 'Confirmada',
          'fechaInicioServicio': '2026-11-24T10:00:00',
          'fechaFinServicio': '2026-11-27T10:00:00',
          'modalidad': 'daily',
          'vehiculo': vehicleJson,
          'seguro': 'premium',
          'seguroNombre': 'Allianz Premium',
          'metodoPago': {'marca': 'Mastercard', 'ultimos4': '4242'},
          'desglose': {
            'unidades': 3,
            'tarifa': 75,
            'alquiler': 225,
            'diasSeguro': 3,
            'seguro': 54,
            'servicio': 24,
            'impuestos': 63.63,
            'descuento': 0,
            'deposito': 150,
          },
          'puntoRecogida': {
            'id': 3,
            'nombre': 'Bocagrande',
            'ciudad': 'Cartagena',
            'direccion': 'Calle 6',
            'distancia': 0.8,
          },
          'codigoLlave': 'KEY-1',
        },
      });

      expect(reservation.id, '55');
      expect(reservation.code, 'CRMN-4821');
      expect(reservation.status, ReservationStatus.confirmed);
      expect(reservation.vehicle.title, 'Tesla Model Y');
      expect(reservation.pricing.total, closeTo(366.63, 0.01));
      expect(reservation.paymentMethodLabel, 'Mastercard •••• 4242');
      expect(reservation.pickupPoint.name, 'Bocagrande');
    });

    test('maps notifications', () {
      final notification = ApiMappers.notification({
        'idNotificacion': 12,
        'tipo': 'reserva',
        'titulo': 'Reserva confirmada',
        'mensaje': 'Tesla Model Y',
        'leida': false,
        'fechaHora': '2026-11-20T09:00:00',
      });

      expect(notification.title, 'Reserva confirmada');
      expect(notification.isRead, isFalse);
      expect(notification.kind.name, 'reservation');
    });

    test('maps the owner dashboard', () {
      final data = ApiMappers.ownerDashboard({
        'estadisticas': {
          'vehiculos': 1,
          'activos': 1,
          'ingresosMes': 1480,
          'reservasPendientes': 2,
          'ocupacion': 0.78,
          'ingresosMesAnterior': 1200,
        },
        'vehiculos': [
          {
            'id': 1,
            'estado': 'Disponible',
            'proximoMantenimiento': '2026-12-20',
            'ingresoMes': 1480,
            'viajesMes': 12,
            'vehiculo': vehicleJson,
          },
        ],
      });

      expect(data.stats.vehicles, 1);
      expect(data.stats.monthlyRevenue, 1480);
      expect(data.listings, hasLength(1));
      expect(data.listings.first.vehicle.title, 'Tesla Model Y');
      expect(data.listings.first.meta.status, OwnerVehicleStatus.available);
    });

    test('derives owner stats when the summary endpoint is absent', () {
      final data = ApiMappers.ownerDashboard({
        'vehiculos': [vehicleJson],
      });
      expect(data.stats.vehicles, 1);
      expect(data.listings.single.vehicle.id, '10');
    });

    test('maps a driver dashboard', () {
      final data = ApiMappers.driverDashboard({
        'disponibilidad': 'disponible',
        'estadisticas': {
          'viajesHoy': 3,
          'gananciasHoy': 64,
          'gananciasSemana': 320,
          'rating': 4.9,
          'aceptacion': 0.94,
          'horasConectado': 4,
          'viajesTotales': 90,
        },
        'servicios': [
          {
            'idServicio': 8,
            'cliente': {'nombre': 'Laura', 'telefono': '+57 300'},
            'vehiculo': vehicleJson,
            'origen': 'Centro',
            'destino': 'Bocagrande',
            'fechaHora': '2026-11-24T15:30:00',
            'distanciaKm': 4.2,
            'duracionMin': 18,
            'ganancia': 18,
            'estado': 'En camino',
          },
        ],
      });

      expect(data.stats.tripsToday, 3);
      expect(data.availability.name, 'online');
      expect(data.trips.single.clientName, 'Laura');
      expect(data.trips.single.vehicle.title, 'Tesla Model Y');
    });

    test('maps the admin dashboard', () {
      final data = ApiMappers.adminDashboard({
        'estadisticas': {
          'usuarios': 1200,
          'conductores': 80,
          'vehiculos': 300,
          'pendientes': 2,
          'reservasHoy': 40,
          'ingresosMes': 12000,
          'crecimiento': 10,
        },
        'usuarios': [
          {
            'idPersona': 1,
            'nombre': 'Alex',
            'apellido': 'Rivera',
            'email': 'alex@carman.es',
            'telefono': '+57 300',
            'ciudad': 'Cartagena',
            'roles': {'cliente': true, 'administrador': true},
            'estado': 'Activo',
            'fechaHoraRegistro': '2025-01-10T00:00:00',
          },
        ],
        'aprobaciones': [
          {
            'idAprobacion': 2,
            'tipo': 'licencia',
            'solicitante': 'María',
            'titulo': 'Licencia',
            'detalle': 'Categoría B',
            'estado': 'Pendiente',
            'fechaSolicitud': '2026-11-20T10:00:00',
          },
        ],
      });

      expect(data.stats.totalUsers, 1200);
      expect(data.users.single.verified, isTrue);
      expect(data.users.single.status.name, 'active');
      expect(data.approvals.single.status.name, 'pending');
    });
  });
}
