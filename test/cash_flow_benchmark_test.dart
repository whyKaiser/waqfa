import 'package:flutter_test/flutter_test.dart';
import 'package:waqfa/services/cash_flow_engine.dart';
import 'package:waqfa/services/financial_decision_engine.dart';
import 'package:waqfa/services/risk_benchmark.dart';
import 'package:waqfa/services/synthetic_financial_scenarios.dart';

void main() {
  group('DailyCashFlowEngine', () {
    test('يعالج الدخل قبل الالتزام إذا كانا في اليوم نفسه', () {
      final result = DailyCashFlowEngine.simulate(
        openingBalance: 0,
        monthlyIncome: 1000,
        horizonDays: 2,
        events: const [
          CashFlowEvent(
            day: 0,
            amount: 600,
            kind: CashFlowEventKind.fixedExpense,
            label: 'إيجار',
            mandatory: true,
          ),
          CashFlowEvent(
            day: 0,
            amount: 1000,
            kind: CashFlowEventKind.income,
            label: 'راتب',
          ),
        ],
      );

      expect(result.missedMandatoryPayments, 0);
      expect(result.closingBalance, 400);
      expect(result.hasCriticalStress, false);
    });

    test('يكشف أول يوم يتعذر فيه التزام إلزامي', () {
      final result = DailyCashFlowEngine.simulate(
        openingBalance: 100,
        monthlyIncome: 5000,
        horizonDays: 3,
        events: const [
          CashFlowEvent(
            day: 1,
            amount: 500,
            kind: CashFlowEventKind.bnplInstallment,
            label: 'قسط',
            mandatory: true,
          ),
        ],
      );

      expect(result.hasCriticalStress, true);
      expect(result.firstCriticalDay, 1);
      expect(result.missedMandatoryPayments, 1);
      expect(result.negativeBalanceDays, 2);
    });
  });

  group('SyntheticScenarioGenerator', () {
    test('ينتج 100 حالة موزعة بالتساوي على خمسة أنماط', () {
      final scenarios = SyntheticScenarioGenerator.generate();

      expect(scenarios, hasLength(100));
      expect(scenarios.map((item) => item.id).toSet(), hasLength(100));
      for (final archetype in FinancialArchetype.values) {
        expect(
          scenarios.where((item) => item.archetype == archetype),
          hasLength(20),
        );
      }
    });

    test('الـ seed الثابت يعيد نفس البيانات', () {
      final first = SyntheticScenarioGenerator.generate();
      final second = SyntheticScenarioGenerator.generate();

      expect(second.first.id, first.first.id);
      expect(second.first.monthlyIncome, first.first.monthlyIncome);
      expect(second.first.openingBalance, first.first.openingBalance);
      expect(second.last.baseEvents.last.amount,
          first.last.baseEvents.last.amount);
    });
  });

  group('FinancialDecisionEngine and benchmark', () {
    test('المختبر يستخدم نفس تنبيهات محرك المنتج', () {
      final scenarios = SyntheticScenarioGenerator.generate();
      final expectedAlerts = scenarios.where((scenario) {
        final analysis = FinancialDecisionEngine.analyze(
          FinancialProfile(
            salary: scenario.monthlyIncome,
            fixedExpenses: scenario.fixedMonthlyExpenses,
            variableExpenses: scenario.variableMonthlyExpenses,
            currentBnpl: scenario.currentBnplMonthly,
          ),
          proposedInstallment: scenario.proposedInstallment,
        );
        return analysis.proposedRisk >=
            FinancialDecisionEngine.warningThreshold;
      }).length;

      final metrics = RiskBenchmark.run(scenarios: scenarios);

      expect(metrics.alertThreshold, FinancialDecisionEngine.warningThreshold);
      expect(metrics.alerts, expectedAlerts);
    });

    test('خفض القسط لا يرفع مؤشر المخاطر', () {
      final scenarios = SyntheticScenarioGenerator.generate();
      for (final scenario in scenarios) {
        final profile = FinancialProfile(
          salary: scenario.monthlyIncome,
          fixedExpenses: scenario.fixedMonthlyExpenses,
          variableExpenses: scenario.variableMonthlyExpenses,
          currentBnpl: scenario.currentBnplMonthly,
        );
        final full = FinancialDecisionEngine.analyze(
          profile,
          proposedInstallment: scenario.proposedInstallment,
        );
        final half = FinancialDecisionEngine.analyze(
          profile,
          proposedInstallment: scenario.proposedInstallment * .5,
        );
        expect(half.proposedRisk, lessThanOrEqualTo(full.proposedRisk),
            reason: scenario.id);
      }
    });

    test('مقاييس benchmark متسقة ومحددة النطاق', () {
      final metrics = RiskBenchmark.run();

      expect(metrics.totalScenarios, 100);
      expect(metrics.criticalScenarios, greaterThan(0));
      expect(metrics.nonCriticalScenarios, greaterThan(0));
      expect(
        metrics.truePositives +
            metrics.falsePositives +
            metrics.falseNegatives +
            metrics.trueNegatives,
        metrics.totalScenarios,
      );
      expect(metrics.criticalRecall, inInclusiveRange(0, 1));
      expect(metrics.falsePositiveRate, inInclusiveRange(0, 1));
      expect(metrics.medianLeadTimeDays, greaterThanOrEqualTo(0));
      expect(metrics.meanRiskReductionPoints, greaterThanOrEqualTo(0));
      expect(metrics.criticalOutcomeAvoidanceRate, inInclusiveRange(0, 1));
      expect(metrics.disclosure, contains('اصطناعي'));
    });
  });
}
