import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/finance_repository.dart' show TransactionSort;
import '../../domain/models/money_transaction.dart';
import '../../state/providers.dart';
import '../../state/tx_filter.dart';
import '../theme/finance_ui.dart';
import '../theme/tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/transaction_tile.dart';
import 'transaction_form_page.dart';

const _sortLabels = {
  TransactionSort.newest: 'Terbaru',
  TransactionSort.oldest: 'Terlama',
  TransactionSort.largest: 'Nominal terbesar',
  TransactionSort.smallest: 'Nominal terkecil',
};

enum _Grouping {
  day('Per hari'),
  month('Per bulan');

  const _Grouping(this.label);
  final String label;
}

/// Judul sebuah bulan beserta totalnya, untuk pengelompokan per bulan.
class _MonthGroup {
  const _MonthGroup(this.month, this.income, this.expense);
  final MonthRef month;
  final int income;
  final int expense;
}

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _search = TextEditingController();
  _Grouping _grouping = _Grouping.day;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(financeSnapshotProvider);
    final filter = ref.watch(txFilterProvider);
    final notifier = ref.read(txFilterProvider.notifier);

    // Menyamakan kotak pencarian bila filter diubah dari tempat lain (Beranda).
    ref.listen<String>(txFilterProvider.select((f) => f.query), (previous, next) {
      if (_search.text != next) {
        setState(() => _search.text = next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          PopupMenuButton<_Grouping>(
            tooltip: 'Kelompokkan',
            icon: const Icon(Icons.view_agenda_outlined),
            initialValue: _grouping,
            onSelected: (g) => setState(() => _grouping = g),
            itemBuilder: (_) => [
              for (final g in _Grouping.values)
                PopupMenuItem(value: g, child: Text(g.label)),
            ],
          ),
          PopupMenuButton<TransactionSort>(
            tooltip: 'Urutkan',
            icon: const Icon(Icons.sort),
            initialValue: filter.sort,
            onSelected: notifier.setSort,
            itemBuilder: (_) => [
              for (final e in _sortLabels.entries)
                PopupMenuItem(value: e.key, child: Text(e.value)),
            ],
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
              message: 'Terjadi kesalahan saat membaca penyimpanan.',
              actionLabel: 'Coba lagi',
              onAction: () => ref.invalidate(financeSnapshotProvider),
            ),
          ),
        ),
        data: (data) {
          final shown = filter.apply(data.transactions);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.sm,
                      Space.sm,
                      Space.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Cari nama atau catatan',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Hapus pencarian',
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        _search.clear();
                                        notifier.setQuery('');
                                        setState(() {});
                                      },
                                    ),
                            ),
                            onChanged: (value) {
                              notifier.setQuery(value);
                              setState(() {});
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Filter',
                          onPressed: () => _showFilterSheet(context, data),
                          icon: Badge(
                            isLabelVisible: filter.activeCount > 0,
                            label: Text('${filter.activeCount}'),
                            child: const Icon(Icons.filter_list),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: shown.isEmpty
                        ? _buildEmpty(data, filter)
                        : _buildList(data, shown, filter),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(FinanceSnapshot data, TxFilter filter) {
    final filtering = data.hasTransactions && filter.isFiltering;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: EmptyState(
          icon: filtering ? Icons.search_off : Icons.edit_note,
          title: filtering
              ? 'Tidak ada transaksi yang cocok'
              : 'Belum ada transaksi',
          message: filtering
              ? 'Ubah kata kunci atau filter untuk melihat transaksi lain.'
              : 'Catat pemasukan atau pengeluaran pertama Anda.',
          actionLabel: filtering ? 'Hapus filter' : 'Catat transaksi',
          onAction: filtering
              ? () {
                  _search.clear();
                  ref.read(txFilterProvider.notifier).clearAll();
                  setState(() {});
                }
              : () => openTransactionForm(context, ref),
        ),
      ),
    );
  }

  Widget _buildList(
    FinanceSnapshot data,
    List<MoneyTransaction> shown,
    TxFilter filter,
  ) {
    final dated =
        filter.sort == TransactionSort.newest ||
        filter.sort == TransactionSort.oldest;
    final byMonth = dated && _grouping == _Grouping.month;

    final monthTotals = <MonthRef, (int, int)>{};
    if (byMonth) {
      for (final t in shown) {
        final m = MonthRef.of(t.date);
        final (income, expense) = monthTotals[m] ?? (0, 0);
        monthTotals[m] = (
          t.type == TransactionType.income ? income + t.amount : income,
          t.type == TransactionType.expense ? expense + t.amount : expense,
        );
      }
    }

    final items = <Object>[];
    DateTime? lastDay;
    MonthRef? lastMonth;
    for (final t in shown) {
      if (byMonth) {
        final m = MonthRef.of(t.date);
        if (lastMonth != m) {
          final totals = monthTotals[m]!;
          items.add(_MonthGroup(m, totals.$1, totals.$2));
          lastMonth = m;
        }
      } else if (dated) {
        final day = dateOnly(t.date);
        if (lastDay != day) {
          items.add(day);
          lastDay = day;
        }
      }
      items.add(t);
    }
    final dayFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 96),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final theme = Theme.of(context);
        final secondary = theme.colorScheme.onSurfaceVariant;
        final item = items[i];
        if (item is _MonthGroup) {
          return Padding(
            padding: const EdgeInsets.only(top: Space.md, bottom: Space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${monthNamesId[item.month.month - 1]} ${item.month.year}',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  'Pemasukan ${Money.format(item.income)} · '
                  'Pengeluaran ${Money.format(item.expense)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
            ),
          );
        }
        if (item is DateTime) {
          return Padding(
            padding: const EdgeInsets.only(top: Space.md, bottom: Space.sm),
            child: Text(
              dayFormat.format(item),
              style: theme.textTheme.labelLarge?.copyWith(color: secondary),
            ),
          );
        }
        final tx = item as MoneyTransaction;
        return Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: TransactionTile(
            tx: tx,
            data: data,
            onTap: () => openTransactionForm(context, ref, existing: tx),
          ),
        );
      },
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    FinanceSnapshot data,
  ) async {
    var draft = ref.read(txFilterProvider);
    final dateFormat = DateFormat('d MMM yyyy', 'id_ID');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(TxFilter f) => setSheet(() => draft = f);
          final range = draft.from == null || draft.to == null
              ? 'Semua tanggal'
              : '${dateFormat.format(draft.from!)} – ${dateFormat.format(draft.to!)}';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                0,
                Space.lg,
                Space.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: Space.lg),
                  const _SheetLabel('Jenis'),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final t in TransactionType.values)
                        FilterChip(
                          label: Text(typeLabel(t)),
                          selected: draft.types.contains(t),
                          onSelected: (on) {
                            final next = {...draft.types};
                            on ? next.add(t) : next.remove(t);
                            update(draft.copyWith(types: next));
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  const _SheetLabel('Akun'),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: draft.accountId == null,
                        onSelected: (_) =>
                            update(draft.copyWith(clearAccount: true)),
                      ),
                      for (final a in data.accounts)
                        ChoiceChip(
                          label: Text(a.name),
                          selected: draft.accountId == a.id,
                          onSelected: (_) =>
                              update(draft.copyWith(accountId: a.id)),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  const _SheetLabel('Kategori'),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final c in data.categories)
                        FilterChip(
                          avatar: Icon(iconForKey(c.iconKey), size: 18),
                          label: Text(c.name),
                          selected: draft.categoryIds.contains(c.id),
                          onSelected: (on) {
                            final next = {...draft.categoryIds};
                            on ? next.add(c.id) : next.remove(c.id);
                            update(draft.copyWith(categoryIds: next));
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  const _SheetLabel('Tanggal'),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(range, overflow: TextOverflow.ellipsis),
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: ctx,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDateRange:
                                  draft.from != null && draft.to != null
                                  ? DateTimeRange(
                                      start: draft.from!,
                                      end: draft.to!,
                                    )
                                  : null,
                            );
                            if (picked != null) {
                              update(
                                draft.copyWith(
                                  from: picked.start,
                                  to: picked.end,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      if (draft.from != null)
                        IconButton(
                          tooltip: 'Hapus rentang tanggal',
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              update(draft.copyWith(clearDates: true)),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => update(
                            TxFilter(query: draft.query, sort: draft.sort),
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            ref.read(txFilterProvider.notifier).set(draft);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Terapkan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}