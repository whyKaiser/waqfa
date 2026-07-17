import 'dart:math' as math;

import 'cash_flow_engine.dart';

enum FinancialArchetype {
  stable,
  bnplStack,
  timingSqueeze,
  variableIncome,
  shockSensitive,
}

extension FinancialArchetypeLabel on FinancialArchetype {
  String get label {
    switch (this) {
      case FinancialArchetype.stable:
        return 'مستقر';
      case FinancialArchetype.bnplStack:
        return 'تكدّس أقساط';
      case FinancialArchetype.timingSqueeze:
        return 'ضغط توقيت';
      case FinancialArchetype.variableIncome:
        return 'دخل متذبذب';
      case FinancialArchetype.shockSensitive:
        return 'هش أمام الطوارئ';
    }
  }
}

enum RecurringObligationKind { fixed, bnpl }

class RecurringObligation {
  final double monthlyAmount;
  final int dueDay;
  final RecurringObligationKind kind;
  final String label;

  const RecurringObligation({
    required this.monthlyAmount,
    required this.dueDay,
    required this.kind,
    required this.label,
  });
}

class SyntheticFinancialScenario {
  final String id;
  final int seed;
  final FinancialArchetype archetype;
  final double monthlyIncome;
  final double openingBalance;
  final double variableMonthlyExpenses;
  final double incomeVolatility;
  final int incomeDay;
  final int activeBnplCount;
  final double proposedInstallment;
  final int proposedDueDay;
  final List<RecurringObligation> recurringObligations;
  final List<CashFlowEvent> baseEvents;
  final List<CashFlowEvent> proposedEvents;

  const SyntheticFinancialScenario({
    required this.id,
    required this.seed,
    required this.archetype,
    required this.monthlyIncome,
    required this.openingBalance,
    required this.variableMonthlyExpenses,
    required this.incomeVolatility,
    required this.incomeDay,
    required this.activeBnplCount,
    required this.proposedInstallment,
    required this.proposedDueDay,
    required this.recurringObligations,
    required this.baseEvents,
    required this.proposedEvents,
  });

  double get fixedMonthlyExpenses => recurringObligations
      .where((item) => item.kind == RecurringObligationKind.fixed)
      .fold(0, (sum, item) => sum + item.monthlyAmount);

  double get currentBnplMonthly => recurringObligations
      .where((item) => item.kind == RecurringObligationKind.bnpl)
      .fold(0, (sum, item) => sum + item.monthlyAmount);

  List<CashFlowEvent> eventsFor({double proposedMultiplier = 1}) {
    if (!proposedMultiplier.isFinite || proposedMultiplier < 0) {
      throw ArgumentError('Proposed installment multiplier must be valid.');
    }
    return <CashFlowEvent>[
      ...baseEvents,
      ...proposedEvents.map((event) => event.scaled(proposedMultiplier)),
    ];
  }
}

/// يولّد 100 حالة افتراضيًا: 20 حالة من كل نمط، باستخدام seed ثابت.
///
/// هذه الحالات لا تمثّل سكان المملكة ولا تثبت دقة واقعية. الغرض منها اختبار
/// اتساق النموذج الأولي وتغطية حالات مالية متنوعة بشكل قابل لإعادة التشغيل.
class SyntheticScenarioGenerator {
  static const int defaultSeed = 20260716;

  static List<SyntheticFinancialScenario> generate({
    int seed = defaultSeed,
    int casesPerArchetype = 20,
  }) {
    if (casesPerArchetype <= 0) {
      throw ArgumentError.value(casesPerArchetype, 'casesPerArchetype');
    }

    final scenarios = <SyntheticFinancialScenario>[];
    for (var archetypeIndex = 0;
        archetypeIndex < FinancialArchetype.values.length;
        archetypeIndex++) {
      final archetype = FinancialArchetype.values[archetypeIndex];
      for (var caseIndex = 0; caseIndex < casesPerArchetype; caseIndex++) {
        final caseSeed = seed + (archetypeIndex * 1000) + caseIndex;
        scenarios.add(_generateOne(
          archetype: archetype,
          index: caseIndex + 1,
          seed: caseSeed,
        ));
      }
    }
    return List.unmodifiable(scenarios);
  }

  static SyntheticFinancialScenario _generateOne({
    required FinancialArchetype archetype,
    required int index,
    required int seed,
  }) {
    final random = math.Random(seed);
    final p = _parameters(archetype, random);
    final monthlyIncome = _between(random, p.incomeMin, p.incomeMax);
    final incomeDay = _integerBetween(random, p.incomeDayMin, p.incomeDayMax);
    final fixedMonthly =
        monthlyIncome * _between(random, p.fixedMin, p.fixedMax);
    final variableMonthly =
        monthlyIncome * _between(random, p.variableMin, p.variableMax);
    final activeBnpl = _integerBetween(random, p.bnplCountMin, p.bnplCountMax);
    final bnplMonthly = activeBnpl == 0
        ? 0.0
        : monthlyIncome * _between(random, p.bnplMin, p.bnplMax);
    final openingBalance =
        monthlyIncome * _between(random, p.openingMin, p.openingMax);
    final incomeVolatility = _between(random, p.volatilityMin, p.volatilityMax);
    final proposedInstallment =
        monthlyIncome * _between(random, p.proposedMin, p.proposedMax);

    final fixedDueDays = archetype == FinancialArchetype.timingSqueeze
        ? const [2, 5, 9]
        : <int>[
            (incomeDay + 1) % 30,
            (incomeDay + 6) % 30,
            (incomeDay + 13) % 30,
          ];
    const fixedShares = [.55, .25, .20];
    final obligations = <RecurringObligation>[
      for (var i = 0; i < fixedShares.length; i++)
        RecurringObligation(
          monthlyAmount: fixedMonthly * fixedShares[i],
          dueDay: fixedDueDays[i],
          kind: RecurringObligationKind.fixed,
          label: 'التزام ثابت ${i + 1}',
        ),
    ];

    for (var i = 0; i < activeBnpl; i++) {
      final dueDay = archetype == FinancialArchetype.timingSqueeze
          ? 3 + (i * 2).clamp(0, 20)
          : _integerBetween(random, 3, 27);
      obligations.add(RecurringObligation(
        monthlyAmount: bnplMonthly / activeBnpl,
        dueDay: dueDay,
        kind: RecurringObligationKind.bnpl,
        label: 'قسط قائم ${i + 1}',
      ));
    }

    final proposedDueDay = archetype == FinancialArchetype.timingSqueeze
        ? math.max(1, incomeDay - 14)
        : (incomeDay + 9) % 30;
    final baseEvents = <CashFlowEvent>[];
    final proposedEvents = <CashFlowEvent>[];

    for (var month = 0; month < 3; month++) {
      final monthStart = month * 30;
      final realizedIncome = monthlyIncome *
          (1 + _between(random, -incomeVolatility, incomeVolatility));
      baseEvents.add(CashFlowEvent(
        day: monthStart + incomeDay,
        amount: math.max(0, realizedIncome),
        kind: CashFlowEventKind.income,
        label: 'دخل الشهر ${month + 1}',
      ));

      for (final obligation in obligations) {
        baseEvents.add(CashFlowEvent(
          day: monthStart + obligation.dueDay,
          amount: obligation.monthlyAmount,
          kind: obligation.kind == RecurringObligationKind.fixed
              ? CashFlowEventKind.fixedExpense
              : CashFlowEventKind.bnplInstallment,
          label: obligation.label,
          mandatory: true,
        ));
      }

      proposedEvents.add(CashFlowEvent(
        day: monthStart + proposedDueDay,
        amount: proposedInstallment,
        kind: CashFlowEventKind.proposedInstallment,
        label: 'القسط المقترح',
        mandatory: true,
      ));

      for (var dayOfMonth = 0; dayOfMonth < 30; dayOfMonth++) {
        final weekendFactor = dayOfMonth % 7 >= 5 ? 1.18 : 1.0;
        final jitter = _between(random, .55, 1.45);
        baseEvents.add(CashFlowEvent(
          day: monthStart + dayOfMonth,
          amount: (variableMonthly / 30) * jitter * weekendFactor,
          kind: CashFlowEventKind.variableExpense,
          label: 'إنفاق يومي',
        ));
      }

      if (random.nextDouble() < p.shockProbability) {
        baseEvents.add(CashFlowEvent(
          day: monthStart + _integerBetween(random, 4, 27),
          amount: monthlyIncome *
              _between(random, p.shockAmountMin, p.shockAmountMax),
          kind: CashFlowEventKind.shock,
          label: 'مصروف طارئ محاكى',
          mandatory: true,
        ));
      }
    }

    return SyntheticFinancialScenario(
      id: '${archetype.name}-${index.toString().padLeft(2, '0')}',
      seed: seed,
      archetype: archetype,
      monthlyIncome: monthlyIncome,
      openingBalance: openingBalance,
      variableMonthlyExpenses: variableMonthly,
      incomeVolatility: incomeVolatility,
      incomeDay: incomeDay,
      activeBnplCount: activeBnpl,
      proposedInstallment: proposedInstallment,
      proposedDueDay: proposedDueDay,
      recurringObligations: List.unmodifiable(obligations),
      baseEvents: List.unmodifiable(baseEvents),
      proposedEvents: List.unmodifiable(proposedEvents),
    );
  }

  static _ArchetypeParameters _parameters(
    FinancialArchetype archetype,
    math.Random random,
  ) {
    switch (archetype) {
      case FinancialArchetype.stable:
        return const _ArchetypeParameters(
          incomeMin: 9000,
          incomeMax: 15000,
          fixedMin: .28,
          fixedMax: .40,
          variableMin: .16,
          variableMax: .24,
          bnplMin: 0,
          bnplMax: .06,
          openingMin: .25,
          openingMax: .60,
          volatilityMin: 0,
          volatilityMax: .05,
          proposedMin: .03,
          proposedMax: .07,
          incomeDayMin: 1,
          incomeDayMax: 5,
          bnplCountMin: 0,
          bnplCountMax: 1,
          shockProbability: .05,
          shockAmountMin: .05,
          shockAmountMax: .10,
        );
      case FinancialArchetype.bnplStack:
        return const _ArchetypeParameters(
          incomeMin: 5000,
          incomeMax: 9000,
          fixedMin: .32,
          fixedMax: .45,
          variableMin: .18,
          variableMax: .27,
          bnplMin: .18,
          bnplMax: .32,
          openingMin: .08,
          openingMax: .20,
          volatilityMin: 0,
          volatilityMax: .08,
          proposedMin: .08,
          proposedMax: .15,
          incomeDayMin: 1,
          incomeDayMax: 8,
          bnplCountMin: 4,
          bnplCountMax: 7,
          shockProbability: .15,
          shockAmountMin: .08,
          shockAmountMax: .15,
        );
      case FinancialArchetype.timingSqueeze:
        return const _ArchetypeParameters(
          incomeMin: 5500,
          incomeMax: 9500,
          fixedMin: .38,
          fixedMax: .50,
          variableMin: .17,
          variableMax: .25,
          bnplMin: .08,
          bnplMax: .16,
          openingMin: .02,
          openingMax: .10,
          volatilityMin: 0,
          volatilityMax: .08,
          proposedMin: .06,
          proposedMax: .14,
          incomeDayMin: 20,
          incomeDayMax: 27,
          bnplCountMin: 2,
          bnplCountMax: 4,
          shockProbability: .12,
          shockAmountMin: .08,
          shockAmountMax: .16,
        );
      case FinancialArchetype.variableIncome:
        return const _ArchetypeParameters(
          incomeMin: 4500,
          incomeMax: 8500,
          fixedMin: .35,
          fixedMax: .48,
          variableMin: .18,
          variableMax: .28,
          bnplMin: .06,
          bnplMax: .15,
          openingMin: .06,
          openingMax: .18,
          volatilityMin: .25,
          volatilityMax: .45,
          proposedMin: .06,
          proposedMax: .14,
          incomeDayMin: 1,
          incomeDayMax: 10,
          bnplCountMin: 1,
          bnplCountMax: 3,
          shockProbability: .20,
          shockAmountMin: .08,
          shockAmountMax: .18,
        );
      case FinancialArchetype.shockSensitive:
        return const _ArchetypeParameters(
          incomeMin: 6000,
          incomeMax: 12000,
          fixedMin: .42,
          fixedMax: .56,
          variableMin: .18,
          variableMax: .26,
          bnplMin: .06,
          bnplMax: .15,
          openingMin: .03,
          openingMax: .12,
          volatilityMin: .05,
          volatilityMax: .15,
          proposedMin: .05,
          proposedMax: .12,
          incomeDayMin: 1,
          incomeDayMax: 7,
          bnplCountMin: 1,
          bnplCountMax: 3,
          shockProbability: .65,
          shockAmountMin: .12,
          shockAmountMax: .25,
        );
    }
  }

  static double _between(math.Random random, double min, double max) =>
      min + (random.nextDouble() * (max - min));

  static int _integerBetween(math.Random random, int min, int max) =>
      min + random.nextInt(max - min + 1);
}

class _ArchetypeParameters {
  final double incomeMin;
  final double incomeMax;
  final double fixedMin;
  final double fixedMax;
  final double variableMin;
  final double variableMax;
  final double bnplMin;
  final double bnplMax;
  final double openingMin;
  final double openingMax;
  final double volatilityMin;
  final double volatilityMax;
  final double proposedMin;
  final double proposedMax;
  final int incomeDayMin;
  final int incomeDayMax;
  final int bnplCountMin;
  final int bnplCountMax;
  final double shockProbability;
  final double shockAmountMin;
  final double shockAmountMax;

  const _ArchetypeParameters({
    required this.incomeMin,
    required this.incomeMax,
    required this.fixedMin,
    required this.fixedMax,
    required this.variableMin,
    required this.variableMax,
    required this.bnplMin,
    required this.bnplMax,
    required this.openingMin,
    required this.openingMax,
    required this.volatilityMin,
    required this.volatilityMax,
    required this.proposedMin,
    required this.proposedMax,
    required this.incomeDayMin,
    required this.incomeDayMax,
    required this.bnplCountMin,
    required this.bnplCountMax,
    required this.shockProbability,
    required this.shockAmountMin,
    required this.shockAmountMax,
  });
}
