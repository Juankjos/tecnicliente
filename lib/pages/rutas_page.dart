import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:geocoding/geocoding.dart' as gc;

import '../models/ruta.dart';
import '../services/rutas_api.dart';
import '../widgets/filtro_chip.dart';
import '../widgets/ruta_tile.dart';
import '../state/destination_state.dart';

// ---- Ajusta tu base según entorno ----
const String _BASE_WEB = "http://localhost/tecnicliente";   // Chrome (dev) con CORS en PHP
const String _BASE_EMU = "http://10.0.2.2/tecnicliente";    // Android emulator
// const String _BASE_LAN = "http://192.168.1.xxx/tecnicliente"; // Dispositivo físico (si lo usas)

Uri _apiUri(String pathWithQuery) {
  final base = kIsWeb ? _BASE_WEB : _BASE_EMU;
  return Uri.parse('$base/$pathWithQuery');
}

class RutasPage extends StatefulWidget {
  const RutasPage({super.key});

  @override
  State<RutasPage> createState() => _RutasPageState();
}

class _RutasPageState extends State<RutasPage> {
  final RutasApi _api = RutasApi(_apiUri);

  List<Ruta> _todas = const <Ruta>[];
  bool _cargando = true;

  final Set<RutaStatus> _filtros = {};
  String _query = '';
  int? _seleccionId;

  @override
  void initState() {
    super.initState();
    _cargarRutas();
  }

  Future<void> _cargarRutas() async {
    setState(() => _cargando = true);
    try {
      // Para tu caso puntual, por contrato 81580:
      final rutas = await _api.fetchPorContrato('81580');
      // O por técnico 106:
      // final rutas = await _api.fetchPorTecnico(106);

      setState(() {
        _todas = rutas;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar las rutas: $e')),
      );
    }
  }

  List<Ruta> get _filtradas {
    Iterable<Ruta> base = _todas;
    if (_filtros.isNotEmpty) {
      base = base.where((r) => _filtros.contains(r.estatus));
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      base = base.where((r) =>
          r.cliente.toLowerCase().contains(q) ||
          r.contrato.toLowerCase().contains(q) ||
          r.direccion.toLowerCase().contains(q) ||
          r.orden.toLowerCase().contains(q));
    }
    final list = base.toList();
    list.sort((a, b) => a.estatus.index.compareTo(b.estatus.index));
    return list;
  }

  bool get _hasRutaActiva => DestinationState.instance.selected.value != null;

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas'),
        actions: [
          IconButton(tooltip: 'Recargar', onPressed: _cargarRutas, icon: const Icon(Icons.refresh)),
          if (_filtros.isNotEmpty || _query.isNotEmpty)
            IconButton(
              tooltip: 'Limpiar filtros',
              onPressed: () => setState(() { _filtros.clear(); _query = ''; }),
              icon: const Icon(Icons.filter_alt_off),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: 8, runSpacing: 4, children: [
                  FiltroChipX(
                    label: 'Pendiente',
                    selected: _filtros.contains(RutaStatus.pendiente),
                    color: Colors.orange,
                    onSelected: (v) => setState(() {
                      v ? _filtros.add(RutaStatus.pendiente) : _filtros.remove(RutaStatus.pendiente);
                    }),
                  ),
                  FiltroChipX(
                    label: 'En Camino',
                    selected: _filtros.contains(RutaStatus.enCamino),
                    color: Colors.blue,
                    onSelected: (v) => setState(() {
                      v ? _filtros.add(RutaStatus.enCamino) : _filtros.remove(RutaStatus.enCamino);
                    }),
                  ),
                  FiltroChipX(
                    label: 'Completada',
                    selected: _filtros.contains(RutaStatus.completada),
                    color: Colors.green,
                    onSelected: (v) => setState(() {
                      v ? _filtros.add(RutaStatus.completada) : _filtros.remove(RutaStatus.completada);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por cliente, contrato, dirección u orden…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (text) => setState(() => _query = text),
              ),
              if (_hasRutaActiva) ...[
                const SizedBox(height: 8),
                const Text(
                  'RUTA EN CURSO: Cancela o Completa tu ruta para seleccionar otra.',
                  style: TextStyle(backgroundColor: Colors.redAccent, color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ]),
          ),
          const Divider(height: 0),

          if (_cargando)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                itemCount: filtradas.length,
                itemBuilder: (context, index) {
                  final r = filtradas[index];
                  final isSelected = _seleccionId == r.id;
                  final enabled = !_hasRutaActiva && r.estatus != RutaStatus.completada;

                  return RutaTile(
                    r: r,
                    isSelected: isSelected,
                    enabled: enabled,
                    onTap: enabled ? () async {
                      if (_hasRutaActiva) {
                        await _mostrarAvisoRutaActiva();
                        return;
                      }
                      final confirmar = await _confirmarSeleccion(context);
                      if (confirmar == true) {
                        setState(() => _seleccionId = r.id);
                        await _geocodificarYEnviar(r);
                      }
                    } : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // --------------------- Diálogos / helpers específicos ---------------------
  Future<void> _mostrarAvisoRutaActiva() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ruta en curso'),
        content: const Text('Ya tienes una ruta activa. Cancélala en el mapa con “Limpiar ruta” antes de seleccionar otra.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
          FilledButton.tonal(
            onPressed: () { Navigator.of(ctx).pop(); Navigator.of(context).pop(); },
            child: const Text('Ir al mapa'),
          ),
        ],
      ),
    );
  }

  Future<void> _geocodificarYEnviar(Ruta r) async {
    if (kIsWeb) {
      // Fallback simple (centro de Tepatitlán aprox.)
      const latLng = LatLng(20.8169, -102.7635);
      DestinationState.instance.setWithDetails(latLng, address: r.direccion, contract: r.contrato, client: r.cliente);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Destino fijado para "${r.direccion}" ¡BUEN VIAJE!')));
      Navigator.of(context).pop();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final list = await gc.locationFromAddress(r.direccion);
      if (list.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo geocodificar la dirección')));
        return;
      }

      final loc = list.first;
      final latLng = LatLng(loc.latitude, loc.longitude);

      DestinationState.instance.setWithDetails(latLng, address: r.direccion, contract: r.contrato, client: r.cliente);

      Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta seleccionada'), behavior: SnackBarBehavior.floating, duration: Duration(milliseconds: 1200)),
      );

      Navigator.of(context).pop();
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de geocodificación: $e')));
    }
  }

  Future<bool?> _confirmarSeleccion(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('¿Deseas seleccionar esta ruta?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Seleccionar')),
        ],
      ),
    );
  }
}
