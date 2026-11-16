import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/tx_category.dart';
import '../../state/providers.dart';
import '../theme/finance_ui.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import 'category_form_sheet.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  CategoryKind _kind = CategoryKind.expense;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(financeSnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        tooltip: 'Tambah kategori',
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
          showCategoryForm(context, data: data, kind: _kind);
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
        data: (data) => _body(context, data),
      ),
    );
  }

  Widget _body(BuildContext context, FinanceSnapshot data) {
    final usage = <String, int>{};
    for (final t in data.transactions) {
      final id = t.categoryId;
      if (id != null) {
        usage[id] = (usage[id] ?? 0) + 1;
      }
    }
    final items = data.categories.where((c) => c.kind == _kind).toList();

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
                Space.lg,
                Space.sm,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<CategoryKind>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: CategoryKind.expense,
                      label: Text('Pengeluaran'),
                    ),
                    ButtonSegment(
                      value: CategoryKind.income,
                      label: Text('Pemasukan'),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.sm,
                  Space.lg,
                  96,
                ),
                children: [
                  for (final c in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: _CategoryTile(
                        category: c,
                        count: usage[c.id] ?? 0,
                        onTap: () => showCategoryForm(
                          context,
                          data: data,
                          kind: c.kind,
                          existing: c,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.count,
    required this.onTap,
  });

  final TxCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info =
        '${category.isDefault ? 'Bawaan · ' : ''}${count == 0 ? 'Belum dipakai' : '$count transaksi'}';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.md,
      ),
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
              iconForKey(category.iconKey),
              size: 20,
              color: Color(category.color),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  info,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
