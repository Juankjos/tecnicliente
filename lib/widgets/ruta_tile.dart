import 'package:flutter/material.dart';
import '../models/ruta.dart';
import 'chip_estatus.dart';
import 'info_line.dart';
import 'pill_badge.dart';

class RutaTile extends StatelessWidget {
  final Ruta r;
  final bool isSelected;
  final bool enabled;
  final VoidCallback? onTap;

  const RutaTile({
    super.key,
    required this.r,
    required this.isSelected,
    required this.enabled,
    this.onTap,
  });

  static String _formatFechaHora(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {

    Color bg;
      if (r.estatus == RutaStatus.completada) {
        bg = Colors.green.shade100;
      } else if (r.estatus == RutaStatus.cancelado) {
        bg = Colors.red.shade100;
      } else if (r.estatus == RutaStatus.enCamino) {
        bg = Colors.blue.shade50;
      } else {
        bg = Colors.white;
      }
      final bool showPills =
        (r.estatus == RutaStatus.completada || r.estatus == RutaStatus.cancelado);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: bg,                          // 👈 usa el color elegido
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          width: isSelected ? 2.2 : 1,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade300,
        ),
      ),
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(r.cliente, style: const TextStyle(fontWeight: FontWeight.w600))),
            ChipEstatus(estatus: r.estatus),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6, right: 4, bottom: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InfoLine(label: 'Número de contrato', value: r.contrato),
            InfoLine(label: 'Dirección', value: r.direccion),
            InfoLine(label: 'Orden', value: r.orden),
            if (showPills && r.fechaHoraInicio != null)
                PillBadge(
                  label: 'Inicio',
                  value: _formatFechaHora(r.fechaHoraInicio!),
                  bg: const Color.fromARGB(255, 143, 230, 149),
                  fg: const Color.fromARGB(255, 12, 114, 24),
                ),
              if (showPills && r.fechaHoraFin != null)
                PillBadge(
                  label: 'Terminación',
                  value: _formatFechaHora(r.fechaHoraFin!),
                  bg: Colors.red.shade50,
                  fg: Colors.red,
                ),
            ],
          ),
        ),
        trailing: enabled
            ? (isSelected ? const Icon(Icons.check_circle, size: 28) : const Icon(Icons.chevron_right))
            : const Icon(Icons.lock_outline),
        isThreeLine: true,
        enabled: enabled,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
