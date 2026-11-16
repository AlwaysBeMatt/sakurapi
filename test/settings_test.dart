import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sakurapi/app.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/state/providers.dart';
import 'package:sakurapi/state/settings.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('AppSettings.load', () {
    test('nilai awal', () {
      final s = AppSettings.load(MemorySettingsStore());
      expect(s.themeMode, ThemeMode.system);
      expect(s.cautionPercent, 75);
      expect(s.warningPercent, 90);
    });

    test('nilai tersimpan dibaca kembali', () async {
      final store = MemorySettingsStore();
      await store.setString(AppSettings.themeKey, 'dark');
      await store.setInt(AppSettings.cautionKey, 60);
      await store.setInt(AppSettings.warningKey, 85);
      final s = AppSettings.load(store);
      expect(s.themeMode, ThemeMode.dark);
      expect(s.cautionPercent, 60);
      expect(s.warningPercent, 85);
    });

    test('nilai rusak kembali ke bawaan', () async {
      final store = MemorySettingsStore();
      await store.setString(AppSettings.themeKey, 'neon');
      await store.setInt(AppSettings.cautionKey, 95);
      await store.setInt(AppSettings.warningKey, 50);
      final s = AppSettings.load(store);
      expect(s.themeMode, ThemeMode.system);
      expect(s.cautionPercent, 75);
      expect(s.warningPercent, 90);
    });
  });

  test('notifier menyimpan tema dan ambang, menolak nilai tidak masuk akal', () async {
    final store = MemorySettingsStore();
    final container = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);

    await notifier.setThemeMode(ThemeMode.dark);
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
    expect(store.getString(AppSettings.themeKey), 'dark');

    await notifier.setThresholds(caution: 60, warning: 80);
    expect(container.read(budgetThresholdsProvider).caution, 60);
    expect(container.read(budgetThresholdsProvider).warning, 80);
    expect(store.getInt(AppSettings.cautionKey), 60);
    expect(store.getInt(AppSettings.warningKey), 80);

    await notifier.setThresholds(caution: 90, warning: 80); // terbalik
    expect(container.read(settingsProvider).cautionPercent, 60);
    expect(container.read(settingsProvider).warningPercent, 80);
  });

  testWidgets('memilih tema Gelap mengubah themeMode aplikasi', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime(2025, 1, 20);
    final snapshot = FinanceSnapshot(
      accounts: [
        Account(
          id: 'acc_cash',
          name: 'Dompet Tunai',
          type: AccountType.cash,
          createdAt: now,
        ),
      ],
      categories: const [],
      transactions: const [],
      budgets: const [],
      goals: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          financeSnapshotProvider.overrideWith((ref) async => snapshot),
        ],
        child: const SakuRapiApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tampilan dan anggaran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });
}