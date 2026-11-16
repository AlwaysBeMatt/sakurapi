import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/errors.dart';
import '../../domain/models/account.dart';
import '../../domain/models/savings_goal.dart';
import '../../state/providers.dart';
import '../theme/finance_ui.dart';
import '../theme/tokens.dart';
import '../widgets/amount_field.dart';
import '../widgets/section_label.dart';

const _goalIcons = {
  'savings': 'Tabungan',
  'star': 'Bintang',
  'gift': 'Hadiah',
  'school': 'Pendidikan',
  'bag': 'Belanja',
  'wallet': 'Dompet',
  'health': 'Kesehatan',
  'work': 'Pekerjaan',
};

const _goalColors = [
  0xFF176B55,
  0xFF2F80ED,
  0xFF9B51E0,
  0xFFE76F72,
  0xFFE6A23C,
  0xFF56B4D3,
];

/// Membuka form tambah (existing == null) atau ubah target tabungan.
Future<void> openGoalForm(
  BuildContext context, {
  required FinanceSnapshot data,
  SavingsGoal? existing,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => GoalFormPage(data: data, existing: existing),
    ),
  );
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class GoalFormPage extends ConsumerStatefulWidget {
  const GoalFormPage({super.key, required this.data, this.existing});

  final FinanceSnapshot data;
  final SavingsGoal? existing;

  @override
  ConsumerState<GoalFormPage> createState() => _GoalFormPageState();
}

class _GoalFormPageState extends ConsumerState<GoalFormPage> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _initial = TextEditingController();
  final _note = TextEditingController();

  String? _accountId;
  DateTime? _date;
  String _iconKey = 'savings';
  int _color = _goalColors.first;

  String? _nameError;
  String? _targetError;
  String? _initialError;
  String? _formError;
  bool _busy = false;

  List<Account> get _accounts =>
      widget.data.accounts.where((a) => !a.archived).toList();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _target.text = Money.formatPlain(e.targetAmount);
      _initial.text = e.initialAmount > 0
          ? Money.formatPlain(e.initialAmount)
          : '';
      _note.text = e.note ?? '';
      _accountId = e.accountId;
      _date = e.targetDate;
      _iconKey = e.iconKey;
      _color = e.color;
    } else {
      final accounts = _accounts;
      Account? pick;
      for (final a in accounts) {
        if (a.type == AccountType.savings) {
          pick ??= a;
        }
      }
      pick ??= accounts.isEmpty ? null : accounts.first;
      _accountId = pick?.id;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _initial.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = dateOnly(picked));
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = Money.tryParse(_target.text);
    final initialText = _initial.text.trim();
    final initial = initialText.isEmpty ? 0 : Money.tryParse(initialText);

    final nameError = name.isEmpty ? 'Nama target wajib diisi.' : null;
    final targetError = (target == null || target <= 0)
        ? 'Masukkan target nominal yang valid (lebih dari Rp0).'
        : null;
    final initialError = initial == null ? 'Nominal awal tidak valid.' : null;
    final formError = _accountId == null ? 'Pilih akun penyimpanan.' : null;

    setState(() {
      _nameError = nameError;
      _targetError = targetError;
      _initialError = initialError;
      _formError = formError;
    });
    if (nameError != null ||
        targetError != null ||
        initialError != null ||
        formError != null) {
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(financeRepositoryProvider);
    final existing = widget.existing;
    final noteText = _note.text.trim();
    try {
      if (existing == null) {
        await repo.createGoal(
          name: name,
          targetAmount: target!,
          accountId: _accountId!,
          initialAmount: initial!,
          targetDate: _date,
          iconKey: _iconKey,
          color: _color,
          note: noteText.isEmpty ? null : noteText,
        );
      } else {
        await repo.updateGoal(
          existing.copyWith(
            name: name,
            targetAmount: target!,
            initialAmount: initial!,
            targetDate: _date,
            clearTargetDate: _date == null,
            iconKey: _iconKey,
            color: _color,
            note: noteText,
          ),
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context)
          .pop(existing == null ? 'Target disimpan' : 'Target diperbarui');
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
    final isEdit = widget.existing != null;
    final accounts = _accounts;
    final colors = _goalColors.contains(_color)
        ? _goalColors
        : [_color, ..._goalColors];

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Ubah target' : 'Tambah target')),
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
                        TextField(
                          controller: _name,
                          maxLength: 60,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: 'Nama target',
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
                        AmountField(
                          controller: _target,
                          label: 'Target nominal',
                          errorText: _targetError,
                          onChanged: (_) {
                            if (_targetError != null) {
                              setState(() => _targetError = null);
                            }
                          },
                        ),
                        const SizedBox(height: Space.lg),
                        AmountField(
                          controller: _initial,
                          label: 'Dana awal (opsional)',
                          errorText: _initialError,
                          onChanged: (_) {
                            if (_initialError != null) {
                              setState(() => _initialError = null);
                            }
                          },
                        ),
                        const SizedBox(height: Space.lg),
                        const SectionLabel('Tenggat'),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(Icons.event),
                                label: Text(
                                  _date == null
                                      ? 'Tanpa tenggat'
                                      : DateFormat(
                                          'EEEE, d MMMM yyyy',
                                          'id_ID',
                                        ).format(_date!),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (_date != null)
                              IconButton(
                                tooltip: 'Hapus tenggat',
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() => _date = null),
                              ),
                          ],
                        ),
                        const SizedBox(height: Space.lg),
                        const SectionLabel('Akun penyimpanan'),
                        if (isEdit) ...[
                          Text(
                            widget.data.accountById[_accountId]?.name ?? '-',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            'Akun penyimpanan tidak bisa diubah.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ] else ...[
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
                          const SizedBox(height: Space.xs),
                          Text(
                            'Setoran adalah transfer dari akun lain ke akun ini.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: Space.lg),
                        const SectionLabel('Ikon'),
                        Wrap(
                          spacing: Space.sm,
                          runSpacing: Space.sm,
                          children: [
                            for (final e in _goalIcons.entries)
                              ChoiceChip(
                                showCheckmark: false,
                                tooltip: e.value,
                                label: Icon(iconForKey(e.key), size: 20),
                                selected: _iconKey == e.key,
                                onSelected: (_) =>
                                    setState(() => _iconKey = e.key),
                              ),
                          ],
                        ),
                        const SizedBox(height: Space.lg),
                        const SectionLabel('Warna'),
                        Wrap(
                          spacing: Space.sm,
                          runSpacing: Space.sm,
                          children: [
                            for (final c in colors)
                              _ColorDot(
                                color: Color(c),
                                selected: _color == c,
                                onTap: () => setState(() => _color = c),
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

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Warna target',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
