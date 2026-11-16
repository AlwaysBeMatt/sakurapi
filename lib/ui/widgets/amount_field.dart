import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'rupiah_input.dart';

/// Isian nominal berformat Rupiah (1.500.000).
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        RupiahInputFormatter(),
      ],
      style: AppText.tabular(theme.textTheme.titleLarge),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        errorText: errorText,
      ),
      onChanged: onChanged,
    );
  }
}
