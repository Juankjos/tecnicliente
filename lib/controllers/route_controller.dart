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
import '../services/live_socket.dart';

class RouteController extends ChangeNotifier {
  final MapController map;
  final RutasApi api;
  final LocationTracker tracker;
  final Geocoder geocoder;
  final LatLng defaultCenter;
  LiveSocket? _live;

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
      _ensureLiveSocketConnected();
      _startTracking(); // start si hay destino
      _moveCamera(dest, 16);
    } else {
      _stopTracking();
      // limpia destino
      markers.removeWhere((m) => m.key == const ValueKey('destino'));
    }
    notifyListeners();
  }

  void _ensureLiveSocketConnected() {
    if (_live != null) return; // ya conectados o en proceso
    final tecId = Session.instance.idTec.value;
    final reportId = DestinationState.instance.reportId.value;

    if (reportId != null) {
      debugPrint('[live] connecting… reportId=$reportId tecId=$tecId');
      _live = LiveSocket()
        ..connect(
          serverUrl: kIsWeb ? 'http://localhost:3001' : 'http://10.0.2.2:3001',
          reportId: reportId,
          tecId: tecId,
        );
    } else {
      // Aún no hay reportId: escucha UNA vez y conecta cuando llegue
      debugPrint('[live] reportId null; waiting for it…');
      void once() {
        final rep = DestinationState.instance.reportId.value;
        if (rep != null) {
          DestinationState.instance.reportId.removeListener(once);
          _ensureLiveSocketConnected();
        }
      }
      DestinationState.instance.reportId.addListener(once);
    }
  }

  // ---------- Tracking ----------
  Future<void> _startTracking() async {
    if (_locSub != null) return;

    debugPrint('[route] _startTracking called; reportId=${DestinationState.instance.reportId.value}');
    _ensureLiveSocketConnected();
    // 🔌 conectar LiveSocket si no está
    final reportId = DestinationState.instance.reportId.value;
    final tecId = Session.instance.idTec.value;
    if (reportId != null && _live == null) {
      _live = LiveSocket()
        ..connect(
          serverUrl: kIsWeb ? 'http://localhost:3001' : 'http://10.0.2.2:3001',
          reportId: reportId,
          tecId: tecId,
        );
    }

    // ⬇️ filtro bajo para pruebas
    await tracker.start(distanceFilter: 1);

    // ✅ enviar posición inicial (se encola si aún no hay conexión)
    final me = await tracker.current();
    if (me != null) {
      debugPrint('[live] initial -> ${me.latitude}, ${me.longitude}');
      _live?.sendLocation(lat: me.latitude, lng: me.longitude);
    }

    // ♻️ Re-emite la última posición cada 3s en pruebas (para autoenfoque web)
    Timer.periodic(const Duration(seconds: 3), (t) async {
      if (_locSub == null) { t.cancel(); return; } // detén cuando pares el tracking
      final cur = await tracker.current();
      if (cur != null) {
        _live?.sendLocation(lat: cur.latitude, lng: cur.longitude);
      }
    });

    _locSub = tracker.stream.listen((p) {
      if (breadcrumb.isEmpty || breadcrumb.last != p) breadcrumb.add(p);

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

      debugPrint('[live] send -> ${p.latitude}, ${p.longitude}');
      _live?.sendLocation(lat: p.latitude, lng: p.longitude);
      notifyListeners();
    });
  }

  Future<void> _stopTracking() async {
    await _locSub?.cancel();
    _locSub = null;
    await tracker.stop();
    breadcrumb.clear();
    markers.removeWhere((m) => m.key == const ValueKey('me'));
    _live?.dispose();    // 🔌 cerrar ws
    _live = null;
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