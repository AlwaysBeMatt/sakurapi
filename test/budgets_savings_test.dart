import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sakurapi/app.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/budget.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/savings_goal.dart';
import 'package:sakurapi/domain/models/tx_category.dart';
import 'package:sakurapi/state/providers.dart';

final _now = DateTime(2025, 1, 20);

FinanceSnapshot _snapshot() => FinanceSnapshot(
  accounts: [
    Account(
      id: 'acc_cash',
      name: 'Dompet Tunai',
      type: AccountType.cash,
      createdAt: _now,
    ),
    Account(
      id: 'sav',
      name: 'Rekening Tabungan',
      type: AccountType.savings,
      createdAt: _now,
    ),
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
  ],
  transactions: [
    MoneyTransaction(
      id: 't1',
      type: TransactionType.expense,
      amount: 250000,
      title: 'Makan siang',
      accountId: 'acc_cash',
      categoryId: 'exp_food',
      date: DateTime(2025, 1, 5),
      createdAt: _now,
      updatedAt: _now,
    ),
  ],
  budgets: [
    Budget(
      id: 'b1',
      categoryId: 'exp_food',
      limitAmount: 300000,
      createdAt: _now,
    ),
  ],
  goals: [
    SavingsGoal(
      id: 'g1',
      name: 'Laptop',
      targetAmount: 6000000,
      initialAmount: 1500000,
      targetDate: DateTime(2025, 10, 20),
      accountId: 'sav',
      createdAt: _now,
    ),
  ],
);

Widget _app(FinanceSnapshot snapshot) => ProviderScope(
  overrides: [
    clockProvider.overrideWithValue(() => _now),
    financeSnapshotProvider.overrideWith((ref) async => snapshot),
  ],
  child: const SakuRapiApp(),
);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find
        .descendant(of: find.byType(NavigationBar), matching: find.text(label))
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('tab Anggaran menampilkan anggaran dan statusnya', (
    tester,
  ) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot()));
    await tester.pumpAndSettle();
    await _openTab(tester, 'Anggaran');

    expect(find.text('Makanan & Minuman'), findsOneWidget);
    expect(find.text('Perhatian'), findsOneWidget); // 250rb dari 300rb = 83%
    expect(find.text('Tersisa Rp50.000 dari Rp300.000'), findsOneWidget);
  });

  testWidgets('form anggaran menolak nominal kosong', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot()));
    await tester.pumpAndSettle();
    await _openTab(tester, 'Anggaran');

    await tester.tap(find.byTooltip('Tambah anggaran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Masukkan batas yang valid (lebih dari Rp0).'),
      findsOneWidget,
    );
  });

  testWidgets('tab Tabungan menampilkan target dan estimasi', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot()));
    await tester.pumpAndSettle();
    await _openTab(tester, 'Tabungan');

    expect(find.text('Laptop'), findsOneWidget);
    expect(find.textContaining('Perlu Rp500.000 per bulan'), findsOneWidget);
  });

  testWidgets('ketuk target membuka detail', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot()));
    await tester.pumpAndSettle();
    await _openTab(tester, 'Tabungan');

    await tester.tap(find.text('Laptop'));
    await tester.pumpAndSettle();

    expect(find.text('Setor'), findsOneWidget);
    expect(find.text('Tarik'), findsOneWidget);
    expect(find.text('Riwayat'), findsOneWidget);
    expect(find.text('Dana awal'), findsOneWidget);
    expect(find.text('Belum ada setoran atau penarikan.'), findsOneWidget);
  });

  testWidgets('form target menolak nama kosong', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot()));
    await tester.pumpAndSettle();
    await _openTab(tester, 'Tabungan');

    await tester.tap(find.byTooltip('Tambah target tabungan'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah target'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Nama target wajib diisi.'), findsOneWidget);
  });
}
