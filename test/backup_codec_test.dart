import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sakurapi/data/app_database.dart';
import 'package:sakurapi/data/backup_codec.dart';
import 'package:sakurapi/data/finance_repository.dart';
import 'package:sakurapi/domain/errors.dart';
import 'package:sakurapi/domain/finance_calculator.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/tx_category.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const cash = AppDatabase.defaultCashAccountId;
final today = DateTime(2025, 1, 20);
final throwsValidation = throwsA(isA<ValidationException>());

Matcher throwsMessage(String part) => throwsA(
  isA<ValidationException>().having((e) => e.message, 'message', contains(part)),
);

void main() {
  sqfliteFfiInit();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sakurapi_backup');
  });
  tearDown(() => dir.delete(recursive: true));

  Future<FinanceRepository> openRepo(String name) async => FinanceRepository(
    await AppDatabase.open(
      path: p.join(dir.path, name),
      factory: databaseFactoryFfi,
    ),
    clock: () => today,
  );

  Future<void> fill(FinanceRepository repo) async {
    final sav = await repo.createAccount(
      name: 'Tabungan',
      type: AccountType.savings,
    );
    final goal = await repo.createGoal(
      name: 'Laptop',
      targetAmount: 6000000,
      accountId: sav.id,
      initialAmount: 1500000,
      targetDate: DateTime(2025, 10, 20),
    );
    await repo.addTransaction(
      TransactionInput(
        type: TransactionType.income,
        amount: 3000000,
        accountId: cash,
        categoryId: 'inc_salary',
        title: 'Gaji',
        date: DateTime(2025, 1, 1),
      ),
    );
    await repo.addTransaction(
      TransactionInput(
        type: TransactionType.expense,
        amount: 250000,
        accountId: cash,
        categoryId: 'exp_food',
        title: 'Makan siang',
        note: 'enak, "mantap"',
        date: DateTime(2025, 1, 5),
      ),
    );
    await repo.depositToGoal(
      goalId: goal.id,
      fromAccountId: cash,
      amount: 500000,
      date: DateTime(2025, 1, 10),
    );
    await repo.saveBudget(categoryId: 'exp_food', limitAmount: 1000000);
    await repo.createCategory(name: 'Kopi', kind: CategoryKind.expense);
  }

  Map<String, dynamic> decode(String json) =>
      jsonDecode(json) as Map<String, dynamic>;

  test('backup lalu restore ke database lain menghasilkan data yang sama', () async {
    final a = await openRepo('a.db');
    await fill(a);
    final json = await a.exportBackup();

    final b = await openRepo('b.db');
    await b.createAccount(name: 'Akun sementara', type: AccountType.bank);
    final summary = await b.restoreBackup(json);

    expect(summary.accounts, 2);
    expect(summary.categories, 15); // 14 bawaan + Kopi
    expect(summary.transactions, 3);
    expect(summary.budgets, 1);
    expect(summary.goals, 1);

    final accountsA = await a.getAccounts();
    final accountsB = await b.getAccounts();
    expect(accountsB.map((x) => x.name), accountsA.map((x) => x.name));
    expect(accountsB.any((x) => x.name == 'Akun sementara'), isFalse);

    final txA = await a.getTransactions();
    final txB = await b.getTransactions();
    expect(
      txB.map((t) => t.toMap()).toList(),
      txA.map((t) => t.toMap()).toList(),
    );
    expect(txB.any((t) => t.note == 'enak, "mantap"'), isTrue);

    expect(
      FinanceCalculator.accountBalances(accountsB, txB),
      FinanceCalculator.accountBalances(accountsA, txA),
    );
    expect((await b.getCategories()).any((c) => c.name == 'Kopi'), isTrue);
    expect((await b.getGoals()).single.initialAmount, 1500000);
    expect((await b.getBudgets()).single.limitAmount, 1000000);

    await a.close();
    await b.close();
  });

  test('file diawali BOM tetap bisa dibaca', () async {
    final a = await openRepo('a.db');
    await fill(a);
    final json = await a.exportBackup();
    final summary = BackupCodec.inspect('\uFEFF$json', today: today);
    expect(summary.transactions, 3);
    await a.close();
  });

  group('file tidak valid ditolak', () {
    late FinanceRepository repo;
    late String validJson;

    setUp(() async {
      final source = await openRepo('source.db');
      await fill(source);
      validJson = await source.exportBackup();
      await source.close();
      repo = await openRepo('target.db');
      await repo.createAccount(name: 'Data asli', type: AccountType.bank);
    });
    tearDown(() => repo.close());

    Future<void> expectUntouched() async {
      final accounts = await repo.getAccounts();
      expect(accounts.map((a) => a.name), ['Dompet Tunai', 'Data asli']);
      expect(await repo.getTransactions(), isEmpty);
    }

    test('bukan JSON', () async {
      await expectLater(repo.restoreBackup('bukan json'), throwsMessage('bukan JSON'));
      await expectUntouched();
    });

    test('bukan file backup SakuRapi', () async {
      await expectLater(
        repo.restoreBackup('{"format":"lain"}'),
        throwsMessage('bukan file backup SakuRapi'),
      );
      await expectUntouched();
    });

    test('versi lebih baru', () async {
      final doc = decode(validJson)..['version'] = 99;
      await expectLater(
        repo.restoreBackup(jsonEncode(doc)),
        throwsMessage('versi aplikasi yang lebih baru'),
      );
      await expectUntouched();
    });

    test('bagian tabel hilang', () async {
      final doc = decode(validJson)..remove('budgets');
      await expectLater(
        repo.restoreBackup(jsonEncode(doc)),
        throwsMessage('budgets'),
      );
      await expectUntouched();
    });

    test('nominal tidak valid', () async {
      final doc = decode(validJson);
      ((doc['transactions'] as List)[0] as Map)['amount'] = 0;
      await expectLater(repo.restoreBackup(jsonEncode(doc)), throwsValidation);
      await expectUntouched();
    });

    test('relasi tidak cocok: dibatalkan seluruhnya', () async {
      final doc = decode(validJson);
      ((doc['transactions'] as List)[0] as Map)['account_id'] = 'tidak-ada';
      await expectLater(
        repo.restoreBackup(jsonEncode(doc)),
        throwsMessage('tidak konsisten'),
      );
      await expectUntouched();
    });

    test('tipe data salah', () async {
      final doc = decode(validJson);
      ((doc['accounts'] as List)[0] as Map)['initial_balance'] = 'banyak';
      await expectLater(repo.restoreBackup(jsonEncode(doc)), throwsValidation);
      await expectUntouched();
    });

    test('tanpa akun', () async {
      final doc = decode(validJson)
        ..['accounts'] = <Object>[]
        ..['transactions'] = <Object>[]
        ..['savings_goals'] = <Object>[];
      await expectLater(
        repo.restoreBackup(jsonEncode(doc)),
        throwsMessage('tidak berisi akun'),
      );
      await expectUntouched();
    });
  });
}