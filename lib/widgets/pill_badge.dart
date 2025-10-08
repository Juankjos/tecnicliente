import 'package:flutter/material.dart';

class PillBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  final Color fg;

  const PillBadge({
    super.key,
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text('$label: $value', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
