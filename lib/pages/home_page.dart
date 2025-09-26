// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/top_menu.dart';
import '../state/destination_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const Color darkGreen = Color(0xFF064E3B);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();

  // Estado del mapa
  bool _mapReady = false;
  LatLng? _pendingDest;

  // Centro por defecto: Tepatitlán
  LatLng _center = const LatLng(20.8169, -102.7635);
  double _zoom = 14;

  // Marcadores (destino y/o mi ubicación)
  final List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();

    // Escuchar el destino publicado desde RutasPage
    DestinationState.instance.selected.addListener(_onDestinationChanged);

    // (Opcional) Intentar centrar en mi ubicación al iniciar
    _initMyLocation();
  }

  @override
  void dispose() {
    DestinationState.instance.selected.removeListener(_onDestinationChanged);
    super.dispose();
  }

  Future<void> _initMyLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      final has = (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse);

      if (has) {
        final pos = await Geolocator.getCurrentPosition();
        _center = LatLng(pos.latitude, pos.longitude);

        if (_mapReady) {
          _mapController.move(_center, _zoom);
        } else {
          _pendingDest = _center; // si aún no está listo, lo aplicamos al ready
        }
        if (mounted) setState(() {});
      }
    } catch (_) {
      // Ignorar
    }
  }

  void _onDestinationChanged() {
    final dest = DestinationState.instance.selected.value;

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
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        title: const Text('TecniCliente'),
        actions: const [TopMenu()],
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
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
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
          FloatingActionButton.extended(
            heroTag: 'me',
            onPressed: _centerOnMyLocation,
            label: const Text('Mi ubicación'),
            icon: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'clear',
            onPressed: () {
              DestinationState.instance.set(null);
              _markers.removeWhere((m) => m.key == const ValueKey('destino'));
              if (mounted) setState(() {});
            },
            label: const Text('Limpiar destino'),
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }
}
