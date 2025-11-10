// lib/widgets/route_polyline_layer.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../state/destination_state.dart';
import '../services/osrm_routing.dart';

class RoutePolylineLayer extends StatefulWidget {
  /// driving | walking | cycling
  final String profile;
  final double strokeWidth;

  const RoutePolylineLayer({
    super.key,
    this.profile = 'driving',
    this.strokeWidth = 4.0,
  });

  @override
  State<RoutePolylineLayer> createState() => _RoutePolylineLayerState();
}

class _RoutePolylineLayerState extends State<RoutePolylineLayer> {
  List<LatLng> _line = const [];
  LatLng? _lastDest;
  StreamSubscription<Position>? _posSub;
  LatLng? _lastOriginUsedForRoute;
  DateTime _lastRerouteAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Ajusta a gusto
  static const double _rerouteMinMoveMeters = 30;     // re-trazar si te moviste ≥ 30 m
  static const double _offRouteThresholdMeters = 25;  // re-trazar si estás ≥ 25 m fuera de la polilínea
  static const Duration _minRerouteInterval = Duration(seconds: 5);
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    DestinationState.instance.selected.addListener(_onDestChange);
    // Si ya hay un destino cuando montamos:
    _maybeFetch();
    _startPositionStream();
  }

  @override
  void dispose() {
    DestinationState.instance.selected.removeListener(_onDestChange);
    _posSub?.cancel();
    super.dispose();
  }

  void _onDestChange() {
    // Evita llamar setState durante build
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFetch());
  }

  Future<void> _startPositionStream() async {
    // Pide permiso una vez; si no hay permiso, no escuchamos el stream
    final hasPerm = await _ensureLocationPermission();
    if (!hasPerm) return;

    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // emite cada ~5 m
      ),
    ).listen(_onPositionUpdate, onError: (e) {
      // opcional: loggear/avisar
    });
  }

  void _onPositionUpdate(Position p) {
    final dest = DestinationState.instance.selected.value;
    if (dest == null) return;

    final now = DateTime.now();
    if (now.difference(_lastRerouteAt) < _minRerouteInterval) return;

    final current = LatLng(p.latitude, p.longitude);

    // Si no hay línea aún, intenta trazar
    if (_line.isEmpty) {
      _buildRouteTo(dest);
      return;
    }

    // 1) ¿Nos salimos de la ruta?
    final offRoute = _distanceToPolylineMeters(current, _line) > _offRouteThresholdMeters;

    // 2) ¿Nos movimos lo suficiente desde el último origen usado?
    final movedEnough = (_lastOriginUsedForRoute == null)
        ? true
        : _haversineMeters(_lastOriginUsedForRoute!, current) > _rerouteMinMoveMeters;

    if (offRoute || movedEnough) {
      _lastRerouteAt = now;
      _buildRouteTo(dest);
    }
  }

  Future<void> _maybeFetch() async {
    final dest = DestinationState.instance.selected.value;
    if (dest == null) {
      if (_line.isNotEmpty) setState(() => _line = const []);
      _lastDest = null;
      return;
    }

    // Si el destino no cambió, no recalcular
    if (_lastDest != null &&
        _lastDest!.latitude == dest.latitude &&
        _lastDest!.longitude == dest.longitude) {
      return;
    }

    _lastDest = dest;
    await _buildRouteTo(dest);
  }

  Future<void> _buildRouteTo(LatLng dest) async {
    if (_loading) return;
    _loading = true;

    try {
      // 1) Asegurar permisos de ubicación
      final hasPerm = await _ensureLocationPermission();
      if (!hasPerm) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado')),
        );
        setState(() => _line = const []);
        return;
      }

      // 2) Obtener ubicación actual
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      final origin = LatLng(pos.latitude, pos.longitude);

      final route = await OsrmRouting.route(
        from: origin,
        to: dest,
        profile: widget.profile,
      );

      if (!mounted) return;

      if (route == null || route.points.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró una ruta óptima')),
        );
        setState(() => _line = const []);
        return;
      }

      setState(() {
        _line = route.points;
        _lastOriginUsedForRoute = origin; // ⟵ guarda el origen usado
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al trazar ruta: $e')),
      );
      setState(() => _line = const []);
    } finally {
      _loading = false;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      return false;
    }
    // En Web, pedir permiso puede requerir HTTPS (excepto localhost)
    if (kIsWeb) {
      // Tip: nada extra, solo advertencia si se necesita
    }
    return true;
    }
  
  // ===== Helpers geométricos (sin dependencias) =====

  // Haversine en metros
  double _haversineMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final h = math.sin(dLat/2)*math.sin(dLat/2) +
        math.cos(lat1)*math.cos(lat2)*math.sin(dLon/2)*math.sin(dLon/2);
    return 2*R*math.asin(math.sqrt(h));
  }

  // Distancia mínima punto–polilínea (m), aproximación equirectangular
  double _distanceToPolylineMeters(LatLng p, List<LatLng> line) {
    if (line.length < 2) return double.infinity;
    double minD = double.infinity;
    for (int i = 0; i < line.length - 1; i++) {
      minD = math.min(minD, _pointToSegmentMeters(p, line[i], line[i+1]));
      if (minD <= _offRouteThresholdMeters) break; // early exit
    }
    return minD;
  }

  double _pointToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    // Proyección equirectangular centrada cerca del segmento
    final lat0 = _deg2rad((a.latitude + b.latitude) / 2.0);
    const R = 6371000.0;

    double x(double lon) => R * _deg2rad(lon) * math.cos(lat0);
    double y(double lat) => R * _deg2rad(lat);

    final ax = x(a.longitude), ay = y(a.latitude);
    final bx = x(b.longitude), by = y(b.latitude);
    final px = x(p.longitude), py = y(p.latitude);

    final vx = bx - ax, vy = by - ay;
    final wx = px - ax, wy = py - ay;

    final c1 = vx*wx + vy*wy;
    final c2 = vx*vx + vy*vy;
    double t = (c2 == 0) ? 0 : (c1 / c2);
    t = t.clamp(0.0, 1.0);
    final projx = ax + t*vx;
    final projy = ay + t*vy;

    final dx = px - projx, dy = py - projy;
    return math.sqrt(dx*dx + dy*dy);
  }

  double _deg2rad(double d) => d * math.pi / 180.0;
  @override
  Widget build(BuildContext context) {
    if (_line.isEmpty) return const SizedBox.shrink();

    return PolylineLayer(
      polylines: [
        Polyline(
          points: _line,
          strokeWidth: widget.strokeWidth,
          color: Colors.blueAccent,
        ),
      ],
    );
  }
}
