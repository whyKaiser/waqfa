import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  final _pages = [
    _OnboardingPage(
      icon: Icons.sentiment_dissatisfied_rounded,
      title: 'تعرف هذا الشعور؟',
      subtitle:
          'آخر الشهر وما تعرف وين راحت فلوسك\nوأقساط تمارا وتابي تتراكم بدون ما تحس',
      color: AppColors.danger,
    ),
    _OnboardingPage(
      icon: Icons.psychology_alt_outlined,
      title: 'وقفة يشوف اللي ما تشوفه',
      subtitle: 'يجمع كل أقساطك ومصاريفك\nويحسب نسبة الخطر على راتبك تلقائياً',
      color: AppColors.primary,
    ),
    _OnboardingPage(
      icon: Icons.notification_important_outlined,
      title: 'ينذرك قبل ما تقع',
      subtitle:
          'مو بعد ما تغرق في الديون\nبل قبلها — بتحليل ذكي وخطوة عملية واحدة',
      color: AppColors.copper,
    ),
    _OnboardingPage(
      icon: Icons.verified_outlined,
      title: 'جاهز تبدأ؟',
      subtitle:
          'سجلك محفوظ على جوالك\nوالتحليل السحابي اختياري ولا يعمل إلا بموافقتك',
      color: AppColors.success,
      isLast: true,
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // Skip
              Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('تخطي',
                      style: TextStyle(color: Colors.white38)),
                ),
              ),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _pages[i],
                ),
              ),

              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? _pages[_currentPage].color
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pages[_currentPage].color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1
                          ? 'ابدأ الحين'
                          : 'التالي',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLast;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // أيقونة واضحة تعمل بدون اعتماد على خطوط الإيموجي.
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 2),
            ),
            child: Center(child: Icon(icon, size: 54, color: color)),
          ),
          const SizedBox(height: 40),

          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white54,
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
