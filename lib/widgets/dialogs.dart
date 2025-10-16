// lib/widgets/dialogs.dart
import 'package:flutter/material.dart';

Future<String?> confirmarContrato(BuildContext ctx, String contratoActual, {String titulo='CONFIRMAR'}) async {
  final ctrl = TextEditingController();
  bool matches = false;
  return showDialog<String>(
    context: ctx, barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('COMPLETAR RUTA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Escribe el contrato para completar la ruta.'),
            const SizedBox(height: 10),
            Text('Contrato: $contratoActual',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Escribe el contrato',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) =>
                  setState(() => matches = v.trim() == contratoActual.trim()),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: matches
                ? () => Navigator.pop(ctx, ctrl.text.trim())
                : null,
            child: const Text('Sí, completar ruta'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    ),
  );
}

Future<String?> pedirMotivo(BuildContext ctx) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: ctx,
    builder: (ctx)=>AlertDialog(
      title: const Text('Motivo (opcional)'),
      content: TextField(controller: ctrl, maxLines: 2, decoration: const InputDecoration(isDense:true, border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx, null), child: const Text('Omitir')),
        FilledButton.tonal(onPressed: ()=>Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
      ],
    ),
  );
}

/// Confirma el contrato y permite escribir el motivo (opcional)
Future<(String contrato, String? motivo)?> confirmarCancelacion(
  BuildContext ctx,
  String contratoActual, {
  String titulo = 'CANCELAR RUTA',
}) async {
  final contratoCtrl = TextEditingController();
  final motivoCtrl = TextEditingController();
  bool matches = false;

  return showDialog<(String, String?)>(
    context: ctx,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('CANCELAR RUTA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Seguro que deseas cancelar la ruta? El cliente será notificado.'),
            const SizedBox(height: 10),
            const Text('Escribe el contrato para cancelar la ruta.'),
            const SizedBox(height: 10),
            Text('Contrato: $contratoActual',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: contratoCtrl,
              decoration: const InputDecoration(
                labelText: 'Escribe el contrato',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) =>
                  setState(() => matches = v.trim() == contratoActual.trim()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton.tonal(
            onPressed: matches
                ? () => Navigator.pop(
                      ctx,
                      (contratoCtrl.text.trim(),
                          motivoCtrl.text.trim().isEmpty
                              ? null
                              : motivoCtrl.text.trim()),
                    )
                : null,
            child: const Text('Sí, cancelar ruta'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('No, SEGUIR'),
          ),
        ],
      ),
    ),
  );
}
