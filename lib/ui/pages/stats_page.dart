import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/finance_calculator.dart';
import '../../domain/models/money_transaction.dart';
import '../../domain/period_report.dart';
import '../../domain/range_report.dart';
import '../../domain/stats_report.dart';
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
import '../widgets/transaction_tile.dart';
import 'transaction_form_page.dart';

final _percent = NumberFormat('#,##0.#', 'id_ID');

List<Widget> _spaced(List<Widget> items) => [
  for (var i = 0; i < items.length; i++) ...[
    if (i > 0) const SizedBox(height: Space.lg),
    items[i],
  ],
];

String _capitalize(String s) => '${s[0].toUpperCase()}${s.substring(1)}';

enum _Mode { period, range }

enum _Preset {
  days30('30 hari terakhir'),
  months3('3 bulan terakhir'),
  months6('6 bulan terakhir'),
  custom('Pilih tanggal');

  const _Preset(this.label);
  final String label;
}

/// Semua yang dibutuhkan kartu Statistik: baik untuk mode periode maupun rentang.
class _Scope {
  const _Scope({
    required this.range,
    required this.previousRange,
    required this.buckets,
    required this.noun,
    required this.lastLabel,
  });

  final DateRange range;
  final DateRange previousRange;
  final List<PeriodBucket> buckets;

  /// "minggu", "bulan", "tahun", atau "rentang".
  final String noun;

  /// "bulan lalu" atau "periode sebelumnya".
  final String lastLabel;
}

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(financeSnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
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
        data: (data) => _StatsContent(data: data),
      ),
    );
  }
}

class _StatsContent extends ConsumerStatefulWidget {
  const _StatsContent({required this.data});

  final FinanceSnapshot data;

  @override
  ConsumerState<_StatsContent> createState() => _StatsContentState();
}

class _StatsContentState extends ConsumerState<_StatsContent> {
  _Mode _mode = _Mode.period;
  _Preset _preset = _Preset.months6;
  DateRange? _custom;

  DateRange _rangeFor(DateTime today) {
    final t = dateOnly(today);
    switch (_preset) {
      case _Preset.days30:
        return DateRange(DateTime(t.year, t.month, t.day - 29), t);
      case _Preset.months3:
        return DateRange(DateTime(t.year, t.month - 2, 1), t);
      case _Preset.months6:
        return DateRange(DateTime(t.year, t.month - 5, 1), t);
      case _Preset.custom:
        return _custom ?? DateRange(DateTime(t.year, t.month - 5, 1), t);
    }
  }

  Future<void> _pickCustom() async {
    final current = _custom;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: current == null
          ? null
          : DateTimeRange(start: current.start, end: current.end),
    );
    if (picked == null || !mounted) {
      return;
    }
    final range = DateRange(picked.start, picked.end);
    if (RangeReport.dayCount(range) > RangeReport.maxDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rentang maksimal sekitar 2 tahun (${RangeReport.maxDays} hari).'),
        ),
      );
      return;
    }
    setState(() {
      _custom = range;
      _preset = _Preset.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final txs = data.transactions;
    final today = ref.watch(clockProvider)();
    final period = ref.watch(periodProvider);

    final _Scope scope;
    List<PeriodBucket>? trend;
    if (_mode == _Mode.period) {
      scope = _Scope(
        range: period.range,
        previousRange: period.previous.range,
        buckets: PeriodReport.buckets(txs, period),
        noun: period.kind.noun,
        lastLabel: '${period.kind.noun} lalu',
      );
      trend = data.hasTransactions ? StatsReport.trend(txs, period) : null;
    } else {
      final range = _rangeFor(today);
      scope = _Scope(
        range: range,
        previousRange: RangeReport.previous(range),
        buckets: RangeReport.buckets(txs, range),
        noun: 'rentang',
        lastLabel: 'periode sebelumnya',
      );
    }

    final current = FinanceCalculator.summarize(txs, scope.range);
    final previous = FinanceCalculator.summarize(txs, scope.previousRange);
    final top = StatsReport.topExpenses(txs, scope.range);
    final filter = TxFilter(from: scope.range.start, to: scope.range.end);

    final cards = <Widget>[
      if (current.isEmpty)
        _EmptyCard(noun: scope.noun)
      else ...[
        _SummaryCard(
          range: scope.range,
          current: current,
          today: today,
          onTap: () => showTransactionsTab(ref, filter),
        ),
        _CashFlowCard(buckets: scope.buckets),
        _CategoryCard(
          data: data,
          range: scope.range,
          noun: scope.noun,
          onCategoryTap: (id, type) => showTransactionsTab(
            ref,
            TxFilter(
              types: {type},
              categoryIds: {id},
              from: scope.range.start,
              to: scope.range.end,
            ),
          ),
        ),
        _CompareCard(
          lastLabel: scope.lastLabel,
          current: current,
          previous: previous,
        ),
        if (top.isNotEmpty) _TopExpensesCard(data: data, items: top),
      ],
      if (trend != null) _TrendCard(buckets: trend, noun: period.kind.noun),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.sm,
          Space.lg,
          Space.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<_Mode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _Mode.period, label: Text('Per periode')),
                    ButtonSegment(value: _Mode.range, label: Text('Rentang')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: Space.md),
                if (_mode == _Mode.period)
                  const PeriodSelector()
                else
                  _RangeControls(
                    preset: _preset,
                    range: scope.range,
                    onPreset: (p) {
                      if (p == _Preset.custom) {
                        _pickCustom();
                      } else {
                        setState(() => _preset = p);
                      }
                    },
                  ),
                const SizedBox(height: Space.lg),
                ..._spaced(cards),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RangeControls extends StatelessWidget {
  const _RangeControls({
    required this.preset,
    required this.range,
    required this.onPreset,
  });

  final _Preset preset;
  final DateRange range;
  final ValueChanged<_Preset> onPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final p in _Preset.values)
                ChoiceChip(
                  avatar: p == _Preset.custom
                      ? const Icon(Icons.date_range, size: 18)
                      : null,
                  label: Text(p.label),
                  selected: preset == p,
                  onSelected: (_) => onPreset(p),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(
            RangeReport.label(range),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.noun});

  final String noun;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Space.xl),
      child: EmptyState(
        icon: Icons.insights_outlined,
        title: 'Belum ada data di $noun ini',
        message: 'Pilih $noun lain atau catat transaksi untuk melihat statistik.',
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Space.sm),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: AppText.tabular(
                  theme.textTheme.titleSmall,
                )?.copyWith(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.color, this.text);

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    final colors = FinanceColors.of(context);
    return Wrap(
      spacing: Space.lg,
      runSpacing: Space.xs,
      children: [
        _LegendItem(colors.income, 'Pemasukan (kiri)'),
        _LegendItem(colors.expense, 'Pengeluaran (kanan)'),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.range,
    required this.current,
    required this.today,
    required this.onTap,
  });

  final DateRange range;
  final PeriodSummary current;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final net = current.net;
    final ratio = current.savingsRatioPercent;
    final saved = current.savingsContribution;
    final avg = RangeReport.averageDaily(current.expense, range, today);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ringkasan periode',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          _KeyValueRow(
            'Pemasukan',
            Money.format(current.income),
            color: colors.income,
          ),
          _KeyValueRow(
            'Pengeluaran',
            Money.format(current.expense),
            color: colors.expenseText,
          ),
          _KeyValueRow(
            'Arus kas bersih',
            Money.format(net),
            color: net < 0
                ? colors.expenseText
                : (net > 0 ? colors.income : null),
          ),
          if (saved != 0)
            _KeyValueRow(
              'Ditabung ke tujuan',
              ratio == null
                  ? Money.format(saved)
                  : '${Money.format(saved)} (${_percent.format(ratio)}%)',
            ),
          if (avg != null)
            _KeyValueRow('Rata-rata pengeluaran per hari', Money.format(avg)),
        ],
      ),
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({required this.buckets});

  final List<PeriodBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final active = buckets
        .where((b) => b.income != 0 || b.expense != 0)
        .toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Arus kas', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          const _ChartLegend(),
          const SizedBox(height: Space.lg),
          IncomeExpenseChart(buckets: buckets),
          if (active.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Space.sm),
              child: Divider(),
            ),
            for (final b in active)
              _KeyValueRow(
                b.label,
                _signed(b.income - b.expense),
                color: b.income - b.expense < 0
                    ? colors.expenseText
                    : (b.income - b.expense > 0 ? colors.income : null),
              ),
          ],
        ],
      ),
    );
  }

  static String _signed(int net) {
    if (net > 0) {
      return '+${Money.format(net)}';
    }
    if (net < 0) {
      return '-${Money.format(-net)}';
    }
    return Money.format(0);
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.data,
    required this.range,
    required this.noun,
    required this.onCategoryTap,
  });

  final FinanceSnapshot data;
  final DateRange range;
  final String noun;
  final void Function(String categoryId, TransactionType type) onCategoryTap;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  static const _fallback = Color(0xFF8A9690);

  TransactionType _type = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;
    final totals = StatsReport.byCategory(
      data.transactions,
      widget.range,
      _type,
    );
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
    final kindLabel = _type == TransactionType.expense
        ? 'pengeluaran'
        : 'pemasukan';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kategori', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.md),
          SegmentedButton<TransactionType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('Pengeluaran'),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text('Pemasukan'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: Space.lg),
          if (totals.isEmpty)
            Text(
              'Belum ada $kindLabel di ${widget.noun} ini.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Center(child: CategoryDonut(slices: slices)),
            const SizedBox(height: Space.md),
            for (final t in top)
              _LegendRow(
                color: colorOf(t.categoryId),
                name:
                    data.categoryById[t.categoryId]?.name ?? 'Kategori dihapus',
                percent: '${_percent.format(t.amount * 100 / total)}%',
                amount: Money.format(t.amount),
                onTap: t.categoryId.isEmpty
                    ? null
                    : () => widget.onCategoryTap(t.categoryId, _type),
              ),
            if (otherSum > 0)
              _LegendRow(
                color: _fallback,
                name: 'Kategori lain',
                percent: '${_percent.format(otherSum * 100 / total)}%',
                amount: Money.format(otherSum),
              ),
          ],
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

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.lastLabel,
    required this.current,
    required this.previous,
  });

  final String lastLabel;
  final PeriodSummary current;
  final PeriodSummary previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dibanding $lastLabel', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.lg),
          _CompareRow(
            label: 'Pemasukan',
            current: current.income,
            previous: previous.income,
            increaseIsGood: true,
            lastLabel: lastLabel,
          ),
          const SizedBox(height: Space.lg),
          _CompareRow(
            label: 'Pengeluaran',
            current: current.expense,
            previous: previous.expense,
            increaseIsGood: false,
            lastLabel: lastLabel,
          ),
          const SizedBox(height: Space.lg),
          _CompareRow(
            label: 'Arus kas bersih',
            current: current.net,
            previous: previous.net,
            increaseIsGood: true,
            lastLabel: lastLabel,
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.current,
    required this.previous,
    required this.increaseIsGood,
    required this.lastLabel,
  });

  final String label;
  final int current;
  final int previous;
  final bool increaseIsGood;
  final String lastLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final delta = current - previous;

    Widget change;
    if (previous == 0) {
      change = const SizedBox.shrink();
    } else if (delta == 0) {
      change = Text(
        'Sama dengan $lastLabel',
        style: theme.textTheme.bodySmall?.copyWith(color: secondary),
      );
    } else {
      final up = delta > 0;
      final color = up == increaseIsGood ? colors.income : colors.expenseText;
      final pct = delta.abs() * 100 / previous.abs();
      change = Row(
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
              '${up ? 'Naik' : 'Turun'} ${_percent.format(pct)}%',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Space.sm),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  Money.format(current),
                  style: AppText.tabular(theme.textTheme.titleSmall),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${_capitalize(lastLabel)} ${Money.format(previous)}',
          style: theme.textTheme.bodySmall?.copyWith(color: secondary),
        ),
        change,
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.buckets, required this.noun});

  final List<PeriodBucket> buckets;
  final String noun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tren ${buckets.length} $noun terakhir',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Space.sm),
          const _ChartLegend(),
          const SizedBox(height: Space.lg),
          IncomeExpenseChart(buckets: buckets),
        ],
      ),
    );
  }
}

class _TopExpensesCard extends ConsumerWidget {
  const _TopExpensesCard({required this.data, required this.items});

  final FinanceSnapshot data;
  final List<MoneyTransaction> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pengeluaran terbesar', style: theme.textTheme.titleMedium),
        for (final tx in items) ...[
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