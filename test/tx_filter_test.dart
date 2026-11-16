import 'package:flutter_test/flutter_test.dart';
import 'package:sakurapi/data/finance_repository.dart' show TransactionSort;
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/state/tx_filter.dart';

final _t0 = DateTime(2025, 1, 1);

MoneyTransaction _tx(
  String id,
  TransactionType type,
  int amount,
  DateTime date, {
  String title = '',
  String? note,
  String account = 'cash',
  String? category,
  String? to,
}) => MoneyTransaction(
  id: id,
  type: type,
  amount: amount,
  title: title,
  note: note,
  accountId: account,
  categoryId: category,
  toAccountId: to,
  date: date,
  createdAt: _t0,
  updatedAt: _t0,
);

void main() {
  final all = [
    _tx(
      'a',
      TransactionType.expense,
      25000,
      DateTime(2025, 1, 5),
      title: 'Kopi susu',
      category: 'exp_food',
    ),
    _tx(
      'b',
      TransactionType.expense,
      300000,
      DateTime(2025, 1, 10),
      title: 'Bensin',
      note: 'isi penuh',
      category: 'exp_transport',
    ),
    _tx(
      'c',
      TransactionType.income,
      3000000,
      DateTime(2025, 1, 1),
      title: 'Gaji',
      category: 'inc_salary',
      account: 'bank',
    ),
    _tx(
      'd',
      TransactionType.transfer,
      500000,
      DateTime(2025, 1, 12),
      account: 'bank',
      to: 'cash',
    ),
  ];

  List<String> ids(TxFilter f) => f.apply(all).map((t) => t.id).toList();

  test('tanpa filter: terbaru dulu', () {
    expect(ids(const TxFilter()), ['d', 'b', 'a', 'c']);
  });

  test('urutan terlama dan nominal', () {
    expect(ids(const TxFilter(sort: TransactionSort.oldest)), [
      'c',
      'a',
      'b',
      'd',
    ]);
    expect(ids(const TxFilter(sort: TransactionSort.largest)), [
      'c',
      'd',
      'b',
      'a',
    ]);
    expect(ids(const TxFilter(sort: TransactionSort.smallest)), [
      'a',
      'b',
      'd',
      'c',
    ]);
  });

  test('cari di nama dan catatan, tanpa membedakan huruf besar', () {
    expect(ids(const TxFilter(query: 'KOPI')), ['a']);
    expect(ids(const TxFilter(query: 'penuh')), ['b']);
    expect(ids(const TxFilter(query: 'tidak ada')), isEmpty);
  });

  test('filter jenis, kategori, akun, dan tanggal', () {
    expect(ids(const TxFilter(types: {TransactionType.expense})), ['b', 'a']);
    expect(ids(const TxFilter(categoryIds: {'exp_food'})), ['a']);
    // akun "cash" ikut mencakup transfer yang tujuannya cash
    expect(ids(const TxFilter(accountId: 'cash')), ['d', 'b', 'a']);
    expect(
      ids(TxFilter(from: DateTime(2025, 1, 5), to: DateTime(2025, 1, 10))),
      ['b', 'a'],
    );
  });

  test('filter digabung dan activeCount', () {
    final f = TxFilter(
      types: const {TransactionType.expense},
      accountId: 'cash',
      from: DateTime(2025, 1, 6),
      to: DateTime(2025, 1, 31),
    );
    expect(ids(f), ['b']);
    expect(f.activeCount, 3);
    expect(const TxFilter(query: 'x').activeCount, 0);
    expect(const TxFilter(query: 'x').isFiltering, isTrue);
  });
}
