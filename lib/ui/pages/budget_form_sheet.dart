import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/errors.dart';
import '../../domain/models/budget.dart';
import '../../domain/models/tx_category.dart';
import '../../state/providers.dart';
import '../theme/finance_ui.dart';
import '../theme/tokens.dart';
import '../widgets/amount_field.dart';
import '../widgets/section_label.dart';

/// Membuka form tambah (existing == null) atau ubah anggaran.
Future<void> showBudgetForm(
  BuildContext context, {
  required FinanceSnapshot data,
  Budget? existing,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BudgetFormSheet(data: data, existing: existing),
  );
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

const _allKey = '__all__';

class _Option {
  const _Option(this.key, this.name, this.icon);
  final String key;
  final String name;
  final IconData icon;
}

class _BudgetFormSheet extends ConsumerStatefulWidget {
  const _BudgetFormSheet({required this.data, this.existing});

  final FinanceSnapshot data;
  final Budget? existing;

  @override
  ConsumerState<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<_BudgetFormSheet> {
  final _amount = TextEditingController();
  String? _choice;
  String? _amountError;
  String? _formError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amount.text = Money.formatPlain(e.limitAmount);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// Kategori yang belum punya anggaran, plus "Semua pengeluaran".
  List<_Option> get _options {
    final used = {for (final b in widget.data.budgets) b.categoryId};
    return [
      if (!used.contains(null))
        const _Option(_allKey, 'Semua pengeluaran', Icons.pie_chart_outline),
      for (final c in widget.data.categories)
        if (c.kind == CategoryKind.expense && !used.contains(c.id))
          _Option(c.id, c.name, iconForKey(c.iconKey)),
    ];
  }

  String get _existingName {
    final id = widget.existing!.categoryId;
    if (id == null) {
      return 'Semua pengeluaran';
    }
    return widget.data.categoryById[id]?.name ?? 'Kategori dihapus';
  }

  Future<void> _save() async {
    final existing = widget.existing;
    final amount = Money.tryParse(_amount.text);
    final amountError = (amount == null || amount <= 0)
        ? 'Masukkan batas yang valid (lebih dari Rp0).'
        : null;
    final formError = (existing == null && _choice == null)
        ? 'Pilih kategori.'
        : null;
    setState(() {
      _amountError = amountError;
      _formError = formError;
    });
    if (amountError != null || formError != null) {
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(financeRepositoryProvider);
    try {
      await repo.saveBudget(
        id: existing?.id,
        categoryId: existing != null
            ? existing.categoryId
            : (_choice == _allKey ? null : _choice),
        limitAmount: amount!,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context)
          .pop(existing == null ? 'Anggaran disimpan' : 'Anggaran diperbarui');
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _formError = e.message;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _formError = 'Gagal menyimpan. Coba lagi.';
          _busy = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus anggaran?'),
        content: const Text(
          'Anggaran ini akan dihapus. Transaksi tidak terpengaruh.',
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
    if (ok != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(financeRepositoryProvider).deleteBudget(existing.id);
      if (mounted) {
        Navigator.of(context).pop('Anggaran dihapus');
      }
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _formError = e.message;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _formError = 'Gagal menghapus. Coba lagi.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;
    final options = isEdit ? const <_Option>[] : _options;
    final noOptions = !isEdit && options.isEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Space.lg,
          0,
          Space.lg,
          Space.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Ubah anggaran' : 'Tambah anggaran',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Space.lg),
            if (isEdit) ...[
              const SectionLabel('Kategori'),
              Text(_existingName, style: theme.textTheme.bodyLarge),
              const SizedBox(height: Space.xs),
              Text(
                'Kategori tidak bisa diubah. Hapus lalu buat ulang bila perlu.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else if (noOptions)
              Text(
                'Semua kategori pengeluaran sudah punya anggaran.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              const SectionLabel('Kategori'),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final o in options)
                    ChoiceChip(
                      avatar: Icon(o.icon, size: 18),
                      label: Text(o.name),
                      selected: _choice == o.key,
                      onSelected: (_) => setState(() {
                        _choice = o.key;
                        _formError = null;
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Space.lg),
            AmountField(
              controller: _amount,
              label: 'Batas per bulan',
              errorText: _amountError,
              onChanged: (_) {
                if (_amountError != null) {
                  setState(() => _amountError = null);
                }
              },
            ),
            if (_formError != null) ...[
              const SizedBox(height: Space.lg),
              FormErrorText(_formError!),
            ],
            const SizedBox(height: Space.xl),
            Row(
              children: [
                if (isEdit) ...[
                  TextButton(
                    onPressed: _busy ? null : _delete,
                    child: const Text('Hapus'),
                  ),
                  const SizedBox(width: Space.sm),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: (_busy || noOptions) ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
