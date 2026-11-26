import 'package:geolocator/geolocator.dart';

import '../../data/models/trip_route.dart';
import '../errors/app_exception.dart';

/// Never invoked automatically: the UI must first receive an explicit tap.
abstract final class ForegroundLocation {
  static Future<RoutePosition> current({bool requestIfDenied = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppException('Activa la ubicación del dispositivo para continuar.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestIfDenied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const AppException('No se concedió permiso de ubicación.');
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return RoutePosition(position.latitude, position.longitude);
    } catch (_) {
      throw const AppException('No se pudo obtener tu posición. Inténtalo de nuevo.');
    }
  }
}
