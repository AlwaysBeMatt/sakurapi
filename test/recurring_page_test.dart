import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sakurapi/app.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/recurring_rule.dart';
import 'package:sakurapi/domain/models/tx_category.dart';
import 'package:sakurapi/state/providers.dart';

final _now = DateTime(2025, 1, 20);

RecurringRule _rule({
  String id = 'r1',
  String title = 'Gaji bulanan',
  int amount = 4000000,
  bool active = true,
  DateTime? end,
  DateTime? next,
}) => RecurringRule(
  id: id,
  type: TransactionType.income,
  amount: amount,
  title: title,
  categoryId: 'inc_salary',
  accountId: 'acc_cash',
  frequency: RecurrenceFrequency.monthly,
  startDate: DateTime(2025, 1, 5),
  nextDate: next ?? DateTime(2025, 2, 5),
  endDate: end,
  active: active,
  createdAt: _now,
);

FinanceSnapshot _snapshot(List<RecurringRule> rules) => FinanceSnapshot(
  accounts: [
    Account(id: 'acc_cash', name: 'Dompet Tunai', type: AccountType.cash, createdAt: _now),
  ],
  categories: const [
    TxCategory(
      id: 'inc_salary',
      name: 'Gaji / Penghasilan',
      kind: CategoryKind.income,
      iconKey: 'work',
      color: 0xFF176B55,
      isDefault: true,
    ),
    TxCategory(
      id: 'exp_food',
      name: 'Makanan & Minuman',
      kind: CategoryKind.expense,
      iconKey: 'restaurant',
      color: 0xFFE76F72,
      isDefault: true,
    ),
  ],
  transactions: const [],
  budgets: const [],
  goals: const [],
  recurringRules: rules,
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

Future<void> _openRecurring(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pengaturan'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Transaksi berulang'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Pengaturan menampilkan jumlah aturan yang aktif', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(
      _app(_snapshot([_rule(), _rule(id: 'r2', active: false)])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.text('1 aktif'), findsOneWidget);
  });

  testWidgets('daftar menampilkan frekuensi, nominal, dan tanggal berikutnya', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot([_rule()])));
    await tester.pumpAndSettle();
    await _openRecurring(tester);

    expect(find.text('Gaji bulanan'), findsOneWidget);
    expect(find.text('Bulanan · Rp4.000.000'), findsOneWidget);
    expect(find.text('Berikutnya 5 Feb 2025 · Dompet Tunai'), findsOneWidget);
  });

  testWidgets('aturan yang dijeda dan selesai diberi label', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(
      _app(
        _snapshot([
          _rule(id: 'paused', title: 'Dijeda', active: false),
          _rule(
            id: 'done',
            title: 'Selesai',
            active: false,
            end: DateTime(2025, 1, 31),
            next: DateTime(2025, 2, 5),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await _openRecurring(tester);

    expect(find.text('Dijeda · Dompet Tunai'), findsOneWidget);
    expect(find.text('Selesai · Dompet Tunai'), findsOneWidget);
  });

  testWidgets('belum ada aturan: tampil empty state', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot(const [])));
    await tester.pumpAndSettle();
    await _openRecurring(tester);

    expect(find.text('Belum ada transaksi berulang'), findsOneWidget);
    expect(find.text('Buat transaksi berulang'), findsOneWidget);
  });

  testWidgets('form menolak nominal kosong dan kategori kosong', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot(const [])));
    await tester.pumpAndSettle();
    await _openRecurring(tester);

    await tester.tap(find.byTooltip('Tambah transaksi berulang'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah transaksi berulang'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan nominal yang valid (lebih dari Rp0).'), findsOneWidget);
    expect(find.text('Pilih kategori.'), findsOneWidget);
  });

  testWidgets('mengubah aturan: jenis dan frekuensi dikunci', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_snapshot([_rule()])));
    await tester.pumpAndSettle();
    await _openRecurring(tester);

    await tester.tap(find.text('Gaji bulanan'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah transaksi berulang'), findsOneWidget);
    expect(find.textContaining('tidak bisa diubah'), findsOneWidget);
    expect(find.text('Jeda'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(800, 1280)]) {
    testWidgets('form tanpa overflow di ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      _setSize(tester, size);
      await tester.pumpWidget(_app(_snapshot(const [])));
      await tester.pumpAndSettle();
      await _openRecurring(tester);
      await tester.tap(find.byTooltip('Tambah transaksi berulang'));
      await tester.pumpAndSettle();
      expect(find.text('Tambah transaksi berulang'), findsOneWidget);
    });
  }
}