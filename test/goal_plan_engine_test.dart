import 'package:flutter_test/flutter_test.dart';
import 'package:waqfa/services/financial_decision_engine.dart';
import 'package:waqfa/services/goal_plan_engine.dart';

void main() {
  const comfortableProfile = FinancialProfile(
    salary: 10000,
    fixedExpenses: 3000,
    variableExpenses: 1500,
    currentBnpl: 500,
  );

  test('يبني خطة ممكنة ويحمي الاحتياطي', () {
    final plan = GoalPlanEngine.build(
      profile: comfortableProfile,
      goalType: GoalType.travel,
      targetAmount: 3000,
      targetDays: 90,
    );

    expect(plan.feasibility, GoalFeasibility.feasible);
    expect(plan.requiredMonthlyContribution, closeTo(1000, .001));
    expect(plan.safetyReserve, 1000);
    expect(plan.safeDailySpend, closeTo(150, .001));
    expect(plan.minimumAdjustment.recommendedKind, GoalAdjustmentKind.none);
    expect(plan.weeklySteps, hasLength(13));
    expect(
      plan.weeklySteps.fold<double>(
        0,
        (sum, step) => sum + step.contributionTarget,
      ),
      closeTo(3000, .001),
    );
  });

  test('يحسب أقل خفض للمصروف المتغير للموعد المطلوب', () {
    const profile = FinancialProfile(
      salary: 7000,
      fixedExpenses: 3000,
      variableExpenses: 2000,
      currentBnpl: 500,
    );

    final plan = GoalPlanEngine.build(
      profile: profile,
      goalType: GoalType.purchase,
      targetAmount: 1500,
      targetDays: 30,
    );

    expect(
      plan.feasibility,
      GoalFeasibility.feasibleWithVariableReduction,
    );
    expect(
      plan.minimumAdjustment.recommendedKind,
      GoalAdjustmentKind.reduceVariableSpending,
    );
    expect(
      plan.minimumAdjustment.requiredVariableExpenseReduction,
      closeTo(700, .001),
    );
    expect(plan.monthlyRemainingAfterGoal, closeTo(0, .001));
    expect(plan.weeklySteps.first.action, contains('700'));
  });

  test('يمدد المدة بأقل عدد أيام عندما لا يكفي الخفض', () {
    const profile = FinancialProfile(
      salary: 7000,
      fixedExpenses: 3000,
      variableExpenses: 2000,
      currentBnpl: 500,
    );

    final plan = GoalPlanEngine.build(
      profile: profile,
      goalType: GoalType.car,
      targetAmount: 6000,
      targetDays: 30,
    );

    expect(plan.feasibility, GoalFeasibility.feasibleWithExtension);
    expect(
      plan.minimumAdjustment.recommendedKind,
      GoalAdjustmentKind.extendDuration,
    );
    expect(plan.minimumAdjustment.extendedTargetDays, 225);
    expect(plan.minimumAdjustment.minimumExtensionDays, 195);
    expect(plan.plannedMonthlyContribution, lessThanOrEqualTo(800));
    expect(plan.isReachable, true);
    expect(plan.meetsRequestedDeadline, false);
  });

  test('دخل صفر يجعل الهدف الموجب غير قابل للوصول', () {
    const profile = FinancialProfile(
      salary: 0,
      fixedExpenses: 0,
      variableExpenses: 0,
      currentBnpl: 0,
    );

    final plan = GoalPlanEngine.build(
      profile: profile,
      goalType: GoalType.emergencyFund,
      targetAmount: 1000,
      targetDays: 30,
    );

    expect(plan.feasibility, GoalFeasibility.unreachable);
    expect(plan.isReachable, false);
    expect(plan.safetyReserve, 500);
    expect(plan.safeDailySpend, 0);
    expect(plan.plannedMonthlyContribution, 0);
    expect(plan.minimumAdjustment.extensionPossible, false);
    expect(
        plan.weeklySteps.every((step) => step.contributionTarget == 0), true);
  });

  test('هدف صفر مكتمل دون تعديل حتى مع دخل صفر', () {
    const profile = FinancialProfile(
      salary: 0,
      fixedExpenses: 0,
      variableExpenses: 0,
      currentBnpl: 0,
    );

    final plan = GoalPlanEngine.build(
      profile: profile,
      goalType: GoalType.other,
      targetAmount: 0,
      targetDays: 7,
    );

    expect(plan.feasibility, GoalFeasibility.feasible);
    expect(plan.minimumAdjustment.recommendedKind, GoalAdjustmentKind.none);
    expect(plan.minimumAdjustment.requiredVariableExpenseReduction, 0);
    expect(plan.requiredMonthlyContribution, 0);
  });

  test('يرفض القيم السالبة وغير المحدودة والمدة الصفرية', () {
    const negativeProfile = FinancialProfile(
      salary: 5000,
      fixedExpenses: -1,
      variableExpenses: 500,
      currentBnpl: 0,
    );
    const infiniteProfile = FinancialProfile(
      salary: double.infinity,
      fixedExpenses: 0,
      variableExpenses: 0,
      currentBnpl: 0,
    );

    expect(
      () => GoalPlanEngine.build(
        profile: negativeProfile,
        goalType: GoalType.other,
        targetAmount: 100,
        targetDays: 7,
      ),
      throwsArgumentError,
    );
    expect(
      () => GoalPlanEngine.build(
        profile: infiniteProfile,
        goalType: GoalType.other,
        targetAmount: 100,
        targetDays: 7,
      ),
      throwsArgumentError,
    );
    expect(
      () => GoalPlanEngine.build(
        profile: comfortableProfile,
        goalType: GoalType.other,
        targetAmount: -1,
        targetDays: 7,
      ),
      throwsArgumentError,
    );
    expect(
      () => GoalPlanEngine.build(
        profile: comfortableProfile,
        goalType: GoalType.other,
        targetAmount: double.nan,
        targetDays: 7,
      ),
      throwsArgumentError,
    );
    expect(
      () => GoalPlanEngine.build(
        profile: comfortableProfile,
        goalType: GoalType.other,
        targetAmount: 100,
        targetDays: 0,
      ),
      throwsArgumentError,
    );
  });

  test('النتائج مستقرة للمدخلات نفسها', () {
    GoalPlan run() => GoalPlanEngine.build(
          profile: comfortableProfile,
          goalType: GoalType.debtReduction,
          targetAmount: 2400,
          targetDays: 90,
        );

    final first = run();
    final second = run();

    expect(
        second.requiredMonthlyContribution, first.requiredMonthlyContribution);
    expect(second.safeDailySpend, first.safeDailySpend);
    expect(second.feasibility, first.feasibility);
    expect(second.weeklySteps.length, first.weeklySteps.length);
    for (var index = 0; index < first.weeklySteps.length; index++) {
      expect(
        second.weeklySteps[index].contributionTarget,
        first.weeklySteps[index].contributionTarget,
      );
      expect(second.weeklySteps[index].action, first.weeklySteps[index].action);
    }
  });
}
