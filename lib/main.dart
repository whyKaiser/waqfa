import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

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
      theme: AppTheme.dark,
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
