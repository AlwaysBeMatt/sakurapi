import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../data/finance_repository.dart';
import '../domain/finance_calculator.dart';
import '../domain/models/account.dart';
import '../domain/models/budget.dart';
import '../domain/models/money_transaction.dart';
import '../domain/models/recurring_rule.dart';
import '../domain/models/savings_goal.dart';
import '../domain/models/tx_category.dart';

/// Diisi di main() dengan repository yang sudah membuka database.
final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => throw UnimplementedError(
    'financeRepositoryProvider harus di-override di main().',
  ),
);

/// Sumber "hari ini" untuk UI. Di test diganti dengan tanggal tetap.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Seluruh data tersimpan, dimuat sekali dan dimuat ulang setiap ada perubahan.
class FinanceSnapshot {
  FinanceSnapshot({
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.budgets,
    required this.goals,
    this.recurringRules = const [],
  }) : accountById = {for (final a in accounts) a.id: a},
       categoryById = {for (final c in categories) c.id: c},
       balances = FinanceCalculator.accountBalances(accounts, transactions),
       totalBalance = FinanceCalculator.totalBalance(accounts, transactions);

  final List<Account> accounts;
  final List<TxCategory> categories;
  final List<MoneyTransaction> transactions;
  final List<Budget> budgets;
  final List<SavingsGoal> goals;
  final List<RecurringRule> recurringRules;

  final Map<String, Account> accountById;
  final Map<String, TxCategory> categoryById;
  final Map<String, int> balances;
  final int totalBalance;

  bool get hasTransactions => transactions.isNotEmpty;
}

final financeSnapshotProvider = FutureProvider<FinanceSnapshot>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  final sub = repo.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);

  final accounts = await repo.getAccounts();
  final categories = await repo.getCategories();
  final transactions = await repo.getTransactions();
  final budgets = await repo.getBudgets();
  final goals = await repo.getGoals();
  final rules = await repo.getRecurringRules();
  return FinanceSnapshot(
    accounts: accounts,
    categories: categories,
    transactions: transactions,
    budgets: budgets,
    goals: goals,
    recurringRules: rules,
  );
});

class SelectedMonthNotifier extends Notifier<MonthRef> {
  @override
  MonthRef build() => MonthRef.of(ref.watch(clockProvider)());

  void previous() {
    state = state.previous;
  }

  void next() {
    state = state.next;
  }

  void reset() {
    state = MonthRef.of(ref.read(clockProvider)());
  }
}

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, MonthRef>(
  SelectedMonthNotifier.new,
);