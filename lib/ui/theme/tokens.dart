import 'package:flutter/material.dart';

abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class Radii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
}

abstract final class AppText {
  /// Digit selebar sama supaya nominal sejajar.
  static TextStyle? tabular(TextStyle? style) =>
      style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

class Palette {
  const Palette({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.mint,
    required this.onMint,
    required this.text,
    required this.textSecondary,
    required this.income,
    required this.expense,
    required this.expenseText,
    required this.warning,
    required this.warningText,
    required this.border,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color onPrimary;
  final Color mint;
  final Color onMint;
  final Color text;
  final Color textSecondary;
  final Color income;
  final Color expense; // isian grafik/ikon
  final Color expenseText; // teks nominal, kontras >= 4.5:1
  final Color warning;
  final Color warningText;
  final Color border;
  final Color shadow;

  static const light = Palette(
    background: Color(0xFFF6F8F7),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF176B55),
    onPrimary: Color(0xFFFFFFFF),
    mint: Color(0xFFBCEBD7),
    onMint: Color(0xFF0B3D30),
    text: Color(0xFF162B25),
    textSecondary: Color(0xFF5F6F67),
    income: Color(0xFF18845B),
    expense: Color(0xFFE76F72),
    expenseText: Color(0xFFC2454A),
    warning: Color(0xFFE6A23C),
    warningText: Color(0xFF9A6312),
    border: Color(0xFFE6ECE8),
    shadow: Color(0x0F162B25),
  );

  static const dark = Palette(
    background: Color(0xFF0F1714),
    surface: Color(0xFF17221E),
    primary: Color(0xFF5CC9A0),
    onPrimary: Color(0xFF06281E),
    mint: Color(0xFF1F4A3C),
    onMint: Color(0xFFCDEFE0),
    text: Color(0xFFE6EFEA),
    textSecondary: Color(0xFF9AABA3),
    income: Color(0xFF4CC38A),
    expense: Color(0xFFF08A8D),
    expenseText: Color(0xFFF08A8D),
    warning: Color(0xFFF0B35A),
    warningText: Color(0xFFF0B35A),
    border: Color(0xFF26332E),
    shadow: Color(0x00000000),
  );
}

/// Warna khusus keuangan yang tidak ada di ColorScheme bawaan.
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.expense,
    required this.expenseText,
    required this.warning,
    required this.warningText,
    required this.mint,
    required this.onMint,
    required this.border,
    required this.shadow,
  });

  factory FinanceColors.fromPalette(Palette p) => FinanceColors(
    income: p.income,
    expense: p.expense,
    expenseText: p.expenseText,
    warning: p.warning,
    warningText: p.warningText,
    mint: p.mint,
    onMint: p.onMint,
    border: p.border,
    shadow: p.shadow,
  );

  static FinanceColors of(BuildContext context) =>
      Theme.of(context).extension<FinanceColors>()!;

  final Color income;
  final Color expense;
  final Color expenseText;
  final Color warning;
  final Color warningText;
  final Color mint;
  final Color onMint;
  final Color border;
  final Color shadow;

  @override
  FinanceColors copyWith({
    Color? income,
    Color? expense,
    Color? expenseText,
    Color? warning,
    Color? warningText,
    Color? mint,
    Color? onMint,
    Color? border,
    Color? shadow,
  }) => FinanceColors(
    income: income ?? this.income,
    expense: expense ?? this.expense,
    expenseText: expenseText ?? this.expenseText,
    warning: warning ?? this.warning,
    warningText: warningText ?? this.warningText,
    mint: mint ?? this.mint,
    onMint: onMint ?? this.onMint,
    border: border ?? this.border,
    shadow: shadow ?? this.shadow,
  );

  @override
  FinanceColors lerp(FinanceColors? other, double t) {
    if (other == null) {
      return this;
    }
    return FinanceColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseText: Color.lerp(expenseText, other.expenseText, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      onMint: Color.lerp(onMint, other.onMint, t)!,
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
