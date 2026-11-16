import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sakurapi/core/dates.dart';
import 'package:sakurapi/data/app_database.dart';
import 'package:sakurapi/data/demo_data.dart';
import 'package:sakurapi/data/finance_repository.dart';
import 'package:sakurapi/domain/errors.dart';
import 'package:sakurapi/domain/finance_calculator.dart';
import 'package:sakurapi/domain/goal_calculator.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const cash = AppDatabase.defaultCashAccountId;
final today = DateTime(2025, 1, 20);

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late FinanceRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sakurapi_demo');
    repo = FinanceRepository(
      await AppDatabase.open(
        path: p.join(dir.path, 'test.db'),
        factory: databaseFactoryFfi,
      ),
      clock: () => today,
    );
  });
  tearDown(() async {
    await repo.close();
    await dir.delete(recursive: true);
  });

  test('memuat data demo: akun, target, anggaran, dan transaksi 3 bulan', () async {
    await repo.loadDemoData();

    final accounts = await repo.getAccounts();
    expect(accounts.map((a) => a.id), [cash, DemoData.bankId, DemoData.savingsId]);
    expect((await repo.getGoals()).single.id, DemoData.goalId);
    expect((await repo.getBudgets()).map((b) => b.id).toSet(), {
      'demo_budget_food',
      'demo_budget_transport',
    });

    final txs = await repo.getTransactions();
    expect(txs.every((t) => t.id.startsWith('demo_tx_')), isTrue);

    // Januari berjalan sampai tanggal 20: transaksi tanggal 21 dan 22 dilewati.
    final jan = FinanceCalculator.summarize(txs, const MonthRef(2025, 1).range);
    expect(jan.income, 4000000);
    expect(jan.expense, 710000);
    expect(jan.savingsContribution, 500000);

    final dec = FinanceCalculator.summarize(txs, const MonthRef(2024, 12).range);
    expect(dec.expense, 995000);

    // Saldo dompet asli tidak tersentuh.
    final balances = FinanceCalculator.accountBalances(accounts, txs);
    expect(balances[cash], 0);

    final goal = (await repo.getGoals()).single;
    expect(GoalCalculator.collected(goal, txs), 1500000 + 3 * 500000);
  });

  test('memuat dua kali ditolak', () async {
    await repo.loadDemoData();
    await expectLater(
      repo.loadDemoData(),
      throwsA(isA<ValidationException>()),
    );
  });

  test('hapus data demo mengembalikan data seperti semula', () async {
    await repo.addTransaction(
      TransactionInput(
        type: TransactionType.income,
        amount: 3000000,
        accountId: cash,
        categoryId: 'inc_salary',
        title: 'Gaji asli',
        date: DateTime(2025, 1, 1),
      ),
    );
    await repo.saveBudget(categoryId: 'exp_food', limitAmount: 700000);
    final beforeAccounts = (await repo.getAccounts()).map((a) => a.id).toList();
    final beforeTx = (await repo.getTransactions()).map((t) => t.id).toList();

    await repo.loadDemoData();
    // Anggaran makanan milik pengguna dihormati: hanya anggaran transport demo.
    expect((await repo.getBudgets()).map((b) => b.id), contains('demo_budget_transport'));
    expect((await repo.getBudgets()).where((b) => b.categoryId == 'exp_food'), hasLength(1));

    await repo.removeDemoData();

    expect((await repo.getAccounts()).map((a) => a.id), beforeAccounts);
    expect((await repo.getTransactions()).map((t) => t.id), beforeTx);
    expect(await repo.getGoals(), isEmpty);
    final budgets = await repo.getBudgets();
    expect(budgets, hasLength(1));
    expect(budgets.single.limitAmount, 700000);
  });

  test('transaksi asli yang memakai target demo ikut terhapus', () async {
    await repo.addTransaction(
      TransactionInput(
        type: TransactionType.income,
        amount: 3000000,
        accountId: cash,
        categoryId: 'inc_salary',
        date: DateTime(2025, 1, 1),
      ),
    );
    await repo.loadDemoData();
    await repo.depositToGoal(
      goalId: DemoData.goalId,
      fromAccountId: cash,
      amount: 100000,
      date: DateTime(2025, 1, 15),
    );

    var accounts = await repo.getAccounts();
    var txs = await repo.getTransactions();
    expect(FinanceCalculator.accountBalances(accounts, txs)[cash], 2900000);

    await repo.removeDemoData();

    accounts = await repo.getAccounts();
    txs = await repo.getTransactions();
    expect(txs, hasLength(1));
    expect(FinanceCalculator.accountBalances(accounts, txs)[cash], 3000000);
  });

  test('hapus tanpa data demo tidak melakukan apa-apa', () async {
    await repo.removeDemoData();
    expect(await repo.getAccounts(), hasLength(1));
  });
}