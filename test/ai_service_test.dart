import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waqfa/services/ai_service.dart';
import 'package:waqfa/services/financial_decision_engine.dart';
import 'package:waqfa/services/generative_ai_provider.dart';
import 'package:waqfa/services/goal_plan_engine.dart';

class _FakeProvider implements GenerativeAiProvider {
  final String text;

  const _FakeProvider(this.text);

  @override
  bool get isConfigured => true;

  @override
  String get name => 'مزود تجريبي';

  @override
  Future<AiProviderResponse> analyzeImage(AiImageRequest request) async =>
      AiProviderResponse(
        ok: true,
        statusCode: 200,
        content: text,
      );

  @override
  Future<AiProviderResponse> generateText(AiTextRequest request) async =>
      AiProviderResponse(
        ok: true,
        statusCode: 200,
        content: text,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(AiService.useDefaultProvider);

  group('ReceiptResult.parse', () {
    test('parses structured receipt JSON', () {
      final result = ReceiptResult.parse('''
        {"merchant":"متجر تجريبي","total":"125.50 ريال","category":"تسوق","is_bnpl":false,"note":"مصروف اختياري"}
      ''');

      expect(result.ok, isTrue);
      expect(result.merchant, 'متجر تجريبي');
      expect(result.total, 125.5);
      expect(result.category, 'تسوق');
      expect(result.isBnpl, isFalse);
      expect(result.note, 'مصروف اختياري');
    });

    test('extracts JSON when the model wraps it in text', () {
      final result = ReceiptResult.parse(
        'النتيجة: {"merchant":"تمارا","total":300,"category":"تقسيط","is_bnpl":true,"note":"راجع التزاماتك"}',
      );

      expect(result.ok, isTrue);
      expect(result.total, 300);
      expect(result.isBnpl, isTrue);
    });

    test('returns a safe error for malformed output', () {
      final result = ReceiptResult.parse('not-json');

      expect(result.ok, isFalse);
      expect(result.total, 0);
      expect(result.note, isNotEmpty);
    });

    test('parses Arabic digits and decimal separator', () {
      final result = ReceiptResult.parse(
        '{"merchant":"مقهى","total":"١٢٥٫٥٠ ر.س","category":"طعام","is_bnpl":false,"note":""}',
      );

      expect(result.ok, isTrue);
      expect(result.total, 125.5);
    });

    test('rejects a response without a positive total', () {
      final result = ReceiptResult.parse(
        '{"merchant":"متجر","total":0,"category":"تسوق","is_bnpl":false,"note":""}',
      );

      expect(result.ok, isFalse);
      expect(result.note, contains('إجمالي'));
    });

    test('keeps BNPL total separate from the visible monthly installment', () {
      final result = ReceiptResult.parse(
        '{"merchant":"تمارا","total":1200,"category":"تقسيط","is_bnpl":true,"monthly_installment":"٣٠٠","note":""}',
      );

      expect(result.ok, isTrue);
      expect(result.isBnpl, isTrue);
      expect(result.total, 1200);
      expect(result.monthlyInstallment, 300);
    });

    test('does not invent a missing BNPL installment', () {
      final result = ReceiptResult.parse(
        '{"merchant":"تابي","total":800,"category":"تقسيط","is_bnpl":true,"note":""}',
      );

      expect(result.ok, isTrue);
      expect(result.monthlyInstallment, 0);
    });
  });

  test('financial analysis reports local source when cloud is disabled',
      () async {
    final result = await AiService.analyzeFinances(
      salary: 8000,
      fixed: 3000,
      variable: 1500,
      bnpl: 500,
    );

    expect(result.usedCloud, isFalse);
    expect(result.text, isNotEmpty);
  });

  test('يمكن تبديل مزود الذكاء الاصطناعي دون تغيير المحرك المالي', () async {
    AiService.configureProvider(const _FakeProvider('شرح من مزود بديل'));

    final result = await AiService.analyzeFinances(
      salary: 8000,
      fixed: 3000,
      variable: 1500,
      bnpl: 500,
      allowCloud: true,
    );

    expect(AiService.providerName, 'مزود تجريبي');
    expect(result.usedCloud, isTrue);
    expect(result.text, 'شرح من مزود بديل');
  });

  test('صياغة خطة الهدف لا تستبدل أرقام المحرك بأرقام المزود', () async {
    AiService.configureProvider(const _FakeProvider('''
      {
        "diagnosis":"الخطة قابلة للتنفيذ",
        "mainProblem":"الالتزام الأسبوعي",
        "riskFactors":["عامل محسوب"],
        "questionsToAsk":[],
        "recommendedPlan":[{"week":1,"targetAmount":999999,"safeDailySpend":999999}],
        "warnings":[],
        "nextStep":"ابدأ الخطة"
      }
    '''));
    final plan = GoalPlanEngine.build(
      profile: const FinancialProfile(
        salary: 10000,
        fixedExpenses: 3000,
        variableExpenses: 1500,
        currentBnpl: 500,
      ),
      goalType: GoalType.travel,
      targetAmount: 3000,
      targetDays: 90,
    );

    final narrative = await AiService.buildGoalPlanNarrative(
      plan: plan,
      allowCloud: true,
    );

    expect(narrative.usedCloud, isTrue);
    expect(
      narrative.recommendedPlan.first.targetAmount,
      plan.weeklySteps.first.contributionTarget,
    );
    expect(narrative.recommendedPlan.first.safeDailySpend, plan.safeDailySpend);
    expect(narrative.recommendedPlan.first.targetAmount, isNot(999999));
  });
}
