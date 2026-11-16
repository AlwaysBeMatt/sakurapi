import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sakurapi/app.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/tx_category.dart';
import 'package:sakurapi/state/file_service.dart';
import 'package:sakurapi/state/providers.dart';

final _now = DateTime(2025, 1, 20);

class _FakeFileService implements FileService {
  _FakeFileService({this.pickResult});

  String? pickResult;
  bool saveResult = true;
  String? savedName;
  String? savedContent;

  @override
  Future<bool> saveText({
    required String fileName,
    required String content,
    String dialogTitle = 'Simpan file',
  }) async {
    savedName = fileName;
    savedContent = content;
    return saveResult;
  }

  @override
  Future<String?> pickText() async => pickResult;
}

FinanceSnapshot _snapshot({bool withDemo = false}) => FinanceSnapshot(
  accounts: [
    Account(
      id: 'acc_cash',
      name: 'Dompet Tunai',
      type: AccountType.cash,
      createdAt: _now,
    ),
    if (withDemo)
      Account(
        id: 'demo_acc_bank',
        name: 'Rekening Demo',
        type: AccountType.bank,
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
    MoneyTransaction(
      id: 't1',
      type: TransactionType.income,
      amount: 3000000,
      title: 'Gaji',
      accountId: 'acc_cash',
      categoryId: 'inc_salary',
      date: DateTime(2025, 1, 1),
      createdAt: _now,
      updatedAt: _now,
    ),
    MoneyTransaction(
      id: 't2',
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
  budgets: const [],
  goals: const [],
);

Widget _app(FileService files, {bool withDemo = false}) => ProviderScope(
  overrides: [
    clockProvider.overrideWithValue(() => _now),
    financeSnapshotProvider.overrideWith((ref) async => _snapshot(withDemo: withDemo)),
    fileServiceProvider.overrideWithValue(files),
  ],
  child: const SakuRapiApp(),
);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _openDataPage(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pengaturan'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Data dan backup'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('ekspor CSV mengirim file dengan nama dan isi yang benar', (tester) async {
    _setSize(tester, const Size(412, 915));
    final files = _FakeFileService();
    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();
    await _openDataPage(tester);

    await _tap(tester, 'Ekspor transaksi (CSV)');

    expect(files.savedName, 'sakurapi-transaksi-2025-01-20.csv');
    expect(files.savedContent, startsWith('\uFEFF'));
    expect(files.savedContent, contains('Tanggal;Jenis;Nominal'));
    expect(files.savedContent, contains('Makan siang'));
    expect(find.text('CSV disimpan (2 transaksi)'), findsOneWidget);
  });

  testWidgets('ekspor CSV dibatalkan: tidak mengaku berhasil', (tester) async {
    _setSize(tester, const Size(412, 915));
    final files = _FakeFileService()..saveResult = false;
    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();
    await _openDataPage(tester);

    await _tap(tester, 'Ekspor transaksi (CSV)');

    expect(find.text('Dibatalkan. Tidak ada file yang dibuat.'), findsOneWidget);
    expect(find.textContaining('CSV disimpan'), findsNothing);
  });

  testWidgets('pemisah koma bisa dipilih untuk CSV', (tester) async {
    _setSize(tester, const Size(412, 915));
    final files = _FakeFileService();
    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();
    await _openDataPage(tester);

    await _tap(tester, 'Koma (,)');
    await _tap(tester, 'Ekspor transaksi (CSV)');

    expect(files.savedContent, contains('Tanggal,Jenis,Nominal'));
  });

  testWidgets('pulihkan: pilihan dibatalkan', (tester) async {
    _setSize(tester, const Size(412, 915));
    final files = _FakeFileService(pickResult: null);
    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();
    await _openDataPage(tester);

    await _tap(tester, 'Pulihkan dari backup');
    expect(find.text('Pemulihan dibatalkan.'), findsOneWidget);
  });

  testWidgets('pulihkan: file bukan JSON ditolak dengan pesan jelas', (tester) async {
    _setSize(tester, const Size(412, 915));
    final files = _FakeFileService(pickResult: 'bukan json');
    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();
    await _openDataPage(tester);

    await _tap(tester, 'Pulihkan dari backup');
    expect(find.text('File bukan JSON yang valid.'), findsOneWidget);
    expect(find.text('Ganti seluruh data?'), findsNothing);
  });

  testWidgets('pulihkan: JSON lain ditolak sebagai bukan backup SakuRapi', (tester) async {
    _setSize(tester, const Size(412, 915));
    final files = _FakeFileService(pickResult: '{"a": 1}');
    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();
    await _openDataPage(tester);

    await _tap(tester, 'Pulihkan dari backup');
    expect(find.text('Ini bukan file backup SakuRapi.'), findsOneWidget);
  });

  testWidgets('tombol data demo mengikuti keberadaan akun demo', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_FakeFileService()));
    await tester.pumpAndSettle();
    await _openDataPage(tester);
    expect(find.text('Muat data demo'), findsOneWidget);
    expect(find.text('Hapus data demo'), findsNothing);
  });

  testWidgets('dengan akun demo yang aktif, tombol berubah menjadi hapus', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_FakeFileService(), withDemo: true));
    await tester.pumpAndSettle();
    await _openDataPage(tester);
    expect(find.text('Hapus data demo'), findsOneWidget);
    expect(find.text('Muat data demo'), findsNothing);
  });

  testWidgets('dialog muat data demo bisa dibatalkan', (tester) async {
    _setSize(tester, const Size(412, 915));
    await tester.pumpWidget(_app(_FakeFileService()));
    await tester.pumpAndSettle();
    await _openDataPage(tester);

    await _tap(tester, 'Muat data demo');
    expect(find.text('Muat data demo?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Muat data demo?'), findsNothing);
  });

  for (final size in const [Size(320, 568), Size(800, 1280), Size(1280, 800)]) {
    testWidgets('tanpa overflow di ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      _setSize(tester, size);
      await tester.pumpWidget(_app(_FakeFileService()));
      await tester.pumpAndSettle();
      await _openDataPage(tester);
      expect(find.text('Backup'), findsOneWidget);

      Navigator.of(tester.element(find.text('Backup'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tampilan dan anggaran'));
      await tester.pumpAndSettle();
      expect(find.text('Tema'), findsOneWidget);
    });
  }
}