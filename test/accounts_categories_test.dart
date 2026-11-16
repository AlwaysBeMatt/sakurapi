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

FinanceSnapshot _snapshot() => FinanceSnapshot(
  accounts: [
    Account(
      id: 'acc_cash',
      name: 'Dompet Tunai',
      type: AccountType.cash,
      createdAt: _now,
    ),
    Account(
      id: 'bca',
      name: 'BCA',
      type: AccountType.bank,
      initialBalance: 1000000,
      createdAt: _now,
    ),
    Account(
      id: 'old',
      name: 'Dana Lama',
      type: AccountType.ewallet,
      createdAt: _now,
      archived: true,
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
    TxCategory(
      id: 'exp_kopi',
      name: 'Kopi',
      kind: CategoryKind.expense,
      iconKey: 'restaurant',
      color: 0xFFE6A23C,
    ),
  ],
  transactions: [
    MoneyTransaction(
      id: 't1',
      type: TransactionType.expense,
      amount: 20000,
      accountId: 'acc_cash',
      categoryId: 'exp_kopi',
      date: DateTime(2025, 1, 5),
      createdAt: _now,
      updatedAt: _now,
    ),
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

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pengaturan'));
  await tester.pumpAndSettle();
}

Future<void> _openAccounts(WidgetTester tester) async {
  await _openSettings(tester);
  await tester.tap(find.text('Akun'));
  await tester.pumpAndSettle();
}

Future<void> _openCategories(WidgetTester tester) async {
  await _openSettings(tester);
  await tester.tap(find.text('Kategori'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Pengaturan dibuka dari Beranda dan menampilkan ringkasan', (
    tester,
  ) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('2 akun aktif · 1 diarsipkan'), findsOneWidget);
    expect(find.text('2 pengeluaran · 1 pemasukan'), findsOneWidget);
  });

  testWidgets('halaman Akun menampilkan akun aktif, saldo, dan arsip', (
    tester,
  ) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openAccounts(tester);

    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('Rp1.000.000'), findsOneWidget);
    expect(
      find.text('-Rp20.000'),
      findsOneWidget,
    ); // dompet setelah pengeluaran
    expect(find.text('Diarsipkan'), findsOneWidget);
    expect(find.text('Dana Lama'), findsOneWidget);
  });

  testWidgets('form akun menolak nama kosong dan nama kembar', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openAccounts(tester);

    await tester.tap(find.byTooltip('Tambah akun'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah akun'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Nama akun wajib diisi.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'bca');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Nama akun sudah dipakai.'), findsOneWidget);
  });

  testWidgets('akun dengan saldo tidak bisa diarsipkan', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openAccounts(tester);

    await tester.tap(find.text('BCA'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah akun'), findsOneWidget);

    await tester.tap(find.text('Arsipkan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saldo akun harus Rp0'), findsOneWidget);
  });

  testWidgets('halaman Kategori memisahkan pengeluaran dan pemasukan', (
    tester,
  ) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openCategories(tester);

    expect(find.text('Makanan & Minuman'), findsOneWidget);
    expect(find.text('Bawaan · Belum dipakai'), findsOneWidget);
    expect(find.text('Kopi'), findsOneWidget);
    expect(find.text('1 transaksi'), findsOneWidget);

    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();
    expect(find.text('Gaji / Penghasilan'), findsOneWidget);
    expect(find.text('Kopi'), findsNothing);
  });

  testWidgets('form kategori menolak nama kosong', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openCategories(tester);

    await tester.tap(find.byTooltip('Tambah kategori'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah kategori pengeluaran'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Nama kategori wajib diisi.'), findsOneWidget);
  });

  testWidgets(
    'kategori bawaan tidak punya tombol hapus, buatan sendiri punya',
    (tester) async {
      _setSize(tester, const Size(412, 915));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _openCategories(tester);

      await tester.tap(find.text('Makanan & Minuman'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nama kategori bawaan tidak bisa diubah.'),
        findsOneWidget,
      );
      expect(find.text('Hapus kategori'), findsNothing);

      Navigator.of(tester.element(find.text('Simpan'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kopi'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus kategori'), findsOneWidget);
    },
  );

  for (final size in const [Size(320, 568), Size(800, 1280), Size(1280, 800)]) {
    testWidgets(
      'tanpa overflow di ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        _setSize(tester, size);
        await tester.pumpWidget(_app());
        await tester.pumpAndSettle();
        await _openAccounts(tester);

        await tester.tap(find.byTooltip('Tambah akun'));
        await tester.pumpAndSettle();
        expect(find.text('Tambah akun'), findsOneWidget);
      },
    );
  }
}
