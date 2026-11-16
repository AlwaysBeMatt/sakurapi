import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Palette.light, Brightness.light);
  static ThemeData dark() => _build(Palette.dark, Brightness.dark);

  static ThemeData _build(Palette p, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: p.primary,
          brightness: brightness,
        ).copyWith(
          primary: p.primary,
          onPrimary: p.onPrimary,
          primaryContainer: p.mint,
          onPrimaryContainer: p.onMint,
          secondaryContainer: p.mint,
          onSecondaryContainer: p.onMint,
          surface: p.surface,
          onSurface: p.text,
          onSurfaceVariant: p.textSecondary,
          outline: p.textSecondary,
          outlineVariant: p.border,
          error: p.expenseText,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
    );
    final text = base.textTheme.apply(bodyColor: p.text, displayColor: p.text);
    final radius = BorderRadius.circular(Radii.sm);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: AppText.tabular(
          text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.mint,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.mint,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: inputBorder(p.border),
        enabledBorder: inputBorder(p.border),
        focusedBorder: inputBorder(p.primary, 1.5),
        errorBorder: inputBorder(p.expenseText),
        focusedErrorBorder: inputBorder(p.expenseText, 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      extensions: [FinanceColors.fromPalette(p)],
    );
  }
}
