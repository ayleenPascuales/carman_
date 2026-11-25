import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_assets.dart';
import '../models/app_notification.dart';
import '../models/booking.dart';
import '../models/owner_models.dart';
import '../models/payment_method.dart';
import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../models/vehicle_query.dart';

/// Deterministic demo catalogue. It mirrors the data contract expected from the
/// NestJS API so screens can be switched to live data without UI changes.
abstract final class MockData {
  static final now = DateTime.now();

  static final pickupPoints = <PickupPoint>[
    const PickupPoint(
      id: 'pp-centro',
      name: 'Cartagena · Centro',
      city: 'Cartagena',
      address: 'Muelle Los Pegasos, Bocagrande o entrega en hotel',
      distance: 0.3,
      type: 'hub',
    ),
    const PickupPoint(
      id: 'pp-bocagrande',
      name: 'Bocagrande · Hotel Estelar',
      city: 'Cartagena',
      address: 'Calle 6 # 6-56, Bocagrande · parking privado',
      distance: 0.8,
      type: 'hotel',
    ),
    const PickupPoint(
      id: 'pp-manga',
      name: 'Carman Express Hub · Manga',
      city: 'Cartagena',
      address: 'Calle 28 # 21-15, Manga · entrega exprés',
      distance: 1.4,
      type: 'hub',
    ),
    const PickupPoint(
      id: 'pp-aeropuerto',
      name: 'Aeropuerto Rafael Núñez',
      city: 'Cartagena',
      address: 'Terminal nacional · módulo Carman',
      distance: 3.2,
      type: 'airport',
    ),
    const PickupPoint(
      id: 'pp-castillogrande',
      name: 'Castillogrande · Parqueadero',
      city: 'Cartagena',
      address: 'Carrera 2 # 5-90, Castillogrande',
      distance: 2.1,
      type: 'parking',
    ),
    const PickupPoint(
      id: 'pp-bogota',
      name: 'Bogotá · Chapinero',
      city: 'Bogotá',
      address: 'Calle 67 # 7-35, Chapinero',
      distance: 0.5,
      type: 'hub',
    ),
    const PickupPoint(
      id: 'pp-medellin',
      name: 'Medellín · El Poblado',
      city: 'Medellín',
      address: 'Carrera 43A # 7-50, El Poblado',
      distance: 0.9,
      type: 'hub',
    ),
  ];

  static const _teslaFeatures = <VehicleFeature>[
    VehicleFeature(
      icon: Icons.key_rounded,
      title: 'Apertura remota directa',
      description: 'Desbloquea el vehículo con un toque directo desde la aplicación Carman.',
    ),
    VehicleFeature(
      icon: Icons.ev_station_rounded,
      title: 'Carga en Superchargers',
      description: 'Recarga gratuita y plug-and-charge incluida hasta el 80% en la red oficial.',
    ),
    VehicleFeature(
      icon: Icons.verified_user_rounded,
      title: 'Seguro a todo riesgo Allianz',
      description: 'Cobertura completa con franquicia 0€ y asistencia 24/7 en carretera.',
    ),
  ];

  static final vehicles = <Vehicle>[
    Vehicle(
      id: 'veh-tesla-y',
      brand: 'Tesla',
      model: 'Model Y Gran Autonomía',
      year: 2023,
      category: VehicleCategory.electric,
      fuel: FuelType.electric,
      transmission: TransmissionType.automatic,
      seats: 5,
      pricePerHour: 18,
      pricePerDay: 75,
      rating: 4.98,
      tripCount: 46,
      ownerName: 'Elena Valdés',
      ownerAvatarAsset: AppAssets.avatarElena,
      ownerBadge: OwnerBadge.superhost,
      locationName: 'Bocagrande',
      city: 'Cartagena',
      photos: AppAssets.teslaGallery,
      autonomyKm: 480,
      acceleration: 4.8,
      luggageLiters: 854,
      traction: 'Dual Motor AWD',
      pickupPoint: pickupPoints[1],
      description:
          'SUV 100% eléctrico con techo panorámico, Autopilot y acceso sin llave. '
          'Ideal para recorrer la ciudad y la costa con cero emisiones.',
      features: _teslaFeatures,
      plate: 'CAR-482',
      ownerId: 'owner-elena',
    ),
    Vehicle(
      id: 'veh-cupra',
      brand: 'Cupra',
      model: 'Formentor e-HYBRID',
      year: 2024,
      category: VehicleCategory.suv,
      fuel: FuelType.hybrid,
      transmission: TransmissionType.automatic,
      seats: 5,
      pricePerHour: 15,
      pricePerDay: 58,
      rating: 4.92,
      tripCount: 31,
      ownerName: 'Marcos Duarte',
      ownerAvatarAsset: AppAssets.avatarUser,
      ownerBadge: OwnerBadge.verified,
      locationName: 'Manga',
      city: 'Cartagena',
      photos: [AppAssets.cupraFormentor2, AppAssets.cupraFormentor],
      autonomyKm: 60,
      acceleration: 7.0,
      luggageLiters: 510,
      traction: 'Delantera',
      pickupPoint: pickupPoints[2],
      description:
          'Híbrido enchufable con etiqueta 0, cambio DSG y modo 100% eléctrico '
          'para moverte sin restricciones por el centro histórico.',
      features: const [
        VehicleFeature(
          icon: Icons.key_rounded,
          title: 'Apertura con app',
          description: 'Entrega sin contacto en el hub de Manga.',
        ),
        VehicleFeature(
          icon: Icons.eco_rounded,
          title: 'Etiqueta 0',
          description: 'Acceso libre a zonas de bajas emisiones.',
        ),
        VehicleFeature(
          icon: Icons.verified_user_rounded,
          title: 'Asistencia 24/7',
          description: 'Cobertura nacional con grúa incluida.',
        ),
      ],
      plate: 'CRN-751',
      ownerId: 'owner-marcos',
    ),
    Vehicle(
      id: 'veh-audi-q3',
      brand: 'Audi',
      model: 'Q3 Sportback',
      year: 2023,
      category: VehicleCategory.suv,
      fuel: FuelType.gasoline,
      transmission: TransmissionType.automatic,
      seats: 5,
      pricePerHour: 16,
      pricePerDay: 62,
      rating: 4.89,
      tripCount: 35,
      ownerName: 'Camila Rojas',
      ownerAvatarAsset: AppAssets.avatarUser,
      ownerBadge: OwnerBadge.verified,
      locationName: 'Castillogrande',
      city: 'Cartagena',
      photos: [AppAssets.audiQ3],
      autonomyKm: 610,
      acceleration: 8.5,
      luggageLiters: 530,
      traction: 'Delantera',
      ecoLabel: 'Eco Gas',
      pickupPoint: pickupPoints[4],
      description:
          'SUV coupé con micro-hibridación, cámara 360° y asientos deportivos. '
          'Perfecto para viajes de trabajo o escapadas familiares.',
      features: const [
        VehicleFeature(
          icon: Icons.camera_alt_rounded,
          title: 'Cámara 360°',
          description: 'Ayuda al aparcamiento y sensores delanteros.',
        ),
        VehicleFeature(
          icon: Icons.bluetooth_rounded,
          title: 'Apple CarPlay',
          description: 'Conectividad inalámbrica y navegación integrada.',
        ),
        VehicleFeature(
          icon: Icons.local_gas_station_rounded,
          title: 'Eco Gas',
          description: 'Etiqueta ECO y consumo contenido.',
        ),
      ],
      plate: 'AUD-902',
      ownerId: 'owner-camila',
    ),
    Vehicle(
      id: 'veh-tesla-3',
      brand: 'Tesla',
      model: 'Model 3',
      year: 2023,
      category: VehicleCategory.electric,
      fuel: FuelType.electric,
      transmission: TransmissionType.automatic,
      seats: 5,
      pricePerHour: 18,
      pricePerDay: 64,
      rating: 4.98,
      tripCount: 42,
      ownerName: 'Elena Valdés',
      ownerAvatarAsset: AppAssets.avatarElenaAlt,
      ownerBadge: OwnerBadge.superhost,
      locationName: 'Centro',
      city: 'Cartagena',
      photos: [
        AppAssets.teslaModel3,
        AppAssets.teslaFront,
        AppAssets.teslaInterior,
      ],
      autonomyKm: 480,
      acceleration: 6.1,
      luggageLiters: 594,
      traction: 'Trasera',
      pickupPoint: pickupPoints[0],
      description:
          'La berlina eléctrica más eficiente de Carman. Autopilot, '
          'techo de cristal y carga rápida incluida por horas.',
      features: _teslaFeatures,
      plate: 'T3S-330',
      ownerId: 'owner-elena',
    ),
    Vehicle(
      id: 'veh-porsche',
      brand: 'Porsche',
      model: '911 Carrera S',
      year: 2022,
      category: VehicleCategory.sport,
      fuel: FuelType.gasoline,
      transmission: TransmissionType.automatic,
      seats: 4,
      pricePerHour: 49,
      pricePerDay: 189,
      rating: 4.99,
      tripCount: 64,
      ownerName: 'Andrés Prieto',
      ownerAvatarAsset: AppAssets.avatarUser,
      ownerBadge: OwnerBadge.superhost,
      locationName: 'Bocagrande',
      city: 'Cartagena',
      photos: [AppAssets.heroPorsche, AppAssets.sportsCar],
      autonomyKm: 420,
      acceleration: 3.5,
      luggageLiters: 132,
      doors: 2,
      traction: 'Trasera',
      ecoLabel: 'Sport',
      pickupPoint: pickupPoints[1],
      description:
          'Experiencia de conducción pura con motor bóxer biturbo, PDK y '
          'escape deportivo. Entrega personalizada con briefing incluido.',
      features: const [
        VehicleFeature(
          icon: Icons.speed_rounded,
          title: 'Modo Sport Chrono',
          description: 'Ajusta motor, cambio y suspensión al instante.',
        ),
        VehicleFeature(
          icon: Icons.verified_rounded,
          title: 'Entrega personalizada',
          description: 'Briefing de conducción de 15 minutos incluido.',
        ),
        VehicleFeature(
          icon: Icons.shield_rounded,
          title: 'Seguro Premium',
          description: 'Cobertura a todo riesgo con franquicia reducida.',
        ),
      ],
      plate: 'PRS-911',
      ownerId: 'owner-andres',
    ),
    Vehicle(
      id: 'veh-bmw-ix',
      brand: 'BMW',
      model: 'iX xDrive50',
      year: 2024,
      category: VehicleCategory.premium,
      fuel: FuelType.electric,
      transmission: TransmissionType.automatic,
      seats: 5,
      pricePerHour: 30,
      pricePerDay: 119,
      rating: 4.95,
      tripCount: 22,
      ownerName: 'Sofía López',
      ownerAvatarAsset: AppAssets.avatarUser,
      ownerBadge: OwnerBadge.verified,
      locationName: 'Chapinero',
      city: 'Bogotá',
      photos: [AppAssets.teslaWhiteShowroom],
      autonomyKm: 630,
      acceleration: 4.6,
      luggageLiters: 500,
      traction: 'xDrive AWD',
      pickupPoint: pickupPoints[5],
      description:
          'SUV eléctrico de lujo con Harman Kardon, asientos ventilados y '
          'conducción asistida nivel 2. Ideal para ejecutivos.',
      features: const [
        VehicleFeature(
          icon: Icons.airline_seat_recline_extra_rounded,
          title: 'Asientos ventilados',
          description: 'Confort premium para trayectos largos.',
        ),
        VehicleFeature(
          icon: Icons.surround_sound_rounded,
          title: 'Harman Kardon',
          description: 'Sistema de sonido de 18 altavoces.',
        ),
        VehicleFeature(
          icon: Icons.key_rounded,
          title: 'Llave digital',
          description: 'Abre y arranca desde Carman.',
        ),
      ],
      plate: 'BMW-1X50',
      ownerId: 'owner-sofia',
    ),
    Vehicle(
      id: 'veh-mercedes',
      brand: 'Mercedes-Benz',
      model: 'Clase C 200',
      year: 2023,
      category: VehicleCategory.premium,
      fuel: FuelType.gasoline,
      transmission: TransmissionType.automatic,
      seats: 5,
      pricePerHour: 24,
      pricePerDay: 95,
      rating: 4.91,
      tripCount: 28,
      ownerName: 'Daniel Mejía',
      ownerAvatarAsset: AppAssets.avatarUser,
      ownerBadge: OwnerBadge.verified,
      locationName: 'El Poblado',
      city: 'Medellín',
      photos: [AppAssets.cupraProto, AppAssets.cupraFormentor],
      autonomyKm: 580,
      acceleration: 7.3,
      luggageLiters: 455,
      traction: 'Trasera',
      pickupPoint: pickupPoints[6],
      description:
          'Elegancia y tecnología con pantalla MBUX, techo panorámico y '
          'asistente de voz. Una opción ejecutiva redonda.',
      features: const [
        VehicleFeature(
          icon: Icons.auto_awesome_rounded,
          title: 'MBUX con voz',
          description: 'Controla navegación y clima con “Hola Mercedes”.',
        ),
        VehicleFeature(
          icon: Icons.panorama_wide_angle_rounded,
          title: 'Techo panorámico',
          description: 'Luz natural y sensación de amplitud.',
        ),
        VehicleFeature(
          icon: Icons.shield_rounded,
          title: 'Seguro todo riesgo',
          description: 'Cobertura Allianz y asistencia nacional.',
        ),
      ],
      plate: 'MBZ-C200',
      ownerId: 'owner-daniel',
    ),
    Vehicle(
      id: 'veh-kia-ev6',
      brand: 'Kia',
      model: 'EV6 GT-Line',
      year: 2024,
      category: VehicleCategory.family,
      fuel: FuelType.electric,
      transmission: TransmissionType.automatic,
      seats: 5,
      pricePerHour: 17,
      pricePerDay: 68,
      rating: 4.90,
      tripCount: 19,
      ownerName: 'Natalia Gómez',
      ownerAvatarAsset: AppAssets.avatarUser,
      ownerBadge: OwnerBadge.newHost,
      locationName: 'Getsemaní',
      city: 'Cartagena',
      photos: [AppAssets.teslaModelYCheckout, AppAssets.teslaSide],
      autonomyKm: 528,
      acceleration: 5.2,
      luggageLiters: 480,
      traction: 'Trasera',
      pickupPoint: pickupPoints[0],
      description:
          'Crossover eléctrico con carga ultrarrápida de 18 minutos, '
          'maletero amplio y plazas traseras reclinables.',
      features: const [
        VehicleFeature(
          icon: Icons.bolt_rounded,
          title: 'Carga ultrarrápida',
          description: 'Del 10 al 80% en unos 18 minutos.',
        ),
        VehicleFeature(
          icon: Icons.child_care_rounded,
          title: 'Silla infantil gratis',
          description: 'Solicítala al confirmar la reserva.',
        ),
        VehicleFeature(
          icon: Icons.luggage_rounded,
          title: 'Maletero 480 L',
          description: 'Espacio de sobra para toda la familia.',
        ),
      ],
      plate: 'KIA-EV6',
      ownerId: 'owner-natalia',
    ),
  ];

  static final demoUser = UserProfile(
    id: 'person-1',
    firstName: 'Alex',
    lastName: 'Rivera',
    email: 'alex.rivera@carman.es',
    phone: '+57 300 123 4567',
    city: 'Cartagena',
    document: '1020304050',
    avatarAsset: AppAssets.avatarUser,
    roles: const {
      UserRole.client,
      UserRole.owner,
      UserRole.driver,
      UserRole.admin,
    },
    licenseStatus: LicenseStatus.approved,
    memberSince: DateTime(2024, 3, 12),
    rating: 4.9,
    tripCount: 14,
  );

  static final notifications = <AppNotification>[
    AppNotification(
      id: 'not-1',
      kind: NotificationKind.reservation,
      title: 'Tu reserva está confirmada',
      body: 'Tesla Model Y · 15 – 18 Nov. Tu llave digital se activará 15 min antes.',
      createdAt: now.subtract(const Duration(minutes: 12)),
      actionRoute: '/trips',
    ),
    AppNotification(
      id: 'not-2',
      kind: NotificationKind.license,
      title: 'Licencia verificada',
      body: 'Tu permiso de conducir fue aprobado. Ya puedes reservar sin límites.',
      createdAt: now.subtract(const Duration(hours: 3)),
      isRead: true,
      actionRoute: '/license',
    ),
    AppNotification(
      id: 'not-3',
      kind: NotificationKind.payment,
      title: 'Pago procesado',
      body: 'Cobro de \$366.63 con Apple Pay · Mastercard •••• 4242.',
      createdAt: now.subtract(const Duration(days: 1)),
      isRead: true,
      actionRoute: '/trips',
    ),
    AppNotification(
      id: 'not-4',
      kind: NotificationKind.message,
      title: 'Elena te envió un mensaje',
      body: '“Te dejé el coche cargado al 100%. ¡Buen viaje!”',
      createdAt: now.subtract(const Duration(days: 2)),
      isRead: true,
    ),
    AppNotification(
      id: 'not-5',
      kind: NotificationKind.system,
      title: 'Nuevos vehículos en Cartagena',
      body: 'Kia EV6 y BMW iX ya están disponibles para tus próximas fechas.',
      createdAt: now.subtract(const Duration(days: 4)),
      isRead: true,
    ),
  ];

  static Reservation _reservation({
    required String id,
    required String code,
    required Vehicle vehicle,
    required DateTime start,
    required DateTime end,
    required ReservationStatus status,
    required InsurancePlan insurance,
    required String paymentMethod,
    bool reviewed = false,
    RentalMode mode = RentalMode.daily,
  }) {
    final point = vehicle.pickupPoint ?? pickupPoints.first;
    return Reservation(
      id: id,
      code: code,
      vehicle: vehicle,
      startAt: start,
      endAt: end,
      mode: mode,
      pickupPoint: point,
      pricing: PricingService.calculate(
        vehicle: vehicle,
        mode: mode,
        startAt: start,
        endAt: end,
        insurance: insurance,
      ),
      status: status,
      createdAt: start.subtract(const Duration(days: 2)),
      paymentMethodLabel: paymentMethod,
      insuranceName: insurance.name,
      hasReview: reviewed,
    );
  }

  static List<Reservation> get reservations {
    final today = DateTime(now.year, now.month, now.day);
    return [
      _reservation(
        id: 'res-active',
        code: 'CRMN-4821',
        vehicle: vehicles[3],
        start: today
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 10)),
        end: today.add(const Duration(days: 1, hours: 10)),
        status: ReservationStatus.active,
        insurance: InsurancePlan.premium,
        paymentMethod: 'Apple Pay · Mastercard •••• 4242',
      ),
      _reservation(
        id: 'res-upcoming',
        code: 'CRMN-7310',
        vehicle: vehicles[0],
        start: today.add(const Duration(days: 3, hours: 10)),
        end: today.add(const Duration(days: 6, hours: 10)),
        status: ReservationStatus.confirmed,
        insurance: InsurancePlan.premium,
        paymentMethod: 'Apple Pay · Mastercard •••• 4242',
      ),
      _reservation(
        id: 'res-past',
        code: 'CRMN-1188',
        vehicle: vehicles[2],
        start: today.subtract(const Duration(days: 26, hours: 2)),
        end: today.subtract(const Duration(days: 24, hours: 2)),
        status: ReservationStatus.completed,
        insurance: InsurancePlan.premium,
        paymentMethod: 'Visa Débito •••• 8819',
      ),
      _reservation(
        id: 'res-cancelled',
        code: 'CRMN-0954',
        vehicle: vehicles[1],
        start: today.subtract(const Duration(days: 55)),
        end: today.subtract(const Duration(days: 52)),
        status: ReservationStatus.cancelled,
        insurance: InsurancePlan.basic,
        paymentMethod: 'PayPal',
      ),
    ];
  }

  static const paymentMethods = PaymentMethodsSeed.all;

  static const ownerStats = OwnerStats(
    vehicles: 2,
    activeVehicles: 2,
    monthlyRevenue: 2480,
    pendingReservations: 3,
    occupancyRate: 0.78,
    previousMonthRevenue: 2210,
  );

  static List<OwnerVehicle> get ownerVehicles {
    final today = DateTime(now.year, now.month, now.day);
    return [
      OwnerVehicle(
        id: 'ov-1',
        vehicleId: vehicles[0].id,
        status: OwnerVehicleStatus.rented,
        nextService: today.add(const Duration(days: 32)),
        monthlyRevenue: 1480,
        tripsThisMonth: 12,
      ),
      OwnerVehicle(
        id: 'ov-2',
        vehicleId: vehicles[3].id,
        status: OwnerVehicleStatus.available,
        nextService: today.add(const Duration(days: 18)),
        monthlyRevenue: 1000,
        tripsThisMonth: 9,
      ),
    ];
  }

  static List<String> get cities => const [
    'Cartagena',
    'Bogotá',
    'Medellín',
    'Cali',
    'Barranquilla',
  ];

  static List<Vehicle> byIds(Iterable<String> ids) {
    final idSet = ids.toSet();
    return vehicles.where((vehicle) => idSet.contains(vehicle.id)).toList();
  }
}
