import 'package:shared_preferences/shared_preferences.dart';

enum DecisionOutcome { delayed, reduced, cancelled, continued }

class DecisionOutcomeSummary {
  final int delayed;
  final int reduced;
  final int cancelled;
  final int continued;

  const DecisionOutcomeSummary({
    required this.delayed,
    required this.reduced,
    required this.cancelled,
    required this.continued,
  });

  int get total => delayed + reduced + cancelled + continued;
  int get saferDecisions => delayed + reduced + cancelled;
  double get saferDecisionRate => total == 0 ? 0 : saferDecisions / total;
}

/// يخزن نتيجة القرار فقط، بلا مبالغ أو هوية أو تفاصيل مالية.
/// هذا قياس محلي لسلوك النموذج الأولي وليس دليلاً على خفض التعثر.
class DecisionOutcomeService {
  static const _prefix = 'decision_outcome_';

  static Future<void> record(DecisionOutcome outcome) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${outcome.name}';
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  static Future<DecisionOutcomeSummary> loadSummary() async {
    final prefs = await SharedPreferences.getInstance();
    int value(DecisionOutcome outcome) =>
        prefs.getInt('$_prefix${outcome.name}') ?? 0;
    return DecisionOutcomeSummary(
      delayed: value(DecisionOutcome.delayed),
      reduced: value(DecisionOutcome.reduced),
      cancelled: value(DecisionOutcome.cancelled),
      continued: value(DecisionOutcome.continued),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final outcome in DecisionOutcome.values) {
      await prefs.remove('$_prefix${outcome.name}');
    }
  }
}
