import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sakurapi/app.dart';
import 'package:sakurapi/core/dates.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/tx_category.dart';
import 'package:sakurapi/domain/range_report.dart';
import 'package:sakurapi/state/providers.dart';

final _now = DateTime(2025, 1, 20);

MoneyTransaction _tx(
  TransactionType type,
  int amount,
  DateTime date, {
  String category = 'exp_food',
  String title = '',
}) => MoneyTransaction(
  id: '${type.name}-$amount-$date',
  type: type,
  amount: amount,
  title: title,
  accountId: 'acc_cash',
  categoryId: category,
  date: date,
  createdAt: _now,
  updatedAt: _now,
);

final _txs = [
  _tx(TransactionType.income, 3000000, DateTime(2025, 1, 1), category: 'inc_salary'),
  _tx(TransactionType.expense, 250000, DateTime(2025, 1, 5), title: 'Makan siang'),
  _tx(TransactionType.expense, 70000, DateTime(2024, 12, 20)),
];

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('RangeReport', () {
    test('previous: panjang sama, berakhir sehari sebelumnya', () {
      final prev = RangeReport.previous(DateRange(DateTime(2025, 1, 1), DateTime(2025, 1, 10)));
      expect(prev.start, DateTime(2024, 12, 22));
      expect(prev.end, DateTime(2024, 12, 31));

      final one = RangeReport.previous(DateRange(DateTime(2025, 3, 1), DateTime(2025, 3, 1)));
      expect(one.start, DateTime(2025, 2, 28));
      expect(one.end, DateTime(2025, 2, 28));
    });

    test('label dalam tiga bentuk', () {
      expect(
        RangeReport.label(DateRange(DateTime(2025, 1, 5), DateTime(2025, 1, 20))),
        '5 – 20 Jan 2025',
      );
      expect(
        RangeReport.label(DateRange(DateTime(2025, 1, 5), DateTime(2025, 3, 20))),
        '5 Jan – 20 Mar 2025',
      );
      expect(
        RangeReport.label(DateRange(DateTime(2024, 8, 1), DateTime(2025, 1, 20))),
        '1 Agu 2024 – 20 Jan 2025',
      );
    });

    test('averageDaily: hanya hari yang sudah berjalan', () {
      final r = DateRange(DateTime(2025, 1, 1), DateTime(2025, 1, 31));
      expect(RangeReport.averageDaily(300000, r, DateTime(2025, 1, 10)), 30000);
      expect(RangeReport.averageDaily(310000, r, DateTime(2025, 3, 1)), 10000);
      expect(RangeReport.averageDaily(1, r, DateTime(2024, 12, 1)), isNull);
    });

    test('kolom harian untuk rentang pendek', () {
      final b = RangeReport.buckets(
        _txs,
        DateRange(DateTime(2025, 1, 1), DateTime(2025, 1, 5)),
      );
      expect(b.map((x) => x.label), ['1', '2', '3', '4', '5']);
      expect(b[0].income, 3000000);
      expect(b[4].expense, 250000);
    });

    test('kolom mingguan untuk rentang menengah, kolom terakhir dipotong', () {
      final b = RangeReport.buckets(
        _txs,
        DateRange(DateTime(2025, 1, 1), DateTime(2025, 2, 28)),
      );
      expect(b, hasLength(9));
      expect(b.first.label, '1 Jan');
      expect(b.last.label, '26 Feb');
      expect(b.last.range.end, DateTime(2025, 2, 28));
      expect(b.first.income, 3000000);
      expect(b.first.expense, 250000);
    });

    test('kolom bulanan melewati dua tahun diberi akhiran tahun', () {
      final b = RangeReport.buckets(
        _txs,
        DateRange(DateTime(2024, 8, 15), DateTime(2025, 1, 20)),
      );
      expect(b.map((x) => x.label), [
        'Agu 24',
        'Sep 24',
        'Okt 24',
        'Nov 24',
        'Des 24',
        'Jan 25',
      ]);
      expect(b.first.range.start, DateTime(2024, 8, 15)); // dipotong rentang
      expect(b.last.range.end, DateTime(2025, 1, 20));
      expect(b[4].expense, 70000);
      expect(b[5].income, 3000000);
    });

    test('kolom bulanan dalam satu tahun tanpa akhiran', () {
      final b = RangeReport.buckets(
        const [],
        DateRange(DateTime(2025, 1, 1), DateTime(2025, 6, 30)),
      );
      expect(b.map((x) => x.label), ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun']);
    });
  });

  FinanceSnapshot snapshot() => FinanceSnapshot(
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
    transactions: _txs,
    budgets: const [],
    goals: const [],
  );

  Widget app() => ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(() => _now),
      financeSnapshotProvider.overrideWith((ref) async => snapshot()),
    ],
    child: const SakuRapiApp(),
  );

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openStats(WidgetTester tester) async {
    final rail = tester.view.physicalSize.width >= 600 && tester.view.physicalSize.height >= 500;
    final nav = find.byType(rail ? NavigationRail : NavigationBar);
    await tester.tap(find.descendant(of: nav, matching: find.text('Statistik')).first);
    await tester.pumpAndSettle();
  }

  testWidgets('mode Rentang: 6 bulan terakhir memakai rentang dan pembanding yang benar', (
    tester,
  ) async {
    setSize(tester, const Size(412, 915));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openStats(tester);

    await tester.tap(find.text('Rentang'));
    await tester.pumpAndSettle();

    expect(find.text('6 bulan terakhir'), findsOneWidget);
    expect(find.text('1 Agu 2024 – 20 Jan 2025'), findsOneWidget);
    expect(find.text('Ringkasan periode'), findsOneWidget);
    expect(find.text('Dibanding periode sebelumnya'), findsOneWidget);
    expect(find.text('Periode sebelumnya Rp0'), findsWidgets);
    // Rentang ini mencakup pemasukan 3 jt dan pengeluaran 250 rb + 70 rb.
    expect(find.text('Rp3.000.000'), findsWidgets);
    expect(find.text('Rp320.000'), findsWidgets);
  });

  testWidgets('mode Rentang: pilihan 30 hari mengubah rentang', (tester) async {
    setSize(tester, const Size(412, 915));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openStats(tester);
    await tester.tap(find.text('Rentang'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('30 hari terakhir'));
    await tester.pumpAndSettle();
    expect(find.text('22 Des 2024 – 20 Jan 2025'), findsOneWidget);
    // 30 hari: Des 20 tidak termasuk, jadi pengeluaran hanya 250 rb.
    expect(find.text('Rp320.000'), findsNothing);
  });

  testWidgets('kembali ke Per periode memulihkan tampilan semula', (tester) async {
    setSize(tester, const Size(412, 915));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openStats(tester);

    await tester.tap(find.text('Rentang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per periode'));
    await tester.pumpAndSettle();

    expect(find.text('Januari 2025'), findsOneWidget);
    expect(find.text('Dibanding bulan lalu'), findsOneWidget);
    expect(find.text('Tren 6 bulan terakhir'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(800, 1280), Size(1280, 800)]) {
    testWidgets('mode Rentang tanpa overflow di ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      setSize(tester, size);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await openStats(tester);
      await tester.tap(find.text('Rentang'));
      await tester.pumpAndSettle();
      for (final label in ['30 hari terakhir', '3 bulan terakhir', '6 bulan terakhir']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(find.text('Ringkasan periode'), findsOneWidget);
    });
  }
}