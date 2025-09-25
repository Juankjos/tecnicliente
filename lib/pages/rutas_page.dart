import 'package:flutter/material.dart';

class RutasPage extends StatefulWidget {
  const RutasPage({super.key});

  @override
  State<RutasPage> createState() => _RutasPageState();
}

class _RutasPageState extends State<RutasPage> {
  // ---- Datos de ejemplo (4 direcciones) ----
  final List<Ruta> _todas = List.generate(
    4,
    (i) => Ruta(
      id: i + 1,
      cliente: 'Juanito Perez',
      contrato: '123123-3',
      direccion: 'Calle: Juan Bernardino #435 Col. El comal En. Tepatitlán, Jalisco.',
      orden: 'Cambio de Modem.',
      estatus: i == 0
          ? RutaStatus.pendiente
          : i == 1
              ? RutaStatus.enProceso
              : RutaStatus.completada,
    ),
  );

  // ---- Estado de UI ----
  final Set<RutaStatus> _filtros = {}; // vacío = mostrar todos
  String _query = '';
  int? _seleccionId; // id seleccionado para resaltar

  // ---- Helpers de filtro/búsqueda ----
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
    // (Opcional) Ordena mostrando primero pendientes, luego en proceso, luego completadas
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
          // ---- Barra de filtros + búsqueda ----
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
          // ---- Lista ----
          Expanded(
            child: ListView.builder(
              itemCount: filtradas.length,
              itemBuilder: (context, index) {
                final r = filtradas[index];
                final isSelected = _seleccionId == r.id;

                return Container(
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      width: isSelected ? 2.2 : 1,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${r.id}'),
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
                        ],
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, size: 28)
                        : const Icon(Icons.chevron_right),
                    isThreeLine: true,
                    onTap: () async {
                      final confirmar = await _confirmarSeleccion(context);
                      if (confirmar == true) {
                        setState(() => _seleccionId = r.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ruta ${r.id} seleccionada'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(milliseconds: 1200),
                          ),
                        );
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

  Ruta({
    required this.id,
    required this.cliente,
    required this.contrato,
    required this.direccion,
    required this.orden,
    required this.estatus,
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
