import 'package:flutter_test/flutter_test.dart';
import 'package:sakurapi/domain/csv_export.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/tx_category.dart';

final _t0 = DateTime(2025, 1, 1);

MoneyTransaction _tx({
  required TransactionType type,
  required int amount,
  String title = '',
  String? note,
  String? category,
  String account = 'cash',
  String? to,
}) => MoneyTransaction(
  id: '$type-$amount-$title',
  type: type,
  amount: amount,
  title: title,
  note: note,
  categoryId: category,
  accountId: account,
  toAccountId: to,
  date: DateTime(2025, 1, 5),
  createdAt: _t0,
  updatedAt: _t0,
);

void main() {
  final accounts = {
    'cash': Account(id: 'cash', name: 'Dompet', type: AccountType.cash, createdAt: _t0),
    'sav': Account(id: 'sav', name: 'Tabungan', type: AccountType.savings, createdAt: _t0),
  };
  const categories = {
    'exp_food': TxCategory(
      id: 'exp_food',
      name: 'Makanan & Minuman',
      kind: CategoryKind.expense,
      iconKey: 'restaurant',
      color: 0xFFE76F72,
    ),
  };

  List<String> lines(String csv) => csv.trim().split('\r\n');

  test('header dan satu baris pengeluaran', () {
    final csv = CsvExport.transactions(
      [
        _tx(
          type: TransactionType.expense,
          amount: 250000,
          title: 'Makan siang',
          category: 'exp_food',
        ),
      ],
      accounts: accounts,
      categories: categories,
    );
    final l = lines(csv);
    expect(l[0], 'Tanggal;Jenis;Nominal;Nama;Kategori;Akun;Akun tujuan;Catatan');
    expect(l[1], '2025-01-05;Pengeluaran;250000;Makan siang;Makanan & Minuman;Dompet;;');
    expect(csv.endsWith('\r\n'), isTrue);
  });

  test('transfer menampilkan akun tujuan dan tanpa kategori', () {
    final csv = CsvExport.transactions(
      [_tx(type: TransactionType.transfer, amount: 500000, to: 'sav')],
      accounts: accounts,
      categories: categories,
    );
    expect(lines(csv)[1], '2025-01-05;Transfer;500000;;;Dompet;Tabungan;');
  });

  test('pemisah, tanda kutip, dan baris baru dikutip dengan benar', () {
    final csv = CsvExport.transactions(
      [
        _tx(
          type: TransactionType.expense,
          amount: 1000,
          title: 'Kopi; susu',
          note: 'kata "enak"\nlagi',
          category: 'exp_food',
        ),
      ],
      accounts: accounts,
      categories: categories,
    );
    expect(csv, contains('"Kopi; susu"'));
    expect(csv, contains('"kata ""enak""\nlagi"'));
  });

  test('pemisah koma dipakai bila diminta', () {
    final csv = CsvExport.transactions(
      [_tx(type: TransactionType.expense, amount: 1000, title: 'Kopi', category: 'exp_food')],
      accounts: accounts,
      categories: categories,
      delimiter: ',',
    );
    expect(lines(csv)[0], startsWith('Tanggal,Jenis,Nominal'));
  });

  test('teks yang diawali rumus diberi tanda petik', () {
    final csv = CsvExport.transactions(
      [
        _tx(type: TransactionType.expense, amount: 1000, title: '=1+1', category: 'exp_food'),
        _tx(type: TransactionType.expense, amount: 2000, title: '-10% diskon', category: 'exp_food'),
        _tx(type: TransactionType.expense, amount: 3000, title: '@admin', category: 'exp_food'),
      ],
      accounts: accounts,
      categories: categories,
    );
    expect(csv, contains(";'=1+1;"));
    expect(csv, contains(";'-10% diskon;"));
    expect(csv, contains(";'@admin;"));
  });

  test('tanpa transaksi hanya berisi header', () {
    final csv = CsvExport.transactions(const [], accounts: accounts, categories: categories);
    expect(lines(csv), hasLength(1));
  });
}