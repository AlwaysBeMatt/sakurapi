import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/errors.dart';
import '../../domain/goal_calculator.dart';
import '../../domain/models/account.dart';
import '../../domain/models/savings_goal.dart';
import '../../state/providers.dart';
import '../theme/tokens.dart';
import '../widgets/amount_field.dart';
import '../widgets/section_label.dart';

/// Form setor ([deposit] true) atau tarik dana dari target tabungan.
Future<void> showGoalMoneySheet(
  BuildContext context, {
  required FinanceSnapshot data,
  required SavingsGoal goal,
  required bool deposit,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _GoalMoneySheet(data: data, goal: goal, deposit: deposit),
  );
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GoalMoneySheet extends ConsumerStatefulWidget {
  const _GoalMoneySheet({
    required this.data,
    required this.goal,
    required this.deposit,
  });

  final FinanceSnapshot data;
  final SavingsGoal goal;
  final bool deposit;

  @override
  ConsumerState<_GoalMoneySheet> createState() => _GoalMoneySheetState();
}

class _GoalMoneySheetState extends ConsumerState<_GoalMoneySheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date;
  String? _accountId;
  String? _amountError;
  String? _formError;
  bool _busy = false;

  /// Akun lawan transfer: semua akun aktif selain akun penyimpanan target.
  List<Account> get _others => widget.data.accounts
      .where((a) => !a.archived && a.id != widget.goal.accountId)
      .toList();

  @override
  void initState() {
    super.initState();
    _date = dateOnly(ref.read(clockProvider)());
    final others = _others;
    _accountId = others.isEmpty ? null : others.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
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
    final formError = _accountId == null ? 'Pilih akun.' : null;
    setState(() {
      _amountError = amountError;
      _formError = formError;
    });
    if (amountError != null || formError != null) {
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(financeRepositoryProvider);
    final noteText = _note.text.trim();
    final note = noteText.isEmpty ? null : noteText;
    try {
      if (widget.deposit) {
        await repo.depositToGoal(
          goalId: widget.goal.id,
          fromAccountId: _accountId!,
          amount: amount!,
          date: _date,
          note: note,
        );
      } else {
        await repo.withdrawFromGoal(
          goalId: widget.goal.id,
          toAccountId: _accountId!,
          amount: amount!,
          date: _date,
          note: note,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context)
          .pop(widget.deposit ? 'Setoran disimpan' : 'Penarikan disimpan');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final others = _others;
    final goalAccount = widget.data.accountById[widget.goal.accountId]?.name;
    final collected = GoalCalculator.collected(
      widget.goal,
      widget.data.transactions,
    );

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
              widget.deposit ? 'Setor ke tabungan' : 'Tarik dari tabungan',
              style: theme.textTheme.titleLarge,
            ),
            if (!widget.deposit) ...[
              const SizedBox(height: Space.xs),
              Text(
                'Dana terkumpul saat ini ${Money.format(collected)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: Space.lg),
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
            SectionLabel(widget.deposit ? 'Dari akun' : 'Ke akun'),
            if (others.isEmpty)
              Text(
                'Dibutuhkan akun lain selain "${goalAccount ?? '-'}". '
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
                  for (final a in others)
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
            const SectionLabel('Tanggal'),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(
                DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_date),
              ),
            ),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _note,
              maxLength: 500,
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
              onPressed: (_busy || others.isEmpty) ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
