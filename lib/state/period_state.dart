import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import 'providers.dart';
import 'settings.dart';

const _kindKey = 'period_kind';

/// Periode yang sedang ditampilkan di Beranda dan Statistik. Jenisnya
/// (minggu, bulan, tahun) diingat setelah aplikasi ditutup.
class PeriodNotifier extends Notifier<Period> {
  @override
  Period build() {
    final saved = ref.read(settingsStoreProvider).getString(_kindKey);
    final kind =
        PeriodKind.values.where((k) => k.name == saved).firstOrNull ??
        PeriodKind.month;
    return Period.containing(kind, ref.read(clockProvider)());
  }

  DateTime get _today => ref.read(clockProvider)();

  /// Berpindah jenis periode sambil tetap di sekitar tanggal yang sedang dilihat.
  void setKind(PeriodKind kind) {
    if (kind == state.kind) {
      return;
    }
    state = Period.containing(kind, state.referenceDate(_today));
    unawaited(ref.read(settingsStoreProvider).setString(_kindKey, kind.name));
  }

  void previous() {
    state = state.previous;
  }

  void next() {
    state = state.next;
  }

  void reset() {
    state = Period.containing(state.kind, _today);
  }
}

final periodProvider = NotifierProvider<PeriodNotifier, Period>(
  PeriodNotifier.new,
);