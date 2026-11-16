import 'package:intl/intl.dart';

/// Nominal Rupiah selalu disimpan sebagai int (rupiah utuh, tanpa sen).
abstract final class Money {
  /// 15 digit: aman untuk int 64-bit dan presisi double di web.
  static const int maxAmount = 999999999999999;

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  static final NumberFormat _plain = NumberFormat.decimalPattern('id_ID');

  /// 25000 -> "Rp25.000".
  static String format(int amount) => _currency.format(amount);

  /// 1500000 -> "1.500.000" (untuk isi field input).
  static String formatPlain(int amount) => _plain.format(amount);

  /// Mengurai "1.500.000" atau "Rp1.500.000". Menolak minus, desimal,
  /// karakter lain, dan nilai di atas [maxAmount]. Mengembalikan null jika tidak valid.
  static int? tryParse(String input) {
    final cleaned = input
        .trim()
        .replaceFirst(RegExp(r'^rp\s*', caseSensitive: false), '')
        .replaceAll('.', '')
        .replaceAll(' ', '');
    if (cleaned.isEmpty || !RegExp(r'^\d{1,15}$').hasMatch(cleaned)) {
      return null;
    }
    final value = int.parse(cleaned);
    return value > maxAmount ? null : value;
  }
}
