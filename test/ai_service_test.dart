import 'package:flutter_test/flutter_test.dart';
import 'package:waqfa/services/ai_service.dart';

void main() {
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

  test('financial analysis reports local source when cloud is disabled', () async {
    final result = await AiService.analyzeFinances(
      salary: 8000,
      fixed: 3000,
      variable: 1500,
      bnpl: 500,
    );

    expect(result.usedCloud, isFalse);
    expect(result.text, isNotEmpty);
  });
}
