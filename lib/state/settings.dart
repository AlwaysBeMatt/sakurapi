import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/budget_calculator.dart';

/// Penyimpanan pengaturan ringan. Implementasi nyata ada di
/// data/prefs_settings_store.dart, dan di test dipakai versi memori.
abstract class SettingsStore {
  String? getString(String key);
  int? getInt(String key);
  Future<void> setString(String key, String value);
  Future<void> setInt(String key, int value);
}

class MemorySettingsStore implements SettingsStore {
  final _values = <String, Object>{};

  @override
  String? getString(String key) {
    final v = _values[key];
    return v is String ? v : null;
  }

  @override
  int? getInt(String key) {
    final v = _values[key];
    return v is int ? v : null;
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.cautionPercent = defaultCaution,
    this.warningPercent = defaultWarning,
  });

  static const themeKey = 'theme_mode';
  static const cautionKey = 'budget_caution';
  static const warningKey = 'budget_warning';
  static const defaultCaution = 75;
  static const defaultWarning = 90;

  final ThemeMode themeMode;
  final int cautionPercent;
  final int warningPercent;

  /// Nilai yang rusak atau tidak masuk akal diganti nilai bawaan.
  factory AppSettings.load(SettingsStore store) {
    final saved = store.getString(themeKey);
    final mode =
        ThemeMode.values.where((m) => m.name == saved).firstOrNull ??
        ThemeMode.system;
    var caution = store.getInt(cautionKey) ?? defaultCaution;
    var warning = store.getInt(warningKey) ?? defaultWarning;
    if (caution < 1 || warning > 99 || caution >= warning) {
      caution = defaultCaution;
      warning = defaultWarning;
    }
    return AppSettings(
      themeMode: mode,
      cautionPercent: caution,
      warningPercent: warning,
    );
  }

  BudgetThresholds get thresholds =>
      BudgetThresholds(caution: cautionPercent, warning: warningPercent);

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? cautionPercent,
    int? warningPercent,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    cautionPercent: cautionPercent ?? this.cautionPercent,
    warningPercent: warningPercent ?? this.warningPercent,
  );
}

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => MemorySettingsStore(),
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.load(ref.read(settingsStoreProvider));

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref
        .read(settingsStoreProvider)
        .setString(AppSettings.themeKey, mode.name);
  }

  /// Mengabaikan nilai yang tidak masuk akal (perhatian harus di bawah hampir habis).
  Future<void> setThresholds({
    required int caution,
    required int warning,
  }) async {
    if (caution < 1 || warning > 99 || caution >= warning) {
      return;
    }
    state = state.copyWith(cautionPercent: caution, warningPercent: warning);
    final store = ref.read(settingsStoreProvider);
    await store.setInt(AppSettings.cautionKey, caution);
    await store.setInt(AppSettings.warningKey, warning);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

final budgetThresholdsProvider = Provider<BudgetThresholds>(
  (ref) => ref.watch(settingsProvider).thresholds,
);