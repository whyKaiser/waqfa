import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waqfa/services/decision_outcome_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('يسجل نتيجة القرار بلا بيانات مالية', () async {
    await DecisionOutcomeService.record(DecisionOutcome.delayed);
    await DecisionOutcomeService.record(DecisionOutcome.reduced);
    await DecisionOutcomeService.record(DecisionOutcome.continued);

    final summary = await DecisionOutcomeService.loadSummary();
    expect(summary.total, 3);
    expect(summary.saferDecisions, 2);
    expect(summary.saferDecisionRate, closeTo(2 / 3, .001));
  });
}
