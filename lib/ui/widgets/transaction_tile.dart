import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/models/money_transaction.dart';
import '../../state/providers.dart';
import '../theme/finance_ui.dart';
import '../theme/tokens.dart';
import 'app_card.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.tx,
    required this.data,
    required this.onTap,
  });

  final MoneyTransaction tx;
  final FinanceSnapshot data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final category = data.categoryById[tx.categoryId];
    final from = data.accountById[tx.accountId]?.name ?? '-';
    final to = data.accountById[tx.toAccountId]?.name ?? '-';

    final isTransfer = tx.type == TransactionType.transfer;
    final title = tx.title.isNotEmpty
        ? tx.title
        : (isTransfer ? 'Transfer' : (category?.name ?? 'Kategori dihapus'));
    final subtitle = isTransfer
        ? '$from → $to'
        : '${category?.name ?? 'Kategori dihapus'} · $from';

    final IconData icon;
    final Color iconColor;
    final String amountText;
    final Color? amountColor;
    switch (tx.type) {
      case TransactionType.income:
        icon = iconForKey(category?.iconKey ?? 'more');
        iconColor = colors.income;
        amountText = '+${Money.format(tx.amount)}';
        amountColor = colors.income;
      case TransactionType.expense:
        icon = iconForKey(category?.iconKey ?? 'more');
        iconColor = colors.expense;
        amountText = '-${Money.format(tx.amount)}';
        amountColor = colors.expenseText;
      case TransactionType.transfer:
        icon = Icons.swap_horiz;
        iconColor = theme.colorScheme.primary;
        amountText = Money.format(tx.amount);
        amountColor = null;
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.md,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                amountText,
                style: AppText.tabular(theme.textTheme.titleSmall)
                    ?.copyWith(color: amountColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
