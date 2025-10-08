import 'package:flutter/material.dart';
import '../services/geo_api.dart';

class ChooseLocationDialog extends StatelessWidget {
  final String query;
  final List<GeoCandidate> results;
  const ChooseLocationDialog({super.key, required this.query, required this.results});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirma dirección'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Resultados para: "$query"'),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = results[i];
                  return ListTile(
                    title: Text(r.label),
                    subtitle: Text('Confianza: ${(r.score * 100).toStringAsFixed(0)}%'),
                    onTap: () => Navigator.of(context).pop<GeoCandidate>(r),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop<GeoCandidate>(null), child: const Text('Cancelar')),
      ],
    );
  }
}
