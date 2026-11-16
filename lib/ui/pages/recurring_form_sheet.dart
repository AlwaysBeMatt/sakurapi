import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/errors.dart';
import '../../domain/models/account.dart';
import '../../domain/models/money_transaction.dart';
import '../../domain/models/recurring_rule.dart';
import '../../domain/models/tx_category.dart';
import '../../state/providers.dart';
import '../theme/finance_ui.dart';
import '../theme/tokens.dart';
import '../widgets/amount_field.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/section_label.dart';

/// Membuka form tambah (existing == null) atau ubah transaksi berulang.
Future<void> showRecurringForm(
  BuildContext context, {
  required FinanceSnapshot data,
  RecurringRule? existing,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RecurringFormSheet(data: data, existing: existing),
  );
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RecurringFormSheet extends ConsumerStatefulWidget {
  const _RecurringFormSheet({required this.data, this.existing});

  final FinanceSnapshot data;
  final RecurringRule? existing;

  @override
  ConsumerState<_RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends ConsumerState<_RecurringFormSheet> {
  final _amount = TextEditingController();
  final _title = TextEditingController();
  final _note = TextEditingController();

  TransactionType _type = TransactionType.expense;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  String? _categoryId;
  String? _accountId;
  late DateTime _start;
  DateTime? _end;
  String? _amountError;
  String? _formError;
  bool _busy = false;

  DateTime get _today => dateOnly(ref.read(clockProvider)());

  List<Account> get _accounts => widget.data.accounts
      .where((a) => !a.archived || a.id == widget.existing?.accountId)
      .toList();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type = e.type;
      _frequency = e.frequency;
      _categoryId = e.categoryId;
      _accountId = e.accountId;
      _start = e.startDate;
      _end = e.endDate;
      _amount.text = Money.formatPlain(e.amount);
      _title.text = e.title;
      _note.text = e.note ?? '';
    } else {
      _start = _today;
      final active = widget.data.accounts.where((a) => !a.archived).toList();
      _accountId = active.isEmpty ? null : active.first.id;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  List<TxCategory> get _categories {
    final kind = _type == TransactionType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    return widget.data.categories.where((c) => c.kind == kind).toList();
  }

  void _setType(TransactionType type) {
    setState(() {
      _type = type;
      _formError = null;
      if (!_categories.any((c) => c.id == _categoryId)) {
        _categoryId = null;
      }
    });
  }

  Future<void> _pickStart() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(today.year, today.month, today.day - 400),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null) {
      setState(() {
        _start = dateOnly(picked);
        final end = _end;
        if (end != null && end.isBefore(_start)) {
          _end = null;
        }
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? _start,
      firstDate: _start,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _end = dateOnly(picked));
    }
  }

  Future<void> _submit(Future<void> Function() action, String message) async {
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await action();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(message);
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
    final amount = Money.tryParse(_amount.text);
    final amountError = (amount == null || amount <= 0)
        ? 'Masukkan nominal yang valid (lebih dari Rp0).'
        : null;
    String? formError;
    if (_accountId == null) {
      formError = 'Pilih akun.';
    } else if (_categoryId == null) {
      formError = 'Pilih kategori.';
    }
    setState(() {
      _amountError = amountError;
      _formError = formError;
    });
    if (amountError != null || formError != null) {
      return;
    }

    final repo = ref.read(financeRepositoryProvider);
    final existing = widget.existing;
    final noteText = _note.text.trim();
    if (existing == null) {
      _submit(() async {
        await repo.createRecurringRule(
          type: _type,
          amount: amount!,
          categoryId: _categoryId!,
          accountId: _accountId!,
          frequency: _frequency,
          startDate: _start,
          endDate: _end,
          title: _title.text,
          note: noteText,
        );
      }, 'Transaksi berulang disimpan');
    } else {
      _submit(() async {
        await repo.updateRecurringRule(
          existing.copyWith(
            amount: amount!,
            title: _title.text.trim(),
            categoryId: _categoryId!,
            accountId: _accountId!,
            endDate: _end,
            clearEndDate: _end == null,
            note: noteText,
            clearNote: noteText.isEmpty,
          ),
        );
      }, 'Transaksi berulang diperbarui');
    }
  }

  void _toggleActive() {
    final existing = widget.existing!;
    final repo = ref.read(financeRepositoryProvider);
    if (existing.active) {
      _submit(() async {
        await repo.updateRecurringRule(existing.copyWith(active: false));
      }, 'Transaksi berulang dijeda');
    } else {
      final resumed = existing.copyWith(active: true).skipTo(_today);
      _submit(() async {
        await repo.updateRecurringRule(resumed);
      }, 'Transaksi berulang diaktifkan kembali');
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final ok = await confirmDialog(
      context,
      title: 'Hapus transaksi berulang?',
      message:
          'Aturan ini dihapus. Transaksi yang sudah tercatat tidak ikut terhapus.',
    );
    if (!ok || !mounted) {
      return;
    }
    final repo = ref.read(financeRepositoryProvider);
    await _submit(() async {
      await repo.deleteRecurringRule(existing.id);
    }, 'Transaksi berulang dihapus');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final existing = widget.existing;
    final isEdit = existing != null;
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final accounts = _accounts;

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
              isEdit ? 'Ubah transaksi berulang' : 'Tambah transaksi berulang',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Space.lg),
            if (!isEdit) ...[
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
                onSelectionChanged: (s) => _setType(s.first),
              ),
              const SizedBox(height: Space.lg),
            ],
            AmountField(
              controller: _amount,
              label: 'Nominal',
              errorText: _amountError,
              onChanged: (_) {
                if (_amountError != null) {
                  setState(() => _amountError = null);
                }
              },
            ),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _title,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nama (opsional)',
                counterText: '',
              ),
            ),
            const SizedBox(height: Space.lg),
            const SectionLabel('Kategori'),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final c in _categories)
                  ChoiceChip(
                    avatar: Icon(iconForKey(c.iconKey), size: 18),
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() {
                      _categoryId = c.id;
                      _formError = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            SectionLabel(
              _type == TransactionType.income ? 'Masuk ke akun' : 'Dibayar dari akun',
            ),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final a in accounts)
                  ChoiceChip(
                    label: Text(a.name),
                    selected: _accountId == a.id,
                    onSelected: (_) => setState(() {
                      _accountId = a.id;
                      _formError = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            const SectionLabel('Frekuensi'),
            if (isEdit)
              Text(
                '${_frequency.label}, mulai ${dateFormat.format(_start)}. '
                'Frekuensi dan tanggal mulai tidak bisa diubah. Hapus lalu buat ulang bila perlu.',
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              )
            else ...[
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final f in RecurrenceFrequency.values)
                    ChoiceChip(
                      label: Text(f.label),
                      selected: _frequency == f,
                      onSelected: (_) => setState(() => _frequency = f),
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
              const SectionLabel('Mulai tanggal'),
              OutlinedButton.icon(
                onPressed: _pickStart,
                icon: const Icon(Icons.event),
                label: Text(dateFormat.format(_start)),
              ),
              const SizedBox(height: Space.xs),
              Text(
                'Jika tanggal mulai sudah lewat, transaksi yang terlewat langsung dicatat.',
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ],
            const SizedBox(height: Space.lg),
            const SectionLabel('Berakhir (opsional)'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEnd,
                    icon: const Icon(Icons.event_busy_outlined),
                    label: Text(
                      _end == null ? 'Tanpa tanggal berakhir' : dateFormat.format(_end!),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_end != null)
                  IconButton(
                    tooltip: 'Hapus tanggal berakhir',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _end = null),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _note,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                counterText: '',
              ),
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
            if (existing != null) ...[
              const SizedBox(height: Space.sm),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  if (!existing.isFinished)
                    TextButton.icon(
                      onPressed: _busy ? null : _toggleActive,
                      icon: Icon(
                        existing.active
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                      ),
                      label: Text(existing.active ? 'Jeda' : 'Aktifkan kembali'),
                    ),
                  TextButton.icon(
                    onPressed: _busy ? null : _delete,
                    style: TextButton.styleFrom(foregroundColor: colors.expenseText),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}