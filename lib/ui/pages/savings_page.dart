import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/goal_calculator.dart';
import '../../state/providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/goal_progress_view.dart';
import 'goal_detail_page.dart';
import 'goal_form_page.dart';

class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(financeSnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tabungan')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        tooltip: 'Tambah target tabungan',
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
          openGoalForm(context, data: data);
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
        data: (data) => _SavingsBody(data: data),
      ),
    );
  }
}

class _SavingsBody extends ConsumerWidget {
  const _SavingsBody({required this.data});

  final FinanceSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(clockProvider)();
    final items = [
      for (final g in data.goals)
        (g, GoalCalculator.evaluate(g, data.transactions, today: today)),
    ];
    final totalCollected = items.fold<int>(0, (s, e) => s + e.$2.collected);
    final totalTarget = items.fold<int>(0, (s, e) => s + e.$2.target);
    final monthlyTotal = items.fold<int>(
      0,
      (s, e) =>
          s +
          (e.$2.status == GoalStatus.inProgress
              ? (e.$2.monthlyNeeded ?? 0)
              : 0),
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 96),
          children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.xxl),
                child: EmptyState(
                  icon: Icons.savings_outlined,
                  title: 'Belum ada target tabungan',
                  message:
                      'Buat target seperti dana darurat atau laptop baru, '
                      'lalu setor sedikit demi sedikit.',
                  actionLabel: 'Buat target',
                  onAction: () => openGoalForm(context, data: data),
                ),
              )
            else ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total tabungan',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Money.format(totalCollected),
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      'dari target ${Money.format(totalTarget)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (monthlyTotal > 0)
                      Text(
                        'Estimasi setoran total ${Money.format(monthlyTotal)} per bulan',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              for (final (goal, progress) in items) ...[
                const SizedBox(height: Space.md),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GoalDetailPage(goalId: goal.id),
                    ),
                  ),
                  child: GoalProgressView(goal: goal, progress: progress),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
