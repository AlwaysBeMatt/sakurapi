import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sakurapi/core/dates.dart';
import 'package:sakurapi/data/app_database.dart';
import 'package:sakurapi/data/finance_repository.dart';
import 'package:sakurapi/domain/errors.dart';
import 'package:sakurapi/domain/finance_calculator.dart';
import 'package:sakurapi/domain/goal_calculator.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/tx_category.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const cash = AppDatabase.defaultCashAccountId;
final today = DateTime(2025, 1, 20);
final throwsValidation = throwsA(isA<ValidationException>());

TransactionInput expense(
  int amount, {
  String cat = 'exp_food',
  String title = '',
}) => TransactionInput(
  type: TransactionType.expense,
  amount: amount,
  accountId: cash,
  categoryId: cat,
  title: title,
  date: DateTime(2025, 1, 5),
);

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late String dbPath;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sakurapi_test');
    dbPath = p.join(dir.path, 'test.db');
  });
  tearDown(() => dir.delete(recursive: true));

  Future<FinanceRepository> openRepo() async => FinanceRepository(
    await AppDatabase.open(path: dbPath, factory: databaseFactoryFfi),
    clock: () => today,
  );

  test('data bawaan tersedia', () async {
    final repo = await openRepo();
    expect(await repo.getCategories(kind: CategoryKind.expense), hasLength(9));
    expect(await repo.getCategories(kind: CategoryKind.income), hasLength(5));
    expect((await repo.getAccounts()).single.id, cash);
    await repo.close();
  });

  test('skenario acuan benar dan bertahan setelah restart', () async {
    var repo = await openRepo();
    final sav = await repo.createAccount(
      name: 'Tabungan',
      type: AccountType.savings,
    );
    final goal = await repo.createGoal(
      name: 'Laptop',
      targetAmount: 6000000,
      accountId: sav.id,
      targetDate: DateTime(2025, 10, 20),
    );
    await repo.addTransaction(
      TransactionInput(
        type: TransactionType.income,
        amount: 3000000,
        accountId: cash,
        categoryId: 'inc_salary',
        date: DateTime(2025, 1, 1),
      ),
    );
    await repo.addTransaction(expense(250000, title: 'Makan siang'));
    await repo.depositToGoal(
      goalId: goal.id,
      fromAccountId: cash,
      amount: 500000,
      date: DateTime(2025, 1, 10),
    );
    await repo.close();

    repo = await openRepo(); // simulasi aplikasi dibuka ulang
    final txs = await repo.getTransactions();
    final accounts = await repo.getAccounts();
    expect(txs, hasLength(3));

    final s = FinanceCalculator.summarize(txs, const MonthRef(2025, 1).range);
    expect(s.income, 3000000);
    expect(s.expense, 250000);
    expect(s.net, 2750000);
    expect(s.savingsContribution, 500000);
    expect(s.savingsRatioPercent, closeTo(16.67, 0.01));

    final balances = FinanceCalculator.accountBalances(accounts, txs);
    expect(balances[cash], 2250000);
    expect(balances[sav.id], 500000);
    expect(FinanceCalculator.totalBalance(accounts, txs), 2750000);

    final gp = GoalCalculator.evaluate(
      (await repo.getGoals()).single,
      txs,
      today: today,
    );
    expect(gp.collected, 500000);
    expect(gp.monthlyNeeded, 611112); // 5.500.000 / 9 bulan, dibulatkan ke atas
    await repo.close();
  });

  test('edit tidak menduplikasi, hapus memperbarui saldo', () async {
    final repo = await openRepo();
    final t = await repo.addTransaction(expense(100000));
    await repo.updateTransaction(t.id, expense(40000, cat: 'exp_transport'));

    var txs = await repo.getTransactions();
    expect(txs, hasLength(1));
    expect(txs.single.amount, 40000);
    expect(txs.single.categoryId, 'exp_transport');
    expect(txs.single.createdAt, t.createdAt);
    expect(
      FinanceCalculator.totalBalance(await repo.getAccounts(), txs),
      -40000,
    );

    await repo.deleteTransaction(t.id);
    txs = await repo.getTransactions();
    expect(txs, isEmpty);
    expect(FinanceCalculator.totalBalance(await repo.getAccounts(), txs), 0);
    await repo.close();
  });

  test('validasi transaksi', () async {
    final repo = await openRepo();
    await expectLater(
      repo.addTransaction(
        TransactionInput(
          type: TransactionType.income,
          amount: 1000,
          accountId: cash,
          categoryId: 'exp_food',
          date: today,
        ),
      ),
      throwsValidation,
    );
    await expectLater(repo.addTransaction(expense(0)), throwsValidation);
    await expectLater(
      repo.addTransaction(
        TransactionInput(
          type: TransactionType.transfer,
          amount: 1000,
          accountId: cash,
          toAccountId: cash,
          date: today,
        ),
      ),
      throwsValidation,
    );
    await expectLater(
      repo.addTransaction(
        TransactionInput(
          type: TransactionType.expense,
          amount: 1000,
          accountId: cash,
          categoryId: 'exp_food',
          date: DateTime(2027, 1, 1),
        ),
      ),
      throwsValidation,
    );
    expect(await repo.getTransactions(), isEmpty);
    await repo.close();
  });

  test('penarikan tidak boleh melebihi dana terkumpul', () async {
    final repo = await openRepo();
    final sav = await repo.createAccount(
      name: 'Tabungan',
      type: AccountType.savings,
    );
    final goal = await repo.createGoal(
      name: 'Dana darurat',
      targetAmount: 1000000,
      accountId: sav.id,
    );
    final dep = await repo.depositToGoal(
      goalId: goal.id,
      fromAccountId: cash,
      amount: 300000,
      date: DateTime(2025, 1, 2),
    );

    await expectLater(
      repo.withdrawFromGoal(
        goalId: goal.id,
        toAccountId: cash,
        amount: 300001,
        date: DateTime(2025, 1, 3),
      ),
      throwsValidation,
    );
    await repo.withdrawFromGoal(
      goalId: goal.id,
      toAccountId: cash,
      amount: 100000,
      date: DateTime(2025, 1, 3),
    );
    await expectLater(repo.deleteTransaction(dep.id), throwsValidation);

    final txs = await repo.getTransactions();
    expect(GoalCalculator.collected(goal, txs), 200000);
    await repo.close();
  });

  test('aturan hapus kategori dan anggaran ganda', () async {
    final repo = await openRepo();
    await expectLater(repo.deleteCategory('exp_food'), throwsValidation);
    final kopi = await repo.createCategory(
      name: 'Kopi',
      kind: CategoryKind.expense,
    );
    await expectLater(
      repo.createCategory(name: 'kopi', kind: CategoryKind.expense),
      throwsValidation,
    );
    await repo.addTransaction(expense(20000, cat: kopi.id));
    await expectLater(repo.deleteCategory(kopi.id), throwsValidation);

    await repo.saveBudget(categoryId: 'exp_food', limitAmount: 1000000);
    await expectLater(
      repo.saveBudget(categoryId: 'exp_food', limitAmount: 5),
      throwsValidation,
    );
    await expectLater(
      repo.saveBudget(categoryId: 'inc_salary', limitAmount: 5),
      throwsValidation,
    );
    await repo.close();
  });

  test('pencarian aman terhadap karakter wildcard', () async {
    final repo = await openRepo();
    await repo.addTransaction(expense(10000, title: 'Diskon 50% sepatu'));
    await repo.addTransaction(expense(10000, title: 'Kopi'));
    expect(
      await repo.getTransactions(const TransactionFilter(query: '%')),
      hasLength(1),
    );
    expect(
      await repo.getTransactions(const TransactionFilter(query: 'kopi')),
      hasLength(1),
    );
    await repo.close();
  });
}
