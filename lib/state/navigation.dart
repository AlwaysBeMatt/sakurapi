import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tx_filter.dart';

abstract final class ShellTab {
  static const home = 0;
  static const transactions = 1;
  static const budgets = 2;
  static const savings = 3;
  static const stats = 4;
}

/// Tab yang sedang aktif di app shell, supaya kartu di Beranda bisa berpindah tab.
class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => ShellTab.home;

  void select(int index) {
    state = index;
  }
}

final shellTabProvider = NotifierProvider<ShellTabNotifier, int>(
  ShellTabNotifier.new,
);

/// Membuka tab Transaksi dengan filter tertentu.
void showTransactionsTab(WidgetRef ref, TxFilter filter) {
  ref.read(txFilterProvider.notifier).set(filter);
  ref.read(shellTabProvider.notifier).select(ShellTab.transactions);
}
