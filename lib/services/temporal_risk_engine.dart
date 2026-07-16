import 'dart:math' as math;

import 'synthetic_financial_scenarios.dart';

class RiskContribution {
  final String code;
  final String title;
  final double points;
  final String explanation;

  const RiskContribution({
    required this.code,
    required this.title,
    required this.points,
    required this.explanation,
  });
}

class TemporalRiskAssessment {
  final int score;
  final int alertThreshold;
  final List<RiskContribution> contributions;
  final String disclosure;

  const TemporalRiskAssessment({
    required this.score,
    required this.alertThreshold,
    required this.contributions,
    required this.disclosure,
  });

  bool get shouldAlert => score >= alertThreshold;
}

/// Scorecard زمني قابل للتفسير يستخدم المعلومات المتاحة لحظة القرار فقط.
///
/// لا يقرأ المصروف الطارئ المحقق مستقبلًا من بيانات السيناريو، حتى يبقى
/// الاختبار الخلفي منفصلًا عن النتيجة الفعلية المحاكاة. الدرجة مؤشر ضغط
/// تجريبي من 100 وليست احتمال تعثر أو تقييمًا ائتمانيًا.
class TemporalRiskEngine {
  // عتبة وقائية تفضّل التقاط حالات الضغط على تقليل التنبيهات. يمكن رفعها
  // عندما تتوفر بيانات حقيقية ومعايرة تكلفة التنبيه مقابل تفويت الحالة.
  static const int defaultAlertThreshold = 50;
  static const String disclosure =
      'مؤشر ضغط مالي تجريبي مبني على محاكاة اصطناعية؛ ليس احتمال تعثر أو تقييمًا ائتمانيًا.';

  static TemporalRiskAssessment assess(
    SyntheticFinancialScenario scenario, {
    double proposedMultiplier = 1,
    int alertThreshold = defaultAlertThreshold,
  }) {
    if (!proposedMultiplier.isFinite || proposedMultiplier < 0) {
      throw ArgumentError(
          'Proposed multiplier must be finite and non-negative.');
    }
    if (alertThreshold < 0 || alertThreshold > 100) {
      throw RangeError.range(alertThreshold, 0, 100, 'alertThreshold');
    }

    final income = math.max(scenario.monthlyIncome, 1).toDouble();
    final proposed = scenario.proposedInstallment * proposedMultiplier;
    final bnpl = scenario.currentBnplMonthly + proposed;
    final committed = scenario.fixedMonthlyExpenses + bnpl;
    final totalExpected = committed + scenario.variableMonthlyExpenses;
    final totalRatio = totalExpected / income;
    final bnplRatio = bnpl / income;
    final bufferRatio = scenario.openingBalance / income;

    final obligationsBeforeIncome = scenario.recurringObligations
            .where((item) => item.dueDay < scenario.incomeDay)
            .fold<double>(0, (sum, item) => sum + item.monthlyAmount) +
        (scenario.proposedDueDay < scenario.incomeDay ? proposed : 0);
    final expectedVariableBeforeIncome =
        scenario.variableMonthlyExpenses * (scenario.incomeDay / 30);
    final preIncomeGapRatio = math.max(
          0,
          obligationsBeforeIncome +
              expectedVariableBeforeIncome -
              scenario.openingBalance,
        ) /
        income;

    final contributions = <RiskContribution>[
      const RiskContribution(
        code: 'base',
        title: 'خط أساس وقائي',
        points: 5,
        explanation: 'خط أساس ثابت يمنع إظهار أمان مطلق.',
      ),
      RiskContribution(
        code: 'total_load',
        title: 'إجمالي الحمل الشهري',
        points: _scaled(totalRatio, .55, 1.00, 30),
        explanation:
            'المصاريف المتوقعة تمثل ${(totalRatio * 100).round()}% من الدخل.',
      ),
      RiskContribution(
        code: 'bnpl_load',
        title: 'عبء الأقساط',
        points: _scaled(bnplRatio, .05, .35, 20),
        explanation: 'الأقساط تمثل ${(bnplRatio * 100).round()}% من الدخل.',
      ),
      RiskContribution(
        code: 'timing_gap',
        title: 'فجوة ما قبل الدخل',
        points: _scaled(preIncomeGapRatio, 0, .25, 20),
        explanation:
            'الفجوة المتوقعة قبل الدخل تساوي ${(preIncomeGapRatio * 100).round()}% من الدخل.',
      ),
      RiskContribution(
        code: 'opening_buffer',
        title: 'هامش البداية',
        points: _scaled(.22 - bufferRatio, 0, .20, 10),
        explanation:
            'الرصيد المتاح يساوي ${(bufferRatio * 100).round()}% من الدخل.',
      ),
      RiskContribution(
        code: 'income_volatility',
        title: 'تذبذب الدخل',
        points: _scaled(scenario.incomeVolatility, .05, .45, 10),
        explanation:
            'تذبذب الدخل المحاكى ${(scenario.incomeVolatility * 100).round()}%.',
      ),
      RiskContribution(
        code: 'installment_stack',
        title: 'تعدد الأقساط',
        points: _scaled(scenario.activeBnplCount.toDouble(), 1, 6, 5),
        explanation: 'يوجد ${scenario.activeBnplCount} أقساط قائمة.',
      ),
    ];
    final rawScore =
        contributions.fold<double>(0, (sum, item) => sum + item.points);
    final score = rawScore.round().clamp(0, 100);
    contributions.sort((a, b) => b.points.compareTo(a.points));

    return TemporalRiskAssessment(
      score: score,
      alertThreshold: alertThreshold,
      contributions: List.unmodifiable(contributions),
      disclosure: disclosure,
    );
  }

  static double _scaled(
    double value,
    double lower,
    double upper,
    double maxPoints,
  ) {
    if (upper <= lower) throw ArgumentError('Invalid score range.');
    return (((value - lower) / (upper - lower)).clamp(0, 1) * maxPoints)
        .toDouble();
  }
}
