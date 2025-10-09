// lib/widgets/route_polyline_layer.dart
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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    DestinationState.instance.selected.addListener(_onDestChange);
    // Si ya hay un destino cuando montamos:
    _maybeFetch();
  }

  @override
  void dispose() {
    DestinationState.instance.selected.removeListener(_onDestChange);
    super.dispose();
  }

  void _onDestChange() {
    // Evita llamar setState durante build
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFetch());
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

      // 3) Pedir ruta a OSRM
      final route = await OsrmRouting.route(from: origin, to: dest, profile: widget.profile);

      if (!mounted) return;

      if (route == null || route.points.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró una ruta óptima')),
        );
        setState(() => _line = const []);
        return;
      }

      setState(() => _line = route.points);
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
