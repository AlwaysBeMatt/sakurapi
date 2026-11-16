import 'package:flutter_test/flutter_test.dart';
import 'package:sakurapi/core/dates.dart';
import 'package:sakurapi/core/money.dart';
import 'package:sakurapi/domain/budget_calculator.dart';
import 'package:sakurapi/domain/finance_calculator.dart';
import 'package:sakurapi/domain/goal_calculator.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/budget.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/savings_goal.dart';

final _t0 = DateTime(2025, 1, 1);

MoneyTransaction _tx(
  String id,
  TransactionType type,
  int amount,
  DateTime date, {
  String accountId = 'wallet',
  String? categoryId,
  String? toAccountId,
  String? goalId,
  GoalFlow? goalFlow,
}) => MoneyTransaction(
  id: id,
  type: type,
  amount: amount,
  accountId: accountId,
  categoryId: categoryId,
  toAccountId: toAccountId,
  goalId: goalId,
  goalFlow: goalFlow,
  date: date,
  createdAt: _t0,
  updatedAt: _t0,
);

SavingsGoal _goal({
  int target = 6000000,
  int initial = 0,
  DateTime? deadline,
}) => SavingsGoal(
  id: 'g1',
  name: 'Laptop',
  targetAmount: target,
  initialAmount: initial,
  targetDate: deadline,
  accountId: 'sav',
  createdAt: _t0,
);

void main() {
  final wallet = Account(
    id: 'wallet',
    name: 'Dompet',
    type: AccountType.cash,
    createdAt: _t0,
  );
  final sav = Account(
    id: 'sav',
    name: 'Tabungan',
    type: AccountType.savings,
    createdAt: _t0,
  );
  const jan = MonthRef(2025, 1);

  final scenario = [
    _tx(
      't1',
      TransactionType.income,
      3000000,
      DateTime(2025, 1, 1),
      categoryId: 'inc_salary',
    ),
    _tx(
      't2',
      TransactionType.expense,
      250000,
      DateTime(2025, 1, 5),
      categoryId: 'exp_food',
    ),
    _tx(
      't3',
      TransactionType.transfer,
      500000,
      DateTime(2025, 1, 10),
      toAccountId: 'sav',
      goalId: 'g1',
      goalFlow: GoalFlow.deposit,
    ),
  ];

  group('Skenario acuan', () {
    final s = FinanceCalculator.summarize(scenario, jan.range);
    final balances = FinanceCalculator.accountBalances([wallet, sav], scenario);

    test('pemasukan, pengeluaran, arus kas', () {
      expect(s.income, 3000000);
      expect(s.expense, 250000); // bukan 750.000
      expect(s.net, 2750000);
    });
    test('saldo akun', () {
      expect(balances['wallet'], 2250000);
      expect(balances['sav'], 500000);
      expect(FinanceCalculator.totalBalance([wallet, sav], scenario), 2750000);
    });
    test('kontribusi dan rasio tabungan', () {
      expect(s.savingsContribution, 500000);
      expect(s.savingsRatioPercent, closeTo(16.67, 0.01));
    });
  });

  test('pergantian bulan memakai periode yang benar', () {
    final feb = FinanceCalculator.summarize(scenario, jan.next.range);
    expect(feb.income, 0);
    expect(feb.expense, 0);
    expect(const MonthRef(2025, 1).previous, const MonthRef(2024, 12));
    final cmp = FinanceCalculator.compareMonths(
      scenario,
      jan.next,
      (s) => s.expense,
    );
    expect(cmp.delta, -250000);
    expect(cmp.percentChange, -100);
  });

  test('pemasukan nol: rasio null, perbandingan dari nol null', () {
    final onlyExpense = [scenario[1]];
    final s = FinanceCalculator.summarize(onlyExpense, jan.range);
    expect(s.income, 0);
    expect(s.savingsRatioPercent, isNull);
    final cmp = FinanceCalculator.compareMonths(
      onlyExpense,
      jan,
      (s) => s.expense,
    );
    expect(cmp.percentChange, isNull);
  });

  group('Anggaran', () {
    Budget budget(int limit, {String? cat}) =>
        Budget(id: 'b', categoryId: cat, limitAmount: limit, createdAt: _t0);
    BudgetProgress eval(Budget b, int spent) => BudgetCalculator.evaluate(b, [
      _tx(
        'x',
        TransactionType.expense,
        spent,
        DateTime(2025, 1, 3),
        categoryId: 'exp_food',
      ),
    ], jan.range);

    test('total tidak memasukkan pemasukan dan transfer tabungan', () {
      final p = BudgetCalculator.evaluate(budget(1000000), scenario, jan.range);
      expect(p.spent, 250000);
      expect(p.remaining, 750000);
      expect(p.status, BudgetStatus.normal);
    });
    test('ambang 75 / 90 / 100', () {
      final b = budget(1000000, cat: 'exp_food');
      expect(eval(b, 749999).status, BudgetStatus.normal);
      expect(eval(b, 750000).status, BudgetStatus.caution);
      expect(eval(b, 900000).status, BudgetStatus.warning);
      expect(eval(b, 1000000).status, BudgetStatus.warning);
      final over = eval(b, 1200000);
      expect(over.status, BudgetStatus.exceeded);
      expect(over.remaining, -200000);
      expect(over.barValue, 1.0);
    });
    test('kategori lain tidak ikut dihitung', () {
      final p = BudgetCalculator.evaluate(
        budget(300000, cat: 'exp_transport'),
        scenario,
        jan.range,
      );
      expect(p.spent, 0);
    });
  });

  group('Tujuan tabungan', () {
    final today = DateTime(2025, 1, 15);

    test('contoh 6jt / 1,5jt / 9 bulan = Rp500.000 per bulan', () {
      final p = GoalCalculator.evaluate(
        _goal(initial: 1500000, deadline: DateTime(2025, 10, 15)),
        [],
        today: today,
      );
      expect(p.collected, 1500000);
      expect(p.remaining, 4500000);
      expect(p.percent, 25);
      expect(p.monthsLeft, 9);
      expect(p.monthlyNeeded, 500000);
      expect(p.status, GoalStatus.inProgress);
    });
    test('setoran dan penarikan', () {
      final txs = [
        scenario[2],
        _tx(
          'w',
          TransactionType.transfer,
          200000,
          DateTime(2025, 1, 12),
          accountId: 'sav',
          toAccountId: 'wallet',
          goalId: 'g1',
          goalFlow: GoalFlow.withdrawal,
        ),
      ];
      expect(GoalCalculator.collected(_goal(), txs), 300000);
    });
    test('target tercapai', () {
      final p = GoalCalculator.evaluate(
        _goal(target: 1000000, initial: 1200000),
        [],
        today: today,
      );
      expect(p.status, GoalStatus.achieved);
      expect(p.remaining, 0);
      expect(p.monthlyNeeded, 0);
      expect(p.barValue, 1.0);
    });
    test('tenggat terlewat: tidak ada angka per bulan', () {
      final p = GoalCalculator.evaluate(
        _goal(deadline: DateTime(2025, 1, 1)),
        [],
        today: today,
      );
      expect(p.status, GoalStatus.overdue);
      expect(p.daysLeft, -14);
      expect(p.monthlyNeeded, isNull);
    });
    test('sisa waktu < 1 bulan: seluruh sisa dibutuhkan bulan ini', () {
      final p = GoalCalculator.evaluate(
        _goal(target: 1000000, deadline: DateTime(2025, 1, 20)),
        [],
        today: today,
      );
      expect(p.monthsLeft, 0);
      expect(p.monthlyNeeded, 1000000);
    });
    test('target nol tidak menyebabkan pembagian nol', () {
      final p = GoalCalculator.evaluate(_goal(target: 0), [], today: today);
      expect(p.percent, 0);
      expect(p.barValue, 0);
    });
  });

  test('format dan parse Rupiah', () {
    expect(Money.format(25000), 'Rp25.000');
    expect(Money.format(1500000), 'Rp1.500.000');
    expect(Money.tryParse('Rp1.500.000'), 1500000);
    expect(Money.tryParse('-5000'), isNull);
    expect(Money.tryParse('12,5'), isNull);
    expect(Money.tryParse(''), isNull);
  });
}
