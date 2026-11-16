import 'package:flutter/services.dart';

import '../../core/money.dart';

/// Memformat ketikan menjadi 1.500.000 dan membatasi 15 digit.
/// Kursor selalu berada di akhir teks.
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }
    final trimmed = digits.length > 15 ? digits.substring(0, 15) : digits;
    final text = Money.formatPlain(int.parse(trimmed));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
