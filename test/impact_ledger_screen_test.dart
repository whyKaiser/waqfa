import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waqfa/screens/impact_ledger_screen.dart';
import 'package:waqfa/services/future_ledger_service.dart';
import 'package:waqfa/theme/waqfa_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app() => MaterialApp(
        theme: WaqfaTheme.dark,
        home: const ImpactLedgerScreen(),
      );

  Future<void> recordEntry() => FutureLedgerService.record(
        FutureLedgerEntry(
          id: 'decision-1',
          date: DateTime(2026, 7, 16),
          type: FutureDecisionType.reduced,
          decisionLabel: 'جهاز بالتقسيط',
          originalInstallment: 640,
          adjustedInstallment: 320,
          avoidedCommitmentWithin90Days: 960,
          riskBefore: 86,
          riskAfter: 62,
          fragileDaysAvoided: 12,
          recoveryDaysImproved: 8,
        ),
      );

  testWidgets('يعرض حالة فارغة مع إفصاح مضاد للواقع', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('empty-impact-ledger')), findsOneWidget);
    expect(find.byKey(const Key('counterfactual-notice')), findsOneWidget);
    expect(find.textContaining('ليست مالًا مدخرًا فعليًا'), findsOneWidget);
  });

  testWidgets('يعرض ملخص الأثر والقرارات المسجلة', (tester) async {
    await recordEntry();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('impact-ledger-summary')), findsOneWidget);
    expect(find.byKey(const Key('impact-entry-decision-1')), findsOneWidget);
    expect(find.text('جهاز بالتقسيط'), findsOneWidget);
    expect(find.text('960 ر.س'), findsOneWidget);
    expect(find.textContaining('إجمالي ضغط التزامات متجنب'), findsOneWidget);
  });

  testWidgets('يمسح السجل بعد التأكيد', (tester) async {
    await recordEntry();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('clear-impact-ledger')));
    await tester.pumpAndSettle();
    expect(find.text('مسح سجل الأثر؟'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-clear-impact-ledger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('empty-impact-ledger')), findsOneWidget);
    expect(await FutureLedgerService.load(), isEmpty);
  });
}
