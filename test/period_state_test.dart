import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakurapi/core/dates.dart';
import 'package:sakurapi/state/navigation.dart';
import 'package:sakurapi/state/period_state.dart';
import 'package:sakurapi/state/providers.dart';

void main() {
  final today = DateTime(2025, 1, 20); // Senin

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [clockProvider.overrideWithValue(() => today)],
  );

  test('awalnya bulan ini', () {
    final c = makeContainer();
    addTearDown(c.dispose);
    expect(c.read(periodProvider).kind, PeriodKind.month);
    expect(c.read(periodProvider).label, 'Januari 2025');
  });

  test('ganti ke minggu, maju, lalu kembali ke minggu ini', () {
    final c = makeContainer();
    addTearDown(c.dispose);
    final n = c.read(periodProvider.notifier);

    n.setKind(PeriodKind.week);
    expect(c.read(periodProvider).label, '20 – 26 Jan 2025');
    n.next();
    expect(c.read(periodProvider).label, '27 Jan – 2 Feb 2025');
    n.reset();
    expect(c.read(periodProvider).label, '20 – 26 Jan 2025');
  });

  test('ganti jenis dari periode lampau tetap di sekitar periode itu', () {
    final c = makeContainer();
    addTearDown(c.dispose);
    final n = c.read(periodProvider.notifier);

    n.previous(); // Desember 2024
    n.setKind(PeriodKind.week);
    expect(c.read(periodProvider).label, '30 Des 2024 – 5 Jan 2025');

    n.setKind(PeriodKind.year);
    expect(c.read(periodProvider).label, '2025');
  });

  test('tab shell dapat dipilih', () {
    final c = makeContainer();
    addTearDown(c.dispose);
    expect(c.read(shellTabProvider), ShellTab.home);
    c.read(shellTabProvider.notifier).select(ShellTab.transactions);
    expect(c.read(shellTabProvider), 1);
  });
}
