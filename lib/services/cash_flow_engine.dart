import 'dart:math' as math;

enum CashFlowEventKind {
  income,
  fixedExpense,
  variableExpense,
  bnplInstallment,
  proposedInstallment,
  shock,
}

class CashFlowEvent {
  final int day;
  final double amount;
  final CashFlowEventKind kind;
  final String label;
  final bool mandatory;

  const CashFlowEvent({
    required this.day,
    required this.amount,
    required this.kind,
    required this.label,
    this.mandatory = false,
  });

  bool get isIncome => kind == CashFlowEventKind.income;

  CashFlowEvent scaled(double multiplier) => CashFlowEvent(
        day: day,
        amount: amount * multiplier,
        kind: kind,
        label: label,
        mandatory: mandatory,
      );
}

class CashFlowSimulationResult {
  final int horizonDays;
  final double openingBalance;
  final double closingBalance;
  final double minimumBalance;
  final double safetyReserve;
  final int daysBelowReserve;
  final int negativeBalanceDays;
  final int missedMandatoryPayments;
  final int? firstCriticalDay;
  final List<double> dailyClosingBalances;

  const CashFlowSimulationResult({
    required this.horizonDays,
    required this.openingBalance,
    required this.closingBalance,
    required this.minimumBalance,
    required this.safetyReserve,
    required this.daysBelowReserve,
    required this.negativeBalanceDays,
    required this.missedMandatoryPayments,
    required this.firstCriticalDay,
    required this.dailyClosingBalances,
  });

  bool get hasCriticalStress => firstCriticalDay != null;
}

/// محاكاة حتمية للتدفق النقدي اليومي.
///
/// تعد الحالة حرجة عند تعذر تغطية التزام إلزامي في يوم استحقاقه، أو عند
/// استمرار الرصيد السالب يومين متتاليين. هذا تعريف منتج تجريبي وليس تعريفًا
/// مصرفيًا للتعثر.
class DailyCashFlowEngine {
  static CashFlowSimulationResult simulate({
    required double openingBalance,
    required double monthlyIncome,
    required Iterable<CashFlowEvent> events,
    int horizonDays = 90,
    double? safetyReserve,
  }) {
    if (!openingBalance.isFinite || !monthlyIncome.isFinite) {
      throw ArgumentError('Balances and income must be finite.');
    }
    if (monthlyIncome < 0 || horizonDays <= 0) {
      throw ArgumentError('Income must be non-negative and horizon positive.');
    }

    final reserve = safetyReserve ?? math.max(500, monthlyIncome * .10);
    final eventsByDay = <int, List<CashFlowEvent>>{};
    for (final event in events) {
      if (event.day < 0 || !event.amount.isFinite || event.amount < 0) {
        throw ArgumentError(
            'Cash-flow events must have a valid day and amount.');
      }
      if (event.day >= horizonDays) continue;
      eventsByDay.putIfAbsent(event.day, () => <CashFlowEvent>[]).add(event);
    }

    // الراتب يدخل أولًا إذا صادف يوم التزام، ثم الالتزامات الإلزامية، ثم
    // الإنفاق المرن. هذا الترتيب ثابت حتى تكون النتائج قابلة لإعادة التشغيل.
    for (final dayEvents in eventsByDay.values) {
      dayEvents.sort((a, b) => _priority(a).compareTo(_priority(b)));
    }

    var balance = openingBalance;
    var minimumBalance = openingBalance;
    var daysBelowReserve = 0;
    var negativeDays = 0;
    var consecutiveNegativeDays = 0;
    var missedMandatory = 0;
    int? firstCriticalDay;
    final dailyBalances = <double>[];

    for (var day = 0; day < horizonDays; day++) {
      for (final event in eventsByDay[day] ?? const <CashFlowEvent>[]) {
        if (event.isIncome) {
          balance += event.amount;
          continue;
        }

        if (event.mandatory && balance < event.amount) {
          missedMandatory++;
          firstCriticalDay ??= day;
        }
        balance -= event.amount;
      }

      minimumBalance = math.min(minimumBalance, balance);
      if (balance < reserve) daysBelowReserve++;
      if (balance < 0) {
        negativeDays++;
        consecutiveNegativeDays++;
        if (consecutiveNegativeDays >= 2) {
          firstCriticalDay ??= day - 1;
        }
      } else {
        consecutiveNegativeDays = 0;
      }
      dailyBalances.add(balance);
    }

    return CashFlowSimulationResult(
      horizonDays: horizonDays,
      openingBalance: openingBalance,
      closingBalance: balance,
      minimumBalance: minimumBalance,
      safetyReserve: reserve.toDouble(),
      daysBelowReserve: daysBelowReserve,
      negativeBalanceDays: negativeDays,
      missedMandatoryPayments: missedMandatory,
      firstCriticalDay: firstCriticalDay,
      dailyClosingBalances: List.unmodifiable(dailyBalances),
    );
  }

  static int _priority(CashFlowEvent event) {
    if (event.isIncome) return 0;
    if (event.mandatory) return 1;
    return 2;
  }
}
