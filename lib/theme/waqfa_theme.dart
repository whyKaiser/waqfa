import 'package:flutter/material.dart';

/// Waqfa's banking palette: navy/blue product identity with AMAD's verified
/// clay, lavender, coral and sand accents.
class WaqfaColors {
  static const background = Color(0xFF07182D);
  static const navy = Color(0xFF0C2341);
  static const surface = Color(0xFF102B4B);
  static const primary = Color(0xFF3B7CFF);
  static const cyan = Color(0xFF48CAE4);
  static const amadSand = Color(0xFFF2EFE9);
  static const amadSandDeep = Color(0xFFEED6C6);
  static const amadClay = Color(0xFFC66E4E);
  static const amadLavender = Color(0xFF8B84D7);
  static const amadCoral = Color(0xFFF58E7C);
  static const safe = Color(0xFF22C55E);
  static const warning = Color(0xFFE7A23B);
  static const danger = amadCoral;
  static const textPrimary = Color(0xFFF8F6F1);
  static const textSecondary = Color(0xFFB9C5D2);

  const WaqfaColors._();
}

class WaqfaTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: WaqfaColors.primary,
      onPrimary: Colors.white,
      secondary: WaqfaColors.amadClay,
      onSecondary: Colors.white,
      tertiary: WaqfaColors.amadLavender,
      error: WaqfaColors.danger,
      surface: WaqfaColors.surface,
      onSurface: WaqfaColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: WaqfaColors.background,
      fontFamily: 'Cairo',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: WaqfaColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: WaqfaColors.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(.055),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: WaqfaColors.primary,
            width: 1.4,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: WaqfaColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WaqfaColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      dividerColor: Colors.white.withOpacity(.08),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: WaqfaColors.surface,
        contentTextStyle: TextStyle(
          fontFamily: 'Cairo',
          color: WaqfaColors.textPrimary,
        ),
      ),
    );
  }

  const WaqfaTheme._();
}
