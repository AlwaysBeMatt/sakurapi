import 'dart:math';

import '../core/dates.dart';
import 'finance_calculator.dart';
import 'models/money_transaction.dart';
import 'period_report.dart';

/// Perhitungan untuk rentang tanggal bebas di halaman Statistik.
abstract final class RangeReport {
  /// Rentang terpanjang yang diizinkan (sekitar 2 tahun).
  static const maxDays = 731;

  static int dayCount(DateRange r) => daysBetween(r.start, r.end) + 1;

  /// Rentang dengan panjang sama yang berakhir sehari sebelum [range] mulai.
  static DateRange previous(DateRange range) {
    final days = dayCount(range);
    final end = DateTime(
      range.start.year,
      range.start.month,
      range.start.day - 1,
    );
    final start = DateTime(end.year, end.month, end.day - (days - 1));
    return DateRange(start, end);
  }

  /// "5 – 20 Jan 2025", "5 Jan – 20 Mar 2025", atau dengan dua tahun.
  static String label(DateRange r) {
    final s = shortMonthNamesId[r.start.month - 1];
    final e = shortMonthNamesId[r.end.month - 1];
    if (r.start.year != r.end.year) {
      return '${r.start.day} $s ${r.start.year} – ${r.end.day} $e ${r.end.year}';
    }
    if (r.start.month != r.end.month) {
      return '${r.start.day} $s – ${r.end.day} $e ${r.end.year}';
    }
    return '${r.start.day} – ${r.end.day} $e ${r.end.year}';
  }

  /// Rata-rata pengeluaran per hari, hanya dari hari yang sudah berjalan.
  /// Null jika rentang belum dimulai.
  static int? averageDaily(int expense, DateRange range, DateTime today) {
    final t = dateOnly(today);
    if (t.isBefore(range.start)) {
      return null;
    }
    final last = t.isAfter(range.end) ? range.end : t;
    return expense ~/ (daysBetween(range.start, last) + 1);
  }

  /// Kolom grafik: harian (sampai 14 hari), mingguan (sampai 93 hari),
  /// selebihnya bulanan.
  static List<PeriodBucket> buckets(
    Iterable<MoneyTransaction> txs,
    DateRange range,
  ) {
    final days = dayCount(range);
    final spans = <(String, DateRange)>[];

    if (days <= 14) {
      for (var i = 0; i < days; i++) {
        final d = DateTime(
          range.start.year,
          range.start.month,
          range.start.day + i,
        );
        spans.add(('${d.day}', DateRange(d, d)));
      }
    } else if (days <= 93) {
      for (var offset = 0; offset < days; offset += 7) {
        final s = DateTime(
          range.start.year,
          range.start.month,
          range.start.day + offset,
        );
        var e = DateTime(s.year, s.month, s.day + 6);
        if (e.isAfter(range.end)) {
          e = range.end;
        }
        spans.add(('${s.day} ${shortMonthNamesId[s.month - 1]}', DateRange(s, e)));
      }
    } else {
      final crossesYears = range.start.year != range.end.year;
      var m = MonthRef.of(range.start);
      final last = MonthRef.of(range.end);
      while (m.compareTo(last) <= 0) {
        final full = m.range;
        final s = full.start.isBefore(range.start) ? range.start : full.start;
        final e = full.end.isAfter(range.end) ? range.end : full.end;
        final name = shortMonthNamesId[m.month - 1];
        final label = crossesYears
            ? '$name ${(m.year % 100).toString().padLeft(2, '0')}'
            : name;
        spans.add((label, DateRange(s, e)));
        m = m.next;
      }
    }

    final result = <PeriodBucket>[];
    for (final (label, span) in spans) {
      final summary = FinanceCalculator.summarize(txs, span);
      result.add(
        PeriodBucket(
          label: label,
          range: span,
          income: summary.income,
          expense: summary.expense,
        ),
      );
    }
    return result;
  }

  /// Hari terbanyak dalam satu kolom (dipakai untuk pengujian).
  static int widestBucket(List<PeriodBucket> buckets) =>
      buckets.fold(0, (m, b) => max(m, dayCount(b.range)));
}