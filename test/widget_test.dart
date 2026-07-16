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
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('وقفة قبل تدفع'), findsOneWidget);
    expect(find.text('قبل القرار'), findsOneWidget);
    expect(find.text('بعد القرار'), findsOneWidget);
    expect(find.textContaining('تدخل متعلم'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('إنذار وقفة الاستباقي'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('إنذار وقفة الاستباقي'), findsOneWidget);
    expect(find.text('أقل تدخل منقذ'), findsOneWidget);
    expect(find.text('76%'), findsOneWidget);

    final adopt = find.text('اعتمد أقل تدخل');
    await tester.scrollUntilVisible(
      adopt,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(adopt);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('تم اعتماد الخطة'), findsOneWidget);
    expect(find.text('تم اعتماد أقل تدخل'), findsOneWidget);
    expect(find.textContaining('الأرقام أعلاه تمثل وضعك بعد تطبيق الخطة'),
        findsOneWidget);
    expect(find.text('54/100'), findsNWidgets(2));
  });
}
