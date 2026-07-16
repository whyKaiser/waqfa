import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waqfa/screens/evidence_screen.dart';
import 'package:waqfa/screens/simulator_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('صفحة الاختبار توضح الهدف والحدود', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EvidenceScreen()));
    await tester.pumpAndSettle();

    expect(find.text('كيف اختبرنا وقفة؟'), findsOneWidget);
    expect(find.textContaining('100 حالة مالية اصطناعية'), findsOneWidget);
    expect(find.textContaining('نفس محرك المخاطر'), findsOneWidget);
    expect(find.textContaining('ماذا وجدنا؟'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('لا تمثل دقة على عملاء حقيقيين'),
      findsOneWidget,
    );
  });

  testWidgets('وقفة قبل تدفع تعرض المقارنة والتدخل', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SimulatorScreen(
        salary: 8000,
        fixed: 3500,
        variable: 1500,
        bnpl: 1800,
      ),
    ));
    await tester.pump();

    expect(find.text('وقفة قبل تدفع'), findsOneWidget);
    expect(find.text('قبل القرار'), findsOneWidget);
    expect(find.text('بعد القرار'), findsOneWidget);
    expect(find.textContaining('تدخل متعلم'), findsOneWidget);
  });
}
