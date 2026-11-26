import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/location/foreground_location.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/booking.dart';
import '../../../../data/models/trip_route.dart';
import '../../../../data/repositories/api_trip_map_repository.dart';
import '../../../../providers.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_card.dart';

/// Se monta solo en la pantalla del viaje; no solicita permiso automáticamente,
/// no ejecuta geolocalización en segundo plano ni guarda trayectorias personales.
class TripRoutePanel extends ConsumerStatefulWidget {
  const TripRoutePanel({super.key, required this.reservation});

  final Reservation reservation;

  @override
  ConsumerState<TripRoutePanel> createState() => _TripRoutePanelState();
}

class _TripRoutePanelState extends ConsumerState<TripRoutePanel>
    with WidgetsBindingObserver {
  TripRoute? _route;
  LocationSnapshot? _location;
  String? _routeError;
  String? _locationError;
  bool _loadingRoute = true;
  bool _busy = false;
  bool _sharing = false;
  bool _foreground = true;
  Timer? _timer;
  late ApiTripMapRepository _repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repo = ref.read(tripMapRepositoryProvider);
    unawaited(_loadRoute());
    if (widget.reservation.status == ReservationStatus.active) {
      unawaited(_refreshLocation());
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!_foreground) return;
      if (_sharing) {
        unawaited(_publish(requestIfDenied: false));
      } else {
        unawaited(_refreshLocation());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _foreground = false;
      _timer?.cancel();
      if (_sharing) {
        setState(() => _sharing = false);
        unawaited(_repo.stopSharing(widget.reservation.id).catchError((Object _) {}));
      }
    } else {
      _foreground = true;
      if (widget.reservation.status == ReservationStatus.active) {
        _startTimer();
        unawaited(_refreshLocation());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_sharing) {
      unawaited(_repo.stopSharing(widget.reservation.id).catchError((Object _) {}));
    }
    super.dispose();
  }

  Future<void> _loadRoute() async {
    try {
      final route = await _repo.getRoute(widget.reservation.id);
      if (mounted) setState(() => _route = route);
    } on AppException catch (error) {
      if (mounted) setState(() => _routeError = error.message);
    } catch (_) {
      if (mounted) setState(() => _routeError = 'La ruta no está disponible.');
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Future<void> _refreshLocation() async {
    if (!mounted || widget.reservation.status != ReservationStatus.active) return;
    try {
      final result = await _repo.getLocation(widget.reservation.id);
      if (mounted) {
        setState(() {
          _location = result;
          _locationError = null;
        });
      }
    } on AppException catch (error) {
      if (mounted) setState(() => _locationError = error.message);
    } catch (_) {
      if (mounted) setState(() => _locationError = 'Ubicación no disponible.');
    }
  }

  Future<void> _publish({bool requestIfDenied = true}) async {
    if (_busy || !mounted || !_foreground) return;
    setState(() => _busy = true);
    try {
      final position = await ForegroundLocation.current(
        requestIfDenied: requestIfDenied,
      );
      if (!mounted || !_foreground) return;
      await _repo.shareLocation(widget.reservation.id, position);
      if (!mounted) return;
      setState(() => _sharing = true);
      await _refreshLocation();
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _sharing = false);
        showCarmanSnack(context, error.message, kind: SnackKind.error);
      }
      // Si falla la autorización o se revoca el permiso, eliminar la última
      // posición del servidor; en cualquier caso caducará a los dos minutos.
      unawaited(_repo.stopSharing(widget.reservation.id).catchError((Object _) {}));
    } catch (_) {
      if (mounted) {
        setState(() => _sharing = false);
        showCarmanSnack(context, 'No se pudo compartir tu ubicación.',
            kind: SnackKind.error);
      }
      unawaited(_repo.stopSharing(widget.reservation.id).catchError((Object _) {}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.stopSharing(widget.reservation.id);
      if (!mounted) return;
      setState(() => _sharing = false);
      await _refreshLocation();
    } on AppException catch (error) {
      if (mounted) showCarmanSnack(context, error.message, kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final pickup = route?.origin ?? widget.reservation.pickupPoint;
    final destination = route?.destination;
    final points = route?.trace ?? const <RoutePosition>[];
    final validPickup = pickup.latitude != 0 && pickup.longitude != 0 &&
        pickup.id != 'pickup' && !pickup.id.endsWith('-pendiente');
    final live = _location?.positions ?? const <SharedLocation>[];

    return CarmanCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ubicación y recorrido', style: AppTheme.titleMd),
          const SizedBox(height: 8),
          Text('Recogida: ${pickup.name} · ${pickup.address}',
              style: AppTheme.bodySm),
          if (destination != null)
            Text('Entrega: ${destination.name} · ${destination.address}',
                style: AppTheme.bodySm),
          const SizedBox(height: 8),
          if (validPickup)
            SizedBox(
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(pickup.latitude, pickup.longitude),
                    initialZoom: 12,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.carman.carman_app',
                    ),
                    if (points.isNotEmpty)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: points
                              .map((point) => LatLng(point.latitude, point.longitude))
                              .toList(),
                          color: AppColors.primary,
                          strokeWidth: 4,
                        ),
                      ]),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(pickup.latitude, pickup.longitude),
                        width: 40, height: 40,
                        child: const Icon(Icons.location_on,
                            color: AppColors.primary, size: 34),
                      ),
                      if (destination != null)
                        Marker(
                          point: LatLng(destination.latitude, destination.longitude),
                          width: 40, height: 40,
                          child: const Icon(Icons.flag,
                              color: AppColors.success, size: 32),
                        ),
                      for (final location in live)
                        Marker(
                          point: LatLng(location.position.latitude,
                              location.position.longitude),
                          width: 40, height: 40,
                          child: Icon(Icons.navigation_rounded,
                              color: location.role == 'Cliente'
                                  ? AppColors.primary : AppColors.success,
                              size: 30),
                        ),
                    ]),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            const Text('No hay coordenadas del punto de recogida.',
                style: AppTheme.bodySm),
          const SizedBox(height: 8),
          if (_loadingRoute)
            const LinearProgressIndicator()
          else if (_routeError != null)
            Text(_routeError!, style: AppTheme.bodySm)
          else if (route?.provider == 'mismo_punto')
            const Text(
              'Recogida y entrega en el mismo punto autorizado.',
              style: AppTheme.bodySm,
            )
          else if (route != null && route.distanceKm >= 0)
            Text(
              'Ruta vial: ${AppFormatters.distance(route.distanceKm)} · '
              '${route.durationMinutes} min aprox. · Mapbox Directions',
              style: AppTheme.bodySm,
            )
          else
            const Text(
              'Ruta vial aún no disponible. No se estima distancia ni se aplica recargo.',
              style: AppTheme.bodySm,
            ),
          Text(
            'Tarifa estimada: ${AppFormatters.money(
              route?.estimatedPrice ?? widget.reservation.pricing.total,
            )} COP. Sin recargo por kilómetros.',
            style: AppTheme.bodySm,
          ),
          if (widget.reservation.status == ReservationStatus.active) ...[
            const Divider(height: 24),
            Text('Ubicación en vivo (solo cliente y conductor adultos)',
                style: AppTheme.labelMd),
            const SizedBox(height: 4),
            Text(
              'Opcional. Solo durante el viaje y con esta pantalla abierta. '
              'La última posición caduca en 2 minutos; no se guarda una trayectoria personal.',
              style: AppTheme.bodySm,
            ),
            if (_location?.available == false)
              const Text('El seguimiento voluntario aún no está habilitado.',
                  style: AppTheme.bodySm),
            if (_locationError != null)
              Text(_locationError!, style: AppTheme.bodySm),
            if (live.isNotEmpty)
              Text('Compartiendo ahora: ${live.map((e) => e.role).join(', ')}',
                  style: AppTheme.bodySm),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy || _location?.available != true ? null : _sharing
                  ? _stop : () => _publish(),
              icon: Icon(_sharing
                  ? Icons.location_disabled_rounded : Icons.my_location_rounded),
              label: Text(_sharing
                  ? 'Detener y borrar mi posición' : 'Compartir mi ubicación'),
            ),
          ],
        ],
      ),
    );
  }
}
