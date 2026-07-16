import 'package:flutter_test/flutter_test.dart';
import 'package:waqfa/services/financial_decision_engine.dart';
import 'package:waqfa/services/financial_prevention_engine.dart';

void main() {
  const demoProfile = FinancialProfile(
    salary: 8000,
    fixedExpenses: 3500,
    variableExpenses: 1500,
    currentBnpl: 1800,
  );

  test('المحاكاة الاحتمالية قابلة لإعادة التشغيل بالـ seed نفسه', () {
    final first = FinancialPreventionEngine.analyze(
      demoProfile,
      proposedInstallment: 640,
    );
    final second = FinancialPreventionEngine.analyze(
      demoProfile,
      proposedInstallment: 640,
    );

    expect(
      second.proposedForecast.criticalProbability,
      first.proposedForecast.criticalProbability,
    );
    expect(second.proposedForecast.fallDay, first.proposedForecast.fallDay);
    expect(
      second.intervention.adjustedInstallment,
      first.intervention.adjustedInstallment,
    );
  });

  test('القرار الجديد لا يخفض احتمال الضغط اصطناعيًا', () {
    final result = FinancialPreventionEngine.analyze(
      demoProfile,
      proposedInstallment: 640,
    );

    expect(
      result.proposedForecast.criticalProbability,
      greaterThanOrEqualTo(result.currentForecast.criticalProbability),
    );
    expect(result.decisionCostWithinHorizon, 640 * 3);
    expect(result.installmentPaymentsWithinHorizon, 3);
    expect(result.proposedForecast.fallDay, isNotNull);
    expect(
      result.proposedForecast.fallDay!,
      lessThan(30),
      reason: 'وقفة يجب أن تنبّه داخل أول دورة مالية لهذا السيناريو.',
    );
  });

  test('أقل تدخل منقذ يخفض المؤشر والاحتمال أو يبقيهما', () {
    final result = FinancialPreventionEngine.analyze(
      demoProfile,
      proposedInstallment: 640,
    );
    final intervention = result.intervention;

    expect(intervention.numberOfChanges, greaterThan(0));
    expect(intervention.riskAfter, lessThanOrEqualTo(intervention.riskBefore));
    expect(
      intervention.probabilityAfter,
      lessThanOrEqualTo(intervention.probabilityBefore),
    );
    expect(intervention.explanation, contains('محاكاة'));
  });

  test('يعرض ثلاثة مسارات مفهومة وحدود الادعاء', () {
    final result = FinancialPreventionEngine.analyze(
      demoProfile,
      proposedInstallment: 640,
    );

    expect(result.proposedForecast.bands, hasLength(3));
    expect(
      result.proposedForecast.bands.map((band) => band.label),
      containsAll(['محافظ', 'متوقع', 'ضاغط']),
    );
    expect(result.proposedForecast.disclosure, contains('ليست ضمانًا'));
    expect(result.proposedForecast.disclosure, contains('3 أيام متتالية'));
    expect(result.proposedForecast.totalPaths, 72);
  });

  test('يرفض القيم السالبة وغير المنطقية', () {
    const invalid = FinancialProfile(
      salary: 8000,
      fixedExpenses: -1,
      variableExpenses: 1000,
      currentBnpl: 0,
    );

    expect(
      () => FinancialPreventionEngine.analyze(
        invalid,
        proposedInstallment: 200,
      ),
      throwsArgumentError,
    );
    expect(
      () => FinancialPreventionEngine.analyze(
        demoProfile,
        proposedInstallment: double.nan,
      ),
      throwsArgumentError,
    );
  });
}
