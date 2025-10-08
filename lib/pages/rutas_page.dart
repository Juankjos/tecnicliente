import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as gc;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../state/destination_state.dart';

/// Ajusta estas constantes a tu entorno.
/// - Si ejecutas `flutter run -d chrome` (dev server), usa localhost con CORS habilitado en PHP.
/// - Si sirves la app desde Apache (build/web), podrías usar Uri.base.resolve(...) en su lugar.
const String BASE_URL_WEB   = "http://localhost/tecnicliente"; // Chrome (dev)
const String BASE_URL_EMU   = "http://10.0.2.2/tecnicliente";  // Android emulator
const String BASE_URL_LAN   = "http://192.168.1.xxx/tecnicliente"; // Dispositivo físico (cambia la IP)

Uri _apiUri(String pathWithQuery) {
  // Para este ejemplo usamos Web vs Emulador; ajusta según tu caso.
  if (kIsWeb) return Uri.parse("$BASE_URL_WEB/$pathWithQuery");
  return Uri.parse("$BASE_URL_EMU/$pathWithQuery");
}

class RutasPage extends StatefulWidget {
  const RutasPage({super.key});

  @override
  State<RutasPage> createState() => _RutasPageState();
}

class _RutasPageState extends State<RutasPage> {
  List<Ruta> _todas = <Ruta>[];
  bool _cargando = true;

  final Set<RutaStatus> _filtros = {};
  String _query = '';
  int? _seleccionId;

  @override
  void initState() {
    super.initState();
    _cargarRutas(); // carga inicial
  }

  // -------------------------- Carga desde PHP --------------------------
  Future<void> _cargarRutas() async {
    setState(() => _cargando = true);
    try {
      // Para tu caso puntual (IDContrato 81580):
      // final uri = _apiUri("get_rutas.php?idContrato=81580");
      // Si quieres traer por técnico (106), usa:
      final uri = _apiUri("get_rutas.php?idTec=106");

      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final data = json.decode(res.body) as List<dynamic>;
      RutaStatus mapStatus(String s) {
        final t = s.toLowerCase();
        if (t.startsWith('complet')) return RutaStatus.completada;
        if (t.startsWith('en camino')) return RutaStatus.enCamino;
        return RutaStatus.pendiente;
      }

      DateTime? parseDt(dynamic v) {
        if (v == null || (v is String && v.isEmpty)) return null;
        return DateTime.parse(v as String);
      }

      final rutas = data.map((e) {
        return Ruta(
          id: e['id'] as int,
          cliente: (e['cliente'] ?? '').toString(),
          contrato: (e['contrato'] ?? '').toString(),
          direccion: (e['direccion'] ?? '').toString(),
          orden: (e['orden'] ?? '').toString(),
          estatus: mapStatus((e['estatus'] ?? '').toString()),
          fechaHoraInicio: parseDt(e['inicio']),
          fechaHoraFin: parseDt(e['fin']),
        );
      }).toList();

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

  // -------------------------- Filtros / búsqueda --------------------------
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

  // -------- Saber si hay una ruta activa (publicada en Home) --------
  bool get _hasRutaActiva => DestinationState.instance.selected.value != null;

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _cargarRutas,
            icon: const Icon(Icons.refresh),
          ),
          if (_filtros.isNotEmpty || _query.isNotEmpty)
            IconButton(
              tooltip: 'Limpiar filtros',
              onPressed: () => setState(() {
                _filtros.clear();
                _query = '';
              }),
              icon: const Icon(Icons.filter_alt_off),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _FiltroChip(
                      label: 'Pendiente',
                      selected: _filtros.contains(RutaStatus.pendiente),
                      color: Colors.orange,
                      onSelected: (v) => setState(() {
                        v ? _filtros.add(RutaStatus.pendiente) : _filtros.remove(RutaStatus.pendiente);
                      }),
                    ),
                    _FiltroChip(
                      label: 'En Camino',
                      selected: _filtros.contains(RutaStatus.enCamino),
                      color: Colors.blue,
                      onSelected: (v) => setState(() {
                        v ? _filtros.add(RutaStatus.enCamino) : _filtros.remove(RutaStatus.enCamino);
                      }),
                    ),
                    _FiltroChip(
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
              ],
            ),
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

                  return Container(
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    decoration: BoxDecoration(
                      color: r.estatus == RutaStatus.completada
                          ? Colors.green.shade100
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        width: isSelected ? 2.2 : 1,
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color.fromARGB(255, 246, 246, 246),
                        child: Text(
                          '${r.id}',
                          style: const TextStyle(
                            color: Color.fromARGB(255, 8, 95, 176),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.cliente,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          _ChipEstatus(estatus: r.estatus),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6, right: 4, bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _line('Número de contrato', r.contrato),
                            _line('Dirección', r.direccion),
                            _line('Orden', r.orden),
                            if (r.estatus == RutaStatus.completada && r.fechaHoraInicio != null)
                              _pill(
                                label: 'Inicio',
                                value: _formatFechaHora(r.fechaHoraInicio!),
                                bg: const Color.fromARGB(255, 143, 230, 149),
                                fg: const Color.fromARGB(255, 18, 143, 32),
                              ),
                            if (r.estatus == RutaStatus.completada && r.fechaHoraFin != null)
                              _pill(
                                label: 'Terminación',
                                value: _formatFechaHora(r.fechaHoraFin!),
                                bg: Colors.red.shade100,
                                fg: Colors.red,
                              ),
                          ],
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, size: 28)
                          : const Icon(Icons.chevron_right),
                      isThreeLine: true,
                      enabled: !_hasRutaActiva && r.estatus != RutaStatus.completada,
                      onTap: r.estatus == RutaStatus.completada
                          ? null
                          : () async {
                              if (_hasRutaActiva) {
                                await _mostrarAvisoRutaActiva();
                                return;
                              }

                              final confirmar = await _confirmarSeleccion(context);
                              if (confirmar == true) {
                                setState(() => _seleccionId = r.id);
                                await _geocodificarYEnviar(r);
                              }
                            },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------- Diálogos / helpers -------------------------
  Future<void> _mostrarAvisoRutaActiva() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ruta en curso'),
        content: const Text(
          'Ya tienes una ruta activa. Cancélala en el mapa con “Limpiar ruta” antes de seleccionar otra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(ctx).pop();     // cierra el diálogo
              Navigator.of(context).pop();  // regresa a Home (mapa)
            },
            child: const Text('Ir al mapa'),
          ),
        ],
      ),
    );
  }

  Future<void> _geocodificarYEnviar(Ruta r) async {
    if (kIsWeb) {
      // Fallback simple para Web (sin geocoding nativo):
      // Si quieres, agrega más "matches" aquí:
      const fallback = LatLng(20.8169, -102.7635); // Centro Tepatitlán aprox.
      final latLng = fallback;

      DestinationState.instance.setWithDetails(
        latLng,
        address: r.direccion,
        contract: r.contrato,
        client: r.cliente,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Destino fijado para "${r.direccion}" ¡BUEN VIAJE!')),
      );

      Navigator.of(context).pop();
      return;
    }

    // En móviles/escritorio puedes usar geocoding real:
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

      Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ruta ${r.id} seleccionada'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de geocodificación: $e')),
      );
    }
  }

  static Widget _pill({
    required String label,
    required String value,
    required Color bg,
    required Color fg,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$label: $value',
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static String _formatFechaHora(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  static Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmarSeleccion(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('¿Deseas seleccionar esta ruta?'),
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
}

// -------------------- Modelos y widgets auxiliares --------------------

enum RutaStatus { pendiente, enCamino, completada }

extension RutaStatusX on RutaStatus {
  String get label {
    switch (this) {
      case RutaStatus.pendiente:
        return 'Pendiente';
      case RutaStatus.enCamino:
        return 'En Camino';
      case RutaStatus.completada:
        return 'Completada';
    }
  }
}

class Ruta {
  final int id;
  final String cliente;
  final String contrato;
  final String direccion;
  final String orden;
  final RutaStatus estatus;
  final DateTime? fechaHoraInicio;
  final DateTime? fechaHoraFin;

  Ruta({
    required this.id,
    required this.cliente,
    required this.contrato,
    required this.direccion,
    required this.orden,
    required this.estatus,
    this.fechaHoraInicio,
    this.fechaHoraFin,
  });
}

class _ChipEstatus extends StatelessWidget {
  final RutaStatus estatus;
  const _ChipEstatus({required this.estatus});

  @override
  Widget build(BuildContext context) {
    Color bg;
    IconData icon;
    switch (estatus) {
      case RutaStatus.pendiente:
        bg = Colors.orange.shade100;
        icon = Icons.schedule;
        break;
      case RutaStatus.enCamino:
        bg = Colors.blue.shade100;
        icon = Icons.run_circle_outlined;
        break;
      case RutaStatus.completada:
        bg = Colors.green.shade100;
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(estatus.label),
        ],
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final ValueChanged<bool> onSelected;

  const _FiltroChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: color.withOpacity(.25),
      checkmarkColor: Colors.black87,
      side: BorderSide(color: selected ? color : Colors.grey.shade400),
    );
  }
}
