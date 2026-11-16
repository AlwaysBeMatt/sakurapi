import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/account_rules.dart';
import '../../domain/errors.dart';
import '../../domain/models/account.dart';
import '../../state/providers.dart';
import '../theme/tokens.dart';
import '../widgets/amount_field.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/section_label.dart';

/// Membuka form tambah (existing == null) atau ubah akun.
Future<void> showAccountForm(
  BuildContext context, {
  required FinanceSnapshot data,
  Account? existing,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AccountFormSheet(data: data, existing: existing),
  );
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccountFormSheet extends ConsumerStatefulWidget {
  const _AccountFormSheet({required this.data, this.existing});

  final FinanceSnapshot data;
  final Account? existing;

  @override
  ConsumerState<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<_AccountFormSheet> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  AccountType _type = AccountType.cash;
  String? _nameError;
  String? _balanceError;
  String? _formError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _type = e.type;
      _balance.text = e.initialBalance > 0
          ? Money.formatPlain(e.initialBalance)
          : '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
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
    final balanceText = _balance.text.trim();
    final balance = balanceText.isEmpty ? 0 : Money.tryParse(balanceText);

    String? nameError;
    if (name.isEmpty) {
      nameError = 'Nama akun wajib diisi.';
    } else if (AccountRules.nameTaken(
      name,
      widget.data.accounts,
      exceptId: existing?.id,
    )) {
      nameError = 'Nama akun sudah dipakai.';
    }
    final balanceError = balance == null ? 'Saldo awal tidak valid.' : null;

    setState(() {
      _nameError = nameError;
      _balanceError = balanceError;
      _formError = null;
    });
    if (nameError != null || balanceError != null) {
      return;
    }

    final repo = ref.read(financeRepositoryProvider);
    if (existing == null) {
      _submit(() async {
        await repo.createAccount(
          name: name,
          type: _type,
          initialBalance: balance!,
        );
      }, 'Akun disimpan');
    } else {
      _submit(() async {
        await repo.updateAccount(
          existing.copyWith(name: name, type: _type, initialBalance: balance!),
        );
      }, 'Akun diperbarui');
    }
  }

  void _toggleArchive() {
    final existing = widget.existing!;
    if (!existing.archived) {
      final blocker = AccountRules.archiveBlocker(
        account: existing,
        all: widget.data.accounts,
        balances: widget.data.balances,
        goals: widget.data.goals,
      );
      if (blocker != null) {
        setState(() => _formError = blocker);
        return;
      }
    }
    final repo = ref.read(financeRepositoryProvider);
    _submit(() async {
      await repo.updateAccount(existing.copyWith(archived: !existing.archived));
    }, existing.archived ? 'Akun diaktifkan kembali' : 'Akun diarsipkan');
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final blocker = AccountRules.deleteBlocker(
      account: existing,
      all: widget.data.accounts,
    );
    if (blocker != null) {
      setState(() => _formError = blocker);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Hapus akun?',
      message:
          'Akun "${existing.name}" akan dihapus permanen. Akun yang sudah punya '
          'transaksi tidak bisa dihapus, arsipkan saja.',
    );
    if (!ok || !mounted) {
      return;
    }
    final repo = ref.read(financeRepositoryProvider);
    await _submit(() async {
      await repo.deleteAccount(existing.id);
    }, 'Akun dihapus');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final existing = widget.existing;
    final isEdit = existing != null;

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
              isEdit ? 'Ubah akun' : 'Tambah akun',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _name,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nama akun',
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
            const SectionLabel('Jenis akun'),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final t in AccountType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            AmountField(
              controller: _balance,
              label: 'Saldo awal',
              errorText: _balanceError,
              onChanged: (_) {
                if (_balanceError != null) {
                  setState(() => _balanceError = null);
                }
              },
            ),
            if (isEdit) ...[
              const SizedBox(height: Space.xs),
              Text(
                'Saldo saat ini ${Money.format(widget.data.balances[existing.id] ?? 0)}. '
                'Mengubah saldo awal ikut mengubah saldo saat ini.',
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ],
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
            if (isEdit) ...[
              const SizedBox(height: Space.sm),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : _toggleArchive,
                    icon: Icon(
                      existing.archived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                    label: Text(
                      existing.archived ? 'Aktifkan kembali' : 'Arsipkan',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.expenseText,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus akun'),
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
