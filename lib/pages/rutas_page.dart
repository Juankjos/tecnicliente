import 'dart:convert';
import 'package:http/http.dart' as http;

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

/// ✅ Mover ESTA clase al tope (fuera del State)
class _GeoCand {
  final String label;
  final double lat;
  final double lon;
  final double score; // 0..1
  const _GeoCand(this.label, this.lat, this.lon, this.score);
}

class RutasPage extends StatefulWidget {
  const RutasPage({super.key});

  @override
  State<RutasPage> createState() => _RutasPageState();
}

// PÁGINA PARA SELECCIONAR RUTAS
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

  Future<void> _persistirEnCamino(Ruta r) async {
    // Solo aplica si estaba "Pendiente"
    if (r.estatus != RutaStatus.pendiente) return;

    // 1) Cambio visual inmediato
    _aplicarEnCaminoUI(r);

    try {
      // 2) POST real al backend
      await _api.cambiarEstatus(
        idReporte: r.id,            // Asegúrate: Ruta.id == IDReporte
        status: 'En camino',
        fechaInicio: DateTime.now(),
      );

      // 3) (opcional) leer del server para asegurar consistencia:
      // await _cargarRutas();

    } catch (e) {
      // Revertir visual si falla el backend
      setState(() {
        final i = _todas.indexWhere((x) => x.id == r.id);
        if (i != -1) {
          final x = _todas[i];
          _todas = List<Ruta>.from(_todas)
            ..[i] = Ruta(
              id: x.id,
              cliente: x.cliente,
              contrato: x.contrato,
              direccion: x.direccion,
              orden: x.orden,
              estatus: RutaStatus.pendiente,
              fechaHoraInicio: x.fechaHoraInicio,
              fechaHoraFin: x.fechaHoraFin,
            );
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo marcar En camino: $e')),
      );
    }
  }

  void _aplicarEnCaminoUI(Ruta r) {
    final now = DateTime.now();
    setState(() {
      final i = _todas.indexWhere((x) => x.id == r.id);
      if (i == -1) return;

      final x = _todas[i];
      _todas = List<Ruta>.from(_todas)
        ..[i] = Ruta(
          id: x.id,
          cliente: x.cliente,
          contrato: x.contrato,
          direccion: x.direccion,
          orden: x.orden,
          estatus: RutaStatus.enCamino,
          fechaHoraInicio: x.fechaHoraInicio ?? now,
          fechaHoraFin: x.fechaHoraFin,
        );
    });
  }

  // FETCH de rutas (por técnico o contrato)
  Future<void> _cargarRutas() async {
    setState(() => _cargando = true);
    try {
      var rutas = await _api.fetchPorTecnico(106);  // <-- var (no final)

      // Si hay una ruta activa en memoria, refleja 'En Camino' visualmente
      final activeContract = DestinationState.instance.contract.value;
      if (activeContract != null) {
        rutas = rutas.map((x) {
          if (x.contrato == activeContract && x.estatus == RutaStatus.pendiente) {
            return Ruta(
              id: x.id,
              cliente: x.cliente,
              contrato: x.contrato,
              direccion: x.direccion,
              orden: x.orden,
              estatus: RutaStatus.enCamino,
              fechaHoraInicio: x.fechaHoraInicio ?? DateTime.now(),
              fechaHoraFin: x.fechaHoraFin,
            );
          }
          return x;
        }).toList();
      }

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


  // FILTRO DE RUTAS
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

    // PÁGINA DE RUTAS
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
                      final confirmar = await _confirmarSeleccion(context, r);
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

  Future<bool?> _confirmarSeleccion(BuildContext context, Ruta r) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Deseas seleccionar esta ruta?'),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87),
                children: [
                  const TextSpan(text: 'Contrato: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: r.contrato),
                ],
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87),
                children: [
                  const TextSpan(text: 'Dirección: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: r.direccion),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Seleccionar'),
          ),
        ],
      ),
    );
  }

  // --------------------- Geocodificación GRATIS ---------------------
  // En Web: Nominatim (OSM) + Photon (sin cuenta). En móviles: plugin geocoding.
  Future<void> _geocodificarYEnviar(Ruta r) async {
    // Sesgo de cercanía: centro de Tepatitlán (mejora relevancia)
    const proximity = (20.8169, -102.7635);

    // Loader
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (kIsWeb) {
        // --- Web: OSM (Nominatim + Photon) ---
        final results = await _geocodeOSM(r.direccion, proximity: proximity);

        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        if (results.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró la dirección. Intenta ajustar la búsqueda.')),
          );
          return;
        }

        // Si hay un match fuerte o único, úsalo; si no, deja elegir
        _GeoCand? chosen;
        if (results.first.score >= 0.9 || results.length == 1) {
          chosen = results.first;
        } else {
          chosen = await showDialog<_GeoCand>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Confirma dirección'),
              content: SizedBox(
                width: 420,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) => ListTile(
                    title: Text(results[i].label),
                    subtitle: Text('Confianza aprox: ${(results[i].score * 100).toStringAsFixed(0)}%'),
                    onTap: () => Navigator.of(ctx).pop(results[i]),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              ],
            ),
          );
          if (chosen == null) return;
        }

        final latLng = LatLng(chosen.lat, chosen.lon);
        DestinationState.instance.setWithDetails(
          latLng,
          address: chosen.label,
          contract: r.contrato,
          client: r.cliente,
        );

        await _persistirEnCamino(r);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Destino fijado: ${chosen.label}')),
        );
        Navigator.of(context).pop(); // volver al mapa/home
      } else {
        // --- Android/iOS: plugin nativo geocoding (sin keys) ---
        final list = await gc.locationFromAddress(r.direccion);
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        if (list.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo geocodificar la dirección')),
          );
          return;
        }
        final loc = list.first;
        final latLng = LatLng(loc.latitude, loc.longitude);
        DestinationState.instance.setWithDetails(
          latLng,
          address: r.direccion,
          contract: r.contrato,
          client: r.cliente,
        );

        await _persistirEnCamino(r);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ruta seleccionada')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al geolocalizar: $e')),
      );
    }
  }

  // ---------- Helpers OSM (Nominatim + Photon) ----------
  Future<List<_GeoCand>> _geocodeOSM(String raw, { (double lat, double lon)? proximity }) async {
    // Normaliza un poco (quita “Colonia/Ciudad”, espacios extra)
    String q = raw
        .replaceAll(RegExp(r'\bColonia\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bCiudad\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Variantes con ciudades comunes de tu zona
    final variants = <String>{
      q,
      '$q Tepatitlán de Morelos, Jalisco, México',
      '$q San José de Gracia, Jalisco, México',
    }.toList();

    for (final v in variants) {
      final n = await _osmNominatim(v, proximity: proximity);
      if (n.isNotEmpty) return n;
    }
    for (final v in variants) {
      final p = await _osmPhoton(v, proximity: proximity);
      if (p.isNotEmpty) return p;
    }
    return const <_GeoCand>[];
  }

  Future<List<_GeoCand>> _osmNominatim(
    String query, {
    int limit = 5,
    String language = 'es',
    String country = 'mx',
    (double lat, double lon)? proximity,
  }) async {
    final qp = <String, String>{
      'q': query,
      'format': 'jsonv2',
      'limit': '$limit',
      'addressdetails': '0',
      'accept-language': language,
      'countrycodes': country,
      if (proximity != null)
        'viewbox':
            '${proximity.$2 - 0.6},${proximity.$1 + 0.6},${proximity.$2 + 0.6},${proximity.$1 - 0.6}', // lonLatBox
    };
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', qp);
    // Nominatim exige un User-Agent identificable
    final headers = {'User-Agent': 'TVC-Rutas/1.0 (tvc.s34rch@gmail.com)'};

    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Nominatim ${res.statusCode}: ${res.body}');
    }
    final list = (json.decode(res.body) as List).cast<Map<String, dynamic>>();
    return list.map((m) {
      final lat = double.tryParse('${m['lat']}') ?? 0.0;
      final lon = double.tryParse('${m['lon']}') ?? 0.0;
      final imp = (m['importance'] is num) ? (m['importance'] as num).toDouble() : 0.0;
      return _GeoCand('${m['display_name']}', lat, lon, imp.clamp(0.0, 1.0));
    }).toList();
  }

  Future<List<_GeoCand>> _osmPhoton(
    String query, {
    int limit = 5,
    String language = 'es',
    (double lat, double lon)? proximity,
  }) async {
    final qp = <String, String>{
      'q': query,
      'lang': language,
      'limit': '$limit',
      if (proximity != null) 'lat': '${proximity.$1}',
      if (proximity != null) 'lon': '${proximity.$2}',
    };
    final uri = Uri.https('photon.komoot.io', '/api/', qp);
    final headers = {'User-Agent': 'TVC-Rutas/1.0 (tvc.s34rch@gmail.com)'};

    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Photon ${res.statusCode}: ${res.body}');
    }
    final body = (json.decode(res.body) as Map<String, dynamic>);
    final feats = (body['features'] as List?) ?? const [];
    return feats.map<_GeoCand>((f) {
      final props = (f as Map)['properties'] as Map;
      final geom = f['geometry'] as Map;
      final coords = (geom['coordinates'] as List).cast<num>();
      final label = (props['name'] ?? props['label'] ?? '').toString();
      return _GeoCand(label, coords[1].toDouble(), coords[0].toDouble(), 0.8);
    }).toList();
  }
}
