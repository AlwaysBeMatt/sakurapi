import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/models/money_transaction.dart';
import '../../domain/models/recurring_rule.dart';
import '../../state/providers.dart';
import '../theme/finance_ui.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import 'recurring_form_sheet.dart';

String _date(DateTime d) => '${d.day} ${shortMonthNamesId[d.month - 1]} ${d.year}';

String _status(RecurringRule r) {
  if (r.isFinished) {
    return 'Selesai';
  }
  if (!r.active) {
    return 'Dijeda';
  }
  return 'Berikutnya ${_date(r.nextDate)}';
}

class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(financeSnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi berulang')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        tooltip: 'Tambah transaksi berulang',
        onPressed: () {
          final data = snapshot.value;
          if (data == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data belum siap. Coba sebentar lagi.')),
            );
            return;
          }
          showRecurringForm(context, data: data);
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
        data: (data) => _Body(data: data),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});

  final FinanceSnapshot data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rules = data.recurringRules;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 96),
          children: [
            if (rules.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.xxl),
                child: EmptyState(
                  icon: Icons.event_repeat_outlined,
                  title: 'Belum ada transaksi berulang',
                  message:
                      'Catat gaji, tagihan, atau langganan sekali saja. '
                      'Transaksinya dicatat otomatis setiap jatuh tempo.',
                  actionLabel: 'Buat transaksi berulang',
                  onAction: () => showRecurringForm(context, data: data),
                ),
              )
            else ...[
              Text(
                'Dicatat otomatis saat aplikasi dibuka pada atau setelah tanggalnya.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final r in rules) ...[
                const SizedBox(height: Space.md),
                _RuleTile(
                  rule: r,
                  data: data,
                  onTap: () => showRecurringForm(context, data: data, existing: r),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.data, required this.onTap});

  final RecurringRule rule;
  final FinanceSnapshot data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final category = data.categoryById[rule.categoryId];
    final account = data.accountById[rule.accountId]?.name ?? '-';
    final isIncome = rule.type == TransactionType.income;
    final name = rule.title.isNotEmpty
        ? rule.title
        : (category?.name ?? 'Kategori dihapus');
    final running = rule.active && !rule.isFinished;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(
              iconForKey(category?.iconKey ?? 'more'),
              size: 20,
              color: isIncome ? colors.income : colors.expense,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: running ? null : secondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${rule.frequency.label} · ${Money.format(rule.amount)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
                Row(
                  children: [
                    if (!running) ...[
                      Icon(
                        rule.isFinished ? Icons.check_circle_outline : Icons.pause_circle_outline,
                        size: 14,
                        color: secondary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        '${_status(rule)} · $account',
                        style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Icon(Icons.chevron_right, color: secondary),
        ],
      ),
    );
  }
}