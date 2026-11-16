import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/finance_calculator.dart';
import '../../domain/models/account.dart';
import '../../domain/models/money_transaction.dart';
import '../../domain/period_report.dart';
import '../../state/navigation.dart';
import '../../state/period_state.dart';
import '../../state/providers.dart';
import '../../state/tx_filter.dart';
import '../layout/app_layout.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/category_donut.dart';
import '../widgets/empty_state.dart';
import '../widgets/income_expense_chart.dart';
import '../widgets/period_selector.dart';
import 'home_extra_cards.dart';
import 'settings_page.dart';

final _percent = NumberFormat('#,##0.#', 'id_ID');

IconData _accountIcon(AccountType type) => switch (type) {
  AccountType.cash => Icons.payments_outlined,
  AccountType.bank => Icons.account_balance_outlined,
  AccountType.ewallet => Icons.account_balance_wallet_outlined,
  AccountType.savings => Icons.savings_outlined,
};

List<Widget> _spaced(List<Widget> items) => [
  for (var i = 0; i < items.length; i++) ...[
    if (i > 0) const SizedBox(height: Space.lg),
    items[i],
  ],
];

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(financeSnapshotProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => openSettings(context),
          ),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: EmptyState(
              icon: Icons.error_outline,
              title: 'Data gagal dimuat',
              message: 'Terjadi kesalahan saat membaca penyimpanan. Coba muat ulang.',
              actionLabel: 'Coba lagi',
              onAction: () => ref.invalidate(financeSnapshotProvider),
            ),
          ),
        ),
        data: (data) => _HomeContent(data: data),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.data});
  final FinanceSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodProvider);
    final today = ref.watch(clockProvider)();
    final txs = data.transactions;
    final noun = period.kind.noun;

    final current = FinanceCalculator.summarize(txs, period.range);
    final previous = FinanceCalculator.summarize(txs, period.previous.range);
    final month = MonthRef.of(period.referenceDate(today));
    final periodFilter = TxFilter(from: period.start, to: period.end);
    final categoryTotals = FinanceCalculator.expenseByCategory(
      txs,
      period.range,
    );

    final balance = _BalanceCard(data: data);
    final summary = _PeriodSummaryCard(
      kind: period.kind,
      current: current,
      previous: previous,
      onTap: () => showTransactionsTab(ref, periodFilter),
    );
    final Widget? empty = current.isEmpty
        ? _NoTransactionsCard(hasAny: data.hasTransactions, noun: noun)
        : null;
    final Widget? chart = current.isEmpty
        ? null
        : _ChartCard(
            buckets: PeriodReport.buckets(txs, period),
            onTap: () => showTransactionsTab(ref, periodFilter),
          );
    final Widget? categories = categoryTotals.isEmpty
        ? null
        : _CategoryCard(
            data: data,
            totals: categoryTotals,
            onCategoryTap: (id) => showTransactionsTab(
              ref,
              TxFilter(
                types: const {TransactionType.expense},
                categoryIds: {id},
                from: period.start,
                to: period.end,
              ),
            ),
          );
    final budget = BudgetSummaryCard(data: data, month: month);
    final savings = SavingsSummaryCard(data: data, today: today);
    final Widget? recent = data.hasTransactions
        ? RecentTransactionsCard(data: data)
        : null;
    final accounts = _AccountsCard(data: data);

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns =
              constraints.maxWidth >= AppLayout.twoColumnMinWidth;

          final Widget cards;
          if (twoColumns) {
            final left = <Widget>[
              balance,
              summary,
              if (empty != null) empty,
              if (chart != null) chart,
              if (recent != null) recent,
            ];
            final right = <Widget>[
              if (categories != null) categories,
              budget,
              savings,
              accounts,
            ];
            cards = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _spaced(left),
                  ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _spaced(right),
                  ),
                ),
              ],
            );
          } else {
            cards = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _spaced([
                balance,
                summary,
                if (empty != null) empty,
                if (chart != null) chart,
                if (categories != null) categories,
                budget,
                savings,
                if (recent != null) recent,
                accounts,
              ]),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              Space.lg,
              96,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.contentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PeriodSelector(),
                    const SizedBox(height: Space.lg),
                    cards,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.data});
  final FinanceSnapshot data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final activeCount = data.accounts.where((a) => !a.archived).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total saldo',
            style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
          ),
          const SizedBox(height: Space.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(data.totalBalance),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: data.totalBalance < 0 ? colors.expenseText : null,
              ),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Dari $activeCount akun',
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard({
    required this.kind,
    required this.current,
    required this.previous,
    required this.onTap,
  });

  final PeriodKind kind;
  final PeriodSummary current;
  final PeriodSummary previous;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final net = current.net;
    final ratio = current.savingsRatioPercent;
    final noun = kind.noun;

    String? savingsDetail;
    if (ratio != null) {
      savingsDetail = '${_percent.format(ratio)}% dari pemasukan';
    } else if (current.savingsContribution != 0) {
      savingsDetail = 'Belum ada pemasukan di $noun ini';
    }

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ringkasan $noun',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          _SummaryRow(
            icon: Icons.south_west,
            iconColor: colors.income,
            label: 'Pemasukan',
            amount: current.income,
            amountColor: colors.income,
            detail: _ChangeLabel(
              PeriodComparison(current.income, previous.income),
              increaseIsGood: true,
              noun: noun,
            ),
          ),
          const SizedBox(height: Space.md),
          _SummaryRow(
            icon: Icons.north_east,
            iconColor: colors.expense,
            label: 'Pengeluaran',
            amount: current.expense,
            amountColor: colors.expenseText,
            detail: _ChangeLabel(
              PeriodComparison(current.expense, previous.expense),
              increaseIsGood: false,
              noun: noun,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.md),
            child: Divider(),
          ),
          _SummaryRow(
            icon: Icons.swap_vert,
            iconColor: theme.colorScheme.primary,
            label: 'Arus kas bersih',
            amount: net,
            amountColor: net < 0
                ? colors.expenseText
                : (net > 0 ? colors.income : null),
            detail: const _DetailText('Pemasukan dikurangi pengeluaran'),
          ),
          const SizedBox(height: Space.md),
          _SummaryRow(
            icon: Icons.savings_outlined,
            iconColor: theme.colorScheme.primary,
            label: 'Ditabung ke tujuan',
            amount: current.savingsContribution,
            detail: savingsDetail == null ? null : _DetailText(savingsDetail),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.amount,
    this.amountColor,
    this.detail,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final int amount;
  final Color? amountColor;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (detail != null) ...[const SizedBox(height: 2), detail!],
            ],
          ),
        ),
        const SizedBox(width: Space.sm),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              Money.format(amount),
              style: AppText.tabular(theme.textTheme.titleMedium)
                  ?.copyWith(color: amountColor),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailText extends StatelessWidget {
  const _DetailText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Perbandingan dengan periode sebelumnya. Arah ditunjukkan dengan ikon dan
/// teks, bukan hanya warna.
class _ChangeLabel extends StatelessWidget {
  const _ChangeLabel(
    this.comparison, {
    required this.increaseIsGood,
    required this.noun,
  });
  final PeriodComparison comparison;
  final bool increaseIsGood;
  final String noun;

  @override
  Widget build(BuildContext context) {
    if (comparison.current == 0 && comparison.previous == 0) {
      return const SizedBox.shrink();
    }
    final pct = comparison.percentChange;
    if (pct == null) {
      return _DetailText(
        '${noun[0].toUpperCase()}${noun.substring(1)} lalu Rp0',
      );
    }
    if (comparison.delta == 0) {
      return _DetailText('Sama dengan $noun lalu');
    }
    final colors = FinanceColors.of(context);
    final up = comparison.delta > 0;
    final color = up == increaseIsGood ? colors.income : colors.expenseText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            '${up ? 'Naik' : 'Turun'} ${_percent.format(pct.abs())}% dari $noun lalu',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.buckets, required this.onTap});
  final List<PeriodBucket> buckets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);

    Widget legend(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: theme.textTheme.bodySmall),
      ],
    );

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pemasukan vs pengeluaran', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.lg,
            runSpacing: Space.xs,
            children: [
              legend(colors.income, 'Pemasukan (kiri)'),
              legend(colors.expense, 'Pengeluaran (kanan)'),
            ],
          ),
          const SizedBox(height: Space.lg),
          IncomeExpenseChart(buckets: buckets),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.data,
    required this.totals,
    required this.onCategoryTap,
  });

  final FinanceSnapshot data;
  final List<CategoryTotal> totals;
  final void Function(String categoryId) onCategoryTap;

  static const _fallback = Color(0xFF8A9690);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totals.fold<int>(0, (s, t) => s + t.amount);
    final top = totals.take(5).toList();
    final otherSum = totals.skip(5).fold<int>(0, (s, t) => s + t.amount);

    Color colorOf(String id) {
      final c = data.categoryById[id];
      return c == null ? _fallback : Color(c.color);
    }

    final slices = [
      for (final t in top) DonutSlice(t.amount, colorOf(t.categoryId)),
      if (otherSum > 0) DonutSlice(otherSum, _fallback),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pengeluaran per kategori', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.lg),
          Center(child: CategoryDonut(slices: slices)),
          const SizedBox(height: Space.md),
          for (final t in top)
            _LegendRow(
              color: colorOf(t.categoryId),
              name: data.categoryById[t.categoryId]?.name ?? 'Kategori dihapus',
              percent: '${_percent.format(t.amount * 100 / total)}%',
              amount: Money.format(t.amount),
              onTap: () => onCategoryTap(t.categoryId),
            ),
          if (otherSum > 0)
            _LegendRow(
              color: _fallback,
              name: 'Kategori lain',
              percent: '${_percent.format(otherSum * 100 / total)}%',
              amount: Money.format(otherSum),
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.name,
    required this.percent,
    required this.amount,
    this.onTap,
  });

  final Color color;
  final String name;
  final String percent;
  final String amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Space.sm),
            Text(
              percent,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: Space.sm),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  amount,
                  style: AppText.tabular(theme.textTheme.titleSmall),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsCard extends StatelessWidget {
  const _AccountsCard({required this.data});
  final FinanceSnapshot data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final accounts = data.accounts.where((a) => !a.archived).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Akun', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          for (final account in accounts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Row(
                children: [
                  Icon(
                    _accountIcon(account.type),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: theme.textTheme.bodyLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          account.type.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Builder(
                        builder: (context) {
                          final balance = data.balances[account.id] ?? 0;
                          return Text(
                            Money.format(balance),
                            style: AppText.tabular(theme.textTheme.titleSmall)
                                ?.copyWith(
                                  color: balance < 0
                                      ? colors.expenseText
                                      : null,
                                ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoTransactionsCard extends StatelessWidget {
  const _NoTransactionsCard({required this.hasAny, required this.noun});
  final bool hasAny;
  final String noun;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Space.xl),
      child: EmptyState(
        icon: Icons.edit_note,
        title: hasAny
            ? 'Belum ada transaksi di $noun ini'
            : 'Belum ada transaksi',
        message: hasAny
            ? 'Pilih $noun lain atau catat transaksi baru untuk $noun ini.'
            : 'Catat pemasukan atau pengeluaran pertama Anda untuk melihat ringkasan di sini.',
      ),
    );
  }
}
