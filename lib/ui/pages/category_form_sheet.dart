import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/errors.dart';
import '../../domain/models/tx_category.dart';
import '../../state/providers.dart';
import '../theme/finance_ui.dart';
import '../theme/tokens.dart';
import '../widgets/color_dot.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/section_label.dart';

const _iconNames = {
  'restaurant': 'Makanan',
  'bus': 'Transportasi',
  'basket': 'Kebutuhan',
  'school': 'Pendidikan',
  'movie': 'Hiburan',
  'receipt': 'Tagihan',
  'health': 'Kesehatan',
  'bag': 'Belanja',
  'wallet': 'Dompet',
  'work': 'Pekerjaan',
  'star': 'Bintang',
  'gift': 'Hadiah',
  'savings': 'Tabungan',
  'more': 'Lainnya',
};

const _palette = [
  0xFFE76F72,
  0xFFE6A23C,
  0xFF7A9E4E,
  0xFF18845B,
  0xFF2EA8A0,
  0xFF4F8FD8,
  0xFF8E6CC9,
  0xFFD97AA8,
  0xFF5B7C99,
  0xFF8A9690,
];

/// Membuka form tambah (existing == null) atau ubah kategori.
Future<void> showCategoryForm(
  BuildContext context, {
  required FinanceSnapshot data,
  required CategoryKind kind,
  TxCategory? existing,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _CategoryFormSheet(data: data, kind: kind, existing: existing),
  );
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CategoryFormSheet extends ConsumerStatefulWidget {
  const _CategoryFormSheet({
    required this.data,
    required this.kind,
    this.existing,
  });

  final FinanceSnapshot data;
  final CategoryKind kind;
  final TxCategory? existing;

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  final _name = TextEditingController();
  String _iconKey = 'more';
  int _color = _palette.last;
  String? _nameError;
  String? _formError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _iconKey = e.iconKey;
      _color = e.color;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await action();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(successMessage);
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
          _formError = 'Terjadi kesalahan. Coba lagi.';
          _busy = false;
        });
      }
    }
  }

  void _save() {
    final existing = widget.existing;
    final name = _name.text.trim();
    final readOnlyName = existing?.isDefault ?? false;
    final nameError = (!readOnlyName && name.isEmpty)
        ? 'Nama kategori wajib diisi.'
        : null;
    setState(() {
      _nameError = nameError;
      _formError = null;
    });
    if (nameError != null) {
      return;
    }

    final repo = ref.read(financeRepositoryProvider);
    if (existing == null) {
      _submit(() async {
        await repo.createCategory(
          name: name,
          kind: widget.kind,
          iconKey: _iconKey,
          color: _color,
        );
      }, 'Kategori disimpan');
    } else {
      _submit(() async {
        await repo.updateCategory(
          TxCategory(
            id: existing.id,
            name: existing.isDefault ? existing.name : name,
            kind: existing.kind,
            iconKey: _iconKey,
            color: _color,
            isDefault: existing.isDefault,
          ),
        );
      }, 'Kategori diperbarui');
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final hasBudget = widget.data.budgets.any(
      (b) => b.categoryId == existing.id,
    );
    final ok = await confirmDialog(
      context,
      title: 'Hapus kategori?',
      message: hasBudget
          ? 'Anggaran untuk kategori ini ikut terhapus. '
                'Tindakan ini tidak bisa dibatalkan.'
          : 'Tindakan ini tidak bisa dibatalkan.',
    );
    if (!ok || !mounted) {
      return;
    }
    final repo = ref.read(financeRepositoryProvider);
    await _submit(() async {
      await repo.deleteCategory(existing.id);
    }, 'Kategori dihapus');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final existing = widget.existing;
    final isEdit = existing != null;
    final readOnlyName = existing?.isDefault ?? false;
    final palette = _palette.contains(_color)
        ? _palette
        : [_color, ..._palette];

    final title = isEdit
        ? 'Ubah kategori'
        : (widget.kind == CategoryKind.expense
              ? 'Tambah kategori pengeluaran'
              : 'Tambah kategori pemasukan');

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
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: Space.lg),
            if (existing != null && existing.isDefault) ...[
              const SectionLabel('Nama'),
              Text(existing.name, style: theme.textTheme.bodyLarge),
              const SizedBox(height: Space.xs),
              Text(
                'Nama kategori bawaan tidak bisa diubah.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else
              TextField(
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nama kategori',
                  counterText: '',
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() => _nameError = null);
                  }
                },
              ),
            const SizedBox(height: Space.lg),
            const SectionLabel('Ikon'),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final e in _iconNames.entries)
                  ChoiceChip(
                    showCheckmark: false,
                    tooltip: e.value,
                    label: Icon(iconForKey(e.key), size: 20),
                    selected: _iconKey == e.key,
                    onSelected: (_) => setState(() => _iconKey = e.key),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            const SectionLabel('Warna'),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final c in palette)
                  ColorDot(
                    color: Color(c),
                    selected: _color == c,
                    label: 'Warna kategori',
                    onTap: () => setState(() => _color = c),
                  ),
              ],
            ),
            if (_formError != null) ...[
              const SizedBox(height: Space.lg),
              FormErrorText(_formError!),
            ],
            const SizedBox(height: Space.xl),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
            if (isEdit && !readOnlyName) ...[
              const SizedBox(height: Space.sm),
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: colors.expenseText,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus kategori'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
