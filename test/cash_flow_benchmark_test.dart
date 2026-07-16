import 'package:flutter_test/flutter_test.dart';
import 'package:waqfa/services/cash_flow_engine.dart';
import 'package:waqfa/services/risk_benchmark.dart';
import 'package:waqfa/services/synthetic_financial_scenarios.dart';
import 'package:waqfa/services/temporal_risk_engine.dart';

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

  group('TemporalRiskEngine and benchmark', () {
    test('كل عامل تفسير يساهم فعليًا في الدرجة', () {
      final scenario = SyntheticScenarioGenerator.generate().first;
      final assessment = TemporalRiskEngine.assess(scenario);
      final explainedScore = assessment.contributions
          .fold<double>(0, (sum, item) => sum + item.points)
          .round();

      expect(assessment.score, explainedScore);
      expect(assessment.disclosure, contains('ليس احتمال تعثر'));
    });

    test('خفض القسط لا يرفع مؤشر المخاطر', () {
      final scenarios = SyntheticScenarioGenerator.generate();
      for (final scenario in scenarios) {
        final full = TemporalRiskEngine.assess(scenario);
        final half = TemporalRiskEngine.assess(
          scenario,
          proposedMultiplier: .5,
        );
        expect(half.score, lessThanOrEqualTo(full.score), reason: scenario.id);
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
      expect(metrics.falseAlertRate, inInclusiveRange(0, 1));
      expect(metrics.medianLeadTimeDays, greaterThanOrEqualTo(0));
      expect(metrics.meanRiskReductionPoints, greaterThanOrEqualTo(0));
      expect(metrics.criticalOutcomeAvoidanceRate, inInclusiveRange(0, 1));
      expect(metrics.disclosure, contains('اصطناعي'));
    });
  });
}
