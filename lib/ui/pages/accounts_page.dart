import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models/account.dart';
import '../../state/providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import 'account_form_sheet.dart';

IconData iconForAccountType(AccountType type) => switch (type) {
  AccountType.cash => Icons.payments_outlined,
  AccountType.bank => Icons.account_balance_outlined,
  AccountType.ewallet => Icons.account_balance_wallet_outlined,
  AccountType.savings => Icons.savings_outlined,
};

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(financeSnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        tooltip: 'Tambah akun',
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
          showAccountForm(context, data: data);
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
        data: (data) => _AccountsBody(data: data),
      ),
    );
  }
}

class _AccountsBody extends StatelessWidget {
  const _AccountsBody({required this.data});

  final FinanceSnapshot data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = data.accounts.where((a) => !a.archived).toList();
    final archived = data.accounts.where((a) => a.archived).toList();

    Widget tile(Account a) => Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: _AccountTile(
        account: a,
        balance: data.balances[a.id] ?? 0,
        onTap: () => showAccountForm(context, data: data, existing: a),
      ),
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 96),
          children: [
            for (final a in active) tile(a),
            if (archived.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Text(
                  'Diarsipkan',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final a in archived) tile(a),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.balance,
    required this.onTap,
  });

  final Account account;
  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            iconForAccountType(account.type),
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  account.type.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                Money.format(balance),
                style: AppText.tabular(theme.textTheme.titleSmall)
                    ?.copyWith(color: balance < 0 ? colors.expenseText : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
