import '../core/dates.dart';
import 'finance_calculator.dart';
import 'models/money_transaction.dart';
import 'period_report.dart';

class CategoryAmount {
  const CategoryAmount(this.categoryId, this.amount);

  /// Kosong jika transaksi tidak punya kategori.
  final String categoryId;
  final int amount;
}

/// Perhitungan tambahan untuk halaman Statistik. Semua fungsinya murni.
abstract final class StatsReport {
  /// Total per kategori untuk jenis [type] (pemasukan atau pengeluaran),
  /// diurutkan dari yang terbesar. Transfer tidak dihitung.
  static List<CategoryAmount> byCategory(
    Iterable<MoneyTransaction> txs,
    DateRange range,
    TransactionType type,
  ) {
    final totals = <String, int>{};
    for (final t in txs) {
      if (t.type != type || !range.contains(t.date)) {
        continue;
      }
      final id = t.categoryId ?? '';
      totals[id] = (totals[id] ?? 0) + t.amount;
    }
    final result = [
      for (final e in totals.entries) CategoryAmount(e.key, e.value),
    ];
    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  /// [count] periode berurutan yang berakhir di [period], paling lama dulu.
  static List<PeriodBucket> trend(
    Iterable<MoneyTransaction> txs,
    Period period, {
    int count = 6,
  }) {
    final periods = <Period>[period];
    while (periods.length < count) {
      periods.insert(0, periods.first.previous);
    }
    return [for (final p in periods) _bucket(txs, p)];
  }

  static PeriodBucket _bucket(Iterable<MoneyTransaction> txs, Period p) {
    final s = FinanceCalculator.summarize(txs, p.range);
    return PeriodBucket(
      label: _label(p),
      range: p.range,
      income: s.income,
      expense: s.expense,
    );
  }

  static String _label(Period p) => switch (p.kind) {
    PeriodKind.week => '${p.start.day} ${shortMonthNamesId[p.start.month - 1]}',
    PeriodKind.month => shortMonthNamesId[p.start.month - 1],
    PeriodKind.year => '${p.start.year}',
  };

  /// Rata-rata pengeluaran per hari. Hanya hari yang sudah berjalan yang
  /// dihitung. Null jika periode belum dimulai.
  static int? averageDailyExpense(int expense, Period period, DateTime today) {
    final t = dateOnly(today);
    if (t.isBefore(period.start)) {
      return null;
    }
    final last = t.isAfter(period.end) ? period.end : t;
    final days = daysBetween(period.start, last) + 1;
    return expense ~/ days;
  }

  /// Pengeluaran terbesar di [range], dari yang terbesar.
  static List<MoneyTransaction> topExpenses(
    Iterable<MoneyTransaction> txs,
    DateRange range, {
    int take = 5,
  }) {
    final list = txs
        .where(
          (t) => t.type == TransactionType.expense && range.contains(t.date),
        )
        .toList();
    list.sort((a, b) {
      final c = b.amount.compareTo(a.amount);
      return c != 0 ? c : b.date.compareTo(a.date);
    });
    return list.take(take).toList();
  }
}
