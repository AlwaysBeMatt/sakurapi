import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakurapi/core/dates.dart';
import 'package:sakurapi/state/period_state.dart';
import 'package:sakurapi/state/providers.dart';
import 'package:sakurapi/state/settings.dart';

void main() {
  final today = DateTime(2025, 1, 20);

  ProviderContainer make(SettingsStore store) => ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(() => today),
      settingsStoreProvider.overrideWithValue(store),
    ],
  );

  test('tanpa pilihan tersimpan: bulan ini', () {
    final c = make(MemorySettingsStore());
    addTearDown(c.dispose);
    expect(c.read(periodProvider).kind, PeriodKind.month);
  });

  test('jenis periode tersimpan dipakai saat aplikasi dibuka kembali', () async {
    final store = MemorySettingsStore();
    await store.setString('period_kind', 'week');
    final c = make(store);
    addTearDown(c.dispose);
    expect(c.read(periodProvider).kind, PeriodKind.week);
    expect(c.read(periodProvider).label, '20 – 26 Jan 2025');
  });

  test('mengganti jenis periode menyimpannya', () {
    final store = MemorySettingsStore();
    final c = make(store);
    addTearDown(c.dispose);

    c.read(periodProvider.notifier).setKind(PeriodKind.year);
    expect(store.getString('period_kind'), 'year');
  });

  test('nilai tersimpan yang rusak kembali ke bulan', () async {
    final store = MemorySettingsStore();
    await store.setString('period_kind', 'dekade');
    final c = make(store);
    addTearDown(c.dispose);
    expect(c.read(periodProvider).kind, PeriodKind.month);
  });
}