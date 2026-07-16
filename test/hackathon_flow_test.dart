import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waqfa/screens/home_screen.dart';
import 'package:waqfa/screens/input_screen.dart';
import 'package:waqfa/screens/waqfa_plan_screen.dart';
import 'package:waqfa/theme/waqfa_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app(Widget home) => MaterialApp(
        theme: WaqfaTheme.dark,
        home: home,
      );

  testWidgets('الرئيسية تعرض رحلة الوقاية الجديدة على شاشة هاتف',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('تاريخ السقوط المالي'), findsOneWidget);
    expect(find.text('أقل تدخل منقذ'), findsOneWidget);
    expect(find.text('خطة وقفة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('زر العرض يحمّل سارة الاصطناعية ويوقف السحابة', (tester) async {
    await tester.pumpWidget(app(const InputScreen()));
    await tester.tap(find.text('تحميل'));
    await tester.pump();

    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].controller!.text, '8000');
    expect(fields[1].controller!.text, '3500');
    expect(fields[2].controller!.text, '1500');
    expect(fields[3].controller!.text, '1800');
    expect(fields[4].controller!.text, contains('640'));
    expect(find.textContaining('شخصية سارة الاصطناعية'), findsOneWidget);
  });

  testWidgets('خطة وقفة تبني أرقامًا محلية منظمة', (tester) async {
    await tester.pumpWidget(app(const WaqfaPlanScreen()));
    final buildButton = find.text('ابنِ خطتي المحسوبة');
    await tester.scrollUntilVisible(
      buildButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(buildButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('ممكن بوقت أطول'), findsOneWidget);
    expect(find.text('6000 ريال خلال 450 يومًا'), findsOneWidget);
    final adjustment = find.text('أقل تعديل يجعل الخطة ممكنة');
    await tester.scrollUntilVisible(
      adjustment,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(adjustment, findsOneWidget);
    expect(find.textContaining('مدّد الخطة 360 يومًا'), findsOneWidget);
  });
}
