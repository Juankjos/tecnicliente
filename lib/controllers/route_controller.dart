// lib/controllers/route_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../state/destination_state.dart';
import '../services/location_tracker.dart';
import '../services/rutas_api.dart';
import '../services/geocoder.dart';
import '../services/geocoder_native.dart';
import '../services/geocoder_web.dart';
import '../services/session.dart';                 // 👈 Session.instance...
import '../models/ruta.dart' show Ruta, RutaStatus; // 👈 tu modelo y enum

class RouteController extends ChangeNotifier {
  final MapController map;
  final RutasApi api;
  final LocationTracker tracker;
  final Geocoder geocoder;
  final LatLng defaultCenter;

  RouteController({
    required this.map,
    required this.api,
    LocationTracker? tracker,
    Geocoder? geocoder,
    this.defaultCenter = const LatLng(20.8169, -102.7635),
  })  : tracker = tracker ?? LocationTracker(),
        geocoder = geocoder ?? (kIsWeb ? WebGeocoder() : NativeGeocoder()) {
    _destListener = () => _onDestinationChanged(DestinationState.instance.selected.value);
    DestinationState.instance.selected.addListener(_destListener);
  }

  // ---- Estado expuesto a UI
  final breadcrumb = <LatLng>[];
  final markers = <Marker>[];
  bool mapReady = false;
  LatLng center = const LatLng(20.8169, -102.7635);
  double zoom = 14;
  bool _syncing = false;
  LatLng? _bufferMove;

  late final VoidCallback _destListener;
  StreamSubscription<LatLng>? _locSub;

  // ---------- Lifecycle ----------
  Future<void> init() async {
    final me = await tracker.current();
    if (me != null) center = me;
    notifyListeners();
    await bootstrapSync();
  }

  void disposeAll() {
    DestinationState.instance.selected.removeListener(_destListener);
    _locSub?.cancel();
    tracker.dispose();
  }

  // ---------- Eventos de mapa ----------
  void onMapReady() {
    mapReady = true;
    if (_bufferMove != null) {
      map.move(_bufferMove!, 16);
      _bufferMove = null;
    }
    notifyListeners();
  }

  // ---------- Destino ----------
  Future<void> restoreDestinationFromRuta(Ruta r) async {
    final coords = await geocoder.geocode(r.direccion, fallback: defaultCenter);
    DestinationState.instance.setWithDetails(
      coords, address: r.direccion, contract: r.contrato, client: r.cliente, reportId: r.id,
    );
  }

  void _onDestinationChanged(LatLng? dest) {
    // marcador destino
    markers.removeWhere((m) => m.key == const ValueKey('destino'));
    if (dest != null) {
      markers.add(Marker(
        key: const ValueKey('destino'),
        point: dest,
        width: 48, height: 48,
        child: const Icon(Icons.location_pin, size: 48, color: Colors.red),
      ));
      _startTracking(); // start si hay destino
      _moveCamera(dest, 16);
    } else {
      _stopTracking();
      // limpia destino
      markers.removeWhere((m) => m.key == const ValueKey('destino'));
    }
    notifyListeners();
  }

  // ---------- Tracking ----------
  Future<void> _startTracking() async {
    if (_locSub != null) return;
    await tracker.start(distanceFilter: 10);
    _locSub = tracker.stream.listen((p) {
      // breadcrumb
      if (breadcrumb.isEmpty || breadcrumb.last != p) breadcrumb.add(p);

      // marcador "yo"
      markers.removeWhere((m) => m.key == const ValueKey('me'));
      markers.add(Marker(
        key: const ValueKey('me'),
        point: p,
        width: 28, height: 28,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ));
      notifyListeners();
    });
  }

  Future<void> _stopTracking() async {
    await _locSub?.cancel();
    _locSub = null;
    await tracker.stop();
    breadcrumb.clear();
    markers.removeWhere((m) => m.key == const ValueKey('me'));
    notifyListeners();
  }

  Future<void> centerOnMe() async {
    final me = await tracker.current();
    if (me == null) return;
    markers.removeWhere((m) => m.key == const ValueKey('me'));
    markers.add(Marker(
      key: const ValueKey('me'), point: me, width: 28, height: 28,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: Colors.blue.withOpacity(.9),
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    ));
    _moveCamera(me, 16);
    notifyListeners();
  }

  void _moveCamera(LatLng p, double z) {
    if (mapReady) {
      map.move(p, z);
    } else {
      _bufferMove = p;
    }
  }

  void focusOnCurrentDestination() {
    final dest = DestinationState.instance.selected.value;
    if (dest != null) {
      _moveCamera(dest, 16);
    }
  }

  // ---------- Sync / acciones de ruta ----------
  Future<void> bootstrapSync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final rutas = await api.fetchPorTecnico(Session.instance.idTec.value!);
      final enCurso = rutas.where((r) => r.estatus == RutaStatus.enCamino).toList();
      if (enCurso.isNotEmpty) {
        final r = enCurso.first;
        final same = DestinationState.instance.contract.value == r.contrato &&
                    DestinationState.instance.selected.value != null;
        if (!same) {
          await restoreDestinationFromRuta(r);
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> completarRuta() async {
    final id = DestinationState.instance.reportId.value;
    if (id == null) throw Exception('No hay id de reporte');
    await api.cambiarEstatus(idReporte: id, status: 'Completado', fechaFin: DateTime.now());
    await _stopTracking();
    DestinationState.instance.set(null);
  }

  Future<void> cancelarRuta({String? motivo}) async {
    final id = DestinationState.instance.reportId.value;
    if (id == null) {
      DestinationState.instance.set(null);
      markers.removeWhere((m)=>m.key==const ValueKey('destino'));
      notifyListeners();
      return;
    }
    await api.cambiarEstatus(
      idReporte: id, status: 'Cancelado', fechaFin: DateTime.now(),
      comentario: (motivo!=null && motivo.trim().isNotEmpty) ? motivo.trim() : null,
    );
    await _stopTracking();
    DestinationState.instance.set(null);
  }
}

// Pequeño tipo helper para no acoplar al modelo real
// abstract class RutaLike {
//   String get direccion;
//   String get contrato;
//   String get cliente;
//   int get id;
// }
typedef RutaLike = Ruta;