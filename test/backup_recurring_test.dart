import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sakurapi/data/app_database.dart';
import 'package:sakurapi/data/backup_codec.dart';
import 'package:sakurapi/data/finance_repository.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/recurring_rule.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const cash = AppDatabase.defaultCashAccountId;
final today = DateTime(2025, 1, 20);

void main() {
  sqfliteFfiInit();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sakurapi_backup_rec');
  });
  tearDown(() => dir.delete(recursive: true));

  Future<FinanceRepository> openRepo(String name) async => FinanceRepository(
    await AppDatabase.open(
      path: p.join(dir.path, name),
      factory: databaseFactoryFfi,
    ),
    clock: () => today,
  );

  Future<RecurringRule> addRule(FinanceRepository repo) => repo.createRecurringRule(
    type: TransactionType.expense,
    amount: 350000,
    categoryId: 'exp_bills',
    accountId: cash,
    frequency: RecurrenceFrequency.monthly,
    startDate: DateTime(2025, 1, 25), // belum jatuh tempo
    title: 'Listrik',
  );

  test('aturan berulang ikut dibackup dan dipulihkan', () async {
    final a = await openRepo('a.db');
    await addRule(a);
    final json = await a.exportBackup();

    final b = await openRepo('b.db');
    final summary = await b.restoreBackup(json);
    expect(summary.recurring, 1);
    expect(summary.description, contains('1 transaksi berulang'));

    final rule = (await b.getRecurringRules()).single;
    expect(rule.title, 'Listrik');
    expect(rule.amount, 350000);
    expect(rule.nextDate, DateTime(2025, 1, 25));
    expect(rule.frequency, RecurrenceFrequency.monthly);

    await a.close();
    await b.close();
  });

  test('backup lama tanpa bagian aturan tetap bisa dipulihkan', () async {
    final a = await openRepo('a.db');
    await addRule(a);
    final doc = jsonDecode(await a.exportBackup()) as Map<String, dynamic>
      ..remove('recurring_rules');

    final b = await openRepo('b.db');
    await addRule(b); // aturan lama di b harus hilang setelah restore
    final summary = await b.restoreBackup(jsonEncode(doc));

    expect(summary.recurring, 0);
    expect(await b.getRecurringRules(), isEmpty);
    expect(BackupCodec.inspect(jsonEncode(doc), today: today).recurring, 0);

    await a.close();
    await b.close();
  });

  test('aturan dengan akun yang tidak ada: dibatalkan, data tidak berubah', () async {
    final a = await openRepo('a.db');
    await addRule(a);
    final doc = jsonDecode(await a.exportBackup()) as Map<String, dynamic>;
    ((doc['recurring_rules'] as List)[0] as Map)['account_id'] = 'tidak-ada';

    final b = await openRepo('b.db');
    await expectLater(b.restoreBackup(jsonEncode(doc)), throwsA(anything));
    expect((await b.getAccounts()).map((x) => x.id), [cash]);

    await a.close();
    await b.close();
  });
}