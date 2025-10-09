import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/top_menu.dart';
import '../state/destination_state.dart';
import 'package:mi_app/widgets/route_polyline_layer.dart';

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

  // -------- Botón "Ver ruta actual" en AppBar --------
  void _onShowRoutePressed() {
    final addr = DestinationState.instance.address.value;
    final dest = DestinationState.instance.selected.value;

    if (addr == null || addr.trim().isEmpty || dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay ruta seleccionada hasta el momento'),
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

    // Si por alguna razón no hay contrato, usa confirmación simple
    if (contratoActual == null || contratoActual.trim().isEmpty) {
      final simple = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar'),
          content: const Text('¿Estás seguro que quieres cancelar la ruta?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No, SEGUIR'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sí, limpiar ruta'),
            ),
          ],
        ),
      );
      if (simple == true) _doClearRoute();
      return;
    }

    final controller = TextEditingController();
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
              Text(
                'EL CLIENTE SERÁ NOTIFICADO',
                style: const TextStyle(fontWeight: FontWeight.w700),),
              const SizedBox(height: 10),
              Text(
                'Contrato: $contratoActual',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Escribe el contrato',
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
            FilledButton.tonal(
              onPressed: matches ? () => Navigator.of(ctx).pop(true) : null,
              child: const Text('Sí, limpiar ruta'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No, SEGUIR'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      _doClearRoute();
    }
  }

  void _doClearRoute() {
    DestinationState.instance.set(null); // limpia coords + address + contrato + cliente
    _markers.removeWhere((m) => m.key == const ValueKey('destino'));

    if (mounted) setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ruta cancelada, EL CLIENTE SERÁ NOTIFICADO.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 4000),
      ),
    );
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
        title: const Text('TecniCliente'),
        actions: [
          // 👇 Botón de texto "Ver ruta actual"
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
          FloatingActionButton.extended(
            heroTag: 'me',
            onPressed: _centerOnMyLocation,
            label: const Text('Mi ubicación'),
            icon: const Icon(Icons.my_location),
          ),

          // Solo si hay una ruta seleccionada
          if (DestinationState.instance.selected.value != null) ...[
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'clear',
              onPressed: _onClearRoutePressed,
              label: const Text('Cancelar ruta'),
              icon: const Icon(Icons.clear),
            ),
          ],
        ],
      ),
    );
  }
}
