import '../core/dates.dart';
import 'models/account.dart';
import 'models/money_transaction.dart';
import 'models/tx_category.dart';

/// Ekspor transaksi ke CSV. Fungsi murni.
abstract final class CsvExport {
  static const header = [
    'Tanggal',
    'Jenis',
    'Nominal',
    'Nama',
    'Kategori',
    'Akun',
    'Akun tujuan',
    'Catatan',
  ];

  /// [delimiter] ';' cocok untuk Excel versi Indonesia, ',' untuk Google Sheets.
  static String transactions(
    Iterable<MoneyTransaction> txs, {
    required Map<String, Account> accounts,
    required Map<String, TxCategory> categories,
    String delimiter = ';',
  }) {
    final lines = <String>[_line(header, delimiter)];
    for (final t in txs) {
      lines.add(
        _line([
          toDbDate(t.date),
          _typeLabel(t.type),
          t.amount.toString(),
          _safe(t.title),
          _safe(categories[t.categoryId]?.name ?? ''),
          _safe(accounts[t.accountId]?.name ?? ''),
          _safe(accounts[t.toAccountId]?.name ?? ''),
          _safe(t.note ?? ''),
        ], delimiter),
      );
    }
    return '${lines.join('\r\n')}\r\n';
  }

  static String _typeLabel(TransactionType t) => switch (t) {
    TransactionType.income => 'Pemasukan',
    TransactionType.expense => 'Pengeluaran',
    TransactionType.transfer => 'Transfer',
  };

  /// Teks yang diawali = + - @ bisa dibaca Excel sebagai rumus, jadi diberi
  /// tanda petik di depan.
  static String _safe(String s) {
    if (s.isNotEmpty && '=+-@\t\r'.contains(s[0])) {
      return "'$s";
    }
    return s;
  }

  static String _quote(String s, String delimiter) {
    if (s.contains(delimiter) ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String _line(List<String> cells, String delimiter) =>
      cells.map((c) => _quote(c, delimiter)).join(delimiter);
}