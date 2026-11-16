import '../core/dates.dart';
import 'models/account.dart';
import 'models/money_transaction.dart';

class PeriodSummary {
  const PeriodSummary({
    required this.income,
    required this.expense,
    required this.savingsContribution,
    required this.incomeCount,
    required this.expenseCount,
  });

  final int income;
  final int expense;

  /// Setoran ke tujuan dikurangi penarikan dari tujuan dalam periode ini.
  final int savingsContribution;
  final int incomeCount;
  final int expenseCount;

  int get net => income - expense;

  /// Null jika pemasukan 0, karena rasionya tidak terdefinisi.
  double? get savingsRatioPercent =>
      income > 0 ? savingsContribution * 100 / income : null;

  bool get isEmpty =>
      incomeCount == 0 && expenseCount == 0 && savingsContribution == 0;
}

class PeriodComparison {
  const PeriodComparison(this.current, this.previous);
  final int current;
  final int previous;

  int get delta => current - previous;

  /// Null jika nilai pembanding 0.
  double? get percentChange =>
      previous == 0 ? null : delta * 100 / previous.abs();
}

class MonthlyPoint {
  const MonthlyPoint(this.month, this.summary);
  final MonthRef month;
  final PeriodSummary summary;
}

class CategoryTotal {
  const CategoryTotal(this.categoryId, this.amount);
  final String categoryId;
  final int amount;
}

/// Satu-satunya tempat rumus pemasukan, pengeluaran, arus kas, dan saldo.
abstract final class FinanceCalculator {
  static PeriodSummary summarize(
    Iterable<MoneyTransaction> txs,
    DateRange range,
  ) {
    var income = 0, expense = 0, savings = 0, incomeCount = 0, expenseCount = 0;
    for (final t in txs) {
      if (!range.contains(t.date)) continue;
      switch (t.type) {
        case TransactionType.income:
          income += t.amount;
          incomeCount++;
        case TransactionType.expense:
          expense += t.amount;
          expenseCount++;
        case TransactionType.transfer:
          // Transfer tidak pernah menjadi pemasukan atau pengeluaran.
          savings += t.goalSignedAmount;
      }
    }
    return PeriodSummary(
      income: income,
      expense: expense,
      savingsContribution: savings,
      incomeCount: incomeCount,
      expenseCount: expenseCount,
    );
  }

  /// Saldo awal + pemasukan + transfer masuk - pengeluaran - transfer keluar.
  static Map<String, int> accountBalances(
    Iterable<Account> accounts,
    Iterable<MoneyTransaction> txs,
  ) {
    final balances = {for (final a in accounts) a.id: a.initialBalance};
    for (final t in txs) {
      final touched = {t.accountId, if (t.toAccountId != null) t.toAccountId!};
      for (final id in touched) {
        final current = balances[id];
        if (current != null) balances[id] = current + t.balanceEffectOn(id);
      }
    }
    return balances;
  }

  static int totalBalance(
    Iterable<Account> accounts,
    Iterable<MoneyTransaction> txs,
  ) => accountBalances(accounts, txs).values.fold(0, (sum, v) => sum + v);

  static PeriodComparison compareMonths(
    Iterable<MoneyTransaction> txs,
    MonthRef month,
    int Function(PeriodSummary s) metric,
  ) => PeriodComparison(
    metric(summarize(txs, month.range)),
    metric(summarize(txs, month.previous.range)),
  );

  static List<MonthlyPoint> monthlySeries(
    Iterable<MoneyTransaction> txs,
    MonthRef from,
    MonthRef to,
  ) {
    final points = <MonthlyPoint>[];
    for (var m = from; m.compareTo(to) <= 0; m = m.next) {
      points.add(MonthlyPoint(m, summarize(txs, m.range)));
    }
    return points;
  }

  /// Pengeluaran per kategori, diurutkan dari yang terbesar.
  static List<CategoryTotal> expenseByCategory(
    Iterable<MoneyTransaction> txs,
    DateRange range,
  ) {
    final totals = <String, int>{};
    for (final t in txs) {
      if (t.type != TransactionType.expense || !range.contains(t.date)) {
        continue;
      }
      totals.update(
        t.categoryId!,
        (v) => v + t.amount,
        ifAbsent: () => t.amount,
      );
    }
    return [for (final e in totals.entries) CategoryTotal(e.key, e.value)]
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Transaksi yang membentuk angka sebuah kategori (untuk detail grafik).
  static List<MoneyTransaction> expensesInCategory(
    Iterable<MoneyTransaction> txs,
    String categoryId,
    DateRange range,
  ) => txs
      .where(
        (t) =>
            t.type == TransactionType.expense &&
            t.categoryId == categoryId &&
            range.contains(t.date),
      )
      .toList();
}
