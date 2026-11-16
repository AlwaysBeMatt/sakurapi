import 'dart:math';

import '../core/dates.dart';
import 'finance_calculator.dart';
import 'models/money_transaction.dart';

class PeriodBucket {
  const PeriodBucket({
    required this.label,
    required this.range,
    required this.income,
    required this.expense,
  });

  final String label;
  final DateRange range;
  final int income;
  final int expense;

  int get peak => max(income, expense);
}

/// Memecah sebuah periode menjadi bagian-bagian untuk grafik batang.
/// Minggu: 7 hari. Bulan: kelompok 7 hari. Tahun: 12 bulan.
abstract final class PeriodReport {
  static const _dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  static List<PeriodBucket> buckets(
    Iterable<MoneyTransaction> txs,
    Period period,
  ) {
    final spans = <(String, DateRange)>[];
    switch (period.kind) {
      case PeriodKind.week:
        for (var i = 0; i < 7; i++) {
          final d = DateTime(
            period.start.year,
            period.start.month,
            period.start.day + i,
          );
          spans.add((_dayLabels[i], DateRange(d, d)));
        }
      case PeriodKind.month:
        final year = period.start.year;
        final monthNo = period.start.month;
        final lastDay = period.end.day;
        for (var from = 1; from <= lastDay; from += 7) {
          final to = min(from + 6, lastDay);
          spans.add((
            '$from–$to',
            DateRange(
              DateTime(year, monthNo, from),
              DateTime(year, monthNo, to),
            ),
          ));
        }
      case PeriodKind.year:
        for (var i = 1; i <= 12; i++) {
          spans.add((
            shortMonthNamesId[i - 1],
            MonthRef(period.start.year, i).range,
          ));
        }
    }

    final result = <PeriodBucket>[];
    for (final (label, range) in spans) {
      final s = FinanceCalculator.summarize(txs, range);
      result.add(
        PeriodBucket(
          label: label,
          range: range,
          income: s.income,
          expense: s.expense,
        ),
      );
    }
    return result;
  }
}
