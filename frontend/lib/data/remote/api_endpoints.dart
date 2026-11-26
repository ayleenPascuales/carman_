/// Central contract with the NestJS backend.
///
/// Keep endpoint paths here so connecting a new environment or renaming a
/// route never requires touching presentation code. The full payload contract
/// is documented in `docs/api_contract.md`.
abstract final class ApiEndpoints {
  // Auth & people.
  static const login = '/auth/login';
  static const requestPasswordReset = '/auth/password/solicitar-recuperacion';
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
  static String publicVehicle(Object id) => '/vehiculos/catalogo/$id';

  // Reservations.
  static const reservations = '/reservas';
  static const myReservations = '/reservas/mis-reservas';

  static String vehicleReservation(Object id) => '/reservas/vehiculo/$id';
  static String reservation(Object id) => '/reservas/$id';
  static String cancelReservation(Object id) => '/reservas/$id/cancelar';
  static String startReservation(Object id) => '/reservas/$id/iniciar';
  static String finishReservation(Object id) => '/reservas/$id/finalizar';
  static String reviewReservation(Object id) => '/calificaciones/reservas/$id';
  static String vehicleReviews(Object id) => '/calificaciones/vehiculo/$id';
  static String driverReviews(Object id) => '/calificaciones/conductores/$id';

  // Notifications.
  static const notifications = '/notificaciones';
  static const notificationsRead = '/notificaciones/leidas';

  static String notificationRead(Object id) => '/notificaciones/$id/leida';
  static String nearestPickup(Object id) =>
      '/rutas/vehiculos/$id/punto-cercano';
  static String tripRoute(Object id) => '/rutas/reservas/$id';
  static String tripLocation(Object id) => '/rutas/reservas/$id/ubicacion';

  // Owner dashboard.
  static const ownerSummary = '/propietario/resumen';

  // Driver panel.
  static const driverSummary = '/conductor/resumen';
  static const driverAvailability = '/personas/conductor/disponibilidad';
  static const driverTrips = '/reservas/conductor/servicios';

  static String driverAccept(Object id) => '/reservas/$id/respuesta-conductor';
  static String driverStart(Object id) => startReservation(id);
  static String driverComplete(Object id) => finishReservation(id);
  static String driverDecline(Object id) => '/reservas/$id/respuesta-conductor';

  // Administration panel.
  static const adminSummary = '/admin/resumen';
  static const adminUsers = '/admin/usuarios';
  static const adminApprovals = '/admin/revisiones';

  static String adminUser(Object id) => '/admin/usuarios/$id';
  static String adminUserStatus(Object id, bool active) =>
      '/admin/usuarios/$id/${active ? 'reactivar' : 'suspender'}';
  static String adminApproval(Object id) => '/admin/revisiones/$id';

  // Payments are available only in Wompi Sandbox on the backend.
  static const paymentHistory = '/pagos/historial';
  static const paymentMethods = '/pagos/metodos';
  static const payments = '/pagos';
  static String reservationOrder(Object id) => '/pagos/reservas/$id/orden';
  static String orderCheckout(Object id) => '/pagos/ordenes/$id/checkout';

  static String paymentMethod(Object id) => '/pagos/metodos/$id';
}
