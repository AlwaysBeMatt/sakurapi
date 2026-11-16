import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/period_report.dart';
import '../theme/tokens.dart';

const double _axisWidth = 44;

/// 600000 -> "600rb", 1200000 -> "1,2jt", 2500000000 -> "2,5M".
String compactRupiah(int v) {
  String fmt(double x, String unit) {
    final whole = x == x.roundToDouble();
    final s = x.toStringAsFixed(whole || x >= 10 ? 0 : 1).replaceAll('.', ',');
    return '$s$unit';
  }

  if (v >= 1000000000) {
    return fmt(v / 1000000000, 'M');
  }
  if (v >= 1000000) {
    return fmt(v / 1000000, 'jt');
  }
  if (v >= 1000) {
    return fmt(v / 1000, 'rb');
  }
  return '$v';
}

/// Batas atas sumbu: bilangan "bulat" terdekat yang >= [peak].
/// 590000 -> 600000, 1300000 -> 1500000.
int niceCeiling(int peak) {
  if (peak <= 0) {
    return 1;
  }
  var mag = 1;
  while (mag * 10 <= peak) {
    mag *= 10;
  }
  for (final t in const [10, 12, 15, 20, 25, 30, 40, 50, 60, 80, 100]) {
    final candidate = (t * mag + 9) ~/ 10;
    if (candidate >= peak) {
      return candidate;
    }
  }
  return mag * 10;
}

/// Grafik batang berpasangan: kiri pemasukan, kanan pengeluaran.
/// Tekan lama sebuah kolom untuk melihat nominalnya.
class IncomeExpenseChart extends StatelessWidget {
  const IncomeExpenseChart({
    super.key,
    required this.buckets,
    this.height = 180,
  });

  final List<PeriodBucket> buckets;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final peak = buckets.fold<int>(0, (m, b) => max(m, b.peak));

    if (buckets.isEmpty || peak == 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Tidak ada pemasukan atau pengeluaran pada periode ini.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
        ),
      );
    }

    final top = niceCeiling(peak);
    double fraction(int v) => v <= 0 ? 0 : max(v / top, 0.02);

    final axisStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10,
      color: secondary,
    );
    final ticks = [(top, 0.0), (top ~/ 2, height / 2), (0, height)];

    return Semantics(
      label: 'Grafik batang pemasukan dan pengeluaran',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotWidth = constraints.maxWidth - _axisWidth;
          final slot = plotWidth / buckets.length;
          final barWidth = ((slot - 6) / 2).clamp(3.0, 20.0);

          return Column(
            children: [
              // Padding atas dan bawah memberi ruang untuk label sumbu
              // yang sejajar dengan garis di tepi grafik.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: SizedBox(
                  height: height,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: _axisWidth,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final (value, y) in ticks)
                              Positioned(
                                left: 0,
                                right: 6,
                                top: y - 7,
                                child: Text(
                                  compactRupiah(value),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  style: axisStyle,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _GridPainter(
                                  gridColor: theme.dividerColor,
                                  baseColor: secondary,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final b in buckets)
                                    Expanded(
                                      child: Tooltip(
                                        message:
                                            '${b.label}: pemasukan ${Money.format(b.income)}, '
                                            'pengeluaran ${Money.format(b.expense)}',
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _Bar(
                                              width: barWidth,
                                              fraction: fraction(b.income),
                                              color: colors.income,
                                            ),
                                            const SizedBox(width: 2),
                                            _Bar(
                                              width: barWidth,
                                              fraction: fraction(b.expense),
                                              color: colors.expense,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: _axisWidth),
                  for (final b in buckets)
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          b.label,
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: secondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.gridColor, required this.baseColor});

  final Color gridColor;
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final base = Paint()
      ..color = baseColor
      ..strokeWidth = 1;

    canvas.drawLine(Offset.zero, Offset(size.width, 0), grid);
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      grid,
    );
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      base,
    );
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.gridColor != gridColor || old.baseColor != baseColor;
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.width,
    required this.fraction,
    required this.color,
  });

  final double width;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: fraction,
          widthFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.75), color],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
