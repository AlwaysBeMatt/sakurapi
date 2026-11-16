import '../core/dates.dart';
import 'models/budget.dart';
import 'models/money_transaction.dart';

enum BudgetStatus {
  normal('Aman'),
  caution('Perhatian'),
  warning('Hampir habis'),
  exceeded('Terlampaui');

  const BudgetStatus(this.label);
  final String label;
}

class BudgetThresholds {
  const BudgetThresholds({this.caution = 75, this.warning = 90});
  final int caution;
  final int warning;
}

class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.spent,
    required this.status,
  });
  final Budget budget;
  final int spent;
  final BudgetStatus status;

  int get limit => budget.limitAmount;

  /// Bernilai negatif jika anggaran terlampaui.
  int get remaining => limit - spent;
  double get percent => limit <= 0 ? 0 : spent * 100 / limit;
  double get barValue => (percent / 100).clamp(0.0, 1.0);
}

abstract final class BudgetCalculator {
  static BudgetProgress evaluate(
    Budget budget,
    Iterable<MoneyTransaction> txs,
    DateRange range, {
    BudgetThresholds thresholds = const BudgetThresholds(),
  }) {
    var spent = 0;
    for (final t in txs) {
      if (t.type != TransactionType.expense || !range.contains(t.date)) {
        continue;
      }
      if (budget.categoryId == null || t.categoryId == budget.categoryId) {
        spent += t.amount;
      }
    }
    final limit = budget.limitAmount;
    final BudgetStatus status;
    if (spent > limit) {
      status = BudgetStatus.exceeded;
    } else if (spent * 100 >= limit * thresholds.warning) {
      status = BudgetStatus.warning;
    } else if (spent * 100 >= limit * thresholds.caution) {
      status = BudgetStatus.caution;
    } else {
      status = BudgetStatus.normal;
    }
    return BudgetProgress(budget: budget, spent: spent, status: status);
  }
}
