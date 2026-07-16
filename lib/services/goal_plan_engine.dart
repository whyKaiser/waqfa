import 'dart:math' as math;

import 'financial_decision_engine.dart';

enum GoalType {
  travel,
  car,
  emergencyFund,
  debtReduction,
  purchase,
  marriage,
  other,
}

enum GoalFeasibility {
  feasible,
  feasibleWithVariableReduction,
  feasibleWithExtension,
  unreachable,
}

enum GoalAdjustmentKind {
  none,
  reduceVariableSpending,
  extendDuration,
  unavailable,
}

class GoalAdjustment {
  final GoalAdjustmentKind recommendedKind;
  final double requiredVariableExpenseReduction;
  final bool variableReductionPossible;
  final int minimumExtensionDays;
  final int extendedTargetDays;
  final bool extensionPossible;

  const GoalAdjustment({
    required this.recommendedKind,
    required this.requiredVariableExpenseReduction,
    required this.variableReductionPossible,
    required this.minimumExtensionDays,
    required this.extendedTargetDays,
    required this.extensionPossible,
  });

  bool get requiresChange => recommendedKind != GoalAdjustmentKind.none;
}

class GoalWeeklyStep {
  final int weekNumber;
  final int startDay;
  final int endDay;
  final double contributionTarget;
  final double maxVariableSpending;
  final double cumulativeContribution;
  final String action;
  final String checkpoint;

  const GoalWeeklyStep({
    required this.weekNumber,
    required this.startDay,
    required this.endDay,
    required this.contributionTarget,
    required this.maxVariableSpending,
    required this.cumulativeContribution,
    required this.action,
    required this.checkpoint,
  });
}

class GoalPlan {
  final GoalType goalType;
  final double targetAmount;
  final int requestedTargetDays;
  final int effectiveTargetDays;
  final double requiredMonthlyContribution;
  final double plannedMonthlyContribution;
  final double safetyReserve;
  final double monthlySurplusBeforeGoal;
  final double monthlyRemainingAfterGoal;
  final double safeDailySpend;
  final GoalFeasibility feasibility;
  final GoalAdjustment minimumAdjustment;
  final List<GoalWeeklyStep> weeklySteps;

  const GoalPlan({
    required this.goalType,
    required this.targetAmount,
    required this.requestedTargetDays,
    required this.effectiveTargetDays,
    required this.requiredMonthlyContribution,
    required this.plannedMonthlyContribution,
    required this.safetyReserve,
    required this.monthlySurplusBeforeGoal,
    required this.monthlyRemainingAfterGoal,
    required this.safeDailySpend,
    required this.feasibility,
    required this.minimumAdjustment,
    required this.weeklySteps,
  });

  bool get isReachable => feasibility != GoalFeasibility.unreachable;

  bool get meetsRequestedDeadline =>
      feasibility == GoalFeasibility.feasible ||
      feasibility == GoalFeasibility.feasibleWithVariableReduction;
}

/// محرك حتمي لخطة هدف مالي. كل الأرقام مشتقة من الملف المالي والهدف،
/// ولا يعتمد أي قرار أو مبلغ على نموذج لغوي.
class GoalPlanEngine {
  static GoalPlan build({
    required FinancialProfile profile,
    required GoalType goalType,
    required double targetAmount,
    required int targetDays,
  }) {
    _validateInputs(
      profile: profile,
      targetAmount: targetAmount,
      targetDays: targetDays,
    );

    final reserve = math.max(500.0, profile.salary * .10);
    final requiredMonthly = targetAmount / targetDays * 30;
    _requireFinite(requiredMonthly, 'Required monthly contribution');

    final currentSurplus = profile.salary -
        profile.fixedExpenses -
        profile.variableExpenses -
        profile.currentBnpl -
        reserve;
    final availableAtCurrentSpending = math.max(0.0, currentSurplus);
    final reductionNeeded = targetAmount == 0
        ? 0.0
        : math.max(0.0, requiredMonthly - currentSurplus);
    final variableReductionPossible =
        reductionNeeded <= profile.variableExpenses;

    var extensionPossible = false;
    var extendedDays = targetDays;
    if (targetAmount == 0) {
      extensionPossible = true;
    } else if (availableAtCurrentSpending > 0) {
      final exactDays = targetAmount / availableAtCurrentSpending * 30;
      _requireFinite(exactDays, 'Extended target duration');
      extendedDays = math.max(targetDays, exactDays.ceil());
      extensionPossible = true;
    }

    final feasibility = _feasibility(
      targetAmount: targetAmount,
      requiredMonthly: requiredMonthly,
      currentSurplus: currentSurplus,
      variableReductionPossible: variableReductionPossible,
      extensionPossible: extensionPossible,
    );
    final adjustmentKind = switch (feasibility) {
      GoalFeasibility.feasible => GoalAdjustmentKind.none,
      GoalFeasibility.feasibleWithVariableReduction =>
        GoalAdjustmentKind.reduceVariableSpending,
      GoalFeasibility.feasibleWithExtension =>
        GoalAdjustmentKind.extendDuration,
      GoalFeasibility.unreachable => GoalAdjustmentKind.unavailable,
    };

    final effectiveDays = feasibility == GoalFeasibility.feasibleWithExtension
        ? extendedDays
        : targetDays;
    final plannedMonthly = switch (feasibility) {
      GoalFeasibility.feasible ||
      GoalFeasibility.feasibleWithVariableReduction =>
        requiredMonthly,
      GoalFeasibility.feasibleWithExtension =>
        targetAmount / effectiveDays * 30,
      GoalFeasibility.unreachable => 0.0,
    };
    _requireFinite(plannedMonthly, 'Planned monthly contribution');

    final appliedVariableReduction =
        feasibility == GoalFeasibility.feasibleWithVariableReduction
            ? reductionNeeded
            : 0.0;
    final effectiveVariableExpenses =
        math.max(0.0, profile.variableExpenses - appliedVariableReduction);
    final safeDaily = math.max(
      0.0,
      (profile.salary -
              profile.fixedExpenses -
              profile.currentBnpl -
              reserve -
              plannedMonthly) /
          30,
    );
    final monthlyRemaining = math.max(
      0.0,
      profile.salary -
          profile.fixedExpenses -
          profile.currentBnpl -
          reserve -
          plannedMonthly -
          effectiveVariableExpenses,
    );

    final adjustment = GoalAdjustment(
      recommendedKind: adjustmentKind,
      requiredVariableExpenseReduction: reductionNeeded,
      variableReductionPossible: variableReductionPossible,
      minimumExtensionDays:
          extensionPossible ? math.max(0, extendedDays - targetDays) : 0,
      extendedTargetDays: extensionPossible ? extendedDays : targetDays,
      extensionPossible: extensionPossible,
    );
    final steps = _weeklySteps(
      targetAmount: targetAmount,
      effectiveTargetDays: effectiveDays,
      safeDailySpend: safeDaily,
      adjustment: adjustment,
      reachable: feasibility != GoalFeasibility.unreachable,
    );

    return GoalPlan(
      goalType: goalType,
      targetAmount: targetAmount,
      requestedTargetDays: targetDays,
      effectiveTargetDays: effectiveDays,
      requiredMonthlyContribution: requiredMonthly,
      plannedMonthlyContribution: plannedMonthly,
      safetyReserve: reserve,
      monthlySurplusBeforeGoal: availableAtCurrentSpending,
      monthlyRemainingAfterGoal: monthlyRemaining,
      safeDailySpend: safeDaily,
      feasibility: feasibility,
      minimumAdjustment: adjustment,
      weeklySteps: List.unmodifiable(steps),
    );
  }

  static GoalFeasibility _feasibility({
    required double targetAmount,
    required double requiredMonthly,
    required double currentSurplus,
    required bool variableReductionPossible,
    required bool extensionPossible,
  }) {
    if (targetAmount == 0 || currentSurplus >= requiredMonthly) {
      return GoalFeasibility.feasible;
    }
    if (variableReductionPossible) {
      return GoalFeasibility.feasibleWithVariableReduction;
    }
    if (extensionPossible) {
      return GoalFeasibility.feasibleWithExtension;
    }
    return GoalFeasibility.unreachable;
  }

  static List<GoalWeeklyStep> _weeklySteps({
    required double targetAmount,
    required int effectiveTargetDays,
    required double safeDailySpend,
    required GoalAdjustment adjustment,
    required bool reachable,
  }) {
    final weekCount = (effectiveTargetDays + 6) ~/ 7;
    final dailyContribution =
        reachable ? targetAmount / effectiveTargetDays : 0.0;
    final steps = <GoalWeeklyStep>[];

    for (var index = 0; index < weekCount; index++) {
      final startDay = index * 7 + 1;
      final endDay = math.min(effectiveTargetDays, startDay + 6);
      final daysInWeek = endDay - startDay + 1;
      final contribution = dailyContribution * daysInWeek;
      final cumulative = math.min(targetAmount, dailyContribution * endDay);
      final action = _weeklyAction(
        index: index,
        weekCount: weekCount,
        adjustment: adjustment,
        reachable: reachable,
      );

      steps.add(GoalWeeklyStep(
        weekNumber: index + 1,
        startDay: startDay,
        endDay: endDay,
        contributionTarget: contribution,
        maxVariableSpending: safeDailySpend * daysInWeek,
        cumulativeContribution: cumulative,
        action: action,
        checkpoint: 'تحقق أن المدخر التراكمي بلغ ${cumulative.round()} ريال.',
      ));
    }
    return steps;
  }

  static String _weeklyAction({
    required int index,
    required int weekCount,
    required GoalAdjustment adjustment,
    required bool reachable,
  }) {
    if (!reachable) {
      return 'أعد ضبط المبلغ أو الدخل؛ الخطة الحالية لا تمول الهدف بأمان.';
    }
    if (index == 0 &&
        adjustment.recommendedKind ==
            GoalAdjustmentKind.reduceVariableSpending) {
      return 'اخفض المصروف المتغير ${adjustment.requiredVariableExpenseReduction.round()} ريال شهريًا وثبّت التحويل الأسبوعي.';
    }
    if (index == 0 &&
        adjustment.recommendedKind == GoalAdjustmentKind.extendDuration) {
      return 'اعتمد الموعد الآمن الجديد بعد ${adjustment.minimumExtensionDays} يومًا إضافيًا وثبّت التحويل الأسبوعي.';
    }
    if (index == 0) {
      return 'ثبّت التحويل الأسبوعي فور نزول الدخل.';
    }
    if (index == weekCount - 1) {
      return 'أكمل التحويل الأخير ولا تستخدم احتياطي الأمان.';
    }
    return 'التزم بسقف الإنفاق الأسبوعي وراجع التقدم نهاية الأسبوع.';
  }

  static void _validateInputs({
    required FinancialProfile profile,
    required double targetAmount,
    required int targetDays,
  }) {
    final monetaryValues = <String, double>{
      'salary': profile.salary,
      'fixedExpenses': profile.fixedExpenses,
      'variableExpenses': profile.variableExpenses,
      'currentBnpl': profile.currentBnpl,
      'targetAmount': targetAmount,
    };
    for (final entry in monetaryValues.entries) {
      if (!entry.value.isFinite || entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Must be finite and non-negative.',
        );
      }
    }
    if (targetDays <= 0) {
      throw ArgumentError.value(
        targetDays,
        'targetDays',
        'Must be positive.',
      );
    }
  }

  static void _requireFinite(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
          value, name, 'Must be finite and non-negative.');
    }
  }
}
