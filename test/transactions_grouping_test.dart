import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sakurapi/app.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/tx_category.dart';
import 'package:sakurapi/state/providers.dart';

final _now = DateTime(2025, 1, 20);

MoneyTransaction _tx(String id, TransactionType type, int amount, String title, DateTime date) =>
    MoneyTransaction(
      id: id,
      type: type,
      amount: amount,
      title: title,
      accountId: 'acc_cash',
      categoryId: type == TransactionType.income ? 'inc_salary' : 'exp_food',
      date: date,
      createdAt: _now,
      updatedAt: _now,
    );

FinanceSnapshot _snapshot() => FinanceSnapshot(
  accounts: [
    Account(id: 'acc_cash', name: 'Dompet Tunai', type: AccountType.cash, createdAt: _now),
  ],
  categories: const [
    TxCategory(
      id: 'exp_food',
      name: 'Makanan & Minuman',
      kind: CategoryKind.expense,
      iconKey: 'restaurant',
      color: 0xFFE76F72,
      isDefault: true,
    ),
    TxCategory(
      id: 'inc_salary',
      name: 'Gaji / Penghasilan',
      kind: CategoryKind.income,
      iconKey: 'work',
      color: 0xFF176B55,
      isDefault: true,
    ),
  ],
  transactions: [
    _tx('1', TransactionType.income, 3000000, 'Gaji', DateTime(2025, 1, 1)),
    _tx('2', TransactionType.expense, 250000, 'Makan siang', DateTime(2025, 1, 5)),
    _tx('3', TransactionType.expense, 70000, 'Kopi', DateTime(2024, 12, 20)),
  ],
  budgets: const [],
  goals: const [],
);

Widget _app() => ProviderScope(
  overrides: [
    clockProvider.overrideWithValue(() => _now),
    financeSnapshotProvider.overrideWith((ref) async => _snapshot()),
  ],
  child: const SakuRapiApp(),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('pengelompokan per bulan menampilkan judul dan total tiap bulan', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Transaksi')).first,
    );
    await tester.pumpAndSettle();

    // Bawaan: per hari.
    expect(find.text('Minggu, 5 Januari 2025'), findsOneWidget);
    expect(find.text('Januari 2025'), findsNothing);

    await tester.tap(find.byTooltip('Kelompokkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per bulan'));
    await tester.pumpAndSettle();

    expect(find.text('Januari 2025'), findsOneWidget);
    expect(find.text('Desember 2024'), findsOneWidget);
    expect(find.text('Pemasukan Rp3.000.000 · Pengeluaran Rp250.000'), findsOneWidget);
    expect(find.text('Pemasukan Rp0 · Pengeluaran Rp70.000'), findsOneWidget);
    expect(find.text('Minggu, 5 Januari 2025'), findsNothing);

    // Kembali ke per hari.
    await tester.tap(find.byTooltip('Kelompokkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per hari'));
    await tester.pumpAndSettle();
    expect(find.text('Minggu, 5 Januari 2025'), findsOneWidget);
  });

  testWidgets('urutan nominal tidak dikelompokkan, apa pun pilihannya', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Transaksi')).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kelompokkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per bulan'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Urutkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nominal terbesar'));
    await tester.pumpAndSettle();

    expect(find.text('Januari 2025'), findsNothing);
    expect(find.text('Gaji'), findsOneWidget);
  });
}