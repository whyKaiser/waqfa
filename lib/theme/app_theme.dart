import 'package:flutter/material.dart';

/// هوية وقفة البصرية — مستوحاة من روح هاكاثون أمد وهوية مصرف الإنماء
/// (كحلي عميق كأثر البحر، نحاسي كأثر الكثبان، بنفسجي كلمسة تقنية).
/// القيم أدناه اجتهاد إبداعي وليست أكواد hex رسمية معتمدة —
/// تُستبدل فورًا إذا توفر دليل هوية بصرية رسمي من الجهة المنظمة.
class AppColors {
  AppColors._();

  // خلفيات كحلية عميقة (بحر)
  static const Color bgDeep = Color(0xFF0B0E1A);
  static const Color surface = Color(0xFF171B2E);
  static const Color surfaceAlt = Color(0xFF15151F);
  static const Color surfaceRaised = Color(0xFF1F2438);

  // البنفسجي — العلامة الأساسية
  static const Color primary = Color(0xFF7C6FF0);
  static const Color primaryDim = Color(0xFF5B4FBE);

  // النحاسي — تمييز ثانوي / تحذير دافئ (بديل الأحمر التقليدي)
  static const Color copper = Color(0xFFC98A4E);
  static const Color copperLight = Color(0xFFE0A868);

  // دلالات الحالة
  static const Color success = Color(0xFF3FBF8F);
  static const Color danger = Color(0xFFE8615C);
  static const Color info = Color(0xFF48CAE4);
  static const Color highlight = Color(0xFFFFD18A);

  static const Color textPrimary = Color(0xFFF5F4FA);
  static const Color textMuted = Color(0xFFB6B3C9);

  /// تدرج الخلفية الرئيسي: من الكحلي العميق إلى لمسة بنفسجية خافتة.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgDeep, surface],
  );

  /// تدرج بنفسجي-نحاسي لأزرار الفعل الرئيسية والبطاقات المميزة.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, copper],
  );
}

class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Cairo';

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle muted = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        secondary: AppColors.copper,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.bgDeep,
      fontFamily: AppTextStyles.fontFamily,
      useMaterial3: true,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardColor: AppColors.surfaceRaised,
      dividerColor: AppColors.textMuted.withOpacity(0.15),
    );
  }
}
