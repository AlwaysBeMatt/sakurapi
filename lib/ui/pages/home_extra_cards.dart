
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/budget_calculator.dart';
import '../../domain/goal_calculator.dart';
import '../../state/navigation.dart';
import '../../state/providers.dart';
import '../../state/tx_filter.dart';
import '../../state/settings.dart';
import '../theme/finance_ui.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/transaction_tile.dart';
import 'transaction_form_page.dart';

final _percent = NumberFormat('#,##0.#', 'id_ID');

class _CardHeader extends StatelessWidget {
  const _CardHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
      ],
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Anggaran yang mendekati atau melewati batas pada bulan [month].
class BudgetSummaryCard extends ConsumerWidget {
  const BudgetSummaryCard({super.key, required this.data, required this.month});

  final FinanceSnapshot data;
  final MonthRef month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thresholds = ref.watch(budgetThresholdsProvider);

    final progress = [
      for (final b in data.budgets)
        BudgetCalculator.evaluate(
          b,
          data.transactions,
          month.range,
          thresholds: thresholds,
        ),
    ];

    final attention =
        progress.where((p) => p.status != BudgetStatus.normal).toList()
          ..sort((a, b) => b.percent.compareTo(a.percent));

    final Widget body;
    if (progress.isEmpty) {
      body = const _MutedText(
        'Belum ada anggaran. Batas pengeluaran bisa diatur di tab Anggaran.',
      );
    } else if (attention.isEmpty) {
      body = _MutedText(
        'Semua anggaran masih aman (${progress.length} anggaran).',
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < attention.take(3).length; i++) ...[
            if (i > 0) const SizedBox(height: Space.lg),
            _BudgetRow(
              name:
                  data.categoryById[attention[i].budget.categoryId]?.name ??
                  (attention[i].budget.categoryId == null
                      ? 'Semua pengeluaran'
                      : 'Kategori dihapus'),
              progress: attention[i],
            ),
          ],
        ],
      );
    }

    return AppCard(
      onTap: () => ref.read(shellTabProvider.notifier).select(ShellTab.budgets),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            'Anggaran ${monthNamesId[month.month - 1]} ${month.year}',
          ),
          const SizedBox(height: Space.md),
          body,
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.name, required this.progress});

  final String name;
  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final p = progress;

    // Status ditunjukkan dengan ikon dan teks, bukan hanya warna.
    final (IconData icon, Color textColor, Color barColor) = switch (p.status) {
      BudgetStatus.normal => (
        Icons.check_circle_outline,
        colors.income,
        colors.income,
      ),
      BudgetStatus.caution => (
        Icons.info_outline,
        colors.warningText,
        colors.warning,
      ),
      BudgetStatus.warning => (
        Icons.warning_amber_rounded,
        colors.warningText,
        colors.warning,
      ),
      BudgetStatus.exceeded => (
        Icons.error_outline,
        colors.expenseText,
        colors.expense,
      ),
    };

    final detail = p.remaining >= 0
        ? 'Tersisa ${Money.format(p.remaining)} dari ${Money.format(p.limit)}'
        : 'Melebihi ${Money.format(-p.remaining)} dari ${Money.format(p.limit)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Space.sm),
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 4),
            Text(
              p.status.label,
              style: theme.textTheme.bodySmall?.copyWith(color: textColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: p.barValue,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          color: barColor,
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Dana tabungan dan progres tiap target.
class SavingsSummaryCard extends ConsumerWidget {
  const SavingsSummaryCard({
    super.key,
    required this.data,
    required this.today,
  });

  final FinanceSnapshot data;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = [
      for (final g in data.goals)
        (g, GoalCalculator.evaluate(g, data.transactions, today: today)),
    ];
    final totalCollected = items.fold<int>(0, (s, e) => s + e.$2.collected);
    final totalTarget = items.fold<int>(0, (s, e) => s + e.$2.target);
    final shown = items.take(3).toList();

    final Widget body;
    if (items.isEmpty) {
      body = const _MutedText(
        'Belum ada target tabungan. Buat target di tab Tabungan.',
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Terkumpul ${Money.format(totalCollected)} dari ${Money.format(totalTarget)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final (goal, p) in shown) ...[
            const SizedBox(height: Space.lg),
            _GoalRow(
              name: goal.name,
              iconKey: goal.iconKey,
              color: Color(goal.color),
              progress: p,
            ),
          ],
        ],
      );
    }

    return AppCard(
      onTap: () => ref.read(shellTabProvider.notifier).select(ShellTab.savings),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHeader('Tabungan'),
          const SizedBox(height: Space.md),
          body,
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.name,
    required this.iconKey,
    required this.color,
    required this.progress,
  });

  final String name;
  final String iconKey;
  final Color color;
  final GoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = progress;
    final status = switch (p.status) {
      GoalStatus.achieved => 'Target tercapai',
      GoalStatus.overdue => 'Tenggat terlewat',
      GoalStatus.noDeadline => 'Tanpa tenggat',
      GoalStatus.inProgress =>
        'Perlu ${Money.format(p.monthlyNeeded ?? 0)} per bulan · sisa ${p.daysLeft ?? 0} hari',
    };
    final secondary = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(iconForKey(iconKey), size: 20, color: color),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Space.sm),
            Text(
              '${_percent.format(p.percent)}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: p.barValue,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          color: color,
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
        const SizedBox(height: 4),
        Text(
          '${Money.format(p.collected)} dari ${Money.format(p.target)}',
          style: theme.textTheme.bodySmall?.copyWith(color: secondary),
        ),
        Text(
          status,
          style: theme.textTheme.bodySmall?.copyWith(color: secondary),
        ),
      ],
    );
  }
}

/// Lima transaksi terbaru (semua periode).
class RecentTransactionsCard extends ConsumerWidget {
  const RecentTransactionsCard({super.key, required this.data});

  final FinanceSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recent = const TxFilter().apply(data.transactions).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Transaksi terbaru',
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () => showTransactionsTab(ref, const TxFilter()),
              child: const Text('Lihat semua'),
            ),
          ],
        ),
        for (final tx in recent) ...[
          const SizedBox(height: Space.sm),
          TransactionTile(
            tx: tx,
            data: data,
            onTap: () => openTransactionForm(context, ref, existing: tx),
          ),
        ],
      ],
    );
  }
}
