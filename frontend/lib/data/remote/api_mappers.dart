import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../models/admin_models.dart';
import '../models/app_notification.dart';
import '../models/booking.dart';
import '../models/driver_models.dart';
import '../models/owner_models.dart';
import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../models/vehicle_query.dart';

/// Defensive mapping from the JSON contract documented in
/// `docs/api_contract.md` to Carman domain models.
abstract final class ApiMappers {
  static Reservation reservation(
    Map<String, dynamic> json, {
    Vehicle? fallbackVehicle,
    BookingDraft? fallbackDraft,
  }) {
    final raw = json['reserva'] is Map<String, dynamic>
        ? json['reserva'] as Map<String, dynamic>
        : json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final vehicle =
        _vehicle(raw['vehiculo'] ?? raw['vehicle']) ??
        fallbackVehicle ??
        _vehicle(raw);
    if (vehicle == null) {
      throw const AppException(
        'La reserva no incluyó la información del vehículo.',
        code: 'invalid_reservation',
      );
    }

    final mode =
        _mode(raw['modalidad'] ?? raw['mode']) ??
        fallbackDraft?.mode ??
        RentalMode.daily;
    final startDate =
        _date(
          raw['fechaInicioServicio'] ?? raw['fechaInicio'] ?? raw['startAt'],
        ) ??
        fallbackDraft?.startAt ??
        DateTime.now().add(const Duration(days: 1));
    final endDate =
        _date(raw['fechaFinServicio'] ?? raw['fechaFin'] ?? raw['endAt']) ??
        fallbackDraft?.endAt ??
        startDate.add(
          mode == RentalMode.hourly
              ? const Duration(hours: 4)
              : const Duration(days: 3),
        );
    DateTime withHour(DateTime date, Object? time) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('$time');
      if (match == null) return date;
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
      );
    }

    final start = withHour(startDate, raw['horaInicioServicio']);
    final end = withHour(endDate, raw['horaFinServicio']);

    final insurance =
        _insurance(raw['seguro'] ?? raw['insurance']) ??
        fallbackDraft?.insurance ??
        InsurancePlan.basic;

    final apiTotal = _double(raw['precioEstimado']);
    final pricing = apiTotal != null
        ? PricingBreakdown(
            mode: RentalMode.daily,
            units:
                (DateTime(end.year, end.month, end.day)
                        .difference(
                          DateTime(start.year, start.month, start.day),
                        )
                        .inDays)
                    .clamp(1, 365),
            unitRate: vehicle.pricePerDay,
            rentalSubtotal: apiTotal,
            insuranceUnits: 0,
            insuranceSubtotal: 0,
            serviceFee: 0,
            taxes: 0,
            discount: 0,
            deposit: 0,
          )
        : _pricing(
                raw,
                vehicle: vehicle,
                mode: mode,
                start: start,
                end: end,
                insurance: insurance,
              ) ??
              PricingService.calculate(
                vehicle: vehicle,
                mode: mode,
                startAt: start,
                endAt: end,
                insurance: insurance,
              );

    final pickup =
        _pickup(raw['puntoRecogida'] ?? raw['pickupPoint']) ??
        _pickup(raw['puntoEntrega']) ??
        vehicle.pickupPoint ??
        fallbackDraft?.pickupPoint ??
        const PickupPoint(
          id: 'pickup',
          name: 'Carman',
          city: 'Cartagena',
          address: 'Punto de entrega Carman',
          distance: 0,
        );

    final paymentRaw = raw['metodoPago'] ?? raw['paymentMethod'];
    final paymentLabel = paymentRaw is Map<String, dynamic>
        ? [
            '${paymentRaw['marca'] ?? paymentRaw['label'] ?? 'Tarjeta'}',
            if (paymentRaw['ultimos4'] != null)
              '•••• ${paymentRaw['ultimos4']}',
          ].join(' ')
        : '${paymentRaw ?? raw['paymentMethodLabel'] ?? 'Método de pago'}';

    return Reservation(
      id: _string(raw['idReserva'] ?? raw['id'] ?? raw['_id']) ?? 'res-api',
      code:
          _string(raw['codigo'] ?? raw['code']) ??
          '#${raw['idReserva'] ?? '—'}',
      vehicle: vehicle,
      startAt: start,
      endAt: end,
      mode: mode,
      pickupPoint: pickup,
      pricing: pricing,
      status: _status(raw['estado'] ?? raw['status']),
      createdAt:
          _date(
            raw['fechaHoraReserva'] ?? raw['createdAt'] ?? raw['fechaCreacion'],
          ) ??
          DateTime.now(),
      paymentMethodLabel: AppConfig.useLiveApi
          ? 'No se ha iniciado un pago'
          : paymentLabel,
      digitalKeyCode:
          _string(raw['codigoLlave'] ?? raw['digitalKeyCode']) ??
          (AppConfig.useLiveApi ? '' : 'CRMN-0000'),
      insuranceName: AppConfig.useLiveApi
          ? 'Sin cobertura adicional contratada'
          : (_string(raw['seguroNombre']) ?? insurance.name),
      hasReview:
          raw['resenado'] == true ||
          raw['resenado'] == 1 ||
          raw['hasReview'] == true,
      canReview:
          !AppConfig.useLiveApi ||
          (raw['rolesRelacionados'] is List &&
              (raw['rolesRelacionados'] as List).contains('Cliente')),
      canOperate:
          AppConfig.useLiveApi &&
          (raw['rolesRelacionados'] is List &&
              ((raw['idConductor'] != null &&
                      (raw['rolesRelacionados'] as List).contains(
                        'Conductor',
                      )) ||
                  (raw['idConductor'] == null &&
                      (raw['rolesRelacionados'] as List).contains('Cliente')))),
      awaitingDriverDecision:
          AppConfig.useLiveApi &&
          raw['idConductor'] == null &&
          raw['estadoRespuestaConductor'] == 'Sin_conductor' &&
          raw['decisionSinConductor'] == null &&
          raw['estado'] == 'Pendiente',
      cancellationFee: _double(raw['cargoCancelacion']) ?? 0,
    );
  }

  static AppNotification notification(Map<String, dynamic> json) {
    final raw = json['notificacion'] is Map<String, dynamic>
        ? json['notificacion'] as Map<String, dynamic>
        : json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return AppNotification(
      id: _string(raw['idNotificacion'] ?? raw['id']) ?? 'not-api',
      kind: _notificationKind(raw['tipo'] ?? raw['kind']),
      title: _string(raw['titulo'] ?? raw['title']) ?? 'Notificación',
      body: _string(raw['mensaje'] ?? raw['body'] ?? raw['descripcion']) ?? '',
      createdAt:
          _date(
            raw['fechaHoraEnvio'] ??
                raw['fechaHora'] ??
                raw['createdAt'] ??
                raw['fecha'],
          ) ??
          DateTime.now(),
      isRead: raw['leida'] == true || raw['isRead'] == true,
      actionRoute: _string(raw['rutaAccion'] ?? raw['actionRoute']),
    );
  }

  static AdminDashboardData adminDashboard(Map<String, dynamic> json) {
    final root = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawUsers = root['usuarios'] ?? root['users'];
    final rawApprovals = root['aprobaciones'] ?? root['approvals'];
    final rawStats = root['estadisticas'] ?? root['stats'];
    if (AppConfig.useLiveApi &&
        (rawUsers is! List ||
            rawApprovals is! List ||
            rawStats is! Map<String, dynamic>)) {
      throw const AppException(
        'El panel administrativo no es válido.',
        code: 'invalid_admin_dashboard',
      );
    }

    final users = <AdminUser>[];
    if (rawUsers is List) {
      for (final item in rawUsers) {
        if (item is! Map<String, dynamic>) {
          if (AppConfig.useLiveApi) {
            throw const AppException('Usuario administrativo inválido.');
          }
          continue;
        }
        if (AppConfig.useLiveApi &&
            (int.tryParse('${item['idPersona']}') == null ||
                _date(item['fechaHoraRegistro']) == null)) {
          throw const AppException('Usuario sin ID o fecha válida.');
        }
        users.add(
          AdminUser(
            id: _string(item['idPersona'] ?? item['id']) ?? 'user',
            name:
                _string(
                  '${item['nombre'] ?? ''} ${item['apellido'] ?? ''}'.trim(),
                ) ??
                'Usuario',
            email: _string(item['email']) ?? '',
            phone: _string(item['telefono'] ?? item['phone']) ?? '',
            city: _string(item['ciudad'] ?? item['city']) ?? '',
            roles: _roles(AppConfig.useLiveApi ? item : item['roles']),
            isAdmin:
                item['administrador'] == 1 || item['administrador'] == true,
            status: AdminUserStatus.fromApi(item['estado'] ?? item['status']),
            joinedAt:
                _date(item['fechaHoraRegistro'] ?? item['createdAt']) ??
                DateTime.now(),
            trips: (item['viajes'] as num?)?.toInt() ?? 0,
            verified:
                item['emailVerificado'] == true ||
                item['emailVerificado'] == 1 ||
                (!AppConfig.useLiveApi && item['emailVerificado'] == null),
            avatarAsset: _string(item['fotoPerfil']),
          ),
        );
      }
    }

    final approvals = <AdminApproval>[];
    if (rawApprovals is List) {
      for (final item in rawApprovals) {
        if (item is! Map<String, dynamic>) {
          if (AppConfig.useLiveApi) {
            throw const AppException('Revisión administrativa inválida.');
          }
          continue;
        }
        if (AppConfig.useLiveApi &&
            int.tryParse('${item['idVehiculo']}') == null) {
          throw const AppException('Revisión sin vehículo válido.');
        }
        approvals.add(
          AdminApproval(
            id:
                _string(
                  item['idVehiculo'] ?? item['idAprobacion'] ?? item['id'],
                ) ??
                'approval',
            type: AppConfig.useLiveApi
                ? AdminApprovalType.vehicle
                : AdminApprovalType.fromApi(item['tipo'] ?? item['type']),
            subjectName:
                _string(
                  AppConfig.useLiveApi
                      ? '${item['nombrePropietario'] ?? ''} ${item['apellidoPropietario'] ?? ''}'
                            .trim()
                      : item['solicitante'] ??
                            item['subjectName'] ??
                            item['nombre'],
                ) ??
                'Usuario',
            subjectEmail: _string(item['email'] ?? item['subjectEmail']) ?? '',
            title: AppConfig.useLiveApi
                ? '${item['marca'] ?? ''} ${item['modelo'] ?? ''}'.trim()
                : _string(item['titulo'] ?? item['title']) ?? 'Solicitud',
            detail:
                _string(
                  AppConfig.useLiveApi
                      ? item['motivo_solicitud_revision']
                      : item['detalle'] ?? item['detail'],
                ) ??
                '',
            submittedAt: _date(item['fechaSolicitud'] ?? item['submittedAt']),
            status: _approvalStatus(
              AppConfig.useLiveApi
                  ? item['estado_solicitud_revision']
                  : item['estado'] ?? item['status'],
            ),
          ),
        );
      }
    }

    final pending = approvals
        .where((approval) => approval.status == AdminApprovalStatus.pending)
        .length;
    final stats = rawStats is Map<String, dynamic>
        ? AdminStats(
            totalUsers: (rawStats['usuarios'] as num?)?.toInt() ?? users.length,
            activeDrivers: (rawStats['conductores'] as num?)?.toInt() ?? 0,
            activeVehicles: (rawStats['vehiculos'] as num?)?.toInt() ?? 0,
            pendingApprovals:
                (rawStats['pendientes'] as num?)?.toInt() ?? pending,
            reservationsToday: (rawStats['reservasHoy'] as num?)?.toInt() ?? 0,
            revenueMonth: _double(rawStats['ingresosMes']) ?? 0,
            growth: _double(rawStats['crecimiento']) ?? 0,
          )
        : AdminStats(
            totalUsers: users.length,
            activeDrivers: users
                .where((user) => user.roles.contains(UserRole.driver))
                .length,
            activeVehicles: 0,
            pendingApprovals: pending,
            reservationsToday: 0,
            revenueMonth: 0,
            growth: 0,
          );

    return AdminDashboardData(
      stats: stats,
      users: users,
      approvals: approvals,
      usersPage: root['paginaUsuarios'] is int
          ? root['paginaUsuarios'] as int
          : 1,
      usersHasMore: root['masUsuarios'] == true,
      revisionsPage: root['paginaRevisiones'] is int
          ? root['paginaRevisiones'] as int
          : 1,
      revisionsHasMore: root['masRevisiones'] == true,
    );
  }

  static Set<UserRole> _roles(Object? raw) {
    final roles = <UserRole>{};
    if (raw is Map<String, dynamic>) {
      if (raw['cliente'] == true || raw['cliente'] == 1) {
        roles.add(UserRole.client);
      }
      if (raw['propietario'] == true || raw['propietario'] == 1) {
        roles.add(UserRole.owner);
      }
      if (raw['conductor'] == true || raw['conductor'] == 1) {
        roles.add(UserRole.driver);
      }
      if (raw['admin'] == true ||
          raw['administrador'] == true ||
          raw['administrador'] == 1) {
        roles.add(UserRole.admin);
      }
    } else if (raw is List) {
      for (final item in raw) {
        final normalized = '${item ?? ''}'.toLowerCase();
        if (normalized.contains('cliente') || normalized.contains('client')) {
          roles.add(UserRole.client);
        }
        if (normalized.contains('propiet')) roles.add(UserRole.owner);
        if (normalized.contains('conduct') || normalized.contains('driver')) {
          roles.add(UserRole.driver);
        }
        if (normalized.contains('admin')) roles.add(UserRole.admin);
      }
    }
    if (roles.isEmpty && !AppConfig.useLiveApi) roles.add(UserRole.client);
    return roles;
  }

  static AdminApprovalStatus _approvalStatus(Object? value) {
    final normalized = '${value ?? ''}'.toLowerCase();
    if (normalized.contains('rechaz') || normalized.contains('reject')) {
      return AdminApprovalStatus.rejected;
    }
    if (normalized.contains('aprob') || normalized.contains('approve')) {
      return AdminApprovalStatus.approved;
    }
    if (normalized.contains('finaliz')) return AdminApprovalStatus.finalized;
    return AdminApprovalStatus.pending;
  }

  static DriverDashboardData driverDashboard(Map<String, dynamic> json) {
    final root = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawStats = root['estadisticas'] ?? root['stats'];
    final live = AppConfig.useLiveApi;
    final rawAvailability =
        '${root['disponibilidad'] ?? root['availability'] ?? ''}'.toLowerCase();
    final availability =
        rawAvailability.contains('curso') || rawAvailability.contains('trip')
        ? DriverAvailability.onTrip
        : rawAvailability.contains('offline') ||
              rawAvailability.contains('desconect') ||
              rawAvailability == 'false'
        ? DriverAvailability.offline
        : DriverAvailability.online;

    final rawTrips = root['servicios'] ?? root['trips'] ?? root['viajes'];
    if (live &&
        (rawTrips is! List ||
            root['disponibilidad'] is! bool ||
            root['licenciaVigente'] is! bool ||
            root['hayMas'] is! bool ||
            root['pagina'] is! int)) {
      throw const AppException(
        'La respuesta de servicios no es válida.',
        code: 'invalid_driver_dashboard',
      );
    }
    final trips = <DriverTrip>[];
    if (rawTrips is List) {
      for (final item in rawTrips) {
        if (item is! Map<String, dynamic>) {
          if (live) {
            throw const AppException(
              'Un servicio no es válido.',
              code: 'invalid_driver_trip',
            );
          }
          continue;
        }
        final vehicle = _vehicle(item['vehiculo'] ?? item['vehicle']);
        if (vehicle == null) {
          if (live) {
            throw const AppException(
              'El vehículo del servicio no es válido.',
              code: 'invalid_driver_trip',
            );
          }
          continue;
        }
        final rawClient = item['cliente'] ?? item['client'];
        final client = rawClient is Map<String, dynamic> ? rawClient : item;
        final id = _string(
          item['idReserva'] ?? item['idServicio'] ?? item['id'],
        );
        final scheduledAt = live
            ? _date(
                '${item['fechaInicioServicio']}T${item['horaInicioServicio']}',
              )
            : _date(item['fechaHora'] ?? item['scheduledAt'] ?? item['fecha']);
        if (live &&
            (id == null ||
                int.tryParse(id) == null ||
                scheduledAt == null ||
                vehicle.id.isEmpty ||
                item['estado'] is! String)) {
          throw const AppException(
            'El servicio no tiene ID, fecha o estado válido.',
            code: 'invalid_driver_trip',
          );
        }
        final status = live
            ? switch ((item['estado'], item['estadoRespuestaConductor'])) {
                ('Pendiente', 'Pendiente') => DriverTripStatus.offered,
                ('Confirmada', 'Aceptada') => DriverTripStatus.accepted,
                ('EnCurso', _) => DriverTripStatus.inProgress,
                ('Finalizada', _) => DriverTripStatus.completed,
                ('Cancelada' || 'Rechazada', _) => DriverTripStatus.cancelled,
                _ => DriverTripStatus.unknown,
              }
            : DriverTripStatus.fromApi(item['estado'] ?? item['status']);
        trips.add(
          DriverTrip(
            id: id ?? 'svc',
            clientName:
                _string(client['nombre'] ?? item['clientName'] ?? 'Cliente') ??
                'Cliente',
            clientPhone:
                _string(client['telefono'] ?? item['clientPhone']) ?? '',
            clientAvatarAsset: _string(client['fotoPerfil']),
            vehicle: vehicle,
            origin: _string(item['origen'] ?? item['origin']) ?? '',
            destination: _string(item['destino'] ?? item['destination']) ?? '',
            scheduledAt: scheduledAt ?? DateTime.now(),
            endsAt: live
                ? _date(
                    '${item['fechaFinServicio']}T${item['horaFinServicio']}',
                  )
                : null,
            distanceKm: _double(item['distanciaKm'] ?? item['distanceKm']) ?? 0,
            durationMinutes:
                (item['duracionMin'] as num?)?.toInt() ??
                (item['durationMinutes'] as num?)?.toInt() ??
                0,
            earnings: _double(item['ganancia'] ?? item['earnings']) ?? 0,
            status: status,
            notes: _string(item['notas'] ?? item['notes']) ?? '',
          ),
        );
      }
    }

    final stats = rawStats is Map<String, dynamic>
        ? DriverStats(
            tripsToday: (rawStats['viajesHoy'] as num?)?.toInt() ?? 0,
            earningsToday: _double(rawStats['gananciasHoy']) ?? 0,
            earningsWeek: _double(rawStats['gananciasSemana']) ?? 0,
            rating: _double(rawStats['rating']) ?? 0,
            acceptanceRate: _double(rawStats['aceptacion']) ?? 0,
            hoursOnline: _double(rawStats['horasConectado']) ?? 0,
            completedTotal: (rawStats['viajesTotales'] as num?)?.toInt() ?? 0,
          )
        : const DriverStats(
            tripsToday: 0,
            earningsToday: 0,
            earningsWeek: 0,
            rating: 0,
            acceptanceRate: 0,
            hoursOnline: 0,
            completedTotal: 0,
          );

    return DriverDashboardData(
      stats: stats,
      availability:
          live &&
              trips.any((trip) => trip.status == DriverTripStatus.inProgress)
          ? DriverAvailability.onTrip
          : availability,
      trips: trips,
      page: root['pagina'] is int ? root['pagina'] as int : 1,
      hasMore: root['hayMas'] == true,
      licenseValid: root['licenciaVigente'] == true || !live,
    );
  }

  static OwnerDashboardData ownerDashboard(Map<String, dynamic> json) {
    final root = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawStats = root['estadisticas'] ?? root['stats'];
    final rawVehicles = root['vehiculos'] ?? root['vehicles'];
    if (rawVehicles is! List) {
      throw const AppException(
        'El inventario del propietario no es válido.',
        code: 'invalid_owner_dashboard',
      );
    }
    final listings = <OwnerListing>[];
    {
      for (final item in rawVehicles) {
        if (item is! Map<String, dynamic>) {
          throw const AppException(
            'El inventario contiene un vehículo inválido.',
            code: 'invalid_owner_vehicle',
          );
        }
        final rawVehicle = item['vehiculo'] is Map<String, dynamic>
            ? item['vehiculo'] as Map<String, dynamic>
            : item;
        final vehicle = _vehicle(rawVehicle);
        if (vehicle == null || vehicle.id.isEmpty) {
          throw const AppException(
            'El inventario contiene un vehículo inválido.',
            code: 'invalid_owner_vehicle',
          );
        }
        final status = OwnerVehicleStatus.fromApi(
          item['estado'] ?? rawVehicle['estado'],
        );
        listings.add(
          OwnerListing(
            meta: OwnerVehicle(
              id:
                  _string(
                    item['idPropietarioVehiculo'] ?? item['id'] ?? vehicle.id,
                  ) ??
                  vehicle.id,
              vehicleId: vehicle.id,
              status: status,
              nextService: _date(
                item['proximoMantenimiento'] ?? item['nextService'],
              ),
              monthlyRevenue: _double(item['ingresoMes']) ?? 0,
              tripsThisMonth: (item['viajesMes'] as num?)?.toInt() ?? 0,
              documentsInOrder: item['documentosAlDia'] as bool? ?? false,
              reviewStatus: _string(item['estado_solicitud_revision']),
              reviewReason: _string(item['motivo_solicitud_revision']),
              rejectionReason: _string(item['motivo_rechazo_revision']),
            ),
            vehicle: vehicle,
          ),
        );
      }
    }

    final stats = _ownerStats(rawStats, listings);
    return OwnerDashboardData(stats: stats, listings: listings);
  }

  static OwnerStats _ownerStats(Object? raw, List<OwnerListing> listings) {
    if (raw is Map<String, dynamic>) {
      return OwnerStats(
        vehicles: (raw['vehiculos'] as num?)?.toInt() ?? listings.length,
        activeVehicles:
            (raw['activos'] as num?)?.toInt() ??
            listings
                .where((l) => l.meta.status == OwnerVehicleStatus.available)
                .length,
        monthlyRevenue:
            _double(raw['ingresosMes']) ??
            listings.fold(0, (sum, l) => sum + l.meta.monthlyRevenue),
        pendingReservations: (raw['reservasPendientes'] as num?)?.toInt() ?? 0,
        occupancyRate: _double(raw['ocupacion']) ?? 0,
        previousMonthRevenue: _double(raw['ingresosMesAnterior']) ?? 0,
      );
    }
    return OwnerStats(
      vehicles: listings.length,
      activeVehicles: listings
          .where((l) => l.meta.status == OwnerVehicleStatus.available)
          .length,
      monthlyRevenue: listings.fold(0, (sum, l) => sum + l.meta.monthlyRevenue),
      pendingReservations: 0,
      occupancyRate: 0,
      previousMonthRevenue: 0,
    );
  }

  static PricingBreakdown? _pricing(
    Map<String, dynamic> raw, {
    required Vehicle vehicle,
    required RentalMode mode,
    required DateTime start,
    required DateTime end,
    required InsurancePlan insurance,
  }) {
    final breakdown = raw['desglose'] ?? raw['pricing'];
    if (breakdown is! Map<String, dynamic>) return null;
    final units =
        (breakdown['unidades'] as num?)?.toInt() ??
        PricingService.unitsFor(mode: mode, startAt: start, endAt: end);
    final unitRate =
        _double(breakdown['tarifa']) ??
        (mode == RentalMode.hourly
            ? vehicle.pricePerHour
            : vehicle.pricePerDay);
    final rental = _double(breakdown['alquiler']) ?? unitRate * units;
    final insuranceUnits = (breakdown['diasSeguro'] as num?)?.toInt() ?? units;
    final insuranceTotal =
        _double(breakdown['seguro']) ?? insurance.dailyPrice * insuranceUnits;
    final service = _double(breakdown['servicio']) ?? 0;
    final taxes = _double(breakdown['impuestos']) ?? 0;
    final discount = _double(breakdown['descuento']) ?? 0;
    final deposit = _double(breakdown['deposito']) ?? 150;
    return PricingBreakdown(
      mode: mode,
      units: units,
      unitRate: unitRate,
      rentalSubtotal: rental,
      insuranceUnits: insuranceUnits,
      insuranceSubtotal: insuranceTotal,
      serviceFee: service,
      taxes: taxes,
      discount: discount,
      deposit: deposit,
    );
  }

  static Vehicle? _vehicle(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      return Vehicle.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static PickupPoint? _pickup(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return PickupPoint(
      id:
          _string(raw['id'] ?? raw['idPunto'] ?? raw['idPuntoRecogida']) ??
          'pickup',
      name: _string(raw['nombre'] ?? raw['name']) ?? 'Entrega',
      city: _string(raw['ciudad'] ?? raw['city']) ?? '',
      address: _string(raw['direccion'] ?? raw['address']) ?? '',
      distance: _double(raw['distancia'] ?? raw['distance']) ?? 0,
      isFree: raw['gratis'] as bool? ?? true,
      latitude: _double(raw['latitud'] ?? raw['latitude']) ?? 10.39,
      longitude: _double(raw['longitud'] ?? raw['longitude']) ?? -75.47,
    );
  }

  static RentalMode? _mode(Object? value) {
    final normalized = '${value ?? ''}'.toLowerCase();
    if (normalized.contains('hour') || normalized.contains('hora')) {
      return RentalMode.hourly;
    }
    if (normalized.contains('day') || normalized.contains('dia')) {
      return RentalMode.daily;
    }
    return null;
  }

  static InsurancePlan? _insurance(Object? value) {
    final normalized = '${value ?? ''}'.toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized.contains('basic') || normalized.contains('basico')) {
      return InsurancePlan.basic;
    }
    return InsurancePlan.premium;
  }

  static ReservationStatus _status(Object? value) {
    final normalized = '${value ?? ''}'.toLowerCase();
    if (normalized.contains('cancel')) return ReservationStatus.cancelled;
    if (normalized.contains('complet') || normalized.contains('finaliz')) {
      return ReservationStatus.completed;
    }
    if (normalized.contains('activ') || normalized.contains('curso')) {
      return ReservationStatus.active;
    }
    if (normalized.contains('rechaz')) return ReservationStatus.rejected;
    if (normalized.contains('expir')) return ReservationStatus.expired;
    if (normalized.contains('pend') || normalized.contains('pago')) {
      return ReservationStatus.pendingPayment;
    }
    return ReservationStatus.confirmed;
  }

  static NotificationKind _notificationKind(Object? value) {
    final normalized = '${value ?? ''}'.toLowerCase();
    if (normalized.contains('reserv')) return NotificationKind.reservation;
    if (normalized.contains('pago') || normalized.contains('payment')) {
      return NotificationKind.payment;
    }
    if (normalized.contains('licen')) return NotificationKind.license;
    if (normalized.contains('mens') || normalized.contains('chat')) {
      return NotificationKind.message;
    }
    return NotificationKind.system;
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }

  static String? _string(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }
}
