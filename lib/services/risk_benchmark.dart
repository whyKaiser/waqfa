import 'cash_flow_engine.dart';
import 'synthetic_financial_scenarios.dart';
import 'temporal_risk_engine.dart';

class BenchmarkMetrics {
  final int seed;
  final int alertThreshold;
  final int totalScenarios;
  final int criticalScenarios;
  final int nonCriticalScenarios;
  final int alerts;
  final int truePositives;
  final int falsePositives;
  final int falseNegatives;
  final int trueNegatives;
  final double criticalRecall;
  final double falseAlertRate;
  final double medianLeadTimeDays;
  final double meanRiskReductionPoints;
  final double criticalOutcomeAvoidanceRate;
  final Map<String, Map<String, int>> archetypeBreakdown;
  final String disclosure;

  const BenchmarkMetrics({
    required this.seed,
    required this.alertThreshold,
    required this.totalScenarios,
    required this.criticalScenarios,
    required this.nonCriticalScenarios,
    required this.alerts,
    required this.truePositives,
    required this.falsePositives,
    required this.falseNegatives,
    required this.trueNegatives,
    required this.criticalRecall,
    required this.falseAlertRate,
    required this.medianLeadTimeDays,
    required this.meanRiskReductionPoints,
    required this.criticalOutcomeAvoidanceRate,
    required this.archetypeBreakdown,
    required this.disclosure,
  });

  Map<String, Object> toJson() => {
        'seed': seed,
        'alert_threshold': alertThreshold,
        'scope': 'synthetic_90_day_scenarios',
        'total_scenarios': totalScenarios,
        'critical_scenarios': criticalScenarios,
        'non_critical_scenarios': nonCriticalScenarios,
        'alerts': alerts,
        'confusion_matrix': {
          'true_positive': truePositives,
          'false_positive': falsePositives,
          'false_negative': falseNegatives,
          'true_negative': trueNegatives,
        },
        'critical_recall': criticalRecall,
        'false_alert_rate': falseAlertRate,
        'median_lead_time_days': medianLeadTimeDays,
        'mean_risk_reduction_points_if_installment_halved':
            meanRiskReductionPoints,
        'critical_outcomes_avoided_if_installment_halved':
            criticalOutcomeAvoidanceRate,
        'archetype_breakdown': archetypeBreakdown,
        'disclosure': disclosure,
      };
}

/// Backtest قابل لإعادة التشغيل على حالات اصطناعية فقط.
///
/// الحقيقة المرجعية تأتي من محرك التدفق اليومي (بما في ذلك الصدمات المحققة)،
/// بينما مؤشر المخاطر لا يرى الصدمات المستقبلية. هذا يمنع استخدام النتيجة ذاتها
/// كمدخل للتنبؤ، لكنه لا يحول الاختبار إلى دليل أداء على عملاء حقيقيين.
class RiskBenchmark {
  static const String disclosure =
      'النتائج تخص 100 سيناريو اصطناعي مولدًا آليًا ولا تمثل دقة على عملاء حقيقيين أو خفضًا مثبتًا للتعثر.';

  static BenchmarkMetrics run({
    List<SyntheticFinancialScenario>? scenarios,
    int seed = SyntheticScenarioGenerator.defaultSeed,
    int alertThreshold = TemporalRiskEngine.defaultAlertThreshold,
  }) {
    final cohort = scenarios ?? SyntheticScenarioGenerator.generate(seed: seed);
    if (cohort.isEmpty)
      throw ArgumentError('Benchmark cohort cannot be empty.');

    var truePositives = 0;
    var falsePositives = 0;
    var falseNegatives = 0;
    var trueNegatives = 0;
    var avoidedCriticalOutcomes = 0;
    final leadTimes = <double>[];
    final riskReductions = <double>[];
    final breakdown = <String, Map<String, int>>{};

    for (final scenario in cohort) {
      final outcome = DailyCashFlowEngine.simulate(
        openingBalance: scenario.openingBalance,
        monthlyIncome: scenario.monthlyIncome,
        events: scenario.eventsFor(),
      );
      final reducedOutcome = DailyCashFlowEngine.simulate(
        openingBalance: scenario.openingBalance,
        monthlyIncome: scenario.monthlyIncome,
        events: scenario.eventsFor(proposedMultiplier: .5),
      );
      final assessment = TemporalRiskEngine.assess(
        scenario,
        alertThreshold: alertThreshold,
      );
      final reducedAssessment = TemporalRiskEngine.assess(
        scenario,
        proposedMultiplier: .5,
        alertThreshold: alertThreshold,
      );
      final critical = outcome.hasCriticalStress;
      final alert = assessment.shouldAlert;

      final bucket = breakdown.putIfAbsent(
        scenario.archetype.name,
        () => {
          'total': 0,
          'critical': 0,
          'alerts': 0,
          'true_positive': 0,
          'false_positive': 0,
        },
      );
      bucket['total'] = bucket['total']! + 1;
      if (critical) bucket['critical'] = bucket['critical']! + 1;
      if (alert) bucket['alerts'] = bucket['alerts']! + 1;

      if (critical && alert) {
        truePositives++;
        bucket['true_positive'] = bucket['true_positive']! + 1;
        leadTimes.add((outcome.firstCriticalDay! + 1).toDouble());
      } else if (!critical && alert) {
        falsePositives++;
        bucket['false_positive'] = bucket['false_positive']! + 1;
      } else if (critical) {
        falseNegatives++;
      } else {
        trueNegatives++;
      }

      if (alert) {
        riskReductions.add(
          (assessment.score - reducedAssessment.score).toDouble(),
        );
      }
      if (critical && !reducedOutcome.hasCriticalStress) {
        avoidedCriticalOutcomes++;
      }
    }

    final criticalCount = truePositives + falseNegatives;
    final nonCriticalCount = falsePositives + trueNegatives;
    return BenchmarkMetrics(
      seed: seed,
      alertThreshold: alertThreshold,
      totalScenarios: cohort.length,
      criticalScenarios: criticalCount,
      nonCriticalScenarios: nonCriticalCount,
      alerts: truePositives + falsePositives,
      truePositives: truePositives,
      falsePositives: falsePositives,
      falseNegatives: falseNegatives,
      trueNegatives: trueNegatives,
      criticalRecall: criticalCount == 0 ? 0 : truePositives / criticalCount,
      falseAlertRate:
          nonCriticalCount == 0 ? 0 : falsePositives / nonCriticalCount,
      medianLeadTimeDays: _median(leadTimes),
      meanRiskReductionPoints: _mean(riskReductions),
      criticalOutcomeAvoidanceRate:
          criticalCount == 0 ? 0 : avoidedCriticalOutcomes / criticalCount,
      archetypeBreakdown: Map<String, Map<String, int>>.unmodifiable(
        breakdown.map(
          (key, value) => MapEntry(key, Map<String, int>.unmodifiable(value)),
        ),
      ),
      disclosure: disclosure,
    );
  }

  static double _mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
