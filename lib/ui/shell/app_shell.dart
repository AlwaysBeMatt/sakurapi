import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/navigation.dart';
import '../layout/app_layout.dart';
import '../pages/budgets_page.dart';
import '../pages/home_page.dart';
import '../pages/savings_page.dart';
import '../pages/stats_page.dart';
import '../pages/transaction_form_page.dart';
import '../pages/transactions_page.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Beranda', Icons.home_outlined, Icons.home),
  _Destination('Transaksi', Icons.receipt_long_outlined, Icons.receipt_long),
  _Destination('Anggaran', Icons.pie_chart_outline, Icons.pie_chart),
  _Destination('Tabungan', Icons.savings_outlined, Icons.savings),
  _Destination('Statistik', Icons.insights_outlined, Icons.insights),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    final index = ref.watch(shellTabProvider);
    void select(int i) => ref.read(shellTabProvider.notifier).select(i);

    // IndexedStack menjaga posisi scroll dan state setiap tab.
    final pages = IndexedStack(
      index: index,
      children: const [
        HomePage(),
        TransactionsPage(),
        BudgetsPage(),
        SavingsPage(),
        StatsPage(),
      ],
    );

    // Tab Anggaran dan Tabungan punya tombol tambah sendiri di halamannya.
    final fab = index <= ShellTab.transactions
        ? FloatingActionButton.extended(
            tooltip: 'Tambah transaksi',
            onPressed: () => openTransactionForm(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Tambah'),
          )
        : null;

    if (AppLayout.useRail(size)) {
      final extended = AppLayout.extendedRail(size);
      return Scaffold(
        floatingActionButton: fab,
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                extended: extended,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedIndex: index,
                onDestinationSelected: select,
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages),
          ],
        ),
      );
    }

    return Scaffold(
      body: pages,
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
