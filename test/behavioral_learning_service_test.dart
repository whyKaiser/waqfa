import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waqfa/services/behavioral_learning_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('يستكشف التدخلات غير المجربة أولاً', () async {
    expect(await BehavioralLearningService.recommend(),
        InterventionStrategy.totalCost);
    await BehavioralLearningService.record(
        InterventionStrategy.totalCost, true);
    expect(await BehavioralLearningService.recommend(),
        InterventionStrategy.dailyBudget);
  });

  test('يخزن نجاح التدخل كعدادات مجهولة فقط', () async {
    await BehavioralLearningService.record(
        InterventionStrategy.coolingOff, true);
    final stats = await BehavioralLearningService.loadStats();
    final cooling = stats.singleWhere(
        (item) => item.strategy == InterventionStrategy.coolingOff);
    expect(cooling.trials, 1);
    expect(cooling.saferChoices, 1);
  });
}
