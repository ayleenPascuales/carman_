/// Central contract with the NestJS backend.
///
/// Keep endpoint paths here so connecting a new environment or renaming a
/// route never requires touching presentation code. The full payload contract
/// is documented in `docs/api_contract.md`.
abstract final class ApiEndpoints {
  // Auth & people.
  static const login = '/auth/login';
  static const verification = '/auth/verificacion';
  static const resendEmail = '/auth/correo/reenviar';
  static const resendPhone = '/auth/telefono/reenviar';
  static const confirmPhone = '/auth/telefono/confirmar';
  static const profile = '/personas/perfil';
  static const register = '/personas/registro';
  static const roles = '/personas/roles';
  static const license = '/personas/licencia';

  // Vehicles.
  static const vehicles = '/vehiculos';
  static const vehicleCatalog = '/vehiculos/catalogo';
  static const myVehicles = '/vehiculos/mis-vehiculos';
  static const pickupPoints = '/puntos-autorizados';
  static const favorites = '/vehiculos/favoritos';

  static String vehicle(Object id) => '/vehiculos/$id';

  // Reservations.
  static const reservations = '/reservas';
  static const myReservations = '/reservas/mias';

  static String reservation(Object id) => '/reservas/$id';
  static String cancelReservation(Object id) => '/reservas/$id/cancelar';
  static String reviewReservation(Object id) => '/reservas/$id/calificacion';

  // Notifications.
  static const notifications = '/notificaciones';
  static const notificationsRead = '/notificaciones/leidas';

  static String notificationRead(Object id) => '/notificaciones/$id/leida';

  // Owner dashboard.
  static const ownerSummary = '/propietario/resumen';

  // Driver panel.
  static const driverSummary = '/conductor/resumen';
  static const driverAvailability = '/conductor/disponibilidad';
  static const driverTrips = '/conductor/servicios';

  static String driverAccept(Object id) => '/conductor/servicios/$id/aceptar';
  static String driverStart(Object id) => '/conductor/servicios/$id/iniciar';
  static String driverComplete(Object id) =>
      '/conductor/servicios/$id/finalizar';
  static String driverDecline(Object id) => '/conductor/servicios/$id/rechazar';

  // Administration panel.
  static const adminSummary = '/admin/resumen';
  static const adminUsers = '/admin/usuarios';
  static const adminApprovals = '/admin/aprobaciones';

  static String adminUserStatus(Object id) => '/admin/usuarios/$id/estado';
  static String adminApproval(Object id) => '/admin/aprobaciones/$id';

  // Payments (contract reserved for the gateway implementation).
  static const paymentMethods = '/pagos/metodos';
  static const payments = '/pagos';

  static String paymentMethod(Object id) => '/pagos/metodos/$id';
}
