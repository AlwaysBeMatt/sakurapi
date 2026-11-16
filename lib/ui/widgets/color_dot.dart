import 'package:flutter/material.dart';

/// Lingkaran warna yang bisa dipilih. Pilihan ditandai centang, bukan hanya warna.
class ColorDot extends StatelessWidget {
  const ColorDot({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
    this.label = 'Warna',
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
