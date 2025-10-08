import 'package:flutter/material.dart';

class FiltroChipX extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final ValueChanged<bool> onSelected;

  const FiltroChipX({
    super.key,
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
