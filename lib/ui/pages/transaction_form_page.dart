import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/errors.dart';
import '../../domain/models/account.dart';
import '../../domain/models/money_transaction.dart';
import '../../domain/models/tx_category.dart';
import '../../state/providers.dart';
import '../theme/finance_ui.dart';
import '../theme/tokens.dart';
import '../widgets/rupiah_input.dart';

Future<bool> confirmDeleteTransaction(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus transaksi?'),
      content: const Text(
        'Saldo, anggaran, dan statistik akan diperbarui. '
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
  return ok ?? false;
}

/// Menghapus transaksi dan menampilkan hasilnya lewat SnackBar.
Future<void> deleteTransactionWithFeedback(
  BuildContext context,
  WidgetRef ref,
  MoneyTransaction tx,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(financeRepositoryProvider).deleteTransaction(tx.id);
    messenger.showSnackBar(const SnackBar(content: Text('Transaksi dihapus')));
  } on ValidationException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Gagal menghapus. Coba lagi.')),
    );
  }
}

/// Membuka form tambah (existing == null) atau ubah.
Future<void> openTransactionForm(
  BuildContext context,
  WidgetRef ref, {
  MoneyTransaction? existing,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final data = ref.read(financeSnapshotProvider).value;
  if (data == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Data belum siap. Coba sebentar lagi.')),
    );
    return;
  }

  if (existing?.goalId != null) {
    final delete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transaksi tabungan'),
        content: const Text(
          'Setoran dan penarikan tabungan dikelola dari halaman Tabungan, '
          'jadi tidak bisa diubah di sini. Anda masih bisa menghapusnya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (delete == true && context.mounted) {
      await deleteTransactionWithFeedback(context, ref, existing!);
    }
    return;
  }

  final message = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => TransactionFormPage(data: data, existing: existing),
    ),
  );
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({super.key, required this.data, this.existing});

  final FinanceSnapshot data;
  final MoneyTransaction? existing;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _amount = TextEditingController();
  final _title = TextEditingController();
  final _note = TextEditingController();

  late TransactionType _type;
  late DateTime _date;
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  String? _amountError;
  String? _formError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type = e.type;
      _date = e.date;
      _categoryId = e.categoryId;
      _accountId = e.accountId;
      _toAccountId = e.toAccountId;
      _amount.text = Money.formatPlain(e.amount);
      _title.text = e.title;
      _note.text = e.note ?? '';
    } else {
      _type = TransactionType.expense;
      _date = dateOnly(ref.read(clockProvider)());
      _accountId = _accounts.isEmpty ? null : _accounts.first.id;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  List<Account> get _accounts => widget.data.accounts
      .where(
        (a) =>
            !a.archived ||
            a.id == widget.existing?.accountId ||
            a.id == widget.existing?.toAccountId,
      )
      .toList();

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
      if (type == TransactionType.transfer) {
        _categoryId = null;
        if (_toAccountId == null || _toAccountId == _accountId) {
          _toAccountId = _firstOtherAccount();
        }
      } else {
        _toAccountId = null;
        final valid = _categories.any((c) => c.id == _categoryId);
        if (!valid) {
          _categoryId = null;
        }
      }
    });
  }

  String? _firstOtherAccount() {
    for (final a in _accounts) {
      if (a.id != _accountId) {
        return a.id;
      }
    }
    return null;
  }

  Future<void> _pickDate() async {
    final today = dateOnly(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null) {
      setState(() => _date = dateOnly(picked));
    }
  }

  Future<void> _save() async {
    final amount = Money.tryParse(_amount.text);
    final amountError = (amount == null || amount <= 0)
        ? 'Masukkan nominal yang valid (lebih dari Rp0).'
        : null;
    String? formError;
    if (_accountId == null) {
      formError = 'Pilih akun.';
    } else if (_type == TransactionType.transfer && _toAccountId == null) {
      formError = 'Pilih akun tujuan. Transfer membutuhkan minimal dua akun.';
    } else if (_type != TransactionType.transfer && _categoryId == null) {
      formError = 'Pilih kategori.';
    }
    setState(() {
      _amountError = amountError;
      _formError = formError;
    });
    if (amountError != null || formError != null) {
      return;
    }

    setState(() => _busy = true);
    final input = TransactionInput(
      type: _type,
      amount: amount!,
      accountId: _accountId!,
      toAccountId: _type == TransactionType.transfer ? _toAccountId : null,
      categoryId: _type == TransactionType.transfer ? null : _categoryId,
      title: _title.text,
      note: _note.text,
      date: _date,
    );
    final repo = ref.read(financeRepositoryProvider);
    final existing = widget.existing;
    try {
      if (existing == null) {
        await repo.addTransaction(input);
      } else {
        await repo.updateTransaction(existing.id, input);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pop(existing == null ? 'Transaksi disimpan' : 'Transaksi diperbarui');
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
    if (!await confirmDeleteTransaction(context)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(financeRepositoryProvider).deleteTransaction(existing.id);
      if (mounted) {
        Navigator.of(context).pop('Transaksi dihapus');
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
    final colors = FinanceColors.of(context);
    final isEdit = widget.existing != null;
    final accounts = _accounts;
    final isTransfer = _type == TransactionType.transfer;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Ubah transaksi' : 'Tambah transaksi'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'Hapus transaksi',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<TransactionType>(
                          showSelectedIcon: false,
                          segments: [
                            for (final t in TransactionType.values)
                              ButtonSegment(
                                value: t,
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(typeLabel(t), maxLines: 1),
                                ),
                              ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (s) => _setType(s.first),
                        ),
                        const SizedBox(height: Space.xl),
                        TextField(
                          controller: _amount,
                          autofocus: !isEdit,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                            RupiahInputFormatter(),
                          ],
                          style: AppText.tabular(
                            theme.textTheme.headlineMedium,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Nominal',
                            prefixText: 'Rp ',
                            errorText: _amountError,
                          ),
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
                            labelText: 'Nama transaksi (opsional)',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: Space.lg),
                        if (!isTransfer) ...[
                          _SectionLabel('Kategori'),
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
                        ],
                        _SectionLabel(
                          isTransfer
                              ? 'Dari akun'
                              : (_type == TransactionType.income
                                    ? 'Masuk ke akun'
                                    : 'Dibayar dari akun'),
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
                                  if (_toAccountId == a.id) {
                                    _toAccountId = null;
                                  }
                                  _formError = null;
                                }),
                              ),
                          ],
                        ),
                        if (isTransfer) ...[
                          const SizedBox(height: Space.lg),
                          _SectionLabel('Ke akun'),
                          if (accounts.length < 2)
                            Text(
                              'Transfer membutuhkan minimal dua akun. '
                              'Fitur menambah akun tersedia di fase 7.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          else
                            Wrap(
                              spacing: Space.sm,
                              runSpacing: Space.sm,
                              children: [
                                for (final a in accounts)
                                  if (a.id != _accountId)
                                    ChoiceChip(
                                      label: Text(a.name),
                                      selected: _toAccountId == a.id,
                                      onSelected: (_) => setState(() {
                                        _toAccountId = a.id;
                                        _formError = null;
                                      }),
                                    ),
                              ],
                            ),
                        ],
                        const SizedBox(height: Space.lg),
                        _SectionLabel('Tanggal'),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.event),
                          label: Text(
                            DateFormat(
                              'EEEE, d MMMM yyyy',
                              'id_ID',
                            ).format(_date),
                          ),
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 20,
                                color: colors.expenseText,
                              ),
                              const SizedBox(width: Space.sm),
                              Expanded(
                                child: Text(
                                  _formError!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.expenseText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.lg,
                    Space.sm,
                    Space.lg,
                    Space.lg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Simpan'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
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
