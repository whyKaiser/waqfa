import 'dart:convert';

import 'package:waqfa/services/financial_decision_engine.dart';
import 'package:waqfa/services/financial_prevention_engine.dart';
import 'package:waqfa/services/goal_plan_engine.dart';

void main() {
  const profile = FinancialProfile(
    salary: 8000,
    fixedExpenses: 3500,
    variableExpenses: 1500,
    currentBnpl: 1800,
  );
  const proposedInstallment = 640.0;

  final decision = FinancialDecisionEngine.analyze(
    profile,
    proposedInstallment: proposedInstallment,
  );
  final prevention = FinancialPreventionEngine.analyze(
    profile,
    proposedInstallment: proposedInstallment,
  );
  final goal = GoalPlanEngine.build(
    profile: profile,
    goalType: GoalType.travel,
    targetAmount: 6000,
    targetDays: 90,
  );
  final intervention = prevention.intervention;

  final output = <String, Object?>{
    'scenario': {
      'salary': profile.salary,
      'fixed_expenses': profile.fixedExpenses,
      'variable_expenses': profile.variableExpenses,
      'current_bnpl': profile.currentBnpl,
      'proposed_installment': proposedInstallment,
    },
    'decision': {
      'risk_before': decision.currentRisk,
      'risk_after': decision.proposedRisk,
      'risk_increase': decision.riskIncrease,
      'monthly_remaining_after': decision.monthlyRemaining,
      'daily_allowance_after': decision.dailyAllowance,
    },
    'forecast': {
      'critical_probability_percent':
          (prevention.proposedForecast.criticalProbability * 100).round(),
      'critical_paths': prevention.proposedForecast.criticalPaths,
      'total_paths': prevention.proposedForecast.totalPaths,
      'financial_fall_day': prevention.proposedForecast.fallDay == null
          ? null
          : prevention.proposedForecast.fallDay! + 1,
      'median_days_below_reserve':
          prevention.proposedForecast.medianDaysBelowReserve,
      'safe_daily_spend': prevention.safeDailySpend,
      'decision_cost_90_days': prevention.decisionCostWithinHorizon,
      'bands': prevention.proposedForecast.bands
          .map(
            (band) => {
              'label': band.label,
              'first_critical_day': band.firstCriticalDay == null
                  ? null
                  : band.firstCriticalDay! + 1,
              'closing_balance': band.closingBalance,
              'days_below_reserve': band.daysBelowReserve,
            },
          )
          .toList(),
    },
    'minimum_intervention': {
      'title': intervention.title,
      'adjusted_installment': intervention.adjustedInstallment,
      'installment_reduction': intervention.installmentReduction,
      'delay_days': intervention.delayDays,
      'monthly_variable_cut': intervention.monthlyVariableCut,
      'risk_before': intervention.riskBefore,
      'risk_after': intervention.riskAfter,
      'probability_before_percent':
          (intervention.probabilityBefore * 100).round(),
      'probability_after_percent':
          (intervention.probabilityAfter * 100).round(),
      'reaches_target': intervention.reachesTarget,
      'fragile_days_avoided': prevention.recovery.avoidedFragileDays,
      'recovery_days_before_decision': prevention.recovery.beforeDecisionDays,
      'recovery_days_before_intervention':
          prevention.recovery.afterDecisionDays,
      'recovery_days_after_intervention':
          prevention.recovery.afterInterventionDays,
    },
    'goal_plan': {
      'target_amount': goal.targetAmount,
      'requested_days': goal.requestedTargetDays,
      'effective_days': goal.effectiveTargetDays,
      'feasibility': goal.feasibility.name,
      'required_monthly_contribution': goal.requiredMonthlyContribution,
      'planned_monthly_contribution': goal.plannedMonthlyContribution,
      'safe_daily_spend': goal.safeDailySpend,
      'safety_reserve': goal.safetyReserve,
      'minimum_variable_reduction':
          goal.minimumAdjustment.requiredVariableExpenseReduction,
      'minimum_extension_days': goal.minimumAdjustment.minimumExtensionDays,
      'weekly_steps': goal.weeklySteps.length,
    },
    'disclosure': prevention.proposedForecast.disclosure,
  };

  print(const JsonEncoder.withIndent('  ').convert(output));
}
