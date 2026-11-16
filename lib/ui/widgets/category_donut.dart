import 'dart:math';

import 'package:flutter/material.dart';

class DonutSlice {
  const DonutSlice(this.value, this.color);
  final int value;
  final Color color;
}

class CategoryDonut extends StatelessWidget {
  const CategoryDonut({super.key, required this.slices, this.size = 140});

  final List<DonutSlice> slices;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Diagram donat pengeluaran per kategori',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(slices, Theme.of(context).dividerColor),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.trackColor);

  final List<DonutSlice> slices;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.18;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final total = slices.fold<int>(0, (s, e) => s + e.value);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    if (total <= 0) {
      canvas.drawArc(arcRect, 0, 2 * pi, false, paint..color = trackColor);
      return;
    }

    var start = -pi / 2;
    for (final s in slices) {
      final sweep = 2 * pi * s.value / total;
      canvas.drawArc(arcRect, start, sweep, false, paint..color = s.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices != slices || old.trackColor != trackColor;
}
