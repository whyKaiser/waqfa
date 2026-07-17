import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waqfa/services/future_ledger_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  FutureLedgerEntry entry(String id) => FutureLedgerEntry(
        id: id,
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
      );

  test('يسجل الأثر المحلي دون وصفه كادخار فعلي', () async {
    await FutureLedgerService.record(entry('decision-1'));

    final entries = await FutureLedgerService.load();
    expect(entries, hasLength(1));
    expect(entries.first.avoidedCommitmentWithin90Days, 960);
    expect(entries.first.riskReduction, 24);
  });

  test('يجمع أثر عدة قرارات بصورة قابلة للقياس', () async {
    await FutureLedgerService.record(entry('decision-1'));
    await FutureLedgerService.record(entry('decision-2'));

    final summary = await FutureLedgerService.summary();
    expect(summary.decisions, 2);
    expect(summary.avoidedCommitmentsWithin90Days, 1920);
    expect(summary.riskPointsReduced, 48);
    expect(summary.fragileDaysAvoided, 24);
    expect(summary.recoveryDaysImproved, 16);
  });

  test('يرفض قيماً سالبة', () async {
    final invalid = FutureLedgerEntry(
      id: 'bad',
      date: DateTime(2026, 7, 16),
      type: FutureDecisionType.cancelled,
      decisionLabel: 'قرار',
      originalInstallment: -1,
      adjustedInstallment: 0,
      avoidedCommitmentWithin90Days: 0,
      riskBefore: 0,
      riskAfter: 0,
      fragileDaysAvoided: 0,
      recoveryDaysImproved: 0,
    );

    await expectLater(
      FutureLedgerService.record(invalid),
      throwsArgumentError,
    );
  });
}
