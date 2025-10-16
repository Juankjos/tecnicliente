  // lib/pages/home_page.dart
  import 'package:flutter/material.dart';
  import 'package:flutter/foundation.dart' show kIsWeb;
  import 'package:flutter_map/flutter_map.dart';
  import '../controllers/route_controller.dart';
  import '../services/rutas_api.dart';
  import '../widgets/map_view.dart';
  import '../widgets/top_menu.dart';
  import '../widgets/dialogs.dart';
  import '../state/destination_state.dart';

  const String _BASE_WEB = "http://localhost/tecnicliente";
  const String _BASE_EMU = "http://10.0.2.2/tecnicliente";
  Uri _apiUri(String pathWithQuery) {
    final base = kIsWeb ? _BASE_WEB : _BASE_EMU;
    return Uri.parse('$base/$pathWithQuery');
  }

  class HomePage extends StatefulWidget {
    const HomePage({super.key});
    @override
    State<HomePage> createState() => _HomePageState();
  }

  class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
    final mapCtrl = MapController();
    late final RutasApi api;
    late final RouteController ctrl;

    @override
    void initState() {
      super.initState();
      WidgetsBinding.instance.addObserver(this);
      api = RutasApi(_apiUri);
      ctrl = RouteController(map: mapCtrl, api: api);
      ctrl.init(); // obtiene ubicación inicial + bootstrapSync
    }

    @override
    void dispose() {
      WidgetsBinding.instance.removeObserver(this);
      ctrl.disposeAll();
      super.dispose();
    }

    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
      if (state == AppLifecycleState.resumed) {
        ctrl.bootstrapSync();
      }
    }

    Future<void> _onCompleteRoutePressed() async {
      final contrato = DestinationState.instance.contract.value;
      final idReporte = DestinationState.instance.reportId.value;
      if (contrato == null || idReporte == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay ruta activa.')));
        return;
      }
      final ok = await confirmarContrato(context, contrato, titulo: 'COMPLETAR RUTA');
      if (ok == null) return;

      // loader
      showDialog(context: context, barrierDismissible: false, builder: (_)=>const Center(child:CircularProgressIndicator()));
      try {
        await ctrl.completarRuta();
        if (mounted) Navigator.of(context).pop();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruta completada ¡Buen trabajo!')));
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

  Future<void> _onClearRoutePressed() async {
    final contrato = DestinationState.instance.contract.value;

    // Si no tenemos contrato, mantenemos el fallback: cancelar sin confirmación de contrato,
    // pero puedes cambiar esto si quieres obligar siempre a la confirmación.
    if (contrato == null || contrato.trim().isEmpty) {
      final motivoFallback = await pedirMotivo(context); // opcional
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await ctrl.cancelarRuta(motivo: motivoFallback);
        if (mounted) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RUTA CANCELADA.')),
        );
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar la ruta: $e')),
        );
      }
      return;
    }

    // ✅ Diálogo combinado: escribe contrato para habilitar "Sí, cancelar" + motivo opcional
    final result = await confirmarCancelacion(context, contrato, titulo: 'CANCELAR RUTA');
    if (result == null) return; // pulsó "No, seguir" o cerró

    final (_, motivo) = result; // motivo puede ser null o string

    // Loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ctrl.cancelarRuta(motivo: motivo);
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
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cancelar la ruta: $e')),
      );
    }
  }


    @override
    Widget build(BuildContext context) {
      // Usa AnimatedBuilder sobre el ChangeNotifier para re-render minimal
      return AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          final hasDest = DestinationState.instance.selected.value != null;
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.white,
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
                    onPressed: () {
                      final addr = DestinationState.instance.address.value;
                      final dest = DestinationState.instance.selected.value;
                      if (addr==null || addr.isEmpty || dest==null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay ruta seleccionada.')));
                        return;
                      }
                      ctrl.focusOnCurrentDestination(); // 👈 mueve la cámara al destino
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dirigiéndose a:\n$addr')));
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: const Color.fromARGB(255, 45, 129, 48),
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
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [ Color.fromARGB(255, 8,95,176), Color.fromARGB(255, 8,95,176), Color(0xFFF5F8FC), Colors.white ],
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
                      child: MapView(
                        controller: mapCtrl,
                        initialCenter: ctrl.center,
                        initialZoom: ctrl.zoom,
                        markers: ctrl.markers,
                        breadcrumb: ctrl.breadcrumb,
                        onMapReady: ctrl.onMapReady,
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
                  onPressed: ctrl.centerOnMe,
                  backgroundColor: const Color.fromARGB(255, 136, 196, 255),
                  child: const Icon(Icons.my_location),
                ),
                if (hasDest) ...[
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
        },
      );
    }
  }
