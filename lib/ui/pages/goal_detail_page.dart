import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../domain/errors.dart';
import '../../domain/goal_calculator.dart';
import '../../domain/models/money_transaction.dart';
import '../../domain/models/savings_goal.dart';
import '../../state/providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/goal_progress_view.dart';
import 'goal_form_page.dart';
import 'goal_money_sheet.dart';
import 'transaction_form_page.dart';

class GoalDetailPage extends ConsumerWidget {
  const GoalDetailPage({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(financeSnapshotProvider);
    final today = ref.watch(clockProvider)();
    final data = snapshot.value;

    if (data == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: snapshot.hasError
              ? const Text('Data gagal dimuat')
              : const CircularProgressIndicator(),
        ),
      );
    }

    SavingsGoal? goal;
    for (final g in data.goals) {
      if (g.id == goalId) {
        goal = g;
      }
    }
    if (goal == null) {
      // Target sudah dihapus; halaman ini akan ditutup.
      return Scaffold(appBar: AppBar());
    }

    return _content(context, ref, data, goal, today);
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    FinanceSnapshot data,
    SavingsGoal goal,
    DateTime today,
  ) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final progress = GoalCalculator.evaluate(
      goal,
      data.transactions,
      today: today,
    );
    final history = data.transactions.where((t) => t.goalId == goal.id).toList()
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
      });
    final accountName = data.accountById[goal.accountId]?.name ?? '-';
    final note = goal.note?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Ubah target',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openGoalForm(context, data: data, existing: goal),
          ),
          IconButton(
            tooltip: 'Hapus target',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteGoal(context, ref, goal),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GoalProgressView(goal: goal, progress: progress),
                      const SizedBox(height: Space.md),
                      if (goal.targetDate != null)
                        Text(
                          'Tenggat ${DateFormat('d MMMM yyyy', 'id_ID').format(goal.targetDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondary,
                          ),
                        ),
                      Text(
                        'Disimpan di $accountName',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                      if (note.isNotEmpty)
                        Text(
                          note,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => showGoalMoneySheet(
                          context,
                          data: data,
                          goal: goal,
                          deposit: true,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Setor'),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showGoalMoneySheet(
                          context,
                          data: data,
                          goal: goal,
                          deposit: false,
                        ),
                        icon: const Icon(Icons.remove),
                        label: const Text('Tarik'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xl),
                Text('Riwayat', style: theme.textTheme.titleMedium),
                const SizedBox(height: Space.sm),
                if (goal.initialAmount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: AppCard(
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined),
                          const SizedBox(width: Space.md),
                          const Expanded(child: Text('Dana awal')),
                          Text(
                            Money.format(goal.initialAmount),
                            style: AppText.tabular(theme.textTheme.titleSmall),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (history.isEmpty)
                  Text(
                    'Belum ada setoran atau penarikan.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondary,
                    ),
                  )
                else
                  for (final tx in history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: _ContributionRow(
                        tx: tx,
                        data: data,
                        onTap: () =>
                            openTransactionForm(context, ref, existing: tx),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGoal(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus target?'),
        content: Text(
          'Target "${goal.name}" akan dihapus. '
          'Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(financeRepositoryProvider).deleteGoal(goal.id);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Target dihapus')));
    } on ValidationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus. Coba lagi.')),
      );
    }
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.tx,
    required this.data,
    required this.onTap,
  });

  final MoneyTransaction tx;
  final FinanceSnapshot data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final isDeposit = tx.goalSignedAmount > 0;
    final from = data.accountById[tx.accountId]?.name ?? '-';
    final to = data.accountById[tx.toAccountId]?.name ?? '-';
    final note = tx.note?.trim() ?? '';
    final date = DateFormat('d MMM yyyy', 'id_ID').format(tx.date);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            isDeposit ? Icons.south_west : Icons.north_east,
            color: isDeposit ? colors.income : colors.expense,
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDeposit ? 'Setoran' : 'Penarikan',
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  '$date · $from → $to',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note.isNotEmpty)
                  Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${isDeposit ? '+' : '-'}${Money.format(tx.amount)}',
                style: AppText.tabular(theme.textTheme.titleSmall)?.copyWith(
                  color: isDeposit ? colors.income : colors.expenseText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
