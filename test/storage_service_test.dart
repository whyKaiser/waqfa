import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waqfa/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AnalysisRecord record(int totalRatio, {int daysAgo = 0}) => AnalysisRecord(
        date: DateTime.now().subtract(Duration(days: daysAgo)),
        salary: 8000,
        fixed: 3000,
        variable: 1000,
        bnpl: totalRatio * 80 - 4000, // قيمة اعتباطية غير مؤثرة على الاختبار
        totalRatio: totalRatio,
        bnplRatio: 20,
        riskLevel: 'warning',
      );

  test('لا يوجد اتجاه مع أقل من 3 تحليلات', () async {
    await StorageService.saveAnalysis(record(60));
    await StorageService.saveAnalysis(record(65));
    final trend = await StorageService.analyzeTrend();
    expect(trend.hasData, false);
    expect(trend.worsening, false);
  });

  test('يكتشف اتجاه تصاعدي واضح (تدهور تدريجي)', () async {
    // نحفظ الأقدم أولاً ثم الأحدث، لأن saveAnalysis يُدرج بالمقدمة (الأحدث أولاً)
    await StorageService.saveAnalysis(record(50));
    await StorageService.saveAnalysis(record(60));
    await StorageService.saveAnalysis(record(75));

    final trend = await StorageService.analyzeTrend();
    expect(trend.hasData, true);
    expect(trend.worsening, true);
    expect(trend.deltaPct, 25); // 75 - 50
  });

  test('لا يعتبره اتجاه إذا النسبة مستقرة أو منخفضة', () async {
    await StorageService.saveAnalysis(record(60));
    await StorageService.saveAnalysis(record(58));
    await StorageService.saveAnalysis(record(59));

    final trend = await StorageService.analyzeTrend();
    expect(trend.worsening, false);
  });

  test('السجل يحفظ وينقرأ بالترتيب الصحيح (الأحدث أولاً)', () async {
    await StorageService.saveAnalysis(record(40));
    await StorageService.saveAnalysis(record(50));
    final all = await StorageService.getAnalyses();
    expect(all.length, 2);
    expect(all.first.totalRatio, 50);
    expect(all.last.totalRatio, 40);
  });
}
