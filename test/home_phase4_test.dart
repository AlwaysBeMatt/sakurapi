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

MoneyTransaction _tx(
  String id,
  TransactionType type,
  int amount,
  String title,
  String category,
  DateTime date,
) => MoneyTransaction(
  id: id,
  type: type,
  amount: amount,
  title: title,
  accountId: 'acc_cash',
  categoryId: category,
  date: date,
  createdAt: _now,
  updatedAt: _now,
);

FinanceSnapshot _snapshot({bool rich = false}) => FinanceSnapshot(
  accounts: [
    Account(
      id: 'acc_cash',
      name: 'Dompet Tunai',
      type: AccountType.cash,
      createdAt: _now,
    ),
    Account(
      id: 'sav',
      name: 'Tabungan',
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
    _tx(
      't1',
      TransactionType.income,
      3000000,
      'Gaji',
      'inc_salary',
      DateTime(2025, 1, 1),
    ),
    _tx(
      't2',
      TransactionType.expense,
      250000,
      'Makan siang',
      'exp_food',
      DateTime(2025, 1, 5),
    ),
  ],
  budgets: rich
      ? [
          Budget(
            id: 'b1',
            categoryId: 'exp_food',
            limitAmount: 300000,
            createdAt: _now,
          ),
        ]
      : [],
  goals: rich
      ? [
          SavingsGoal(
            id: 'g1',
            name: 'Laptop',
            targetAmount: 6000000,
            initialAmount: 1500000,
            targetDate: DateTime(2025, 10, 20),
            accountId: 'sav',
            createdAt: _now,
          ),
        ]
      : [],
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

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('pilihan periode minggu, bulan, dan tahun', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot()));
    await tester.pumpAndSettle();

    expect(find.text('Januari 2025'), findsOneWidget);
    expect(find.text('Rp3.000.000'), findsOneWidget);

    await tester.tap(find.text('Minggu'));
    await tester.pumpAndSettle();
    expect(find.text('20 – 26 Jan 2025'), findsOneWidget);
    expect(find.text('Belum ada transaksi di minggu ini'), findsOneWidget);

    await tester.tap(find.byTooltip('Minggu sebelumnya'));
    await tester.pumpAndSettle();
    expect(find.text('13 – 19 Jan 2025'), findsOneWidget);
    expect(find.text('Kembali ke minggu ini'), findsOneWidget);

    await tester.tap(find.text('Tahun'));
    await tester.pumpAndSettle();
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('Rp3.000.000'), findsOneWidget);

    await tester.tap(find.text('Bulan'));
    await tester.pumpAndSettle();
    expect(find.text('Januari 2025'), findsOneWidget);
  });

  testWidgets('kartu grafik, kategori, dan transaksi terbaru tampil', (
    tester,
  ) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot()));
    await tester.pumpAndSettle();

    expect(find.text('Pemasukan vs pengeluaran'), findsOneWidget);
    expect(find.text('Pengeluaran per kategori'), findsOneWidget);
    expect(find.text('Makanan & Minuman'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Transaksi terbaru'), findsOneWidget);
    expect(find.text('Makan siang'), findsOneWidget);
    expect(
      find.text(
        'Belum ada anggaran. Batas pengeluaran bisa diatur di tab Anggaran.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('anggaran dan tabungan memakai data tersimpan', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot(rich: true)));
    await tester.pumpAndSettle();

    expect(find.text('Perhatian'), findsOneWidget); // 250rb dari 300rb = 83%
    expect(find.text('Tersisa Rp50.000 dari Rp300.000'), findsOneWidget);
    expect(find.text('Laptop'), findsOneWidget);
    expect(find.textContaining('Perlu Rp500.000 per bulan'), findsOneWidget);
  });

  testWidgets('ketuk ringkasan membuka Transaksi dengan filter periode', (
    tester,
  ) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ringkasan bulan'));
    await tester.pumpAndSettle();
    expect(find.text('Cari nama atau catatan'), findsOneWidget);
    expect(find.text('Makan siang'), findsOneWidget);
    expect(find.text('Gaji'), findsOneWidget);
  });

  testWidgets('ketuk kategori memfilter Transaksi', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Makanan & Minuman'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makanan & Minuman'));
    await tester.pumpAndSettle();

    expect(find.text('Cari nama atau catatan'), findsOneWidget);
    expect(find.text('Makan siang'), findsOneWidget);
    expect(find.text('Gaji'), findsNothing);
  });

  testWidgets('Lihat semua membuka tab Transaksi', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Lihat semua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat semua'));
    await tester.pumpAndSettle();
    expect(find.text('Cari nama atau catatan'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(800, 1280), Size(1280, 800)]) {
    testWidgets(
      'tanpa overflow di ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        _setSize(tester, size);
        await tester.pumpWidget(_app(_snapshot(rich: true)));
        await tester.pumpAndSettle();

        for (final kind in ['Minggu', 'Tahun', 'Bulan']) {
          await tester.tap(find.text(kind));
          await tester.pumpAndSettle();
        }
        expect(find.text('Total saldo'), findsOneWidget);
      },
    );
  }
}
