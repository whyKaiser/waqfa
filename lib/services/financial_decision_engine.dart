import 'dart:math' as math;

import 'cash_flow_engine.dart';

class FinancialProfile {
  final double salary;
  final double fixedExpenses;
  final double variableExpenses;
  final double currentBnpl;

  const FinancialProfile({
    required this.salary,
    required this.fixedExpenses,
    required this.variableExpenses,
    required this.currentBnpl,
  });
}

class RiskFactor {
  final String title;
  final String explanation;
  final int impact;

  const RiskFactor(this.title, this.explanation, this.impact);
}

class SafeAlternative {
  final String title;
  final String explanation;
  final double installment;
  final int riskScore;

  const SafeAlternative({
    required this.title,
    required this.explanation,
    required this.installment,
    required this.riskScore,
  });
}

class ShockResult {
  final String name;
  final double amount;
  final bool survives;
  final double balanceAfterShock;

  const ShockResult({
    required this.name,
    required this.amount,
    required this.survives,
    required this.balanceAfterShock,
  });
}

class DecisionAnalysis {
  final int currentRisk;
  final int proposedRisk;
  final int riskIncrease;
  final double monthlyRemaining;
  final double dailyAllowance;
  final int safeDays;
  final String level;
  final String verdict;
  final String behavioralNudge;
  final List<double> ninetyDayBalances;
  final int? firstCriticalDay;
  final int daysBelowSafetyReserve;
  final List<RiskFactor> factors;
  final List<SafeAlternative> alternatives;
  final List<ShockResult> shocks;

  const DecisionAnalysis({
    required this.currentRisk,
    required this.proposedRisk,
    required this.riskIncrease,
    required this.monthlyRemaining,
    required this.dailyAllowance,
    required this.safeDays,
    required this.level,
    required this.verdict,
    required this.behavioralNudge,
    required this.ninetyDayBalances,
    required this.firstCriticalDay,
    required this.daysBelowSafetyReserve,
    required this.factors,
    required this.alternatives,
    required this.shocks,
  });
}

/// محرك مالي حتمي وقابل للتفسير. الذكاء التوليدي يمكنه صياغة التدخل،
/// بينما تبقى الأرقام هنا ثابتة وقابلة للاختبار والتدقيق.
class FinancialDecisionEngine {
  /// حدود موحّدة لكل شاشة وقياس داخل التطبيق.
  static const int warningThreshold = 45;
  static const int dangerThreshold = 70;

  static DecisionAnalysis analyze(
    FinancialProfile profile, {
    required double proposedInstallment,
  }) {
    _validate(profile, proposedInstallment);
    final salary = math.max(profile.salary, 1).toDouble();
    final installment = proposedInstallment;
    final currentRisk = _score(profile, 0);
    final proposedRisk = _score(profile, installment);
    final total = profile.fixedExpenses +
        profile.variableExpenses +
        profile.currentBnpl +
        installment;
    final remaining = salary - total;
    final daily = remaining / 30;
    final projection = _projectNinetyDays(profile, installment);
    final balances = [
      projection.dailyClosingBalances[29],
      projection.dailyClosingBalances[59],
      projection.dailyClosingBalances[89],
    ];
    final factors = _factors(profile, installment);
    final shocks = _shocks(remaining, salary);
    final alternatives = _alternatives(profile, installment);
    final level = proposedRisk >= dangerThreshold
        ? 'خطر مرتفع'
        : proposedRisk >= warningThreshold
            ? 'يحتاج وقفة'
            : 'قرار آمن';

    return DecisionAnalysis(
      currentRisk: currentRisk,
      proposedRisk: proposedRisk,
      riskIncrease: proposedRisk - currentRisk,
      monthlyRemaining: remaining,
      dailyAllowance: daily,
      safeDays: daily <= 0
          ? 0
          : (remaining / math.max(salary * 0.03, 1)).floor().clamp(0, 30),
      level: level,
      verdict: _verdict(proposedRisk, remaining, installment),
      behavioralNudge: _nudge(profile, installment, daily, proposedRisk),
      ninetyDayBalances: balances,
      firstCriticalDay: projection.firstCriticalDay,
      daysBelowSafetyReserve: projection.daysBelowReserve,
      factors: factors,
      alternatives: alternatives,
      shocks: shocks,
    );
  }

  static void _validate(
    FinancialProfile profile,
    double proposedInstallment,
  ) {
    final values = [
      profile.salary,
      profile.fixedExpenses,
      profile.variableExpenses,
      profile.currentBnpl,
      proposedInstallment,
    ];
    if (values.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError('Financial values must be finite and non-negative.');
    }
  }

  static CashFlowSimulationResult _projectNinetyDays(
      FinancialProfile profile, double installment) {
    final events = <CashFlowEvent>[];
    for (var month = 0; month < 3; month++) {
      final start = month * 30;
      events.add(CashFlowEvent(
        day: start,
        amount: math.max(profile.salary, 0).toDouble(),
        kind: CashFlowEventKind.income,
        label: 'الراتب',
      ));
      events.add(CashFlowEvent(
        day: start + 2,
        amount: math.max(profile.fixedExpenses, 0).toDouble(),
        kind: CashFlowEventKind.fixedExpense,
        label: 'المصاريف الثابتة',
        mandatory: true,
      ));
      events.add(CashFlowEvent(
        day: start + 7,
        amount: math.max(profile.currentBnpl, 0).toDouble(),
        kind: CashFlowEventKind.bnplInstallment,
        label: 'الأقساط القائمة',
        mandatory: true,
      ));
      if (installment > 0) {
        events.add(CashFlowEvent(
          day: start + 10,
          amount: installment,
          kind: CashFlowEventKind.proposedInstallment,
          label: 'القسط المقترح',
          mandatory: true,
        ));
      }
      for (var day = 0; day < 30; day++) {
        events.add(CashFlowEvent(
          day: start + day,
          amount: math.max(profile.variableExpenses / 30, 0).toDouble(),
          kind: CashFlowEventKind.variableExpense,
          label: 'إنفاق يومي متوقع',
        ));
      }
    }
    return DailyCashFlowEngine.simulate(
      openingBalance: 0,
      monthlyIncome: math.max(profile.salary, 0).toDouble(),
      events: events,
    );
  }

  static int _score(FinancialProfile p, double extra) {
    final salary = math.max(p.salary, 1).toDouble();
    final bnplRatio = (p.currentBnpl + extra) / salary;
    final expenseRatio =
        (p.fixedExpenses + p.variableExpenses + p.currentBnpl + extra) / salary;
    final remaining = salary * (1 - expenseRatio);

    var score = 8.0;
    score += (bnplRatio * 95).clamp(0, 38);
    score += ((expenseRatio - 0.55).clamp(0, 0.55) * 82);
    if (remaining < salary * 0.15) score += 18;
    if (remaining < 0) score += 24;
    if (p.fixedExpenses / salary > 0.5) score += 8;
    return score.round().clamp(0, 100);
  }

  static List<RiskFactor> _factors(FinancialProfile p, double extra) {
    final salary = math.max(p.salary, 1).toDouble();
    final bnplRatio = (p.currentBnpl + extra) / salary;
    final totalRatio =
        (p.fixedExpenses + p.variableExpenses + p.currentBnpl + extra) / salary;
    final remaining = salary * (1 - totalRatio);
    final factors = <RiskFactor>[
      RiskFactor(
        'عبء الأقساط ${(bnplRatio * 100).round()}%',
        bnplRatio > .30
            ? 'تجاوز النطاق الوقائي البالغ 30% من الدخل.'
            : 'لا يزال داخل النطاق الوقائي، لكن تراكم الأقساط يرفع الهشاشة.',
        (bnplRatio * 38).round(),
      ),
      RiskFactor(
        'المتبقي ${remaining.round()} ريال',
        remaining < salary * .15
            ? 'الهامش المتبقي لا يمتص مصروفًا مفاجئًا بشكل آمن.'
            : 'يوفر هامشًا للمصاريف اليومية والطوارئ.',
        remaining < salary * .15 ? 18 : -6,
      ),
      RiskFactor(
        'إجمالي الالتزامات ${(totalRatio * 100).round()}%',
        totalRatio > .80
            ? 'معظم الدخل محجوز قبل بداية الشهر.'
            : 'يوجد مجال للمناورة بعد الالتزامات.',
        totalRatio > .80 ? 22 : 4,
      ),
    ];
    factors.sort((a, b) => b.impact.compareTo(a.impact));
    return factors;
  }

  static List<SafeAlternative> _alternatives(
      FinancialProfile p, double installment) {
    if (installment <= 0) return const [];
    final candidates = <(String, String, double)>[
      (
        'خفّض القسط 25%',
        'اختر دفعة أولى أعلى أو منتجًا أقل تكلفة.',
        installment * .75
      ),
      (
        'خفّض القسط للنصف',
        'يحافظ على هامش للطوارئ ويخفف تزامن الالتزامات.',
        installment * .50
      ),
      (
        'مهلة 24 ساعة',
        'جمّد القرار اليوم وأعد المحاكاة بعد مراجعة احتياجك.',
        0
      ),
    ];
    return candidates
        .map((c) => SafeAlternative(
              title: c.$1,
              explanation: c.$2,
              installment: c.$3,
              riskScore: _score(p, c.$3),
            ))
        .toList();
  }

  static List<ShockResult> _shocks(double remaining, double salary) {
    final scenarios = <(String, double)>[
      ('فاتورة مفاجئة', math.max(500, salary * .08).toDouble()),
      ('صيانة سيارة', math.max(900, salary * .12).toDouble()),
      ('تأخر جزء من الدخل', salary * .20),
    ];
    return scenarios
        .map((s) => ShockResult(
              name: s.$1,
              amount: s.$2,
              survives: remaining - s.$2 >= 0,
              balanceAfterShock: remaining - s.$2,
            ))
        .toList();
  }

  static String _verdict(int risk, double remaining, double installment) {
    if (installment <= 0)
      return 'أدخل القسط الذي تفكر فيه لتختبر القرار قبل الالتزام.';
    if (risk >= dangerThreshold) {
      return 'توقّف الآن: القرار يضغط تدفقك النقدي ويترك لك ${remaining.round()} ريال فقط هذا الشهر.';
    }
    if (risk >= warningThreshold) {
      return 'القرار ممكن، لكنه يقلّل هامش الأمان. جرّب أحد البدائل قبل الالتزام.';
    }
    return 'القرار داخل النطاق الآمن حاليًا، مع ضرورة إبقاء احتياطي للطوارئ.';
  }

  static String _nudge(
      FinancialProfile p, double installment, double daily, int risk) {
    if (installment <= 0) return 'وقفة صغيرة الآن تحمي خياراتك القادمة.';
    if (risk >= dangerThreshold) {
      return 'القسط يبدو ${installment.round()} ريال فقط، لكنه يترك لك ${math.max(daily, 0).round()} ريال يوميًا حتى الراتب. فعّل مهلة 24 ساعة.';
    }
    if (p.currentBnpl > installment && p.currentBnpl > 0) {
      return 'الأقساط الصغيرة تتراكم: ستدفع ${(p.currentBnpl + installment).round()} ريال شهريًا عند جمعها.';
    }
    return 'قبل التأكيد، قارن قيمة القسط بما سيتبقى لك يوميًا: ${math.max(daily, 0).round()} ريال.';
  }
}
