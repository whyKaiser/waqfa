import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService.init();
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  runApp(WaqfaApp(showOnboarding: !onboardingDone));
}

class WaqfaApp extends StatelessWidget {
  final bool showOnboarding;
  const WaqfaApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وقفة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
