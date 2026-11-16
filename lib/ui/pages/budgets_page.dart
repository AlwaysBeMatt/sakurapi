
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/budget_calculator.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../theme/finance_ui.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import 'budget_form_sheet.dart';

final _percent = NumberFormat('#,##0.#', 'id_ID');

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(financeSnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Anggaran')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        tooltip: 'Tambah anggaran',
        onPressed: () {
          final data = snapshot.value;
          if (data == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Data belum siap. Coba sebentar lagi.'),
              ),
            );
            return;
          }
          showBudgetForm(context, data: data);
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: EmptyState(
              icon: Icons.error_outline,
              title: 'Data gagal dimuat',
              message: 'Terjadi kesalahan saat membaca penyimpanan.',
              actionLabel: 'Coba lagi',
              onAction: () => ref.invalidate(financeSnapshotProvider),
            ),
          ),
        ),
        data: (data) => _BudgetsBody(data: data),
      ),
    );
  }
}

class _BudgetsBody extends ConsumerWidget {
  const _BudgetsBody({required this.data});

  final FinanceSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final thresholds = ref.watch(budgetThresholdsProvider);

    final progress = [
      for (final b in data.budgets)
        BudgetCalculator.evaluate(
          b,
          data.transactions,
          month.range,
          thresholds: thresholds,
        ),
    ]..sort((a, b) => b.percent.compareTo(a.percent));

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 96),
          children: [
            if (progress.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.xxl),
                child: EmptyState(
                  icon: Icons.pie_chart_outline,
                  title: 'Belum ada anggaran',
                  message:
                      'Tetapkan batas pengeluaran bulanan per kategori '
                      'supaya pengeluaran lebih terkendali.',
                  actionLabel: 'Buat anggaran',
                  onAction: () => showBudgetForm(context, data: data),
                ),
              )
            else ...[
              const _MonthBar(),
              for (final p in progress) ...[
                const SizedBox(height: Space.md),
                _BudgetTile(
                  data: data,
                  progress: p,
                  onTap: () =>
                      showBudgetForm(context, data: data, existing: p.budget),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthBar extends ConsumerWidget {
  const _MonthBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final notifier = ref.read(selectedMonthProvider.notifier);
    final today = ref.watch(clockProvider)();
    final isCurrent = month == MonthRef.of(today);

    return AppCard(
      padding: const EdgeInsets.all(Space.xs),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Bulan anggaran sebelumnya',
            onPressed: notifier.previous,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${monthNamesId[month.month - 1]} ${month.year}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isCurrent)
                  TextButton(
                    onPressed: notifier.reset,
                    child: const Text('Kembali ke bulan ini'),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Bulan anggaran berikutnya',
            onPressed: notifier.next,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.data,
    required this.progress,
    required this.onTap,
  });

  final FinanceSnapshot data;
  final BudgetProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final p = progress;

    final id = p.budget.categoryId;
    final category = id == null ? null : data.categoryById[id];
    final name = id == null
        ? 'Semua pengeluaran'
        : (category?.name ?? 'Kategori dihapus');
    final icon = id == null
        ? Icons.pie_chart_outline
        : iconForKey(category?.iconKey ?? 'more');

    // Status ditunjukkan dengan ikon dan teks, bukan hanya warna.
    final (
      IconData statusIcon,
      Color textColor,
      Color barColor,
    ) = switch (p.status) {
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

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
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
              Icon(statusIcon, size: 16, color: textColor),
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
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
          Text(
            '${Money.format(p.spent)} terpakai · ${_percent.format(p.percent)}%',
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}
