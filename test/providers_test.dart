import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sakurapi/data/app_database.dart';
import 'package:sakurapi/data/finance_repository.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/state/providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final today = DateTime(2025, 1, 20);

  test('snapshot dimuat ulang otomatis setelah data berubah', () async {
    final dir = await Directory.systemTemp.createTemp('sakurapi_provider');
    final repo = FinanceRepository(
      await AppDatabase.open(
        path: p.join(dir.path, 'test.db'),
        factory: databaseFactoryFfi,
      ),
      clock: () => today,
    );
    final container = ProviderContainer(
      overrides: [
        financeRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => today),
      ],
    );
    final sub = container.listen(financeSnapshotProvider, (previous, next) {});

    var snapshot = await container.read(financeSnapshotProvider.future);
    expect(snapshot.transactions, isEmpty);
    expect(snapshot.totalBalance, 0);

    await repo.addTransaction(
      TransactionInput(
        type: TransactionType.income,
        amount: 3000000,
        accountId: AppDatabase.defaultCashAccountId,
        categoryId: 'inc_salary',
        date: today,
      ),
    );
    await Future<void>.delayed(
      Duration.zero,
    ); // beri waktu notifikasi perubahan

    snapshot = await container.read(financeSnapshotProvider.future);
    expect(snapshot.transactions, hasLength(1));
    expect(snapshot.totalBalance, 3000000);

    sub.close();
    container.dispose();
    await repo.close();
    await dir.delete(recursive: true);
  });

  test('pemilih bulan maju, mundur, dan kembali ke bulan ini', () {
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => today)],
    );
    final notifier = container.read(selectedMonthProvider.notifier);
    notifier.previous();
    expect(container.read(selectedMonthProvider).month, 12);
    expect(container.read(selectedMonthProvider).year, 2024);
    notifier.next();
    notifier.next();
    expect(container.read(selectedMonthProvider).month, 2);
    notifier.reset();
    expect(container.read(selectedMonthProvider).month, 1);
    container.dispose();
  });
}
