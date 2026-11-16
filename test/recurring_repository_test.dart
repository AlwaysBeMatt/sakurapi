import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sakurapi/core/dates.dart';
import 'package:sakurapi/data/app_database.dart';
import 'package:sakurapi/data/finance_repository.dart';
import 'package:sakurapi/domain/errors.dart';
import 'package:sakurapi/domain/finance_calculator.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/recurring_rule.dart';
import 'package:sakurapi/domain/models/tx_category.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const cash = AppDatabase.defaultCashAccountId;
final throwsValidation = throwsA(isA<ValidationException>());

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late DateTime now;
  late FinanceRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sakurapi_recurring');
    now = DateTime(2025, 1, 20);
    repo = FinanceRepository(
      await AppDatabase.open(
        path: p.join(dir.path, 'test.db'),
        factory: databaseFactoryFfi,
      ),
      clock: () => now,
    );
  });
  tearDown(() async {
    await repo.close();
    await dir.delete(recursive: true);
  });

  Future<RecurringRule> create({
    required DateTime start,
    DateTime? end,
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    TransactionType type = TransactionType.income,
    String category = 'inc_salary',
    int amount = 4000000,
  }) => repo.createRecurringRule(
    type: type,
    amount: amount,
    categoryId: category,
    accountId: cash,
    frequency: frequency,
    startDate: start,
    endDate: end,
    title: 'Gaji',
  );

  Future<List<String>> dates() async => [
    for (final t in await repo.getTransactions()) toDbDate(t.date),
  ];

  test('mulai hari ini: langsung dicatat sekali, berikutnya bulan depan', () async {
    await create(start: DateTime(2025, 1, 20));

    expect(await dates(), ['2025-01-20']);
    final rule = (await repo.getRecurringRules()).single;
    expect(rule.nextDate, DateTime(2025, 2, 20));

    final txs = await repo.getTransactions();
    final balances = FinanceCalculator.accountBalances(await repo.getAccounts(), txs);
    expect(balances[cash], 4000000);
  });

  test('mulai di masa lalu: semua yang terlewat dicatat', () async {
    await create(start: DateTime(2024, 11, 20));
    expect(await dates(), ['2025-01-20', '2024-12-20', '2024-11-20']);
    expect((await repo.getRecurringRules()).single.nextDate, DateTime(2025, 2, 20));
  });

  test('menjalankan lagi tidak membuat duplikat', () async {
    await create(start: DateTime(2024, 11, 20));
    expect(await repo.generateDueRecurring(), 0);
    expect(await repo.getTransactions(), hasLength(3));
  });

  test('waktu berjalan: transaksi baru muncul saat jatuh tempo', () async {
    await create(start: DateTime(2025, 1, 20));
    now = DateTime(2025, 3, 25);
    expect(await repo.generateDueRecurring(), 2);
    expect(await dates(), ['2025-03-20', '2025-02-20', '2025-01-20']);
  });

  test('mingguan', () async {
    await create(start: DateTime(2025, 1, 6), frequency: RecurrenceFrequency.weekly);
    expect(await dates(), ['2025-01-20', '2025-01-13', '2025-01-06']);
  });

  test('pengeluaran berulang mengurangi saldo', () async {
    await create(
      start: DateTime(2024, 12, 20),
      type: TransactionType.expense,
      category: 'exp_bills',
      amount: 350000,
    );
    final txs = await repo.getTransactions();
    final balances = FinanceCalculator.accountBalances(await repo.getAccounts(), txs);
    expect(balances[cash], -700000);
  });

  test('tanggal berakhir: berhenti dan aturan menjadi tidak aktif', () async {
    await create(start: DateTime(2024, 11, 20), end: DateTime(2024, 12, 31));
    expect(await dates(), ['2024-12-20', '2024-11-20']);
    final rule = (await repo.getRecurringRules()).single;
    expect(rule.active, isFalse);
    expect(rule.isFinished, isTrue);

    now = DateTime(2025, 6, 1);
    expect(await repo.generateDueRecurring(), 0);
  });

  test('dijeda tidak mencatat, diaktifkan kembali tanpa mencatat mundur', () async {
    await create(start: DateTime(2025, 1, 20));
    final rule = (await repo.getRecurringRules()).single;
    await repo.updateRecurringRule(rule.copyWith(active: false));

    now = DateTime(2025, 3, 25);
    expect(await repo.generateDueRecurring(), 0);
    expect(await repo.getTransactions(), hasLength(1));

    final paused = (await repo.getRecurringRules()).single;
    await repo.updateRecurringRule(paused.copyWith(active: true).skipTo(now));
    expect(await repo.getTransactions(), hasLength(1)); // belum jatuh tempo lagi

    now = DateTime(2025, 4, 21);
    expect(await repo.generateDueRecurring(), 1);
    expect(await dates(), ['2025-04-20', '2025-01-20']);
  });

  test('perubahan nominal tidak mengubah transaksi yang sudah tercatat', () async {
    await create(start: DateTime(2025, 1, 20));
    final rule = (await repo.getRecurringRules()).single;
    await repo.updateRecurringRule(rule.copyWith(amount: 5000000));

    expect((await repo.getTransactions()).single.amount, 4000000);
    now = DateTime(2025, 2, 21);
    await repo.generateDueRecurring();
    final amounts = (await repo.getTransactions()).map((t) => t.amount).toList();
    expect(amounts, [5000000, 4000000]);
  });

  test('menghapus aturan tidak menghapus transaksi yang sudah tercatat', () async {
    final rule = await create(start: DateTime(2025, 1, 20));
    await repo.deleteRecurringRule(rule.id);
    expect(await repo.getRecurringRules(), isEmpty);
    expect(await repo.getTransactions(), hasLength(1));
  });

  test('menghapus kategori ikut menghapus aturannya', () async {
    final kopi = await repo.createCategory(name: 'Kopi', kind: CategoryKind.expense);
    await create(
      start: DateTime(2025, 1, 25), // belum jatuh tempo, jadi belum ada transaksi
      type: TransactionType.expense,
      category: kopi.id,
      amount: 20000,
    );
    expect(await repo.getRecurringRules(), hasLength(1));

    await repo.deleteCategory(kopi.id);
    expect(await repo.getRecurringRules(), isEmpty);
  });

  group('validasi', () {
    test('nominal nol', () async {
      await expectLater(create(start: now, amount: 0), throwsValidation);
    });

    test('jenis kategori tidak cocok', () async {
      await expectLater(create(start: now, category: 'exp_food'), throwsValidation);
    });

    test('akun tidak ada', () async {
      await expectLater(
        repo.createRecurringRule(
          type: TransactionType.income,
          amount: 1000,
          categoryId: 'inc_salary',
          accountId: 'tidak-ada',
          frequency: RecurrenceFrequency.monthly,
          startDate: now,
        ),
        throwsValidation,
      );
    });

    test('mulai lebih dari 13 bulan ke belakang', () async {
      await expectLater(create(start: DateTime(2023, 1, 1)), throwsValidation);
    });

    test('berakhir sebelum mulai', () async {
      await expectLater(
        create(start: DateTime(2025, 1, 20), end: DateTime(2025, 1, 1)),
        throwsValidation,
      );
    });

    test('tidak ada yang tersimpan bila ditolak', () async {
      await expectLater(create(start: now, amount: 0), throwsValidation);
      expect(await repo.getRecurringRules(), isEmpty);
      expect(await repo.getTransactions(), isEmpty);
    });
  });
}