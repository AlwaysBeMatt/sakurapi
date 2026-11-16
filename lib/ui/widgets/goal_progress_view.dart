import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../domain/goal_calculator.dart';
import '../../domain/models/savings_goal.dart';
import '../theme/finance_ui.dart';
import '../theme/tokens.dart';

final _percent = NumberFormat('#,##0.#', 'id_ID');

String goalStatusText(GoalProgress p) => switch (p.status) {
  GoalStatus.achieved => 'Target tercapai',
  GoalStatus.overdue => 'Tenggat terlewat',
  GoalStatus.noDeadline => 'Tanpa tenggat',
  GoalStatus.inProgress =>
    'Perlu ${Money.format(p.monthlyNeeded ?? 0)} per bulan · '
        'sisa ${p.daysLeft ?? 0} hari',
};

/// Nama, persen, bar progres, dan status satu target tabungan.
class GoalProgressView extends StatelessWidget {
  const GoalProgressView({
    super.key,
    required this.goal,
    required this.progress,
  });

  final SavingsGoal goal;
  final GoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final color = Color(goal.color);
    final p = progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(iconForKey(goal.iconKey), size: 20, color: color),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                goal.name,
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Space.sm),
            Text(
              '${_percent.format(p.percent)}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: p.barValue,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          color: color,
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
        const SizedBox(height: 4),
        Text(
          '${Money.format(p.collected)} dari ${Money.format(p.target)}',
          style: theme.textTheme.bodySmall?.copyWith(color: secondary),
        ),
        Text(
          goalStatusText(p),
          style: theme.textTheme.bodySmall?.copyWith(color: secondary),
        ),
      ],
    );
  }
}
