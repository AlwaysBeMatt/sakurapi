import 'dart:math';

import '../core/dates.dart';
import 'models/money_transaction.dart';
import 'models/savings_goal.dart';

enum GoalStatus { inProgress, achieved, overdue, noDeadline }

class GoalProgress {
  const GoalProgress({
    required this.collected,
    required this.target,
    required this.status,
    this.daysLeft,
    this.monthsLeft,
    this.monthlyNeeded,
  });

  final int collected;
  final int target;
  final GoalStatus status;

  /// Null jika tanpa tenggat. Negatif jika tenggat sudah terlewat.
  final int? daysLeft;
  final int? monthsLeft;

  /// Null jika tanpa tenggat atau tenggat terlewat. 0 jika target tercapai.
  final int? monthlyNeeded;

  int get remaining => max(0, target - collected);
  double get percent => target <= 0 ? 0 : collected * 100 / target;
  double get barValue => (percent / 100).clamp(0.0, 1.0);
}

abstract final class GoalCalculator {
  /// Nominal awal + setoran - penarikan.
  static int collected(SavingsGoal goal, Iterable<MoneyTransaction> txs) => txs
      .where((t) => t.goalId == goal.id)
      .fold(goal.initialAmount, (sum, t) => sum + t.goalSignedAmount);

  static GoalProgress evaluate(
    SavingsGoal goal,
    Iterable<MoneyTransaction> txs, {
    required DateTime today,
  }) {
    final c = collected(goal, txs);
    final target = goal.targetAmount;
    final remaining = max(0, target - c);
    final deadline = goal.targetDate;
    final days = deadline == null ? null : daysBetween(today, deadline);
    final months = deadline == null
        ? null
        : max(0, wholeMonthsBetween(today, deadline));

    if (target > 0 && remaining == 0) {
      return GoalProgress(
        collected: c,
        target: target,
        status: GoalStatus.achieved,
        daysLeft: days,
        monthsLeft: months,
        monthlyNeeded: 0,
      );
    }
    if (deadline == null) {
      return GoalProgress(
        collected: c,
        target: target,
        status: GoalStatus.noDeadline,
      );
    }
    if (days! < 0) {
      return GoalProgress(
        collected: c,
        target: target,
        status: GoalStatus.overdue,
        daysLeft: days,
        monthsLeft: 0,
      );
    }
    // Kurang dari sebulan dihitung satu periode: sisa dana dibutuhkan bulan ini.
    final periods = max(1, months!);
    return GoalProgress(
      collected: c,
      target: target,
      status: GoalStatus.inProgress,
      daysLeft: days,
      monthsLeft: months,
      monthlyNeeded: (remaining + periods - 1) ~/ periods, // dibulatkan ke atas
    );
  }
}
