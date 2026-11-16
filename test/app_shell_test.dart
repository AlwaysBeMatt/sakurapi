import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sakurapi/app.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/state/providers.dart';

final _now = DateTime(2025, 1, 20);

MoneyTransaction _tx(
  String id,
  TransactionType type,
  int amount,
  String category,
) => MoneyTransaction(
  id: id,
  type: type,
  amount: amount,
  accountId: 'acc_cash',
  categoryId: category,
  date: DateTime(2025, 1, 5),
  createdAt: _now,
  updatedAt: _now,
);

FinanceSnapshot _snapshot({required bool withData}) => FinanceSnapshot(
  accounts: [
    Account(
      id: 'acc_cash',
      name: 'Dompet Tunai',
      type: AccountType.cash,
      createdAt: _now,
    ),
  ],
  categories: const [],
  transactions: withData
      ? [
          _tx('t1', TransactionType.income, 3000000, 'inc_salary'),
          _tx('t2', TransactionType.expense, 250000, 'exp_food'),
        ]
      : const [],
  budgets: const [],
  goals: const [],
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

  const sizes = {
    'HP kecil': Size(320, 568),
    'HP standar': Size(412, 915),
    'HP landscape': Size(915, 412),
    'Tablet portrait': Size(800, 1280),
    'Tablet landscape': Size(1280, 800),
  };

  for (final entry in sizes.entries) {
    testWidgets('${entry.key}: tanpa overflow dan semua tab bisa dibuka', (
      tester,
    ) async {
      _setSize(tester, entry.value);
      await tester.pumpWidget(_app(_snapshot(withData: true)));
      await tester.pumpAndSettle();

      final rail = entry.value.width >= 600 && entry.value.height >= 500;
      expect(find.byType(NavigationRail), rail ? findsOneWidget : findsNothing);
      expect(find.byType(NavigationBar), rail ? findsNothing : findsOneWidget);

      expect(find.text('Januari 2025'), findsOneWidget);
      expect(find.text('Rp3.000.000'), findsOneWidget); // pemasukan
      expect(
        find.text('Rp250.000'),
        findsWidgets,
      ); // pengeluaran + legenda kategori
      expect(
        find.text('Rp2.750.000'),
        findsWidgets,
      ); // total saldo dan arus kas bersih

      final nav = find.byType(rail ? NavigationRail : NavigationBar);

      // Transaksi sudah halaman asli (fase 3).
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Transaksi')).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Cari nama atau catatan'), findsOneWidget);

      // Anggaran dan Tabungan sudah halaman asli (fase 5).
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Anggaran')).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada anggaran'), findsOneWidget);

      await tester.tap(
        find.descendant(of: nav, matching: find.text('Tabungan')).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada target tabungan'), findsOneWidget);

      // Statistik sudah halaman asli (fase 6).
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Statistik')).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Ringkasan periode'), findsOneWidget);

      await tester.tap(
        find.descendant(of: nav, matching: find.text('Beranda')).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Total saldo'), findsOneWidget);
    });
  }

  testWidgets('pengguna baru melihat empty state', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot(withData: false)));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada transaksi'), findsOneWidget);
    expect(find.text('Rp0'), findsWidgets);
  });

  testWidgets('pemilih bulan berpindah dan bisa kembali', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot(withData: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bulan sebelumnya'));
    await tester.pumpAndSettle();
    expect(find.text('Desember 2024'), findsOneWidget);
    expect(find.text('Belum ada transaksi di bulan ini'), findsOneWidget);

    await tester.tap(find.text('Kembali ke bulan ini'));
    await tester.pumpAndSettle();
    expect(find.text('Januari 2025'), findsOneWidget);
  });
}
