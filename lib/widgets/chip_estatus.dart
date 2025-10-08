import 'package:flutter/material.dart';
import '../models/ruta.dart';

class ChipEstatus extends StatelessWidget {
  final RutaStatus estatus;
  const ChipEstatus({super.key, required this.estatus});

  @override
  Widget build(BuildContext context) {
    Color bg; IconData icon;
    switch (estatus) {
      case RutaStatus.pendiente:  bg = Colors.orange.shade100; icon = Icons.schedule; break;
      case RutaStatus.enCamino:   bg = Colors.blue.shade100;   icon = Icons.run_circle_outlined; break;
      case RutaStatus.completada: bg = Colors.green.shade100;  icon = Icons.check_circle_outline; break;
    }
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(estatus.label),
      ]),
    );
  }
}
