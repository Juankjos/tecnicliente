import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async'; 

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as gc; // 👈 geocoding nativo

import '../widgets/top_menu.dart';
import '../state/destination_state.dart';
import 'package:rutas/widgets/route_polyline_layer.dart';
import '../services/rutas_api.dart';
import '../models/ruta.dart';
// ---- Ajusta tu base según entorno (igual que en rutas_page.dart)
const String _BASE_WEB = "http://localhost/tecnicliente";   // Web
const String _BASE_EMU = "http://10.0.2.2/tecnicliente";    // Android emulator
Uri _apiUri(String pathWithQuery) {
  final base = kIsWeb ? _BASE_WEB : _BASE_EMU;
  return Uri.parse('$base/$pathWithQuery');
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const Color darkGreen = Color(0xFF064E3B);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver  {
  final MapController _mapController = MapController();
  final RutasApi _api = RutasApi(_apiUri);
  StreamSubscription<Position>? _posSub;
  final List<LatLng> _breadcrumb = [];

  bool _mapReady = false;
  LatLng? _pendingDest;

  // Centro por defecto: Tepatitlán
  LatLng _center = const LatLng(20.8169, -102.7635);
  double _zoom = 14;

  // Marcadores (destino y/o mi ubicación)
  final List<Marker> _markers = [];

  // 🔄 Bootstrap/refresh flag
  bool _syncing = false;

  void _startTrackingBreadcrumb() {
    // evita duplicados
    if (_posSub != null) return;

    // Ajusta a tu gusto: intervalos, precisión y distancia mínima
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.best, // o high/medium si quieres ahorrar batería
      distanceFilter: 10,              // en metros: añade punto cuando te mueves >=10m
    );

    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        final p = LatLng(pos.latitude, pos.longitude);

        // 1) agrega punto a la estela
        if (_breadcrumb.isEmpty || _breadcrumb.last != p) {
          _breadcrumb.add(p);
        }

        // 2) actualiza marcador “yo” (para que se mueva)
        _markers.removeWhere((m) => m.key == const ValueKey('me'));
        _markers.add(
          Marker(
            key: const ValueKey('me'),
            point: p,
            width: 28,
            height: 28,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        );

        // 3) opcional: seguir al usuario mientras hay destino
        if (DestinationState.instance.selected.value != null && _mapReady) {
          // _mapController.move(p, _mapController.camera.zoom); // si quieres “seguir” el punto
        }

        if (mounted) setState(() {});
      },
      onError: (_) {
        // Silencioso; podrías mostrar un SnackBar si quieres
      },
    );
  }

  void _stopTrackingBreadcrumb() {
    _posSub?.cancel();
    _posSub = null;
    _breadcrumb.clear();              // limpia estela al terminar la ruta
    _markers.removeWhere((m) => m.key == const ValueKey('me'));
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);               // 👈 registrar
    DestinationState.instance.selected.addListener(_onDestinationChanged);

    _initMyLocation();

    // Bootstrap al abrir: sincroniza contra servidor (y restaura En Camino)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ✅ vuelve a activarlo
    DestinationState.instance.selected.removeListener(_onDestinationChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bootstrapSync();                                     // 👈 re-sincroniza al volver
    }
  }

  //RESYNC DE RUTAS
  Future<void> _onCompleteRoutePressed() async {
    final contratoActual = DestinationState.instance.contract.value;
    final idReporte      = DestinationState.instance.reportId.value;

    if (contratoActual == null || idReporte == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay ruta activa con contrato e ID válidos.')),
        );
      }
      return;
    }

    final controller = TextEditingController();
    bool matches = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('COMPLETAR RUTA'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Estás seguro que quieres completar la ruta?'),
              const SizedBox(height: 10),
              Text('Contrato: $contratoActual', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Escribe el contrato para confirmar',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  setState(() {
                    matches = v.trim() == contratoActual.trim();
                  });
                },
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: matches ? () => Navigator.of(ctx).pop(true) : null,
              child: const Text('Sí, llegué al destino.'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // Loader breve
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _api.cambiarEstatus(
        idReporte: idReporte,
        status: 'Completado',
        fechaFin: DateTime.now(),
      );

      _stopTrackingBreadcrumb(); 
      DestinationState.instance.set(null); // limpia destino
      _markers.removeWhere((m) => m.key == const ValueKey('destino'));

      if (mounted) Navigator.of(context).pop(); // cierra loader
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ruta completada. ¡Buen trabajo!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 3000),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // cierra loader
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo completar la ruta: $e')),
      );
    }
  }

  Future<void> _bootstrapSync() async {
    if (_syncing) return;
    _syncing = true;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final rutas = await _api.fetchPorTecnico(106);
      final enCamino = rutas.where((r) => r.estatus == RutaStatus.enCamino).toList();

      if (enCamino.isNotEmpty) {
        final r = enCamino.first;

        final alreadySame =
            DestinationState.instance.contract.value == r.contrato &&
            DestinationState.instance.selected.value != null;

        if (!alreadySame) {
          await _restoreDestination(r);
          _startTrackingBreadcrumb();
        }

        if (mounted) {
          Navigator.of(context).pop(); // cierra loader
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Actualizado: ruta en curso ${r.direccion}')),
          );
        }
      } else {
        if (mounted) Navigator.of(context).pop(); // cierra loader
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // cierra loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar información: $e')),
        );
      }
    } finally {
      _syncing = false;
    }
  }

  // void _safeCloseDialog() {
  //   if (!mounted) return;
  //   final nav = Navigator.of(context, rootNavigator: true);
  //   if (nav.canPop()) {
  //     nav.pop();
  //   }
  // }

  /// Geocodifica la dirección y publica el destino en DestinationState
  Future<void> _restoreDestination(Ruta r) async {
    final LatLng coords = await _geocodeAddress(r.direccion);

    DestinationState.instance.setWithDetails(
      coords,
      address: r.direccion, // si quieres, aquí puedes poner la "display_name" del geocoder web
      contract: r.contrato,
      client: r.cliente,
      reportId: r.id,       // 👈 MUY IMPORTANTE para completar/cancelar
    );

    if (_mapReady) {
      _mapController.move(coords, 16);
    } else {
      _pendingDest = coords;
    }

    _markers.removeWhere((m) => m.key == const ValueKey('destino'));
    _markers.add(
      Marker(
        key: const ValueKey('destino'),
        point: coords,
        width: 48,
        height: 48,
        child: const Icon(Icons.location_pin, size: 48, color: Colors.red),
      ),
    );

    _startTrackingBreadcrumb();

    if (mounted) setState(() {});
  }

  Future<LatLng> _geocodeAddress(String raw) async {
    if (!kIsWeb) {
      try {
        final list = await gc.locationFromAddress(raw);
        if (list.isNotEmpty) {
          final loc = list.first;
          return LatLng(loc.latitude, loc.longitude);
        }
      } catch (_) {}
      return _center; // fallback
    } else {
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': raw,
          'format': 'jsonv2',
          'limit': '1',
          'addressdetails': '0',
          'accept-language': 'es',
          'countrycodes': 'mx',
        });
        final headers = {'User-Agent': 'TVC-Rutas/1.0 (tvc.s34rch@gmail.com)'};
        final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final arr = (json.decode(res.body) as List?) ?? [];
          if (arr.isNotEmpty) {
            final m = arr.first as Map<String, dynamic>;
            final lat = double.tryParse('${m['lat']}') ?? _center.latitude;
            final lon = double.tryParse('${m['lon']}') ?? _center.longitude;
            return LatLng(lat, lon);
          }
        }
      } catch (_) {}
      return _center; // fallback
    }
  }

  Future<void> _initMyLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      final has = (perm == LocationPermission.always || perm == LocationPermission.whileInUse);

      if (has) {
        final pos = await Geolocator.getCurrentPosition();
        _center = LatLng(pos.latitude, pos.longitude);

        if (_mapReady) {
          _mapController.move(_center, _zoom);
        } else {
          _pendingDest = _center;
        }
        if (mounted) setState(() {});
      }
    } catch (_) {
      // Ignorar
    }
  }

  void _onDestinationChanged() {
    final dest = DestinationState.instance.selected.value;

    if (dest != null) {
        _startTrackingBreadcrumb();
    } else {
      _stopTrackingBreadcrumb();
    }

    // Actualiza markers
    _markers.removeWhere((m) => m.key == const ValueKey('destino'));
    if (dest != null) {
      _markers.add(
        Marker(
          key: const ValueKey('destino'),
          point: dest,
          width: 48,
          height: 48,
          child: const Icon(Icons.location_pin, size: 48, color: Colors.red),
        ),
      );
    }

    // Mover cámara ahora o bufferizar si el mapa no está listo
    if (_mapReady && dest != null) {
      _mapController.move(dest, 16);
    } else {
      _pendingDest = dest;
    }

    if (mounted) setState(() {});
  }

  Future<void> _centerOnMyLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final me = LatLng(pos.latitude, pos.longitude);

      _markers.removeWhere((m) => m.key == const ValueKey('me'));
      _markers.add(
        Marker(
          key: const ValueKey('me'),
          point: me,
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(.9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );

      if (_mapReady) {
        _mapController.move(me, 16);
      } else {
        _pendingDest = me;
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener ubicación actual: $e')),
        );
      }
    }
  }

  // -------- Botón "Ver ruta actual" en AppBar --------
  void _onShowRoutePressed() {
    final addr = DestinationState.instance.address.value;
    final dest = DestinationState.instance.selected.value;

    if (addr == null || addr.trim().isEmpty || dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay ruta seleccionada hasta el momento.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1800),
        ),
      );
      return;
    }

    // Re-centrar en el destino por si el usuario se movió
    if (_mapReady) {
      _mapController.move(dest, 16);
    } else {
      _pendingDest = dest;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dirigiéndose a domicilio\n$addr'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 4000),
      ),
    );
  }

  // -------- Botón "Limpiar ruta" con verificación de contrato --------
  Future<void> _onClearRoutePressed() async {
    final contratoActual = DestinationState.instance.contract.value;

    if (contratoActual == null || contratoActual.trim().isEmpty) {
      final simple = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar'),
          content: const Text('¿Estás seguro que quieres cancelar la ruta?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No, SEGUIR')),
            FilledButton.tonal(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sí, cancelar')),
          ],
        ),
      );
      if (simple == true) _doCancelRoute(); // <-- aquí
      return;
    }

    final contratoCtrl = TextEditingController();
    final motivoCtrl   = TextEditingController();
    bool matches = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('CANCELAR RUTA'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Estás seguro que quieres cancelar la ruta?'),
              const SizedBox(height: 10),
              Text('Contrato: $contratoActual', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: contratoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Escribe el contrato',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => matches = v.trim() == contratoActual.trim()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  hintText: 'Ej. cliente no estaba, equipo fuera',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            FilledButton.tonal(
              onPressed: matches ? () => Navigator.of(ctx).pop(true) : null,
              child: const Text('Sí, cancelar'),
            ),
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No, SEGUIR')),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final motivo = motivoCtrl.text.trim();
      await _doCancelRoute(motivo: motivo.isEmpty ? null : motivo);
    }
  }

  Future<void> _doCancelRoute({String? motivo}) async {
    final idReporte = DestinationState.instance.reportId.value;

    if (idReporte == null) {
      // Si por alguna razón no tenemos id, sólo limpia UI (pero lo ideal es siempre setear reportId)
      DestinationState.instance.set(null);
      _markers.removeWhere((m) => m.key == const ValueKey('destino'));
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta cancelada (sin ID de reporte).')),
      );
      return;
    }

    // Loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 🔥 Persistir en BD: Status=Cancelado + FechaFin=NOW
      await _api.cambiarEstatus(
        idReporte: idReporte,
        status: 'Cancelado',
        fechaFin: DateTime.now(),
        comentario: (motivo != null && motivo.trim().isNotEmpty) ? motivo.trim() : null,
      );

      // Limpia estado local del mapa y destino
      _stopTrackingBreadcrumb();  
      DestinationState.instance.set(null);
      _markers.removeWhere((m) => m.key == const ValueKey('destino'));

      if (mounted) Navigator.of(context).pop(); // cierra loader
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ruta cancelada y registrada.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 3000),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // cierra loader
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar la ruta: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leadingWidth: 78,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
        title: const Text('Rutas'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton(
              onPressed: _onShowRoutePressed,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color.fromARGB(255, 45, 129, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                textStyle: const TextStyle(fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Ver Ruta Actual'),
            ),
          ),
          const TopMenu(),
        ],
      ),
      body: Stack(
        children: [
          // Fondo con degradado
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromARGB(255, 8, 95, 176),
                    Color.fromARGB(255, 8, 95, 176),
                    Color(0xFFF5F8FC),
                    Colors.white,
                  ],
                  stops: [0.0, 0.10, 0.45, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _zoom,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                    onMapReady: () {
                      _mapReady = true;
                      if (_pendingDest != null) {
                        _mapController.move(_pendingDest!, 16);
                        _pendingDest = null;
                      }
                      setState(() {});
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.tuempresa.tecnicliente',
                    ),
                    MarkerLayer(markers: _markers),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors', onTap: () {}),
                      ],
                    ),
                    PolylineLayer(
                      polylines: [
                        if (_breadcrumb.length >= 2)
                          Polyline(points: _breadcrumb, strokeWidth: 4.0),
                      ],
                    ),
                    const RoutePolylineLayer(profile: 'driving'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'me',
            onPressed: _centerOnMyLocation,
            backgroundColor: const Color.fromARGB(255, 136, 196, 255),
            child: const Icon(Icons.my_location),
          ),

          // Solo si hay una ruta seleccionada
          if (DestinationState.instance.selected.value != null) ...[
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'complete',
              onPressed: _onCompleteRoutePressed,
              label: const Text('Completar ruta'),
              icon: const Icon(Icons.flag),
              foregroundColor: Colors.white,
              backgroundColor: const Color.fromARGB(255, 45, 129, 48),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'clear',
              onPressed: _onClearRoutePressed,
              label: const Text('Cancelar ruta'),
              icon: const Icon(Icons.clear),
              foregroundColor: Colors.white,
              backgroundColor: const Color.fromARGB(255, 178, 28, 28),
            ),
          ],
        ],
      ),
    );
  }
}
