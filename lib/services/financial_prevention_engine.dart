import 'dart:math' as math;

import 'cash_flow_engine.dart';
import 'financial_decision_engine.dart';

/// Assumptions used by the hackathon prototype when exact banking dates are
/// unavailable. They are deliberately explicit so the UI can disclose them.
class ForecastAssumptions {
  final int horizonDays;
  final int simulationPaths;
  final int seed;
  final int incomeDay;
  final int fixedExpenseDay;
  final int bnplDueDay;
  final int proposedDueDay;
  final double incomeVolatility;
  final double variableExpenseVolatility;
  final double monthlyShockProbability;

  const ForecastAssumptions({
    this.horizonDays = 90,
    this.simulationPaths = 72,
    this.seed = 20260716,
    this.incomeDay = 0,
    this.fixedExpenseDay = 2,
    this.bnplDueDay = 7,
    this.proposedDueDay = 10,
    this.incomeVolatility = .04,
    this.variableExpenseVolatility = .16,
    this.monthlyShockProbability = .12,
  });

  String get disclosure =>
      'محاكاة نموذج أولي لمدة $horizonDays يومًا بافتراض الراتب يوم ${incomeDay + 1}، '
      'المصاريف الثابتة يوم ${fixedExpenseDay + 1}، الأقساط القائمة يوم ${bnplDueDay + 1}، '
      'والقسط الجديد يوم ${proposedDueDay + 1}. يُعرَّف السقوط المالي هنا بأنه البقاء تحت احتياطي الأمان 3 أيام متتالية؛ '
      'النسبة احتمال داخل المحاكاة وليست ضمانًا، ولا تعثرًا أو تقييمًا ائتمانيًا.';
}

class ForecastBand {
  final String label;
  final int? firstCriticalDay;
  final double minimumBalance;
  final double closingBalance;
  final int daysBelowReserve;

  const ForecastBand({
    required this.label,
    required this.firstCriticalDay,
    required this.minimumBalance,
    required this.closingBalance,
    required this.daysBelowReserve,
  });
}

class FinancialFallForecast {
  final double criticalProbability;
  final int criticalPaths;
  final int totalPaths;
  final int? fallDay;
  final int medianDaysBelowReserve;
  final String confidenceLabel;
  final List<ForecastBand> bands;
  final String disclosure;

  const FinancialFallForecast({
    required this.criticalProbability,
    required this.criticalPaths,
    required this.totalPaths,
    required this.fallDay,
    required this.medianDaysBelowReserve,
    required this.confidenceLabel,
    required this.bands,
    required this.disclosure,
  });

  bool get hasMaterialRisk => criticalProbability >= .20;
}

class RecoveryComparison {
  /// Days from first drop below the reserve until seven consecutive days above
  /// it. Null means recovery was not observed inside the 90-day horizon.
  final int? beforeDecisionDays;
  final int? afterDecisionDays;
  final int? afterInterventionDays;
  final int daysBelowReserveBefore;
  final int daysBelowReserveAfter;
  final int daysBelowReserveAfterIntervention;

  const RecoveryComparison({
    required this.beforeDecisionDays,
    required this.afterDecisionDays,
    required this.afterInterventionDays,
    required this.daysBelowReserveBefore,
    required this.daysBelowReserveAfter,
    required this.daysBelowReserveAfterIntervention,
  });

  int get avoidedFragileDays => math.max(
        0,
        daysBelowReserveAfter - daysBelowReserveAfterIntervention,
      );
}

class MinimumSavingIntervention {
  final double originalInstallment;
  final double adjustedInstallment;
  final int delayDays;
  final double monthlyVariableCut;
  final int riskBefore;
  final int riskAfter;
  final double probabilityBefore;
  final double probabilityAfter;
  final bool reachesTarget;
  final String title;
  final String explanation;

  const MinimumSavingIntervention({
    required this.originalInstallment,
    required this.adjustedInstallment,
    required this.delayDays,
    required this.monthlyVariableCut,
    required this.riskBefore,
    required this.riskAfter,
    required this.probabilityBefore,
    required this.probabilityAfter,
    required this.reachesTarget,
    required this.title,
    required this.explanation,
  });

  double get installmentReduction =>
      math.max(0, originalInstallment - adjustedInstallment);

  int get numberOfChanges =>
      (installmentReduction > .01 ? 1 : 0) +
      (delayDays > 0 ? 1 : 0) +
      (monthlyVariableCut > .01 ? 1 : 0);
}

class FinancialPreventionAnalysis {
  final FinancialFallForecast currentForecast;
  final FinancialFallForecast proposedForecast;
  final MinimumSavingIntervention intervention;
  final RecoveryComparison recovery;
  final double safeDailySpend;
  final double protectedForCommitments;
  final double decisionCostWithinHorizon;
  final int installmentPaymentsWithinHorizon;

  const FinancialPreventionAnalysis({
    required this.currentForecast,
    required this.proposedForecast,
    required this.intervention,
    required this.recovery,
    required this.safeDailySpend,
    required this.protectedForCommitments,
    required this.decisionCostWithinHorizon,
    required this.installmentPaymentsWithinHorizon,
  });
}

/// Probabilistic, reproducible prevention layer built above the deterministic
/// product score. It never calls an LLM and never invents dates from text.
class FinancialPreventionEngine {
  static const double _materialRiskThreshold = .20;

  static FinancialPreventionAnalysis analyze(
    FinancialProfile profile, {
    required double proposedInstallment,
    ForecastAssumptions assumptions = const ForecastAssumptions(),
  }) {
    _validate(profile, proposedInstallment, assumptions);

    final current = _forecast(
      profile,
      installment: 0,
      assumptions: assumptions,
    );
    final proposed = _forecast(
      profile,
      installment: proposedInstallment,
      assumptions: assumptions,
    );
    final intervention = _findMinimumIntervention(
      profile,
      proposedInstallment,
      current,
      proposed,
      assumptions,
    );

    final beforeSimulation = _expectedSimulation(
      profile,
      installment: 0,
      assumptions: assumptions,
    );
    final afterSimulation = _expectedSimulation(
      profile,
      installment: proposedInstallment,
      assumptions: assumptions,
    );
    final interventionProfile = FinancialProfile(
      salary: profile.salary,
      fixedExpenses: profile.fixedExpenses,
      variableExpenses: math.max(
          0, profile.variableExpenses - intervention.monthlyVariableCut),
      currentBnpl: profile.currentBnpl,
    );
    final interventionSimulation = _expectedSimulation(
      interventionProfile,
      installment: intervention.adjustedInstallment,
      delayDays: intervention.delayDays,
      assumptions: assumptions,
    );

    final paymentCount = _paymentCount(
      installment: proposedInstallment,
      delayDays: 0,
      assumptions: assumptions,
    );
    final reserve = math.max(500, profile.salary * .10).toDouble();
    final safeDailySpend = math
        .max(
          0,
          (profile.salary -
                  profile.fixedExpenses -
                  profile.currentBnpl -
                  proposedInstallment -
                  reserve) /
              30,
        )
        .toDouble();

    return FinancialPreventionAnalysis(
      currentForecast: current,
      proposedForecast: proposed,
      intervention: intervention,
      recovery: RecoveryComparison(
        beforeDecisionDays: _recoveryDays(beforeSimulation),
        afterDecisionDays: _recoveryDays(afterSimulation),
        afterInterventionDays: _recoveryDays(interventionSimulation),
        daysBelowReserveBefore: beforeSimulation.daysBelowReserve,
        daysBelowReserveAfter: afterSimulation.daysBelowReserve,
        daysBelowReserveAfterIntervention:
            interventionSimulation.daysBelowReserve,
      ),
      safeDailySpend: safeDailySpend,
      protectedForCommitments: profile.fixedExpenses +
          profile.currentBnpl +
          proposedInstallment +
          reserve,
      decisionCostWithinHorizon: proposedInstallment * paymentCount,
      installmentPaymentsWithinHorizon: paymentCount,
    );
  }

  static FinancialFallForecast _forecast(
    FinancialProfile profile, {
    required double installment,
    int delayDays = 0,
    double monthlyVariableCut = 0,
    required ForecastAssumptions assumptions,
    int? pathCount,
  }) {
    final count = pathCount ?? assumptions.simulationPaths;
    final criticalDays = <int>[];
    final belowReserveDays = <int>[];

    for (var path = 0; path < count; path++) {
      final result = _simulatePath(
        profile,
        installment: installment,
        delayDays: delayDays,
        monthlyVariableCut: monthlyVariableCut,
        assumptions: assumptions,
        path: path,
      );
      belowReserveDays.add(result.daysBelowReserve);
      final reserveBreachDay = _firstSustainedReserveBreach(result);
      if (reserveBreachDay != null) {
        criticalDays.add(reserveBreachDay);
      }
    }

    criticalDays.sort();
    belowReserveDays.sort();
    final probability = criticalDays.length / count;
    final fallDay = probability < _materialRiskThreshold || criticalDays.isEmpty
        ? null
        : _medianInt(criticalDays);

    return FinancialFallForecast(
      criticalProbability: probability,
      criticalPaths: criticalDays.length,
      totalPaths: count,
      fallDay: fallDay,
      medianDaysBelowReserve: _medianInt(belowReserveDays),
      confidenceLabel: count >= 60
          ? 'ثقة محاكاة متوسطة — المدخلات الأساسية متاحة والتواريخ مفترضة'
          : 'ثقة محاكاة أولية — عدد المسارات محدود',
      bands: _bands(
        profile,
        installment: installment,
        delayDays: delayDays,
        monthlyVariableCut: monthlyVariableCut,
        assumptions: assumptions,
      ),
      disclosure: assumptions.disclosure,
    );
  }

  static List<ForecastBand> _bands(
    FinancialProfile profile, {
    required double installment,
    required int delayDays,
    required double monthlyVariableCut,
    required ForecastAssumptions assumptions,
  }) {
    final variants = <(String, double, double, double)>[
      ('محافظ', 1.02, .90, 0),
      ('متوقع', 1.00, 1.00, 0),
      ('ضاغط', .90, 1.15, .10),
    ];

    return variants.map((variant) {
      final adjusted = FinancialProfile(
        salary: profile.salary * variant.$2,
        fixedExpenses: profile.fixedExpenses,
        variableExpenses: math.max(
          0,
          (profile.variableExpenses - monthlyVariableCut) * variant.$3,
        ),
        currentBnpl: profile.currentBnpl,
      );
      final events = _events(
        adjusted,
        installment: installment,
        delayDays: delayDays,
        assumptions: assumptions,
        random: null,
        forcedShockRatio: variant.$4,
      );
      final result = DailyCashFlowEngine.simulate(
        openingBalance: 0,
        monthlyIncome: adjusted.salary,
        events: events,
        horizonDays: assumptions.horizonDays,
      );
      return ForecastBand(
        label: variant.$1,
        firstCriticalDay: _firstSustainedReserveBreach(result),
        minimumBalance: result.minimumBalance,
        closingBalance: result.closingBalance,
        daysBelowReserve: result.daysBelowReserve,
      );
    }).toList(growable: false);
  }

  static CashFlowSimulationResult _simulatePath(
    FinancialProfile profile, {
    required double installment,
    required int delayDays,
    required double monthlyVariableCut,
    required ForecastAssumptions assumptions,
    required int path,
  }) {
    final random = math.Random(assumptions.seed + (path * 7919));
    final adjusted = FinancialProfile(
      salary: profile.salary,
      fixedExpenses: profile.fixedExpenses,
      variableExpenses:
          math.max(0, profile.variableExpenses - monthlyVariableCut),
      currentBnpl: profile.currentBnpl,
    );
    return DailyCashFlowEngine.simulate(
      openingBalance: 0,
      monthlyIncome: adjusted.salary,
      events: _events(
        adjusted,
        installment: installment,
        delayDays: delayDays,
        assumptions: assumptions,
        random: random,
      ),
      horizonDays: assumptions.horizonDays,
    );
  }

  static CashFlowSimulationResult _expectedSimulation(
    FinancialProfile profile, {
    required double installment,
    int delayDays = 0,
    required ForecastAssumptions assumptions,
  }) {
    return DailyCashFlowEngine.simulate(
      openingBalance: 0,
      monthlyIncome: profile.salary,
      events: _events(
        profile,
        installment: installment,
        delayDays: delayDays,
        assumptions: assumptions,
        random: null,
      ),
      horizonDays: assumptions.horizonDays,
    );
  }

  static List<CashFlowEvent> _events(
    FinancialProfile profile, {
    required double installment,
    required int delayDays,
    required ForecastAssumptions assumptions,
    required math.Random? random,
    double forcedShockRatio = 0,
  }) {
    final events = <CashFlowEvent>[];
    final months = (assumptions.horizonDays / 30).ceil();
    for (var month = 0; month < months; month++) {
      final start = month * 30;
      final incomeFactor = random == null
          ? 1.0
          : 1 + ((random.nextDouble() * 2 - 1) * assumptions.incomeVolatility);
      events.add(CashFlowEvent(
        day: start + assumptions.incomeDay,
        amount: profile.salary * incomeFactor,
        kind: CashFlowEventKind.income,
        label: 'الدخل المتوقع',
      ));
      events.add(CashFlowEvent(
        day: start + assumptions.fixedExpenseDay,
        amount: profile.fixedExpenses,
        kind: CashFlowEventKind.fixedExpense,
        label: 'المصاريف الثابتة',
        mandatory: true,
      ));
      events.add(CashFlowEvent(
        day: start + assumptions.bnplDueDay,
        amount: profile.currentBnpl,
        kind: CashFlowEventKind.bnplInstallment,
        label: 'الأقساط القائمة',
        mandatory: true,
      ));

      final proposedDay = start + assumptions.proposedDueDay + delayDays;
      if (installment > 0 && proposedDay < assumptions.horizonDays) {
        events.add(CashFlowEvent(
          day: proposedDay,
          amount: installment,
          kind: CashFlowEventKind.proposedInstallment,
          label: 'القرار المقترح',
          mandatory: true,
        ));
      }

      for (var day = 0; day < 30; day++) {
        final jitter = random == null
            ? 1.0
            : 1 +
                ((random.nextDouble() * 2 - 1) *
                    assumptions.variableExpenseVolatility);
        events.add(CashFlowEvent(
          day: start + day,
          amount: (profile.variableExpenses / 30) * jitter,
          kind: CashFlowEventKind.variableExpense,
          label: 'الإنفاق المتغير',
        ));
      }

      final randomShock = random != null &&
          random.nextDouble() < assumptions.monthlyShockProbability;
      if (forcedShockRatio > 0 || randomShock) {
        final shockRatio = forcedShockRatio > 0
            ? forcedShockRatio
            : .05 + (random!.nextDouble() * .10);
        final shockDay =
            start + (random == null ? 18 : 12 + random.nextInt(14));
        events.add(CashFlowEvent(
          day: shockDay,
          amount: profile.salary * shockRatio,
          kind: CashFlowEventKind.shock,
          label: 'طارئ محاكى',
          mandatory: true,
        ));
      }
    }
    return events;
  }

  static MinimumSavingIntervention _findMinimumIntervention(
    FinancialProfile profile,
    double installment,
    FinancialFallForecast current,
    FinancialFallForecast proposed,
    ForecastAssumptions assumptions,
  ) {
    final baseAssessment = FinancialDecisionEngine.analyze(
      profile,
      proposedInstallment: installment,
    );
    if (installment <= 0) {
      return MinimumSavingIntervention(
        originalInstallment: 0,
        adjustedInstallment: 0,
        delayDays: 0,
        monthlyVariableCut: 0,
        riskBefore: baseAssessment.proposedRisk,
        riskAfter: baseAssessment.proposedRisk,
        probabilityBefore: proposed.criticalProbability,
        probabilityAfter: proposed.criticalProbability,
        reachesTarget: true,
        title: 'لا يوجد التزام جديد لاختباره',
        explanation: 'أدخل قيمة القرار أولًا ليبحث وقفة عن أصغر تدخل.',
      );
    }

    final currentAssessment = FinancialDecisionEngine.analyze(
      profile,
      proposedInstallment: 0,
    );
    final targetScore = math.max(
      FinancialDecisionEngine.warningThreshold - 1,
      currentAssessment.currentRisk + 5,
    );
    final targetProbability = math.min(
      .60,
      math.max(.25, current.criticalProbability + .05),
    );

    final cuts = <double>{
      0,
      math.min(profile.variableExpenses * .10, profile.salary * .02),
      math.min(profile.variableExpenses * .20, profile.salary * .04),
    }.toList()
      ..sort();
    const installmentFactors = [1.0, .90, .80, .70, .60, .50, .25, 0.0];
    const delays = [0, 7, 14, 30];

    _Candidate? bestSafe;
    _Candidate? bestFallback;
    for (final factor in installmentFactors) {
      for (final delay in delays) {
        for (final cut in cuts) {
          if (factor == 1 && delay == 0 && cut == 0) continue;
          final adjustedInstallment = installment * factor;
          final adjustedProfile = FinancialProfile(
            salary: profile.salary,
            fixedExpenses: profile.fixedExpenses,
            variableExpenses: math.max(0, profile.variableExpenses - cut),
            currentBnpl: profile.currentBnpl,
          );
          final assessment = FinancialDecisionEngine.analyze(
            adjustedProfile,
            proposedInstallment: adjustedInstallment,
          );
          final forecast = _forecast(
            profile,
            installment: adjustedInstallment,
            delayDays: delay,
            monthlyVariableCut: cut,
            assumptions: assumptions,
            pathCount: math.min(36, assumptions.simulationPaths),
          );
          final changes = (factor < .999 ? 1 : 0) +
              (delay > 0 ? 1 : 0) +
              (cut > .01 ? 1 : 0);
          final sacrifice = ((1 - factor) * 60) +
              ((delay / 30) * 18) +
              (profile.variableExpenses <= 0
                  ? 0
                  : (cut / profile.variableExpenses) * 22) +
              (changes * 2.5);
          final candidate = _Candidate(
            installment: adjustedInstallment,
            delayDays: delay,
            cut: cut,
            risk: assessment.proposedRisk,
            probability: forecast.criticalProbability,
            sacrifice: sacrifice,
          );
          final reachesTarget = assessment.proposedRisk <= targetScore &&
              forecast.criticalProbability <= targetProbability;
          if (reachesTarget &&
              (bestSafe == null || candidate.isBetterSafeThan(bestSafe))) {
            bestSafe = candidate;
          }
          if (bestFallback == null ||
              candidate.isBetterFallbackThan(
                bestFallback,
                originalRisk: baseAssessment.proposedRisk,
                originalProbability: proposed.criticalProbability,
              )) {
            bestFallback = candidate;
          }
        }
      }
    }

    final selected = bestSafe ?? bestFallback!;
    final reachesTarget = bestSafe != null;
    final reduction = installment - selected.installment;
    final parts = <String>[];
    if (reduction > .5) {
      parts.add('خفض القسط ${reduction.round()} ريال');
    }
    if (selected.delayDays > 0) {
      parts.add('تأجيل البداية ${selected.delayDays} يومًا');
    }
    if (selected.cut > .5) {
      parts.add('حماية ${selected.cut.round()} ريال من الصرف المتغير شهريًا');
    }
    final actionText =
        parts.isEmpty ? 'إلغاء الالتزام الجديد' : parts.join(' + ');
    final probabilityBefore = (proposed.criticalProbability * 100).round();
    final probabilityAfter = (selected.probability * 100).round();

    return MinimumSavingIntervention(
      originalInstallment: installment,
      adjustedInstallment: selected.installment,
      delayDays: selected.delayDays,
      monthlyVariableCut: selected.cut,
      riskBefore: baseAssessment.proposedRisk,
      riskAfter: selected.risk,
      probabilityBefore: proposed.criticalProbability,
      probabilityAfter: selected.probability,
      reachesTarget: reachesTarget,
      title: reachesTarget ? 'أقل تدخل منقذ' : 'أفضل تخفيف وجدناه',
      explanation: '$actionText يخفض مؤشر القرار من '
          '${baseAssessment.proposedRisk} إلى ${selected.risk}، واحتمال الضغط داخل المحاكاة من '
          '$probabilityBefore% إلى $probabilityAfter%.',
    );
  }

  static int _paymentCount({
    required double installment,
    required int delayDays,
    required ForecastAssumptions assumptions,
  }) {
    if (installment <= 0) return 0;
    var count = 0;
    final months = (assumptions.horizonDays / 30).ceil();
    for (var month = 0; month < months; month++) {
      final day = month * 30 + assumptions.proposedDueDay + delayDays;
      if (day < assumptions.horizonDays) count++;
    }
    return count;
  }

  static int? _recoveryDays(CashFlowSimulationResult result) {
    final balances = result.dailyClosingBalances;
    final firstBelow =
        balances.indexWhere((value) => value < result.safetyReserve);
    if (firstBelow < 0) return 0;
    const stableDays = 7;
    for (var day = firstBelow; day <= balances.length - stableDays; day++) {
      var stable = true;
      for (var offset = 0; offset < stableDays; offset++) {
        if (balances[day + offset] < result.safetyReserve) {
          stable = false;
          break;
        }
      }
      if (stable) return day - firstBelow;
    }
    return null;
  }

  static int? _firstSustainedReserveBreach(
    CashFlowSimulationResult result, {
    int consecutiveDays = 3,
  }) {
    final balances = result.dailyClosingBalances;
    if (balances.length < consecutiveDays) return null;
    for (var start = 0; start <= balances.length - consecutiveDays; start++) {
      var below = true;
      for (var offset = 0; offset < consecutiveDays; offset++) {
        if (balances[start + offset] >= result.safetyReserve) {
          below = false;
          break;
        }
      }
      if (below) return start;
    }
    return null;
  }

  static int _medianInt(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return ((sorted[middle - 1] + sorted[middle]) / 2).round();
  }

  static void _validate(
    FinancialProfile profile,
    double installment,
    ForecastAssumptions assumptions,
  ) {
    final values = [
      profile.salary,
      profile.fixedExpenses,
      profile.variableExpenses,
      profile.currentBnpl,
      installment,
    ];
    if (values.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError('Financial values must be finite and non-negative.');
    }
    if (profile.salary <= 0) {
      throw ArgumentError('Salary must be greater than zero.');
    }
    if (assumptions.horizonDays < 30 || assumptions.simulationPaths < 12) {
      throw ArgumentError('Forecast horizon or path count is too small.');
    }
    if (assumptions.incomeDay < 0 ||
        assumptions.fixedExpenseDay < 0 ||
        assumptions.bnplDueDay < 0 ||
        assumptions.proposedDueDay < 0) {
      throw ArgumentError('Assumed dates must be non-negative.');
    }
  }
}

class _Candidate {
  final double installment;
  final int delayDays;
  final double cut;
  final int risk;
  final double probability;
  final double sacrifice;

  const _Candidate({
    required this.installment,
    required this.delayDays,
    required this.cut,
    required this.risk,
    required this.probability,
    required this.sacrifice,
  });

  bool isBetterSafeThan(_Candidate other) {
    if ((sacrifice - other.sacrifice).abs() > .001) {
      return sacrifice < other.sacrifice;
    }
    if ((probability - other.probability).abs() > .001) {
      return probability < other.probability;
    }
    return risk < other.risk;
  }

  bool isBetterFallbackThan(
    _Candidate other, {
    required int originalRisk,
    required double originalProbability,
  }) {
    final benefit = (originalRisk - risk) +
        ((originalProbability - probability) * 100) -
        (sacrifice * .12);
    final otherBenefit = (originalRisk - other.risk) +
        ((originalProbability - other.probability) * 100) -
        (other.sacrifice * .12);
    return benefit > otherBenefit;
  }
}
