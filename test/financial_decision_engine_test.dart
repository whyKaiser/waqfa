import 'package:flutter_test/flutter_test.dart';
import 'package:waqfa/services/financial_decision_engine.dart';

void main() {
  const profile = FinancialProfile(
    salary: 7000,
    fixedExpenses: 3000,
    variableExpenses: 1200,
    currentBnpl: 700,
  );

  test('القسط الجديد يرفع الخطر ويظهر تفسيراً', () {
    final result = FinancialDecisionEngine.analyze(
      profile,
      proposedInstallment: 900,
    );
    expect(result.proposedRisk, greaterThan(result.currentRisk));
    expect(result.factors, hasLength(3));
    expect(result.verdict, isNotEmpty);
    expect(result.ninetyDayBalances, hasLength(3));
  });

  test('البدائل المقترحة أقل خطراً من القرار الأصلي', () {
    final result = FinancialDecisionEngine.analyze(
      profile,
      proposedInstallment: 1200,
    );
    expect(result.alternatives, hasLength(3));
    expect(result.alternatives.last.riskScore, lessThan(result.proposedRisk));
  });

  test('اختبار الصدمات يكشف العجز في الوضع الهش', () {
    const fragile = FinancialProfile(
      salary: 5000,
      fixedExpenses: 3000,
      variableExpenses: 1000,
      currentBnpl: 700,
    );
    final result = FinancialDecisionEngine.analyze(
      fragile,
      proposedInstallment: 500,
    );
    expect(result.shocks.any((shock) => !shock.survives), true);
    expect(result.proposedRisk, greaterThanOrEqualTo(70));
  });

  test('المدخلات الصفرية لا تسبب قسمة على صفر', () {
    const empty = FinancialProfile(
      salary: 0,
      fixedExpenses: 0,
      variableExpenses: 0,
      currentBnpl: 0,
    );
    final result = FinancialDecisionEngine.analyze(
      empty,
      proposedInstallment: 0,
    );
    expect(result.proposedRisk, inInclusiveRange(0, 100));
  });
}
