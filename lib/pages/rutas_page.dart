// lib/pages/rutas_page.dart
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:latlong2/latlong.dart' show LatLng;
import '../state/destination_state.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RutasPage extends StatefulWidget {
  const RutasPage({super.key});

  @override
  State<RutasPage> createState() => _RutasPageState();
}

class _RutasPageState extends State<RutasPage> {
  final List<Ruta> _todas = <Ruta>[
    Ruta(
      id: 1,
      cliente: 'Juanito Perez Ruvalcaba',
      contrato: '123123-3',
      direccion: 'José Clemente Orozco 267, La Gloria, 47670 Tepatitlán de Morelos, Jal.',
      orden: 'Cambio de módem.',
      estatus: RutaStatus.pendiente,
    ),
    Ruta(
      id: 2,
      cliente: 'Adriana Esmeralda Rodríguez Muñóz',
      contrato: '456789-1',
      direccion: 'C. J. Cruz Ramírez 545-531, San Antonio El Alto, 47640 Tepatitlán de Morelos, Jal.',
      orden: 'Instalación de TV digital.',
      estatus: RutaStatus.enProceso,
    ),
    Ruta(
      id: 3,
      cliente: 'Homero Simpson Springfield',
      contrato: '987654-2',
      direccion: 'C. J. Luis Velazco 159-129, Cerrito de La Cruz, 47610 Tepatitlán de Morelos, Jal.',
      orden: 'Reconexión de servicio.',
      estatus: RutaStatus.completada,
      fechaHoraInicio: DateTime(2025, 9, 18, 15, 10),
      fechaHoraFin: DateTime(2025, 9, 18, 16, 30),
    ),
    Ruta(
      id: 4,
      cliente: 'Cósimo Juárez Travaldaba',
      contrato: '741258-9',
      direccion: 'Quirino Navarro 408-452, Santa Monica, 47634 Tepatitlán de Morelos, Jal.',
      orden: 'Retiro de equipo.',
      estatus: RutaStatus.completada,
      fechaHoraInicio: DateTime(2025, 9, 19, 10, 20),
      fechaHoraFin: DateTime(2025, 9, 19, 11, 15),
    ),
  ];

  final Set<RutaStatus> _filtros = {};
  String _query = '';
  int? _seleccionId;

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

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas'),
        actions: [
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
                      label: 'En proceso',
                      selected: _filtros.contains(RutaStatus.enProceso),
                      color: Colors.blue,
                      onSelected: (v) => setState(() {
                        v ? _filtros.add(RutaStatus.enProceso) : _filtros.remove(RutaStatus.enProceso);
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
              ],
            ),
          ),
          const Divider(height: 0),
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
                          fontWeight: FontWeight.w700, // opcional
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
                    onTap: r.estatus == RutaStatus.completada
                        ? null
                        : () async {
                            final confirmar = await _confirmarSeleccion(context);
                            if (confirmar == true) {
                              setState(() => _seleccionId = r.id);
                              await _geocodificarYEnviar(r); // 👈 NUEVO
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

  Future<void> _geocodificarYEnviar(Ruta r) async {
    if (kIsWeb) {
      // Fallback de demo para web
      final demoTable = <String, LatLng>{
        'José Clemente Orozco 267, La Gloria, 47670 Tepatitlán de Morelos, Jal.': const LatLng(20.8179, -102.7615),
        'C. J. Cruz Ramírez 545-531, San Antonio El Alto, 47640 Tepatitlán de Morelos, Jal.': const LatLng(20.8125, -102.7468),
        'C. J. Luis Velazco 159-129, Cerrito de La Cruz, 47610 Tepatitlán de Morelos, Jal.': const LatLng(20.8098, -102.7442),
        'Quirino Navarro 408-452, Santa Monica, 47634 Tepatitlán de Morelos, Jal.': const LatLng(20.8141, -102.7537),
      };

      final latLng = demoTable[r.direccion] ?? const LatLng(20.8169, -102.7635);

      DestinationState.instance.set(latLng);

      if (!mounted) return;

      // 👇 Muestra el aviso ANTES de navegar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demo web: destino fijado para "${r.cliente}"')),
      );

      // 👇 SOLO un pop para volver a Home
      Navigator.of(context).pop();
      return;
    }

    // Pequeño loader modal sin cambiar tu layout
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final list = await gc.locationFromAddress(r.direccion);
      if (list.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop(); // cierra loader
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo geocodificar la dirección')),
        );
        return;
      }

      final loc = list.first;
      final latLng = LatLng(loc.latitude, loc.longitude);

      // Publicar destino para HomePage (mover cámara y marcador)
      DestinationState.instance.set(latLng);

      Navigator.of(context).pop(); // cierra loader
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ruta ${r.id} seleccionada'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
        ),
      );

      // Opcional: regresar a Home al terminar
      Navigator.of(context).pop();
    } catch (e) {
      Navigator.of(context).pop(); // cierra loader
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

enum RutaStatus { pendiente, enProceso, completada }

extension RutaStatusX on RutaStatus {
  String get label {
    switch (this) {
      case RutaStatus.pendiente:
        return 'Pendiente';
      case RutaStatus.enProceso:
        return 'En proceso';
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
      case RutaStatus.enProceso:
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
