import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sakurapi/app.dart';
import 'package:sakurapi/core/dates.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/tx_category.dart';
import 'package:sakurapi/domain/stats_report.dart';
import 'package:sakurapi/state/providers.dart';

final _now = DateTime(2025, 1, 20);

MoneyTransaction _tx(
  TransactionType type,
  int amount,
  DateTime date, {
  String? category,
  String? to,
  String title = '',
}) => MoneyTransaction(
  id: '${type.name}-$amount-$date',
  type: type,
  amount: amount,
  title: title,
  accountId: 'acc_cash',
  categoryId: category,
  toAccountId: to,
  date: date,
  createdAt: _now,
  updatedAt: _now,
);

final _txs = [
  _tx(
    TransactionType.income,
    3000000,
    DateTime(2025, 1, 1),
    category: 'inc_salary',
  ),
  _tx(
    TransactionType.expense,
    250000,
    DateTime(2025, 1, 5),
    category: 'exp_food',
    title: 'Makan siang',
  ),
  _tx(
    TransactionType.expense,
    100000,
    DateTime(2025, 1, 6),
    category: 'exp_food',
  ),
  _tx(
    TransactionType.expense,
    400000,
    DateTime(2025, 1, 10),
    category: 'exp_transport',
  ),
  _tx(TransactionType.transfer, 500000, DateTime(2025, 1, 10), to: 'sav'),
  _tx(
    TransactionType.expense,
    70000,
    DateTime(2024, 12, 20),
    category: 'exp_food',
  ),
];

FinanceSnapshot _snapshot() => FinanceSnapshot(
  accounts: [
    Account(
      id: 'acc_cash',
      name: 'Dompet Tunai',
      type: AccountType.cash,
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
      id: 'exp_transport',
      name: 'Transportasi',
      kind: CategoryKind.expense,
      iconKey: 'bus',
      color: 0xFF2F80ED,
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

Widget _app() => ProviderScope(
  overrides: [
    clockProvider.overrideWithValue(() => _now),
    financeSnapshotProvider.overrideWith((ref) async => _snapshot()),
  ],
  child: const SakuRapiApp(),
);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _openStats(WidgetTester tester) async {
  await tester.tap(
    find
        .descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Statistik'),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  final jan = Period.containing(PeriodKind.month, DateTime(2025, 1, 15));

  group('StatsReport', () {
    test('byCategory: terbesar dulu dan transfer diabaikan', () {
      final expense = StatsReport.byCategory(
        _txs,
        jan.range,
        TransactionType.expense,
      );
      expect(expense.map((e) => e.categoryId), ['exp_transport', 'exp_food']);
      expect(expense.map((e) => e.amount), [400000, 350000]);

      final income = StatsReport.byCategory(
        _txs,
        jan.range,
        TransactionType.income,
      );
      expect(income.single.categoryId, 'inc_salary');
      expect(income.single.amount, 3000000);
    });

    test('trend: tiga bulan berakhir di bulan ini', () {
      final t = StatsReport.trend(_txs, jan, count: 3);
      expect(t.map((b) => b.label), ['Nov', 'Des', 'Jan']);
      expect(t[0].peak, 0);
      expect(t[1].expense, 70000);
      expect(t[2].income, 3000000);
      expect(t[2].expense, 750000);
    });

    test('trend bawaan berisi enam periode', () {
      expect(StatsReport.trend(_txs, jan), hasLength(6));
    });

    test('averageDailyExpense: hanya hari yang sudah berjalan', () {
      expect(
        StatsReport.averageDailyExpense(750000, jan, DateTime(2025, 1, 20)),
        37500,
      );
      expect(
        StatsReport.averageDailyExpense(750000, jan, DateTime(2025, 2, 10)),
        24193,
      );
      expect(
        StatsReport.averageDailyExpense(750000, jan, DateTime(2024, 12, 15)),
        isNull,
      );
    });

    test('topExpenses: urut nominal terbesar', () {
      final top = StatsReport.topExpenses(_txs, jan.range, take: 2);
      expect(top.map((t) => t.amount), [400000, 250000]);
    });
  });

  testWidgets('tab Statistik menampilkan semua kartu', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openStats(tester);

    expect(find.text('Ringkasan periode'), findsOneWidget);
    expect(find.text('Arus kas'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Dibanding bulan lalu'), findsOneWidget);
    expect(find.text('Tren 6 bulan terakhir'), findsOneWidget);
    expect(find.text('Pengeluaran terbesar'), findsOneWidget);
    expect(find.text('Makan siang'), findsOneWidget);
  });

  testWidgets('kategori bisa dialihkan ke pemasukan', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openStats(tester);

    expect(find.text('Makanan & Minuman'), findsOneWidget);

    final segment = find.descendant(
      of: find.byType(SegmentedButton<TransactionType>),
      matching: find.text('Pemasukan'),
    );
    await tester.ensureVisible(segment);
    await tester.pumpAndSettle();
    await tester.tap(segment);
    await tester.pumpAndSettle();

    expect(find.text('Gaji / Penghasilan'), findsOneWidget);
    expect(find.text('Makanan & Minuman'), findsNothing);
  });

  testWidgets('ketuk kategori membuka Transaksi dengan filter', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openStats(tester);

    final row = find.text('Makanan & Minuman');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.text('Cari nama atau catatan'), findsOneWidget);
    expect(find.text('Makan siang'), findsOneWidget);
  });

  testWidgets('ganti ke minggu tanpa data menampilkan empty state', (
    tester,
  ) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openStats(tester);

    await tester.tap(find.text('Minggu'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada data di minggu ini'), findsOneWidget);
    expect(find.text('Tren 6 minggu terakhir'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(800, 1280), Size(1280, 800)]) {
    testWidgets(
      'tanpa overflow di ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        _setSize(tester, size);
        await tester.pumpWidget(_app());
        await tester.pumpAndSettle();

        final rail = size.width >= 600 && size.height >= 500;
        final nav = find.byType(rail ? NavigationRail : NavigationBar);
        await tester.tap(
          find.descendant(of: nav, matching: find.text('Statistik')).first,
        );
        await tester.pumpAndSettle();

        for (final kind in ['Minggu', 'Tahun', 'Bulan']) {
          await tester.tap(find.text(kind));
          await tester.pumpAndSettle();
        }
        expect(find.text('Ringkasan periode'), findsOneWidget);
      },
    );
  }
}
