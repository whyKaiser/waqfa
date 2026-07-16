import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'input_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'learn_screen.dart';
import 'evidence_screen.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _contentController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleFade;
  late List<Animation<Offset>> _cardSlides;
  late List<Animation<double>> _cardFades;
  late Animation<double> _buttonFade;
  late Animation<Offset> _buttonSlide;

  final _features = [
    (
      Icons.credit_card_off_outlined,
      'يراقب أقساط BNPL',
      'تمارا، تابي، وغيرها',
      AppColors.danger
    ),
    (
      Icons.warning_amber_outlined,
      'إنذار مبكر ذكي',
      'قبل ما تقع في المشكلة',
      AppColors.copper
    ),
    (
      Icons.psychology_outlined,
      'تحليل بالذكاء الاصطناعي',
      'نصيحة شخصية بالعربي',
      AppColors.primary
    ),
  ];

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _contentController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _logoController, curve: const Interval(0.0, 0.5)));

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _contentController,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)));
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _contentController, curve: const Interval(0.0, 0.4)));

    _cardSlides = List.generate(
        3,
        (i) => Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _contentController,
                curve: Interval(0.2 + i * 0.15, 0.6 + i * 0.15,
                    curve: Curves.easeOutCubic))));
    _cardFades = List.generate(
        3,
        (i) => Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
            parent: _contentController,
            curve: Interval(0.2 + i * 0.15, 0.6 + i * 0.15))));

    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _contentController, curve: const Interval(0.7, 1.0)));
    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _contentController,
            curve: const Interval(0.7, 1.0, curve: Curves.easeOutCubic)));

    Future.delayed(const Duration(milliseconds: 100), () {
      _logoController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _contentController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    HapticFeedback.lightImpact();
    Navigator.push(context, _smoothRoute(screen));
  }

  PageRouteBuilder _smoothRoute(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (_, animation, __) => screen,
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.info],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.pause_circle_outline_rounded,
                              color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                    // Quick actions
                    FadeTransition(
                      opacity: _logoFade,
                      child: Row(
                        children: [
                          _IconBtn(
                            icon: Icons.science_outlined,
                            label: 'مختبر التحقق',
                            onTap: () => _navigateTo(const EvidenceScreen()),
                          ),
                          const SizedBox(width: 8),
                          _IconBtn(
                            icon: Icons.school_outlined,
                            label: 'التعلّم المالي',
                            onTap: () => _navigateTo(const LearnScreen()),
                          ),
                          const SizedBox(width: 8),
                          _IconBtn(
                            icon: Icons.person_outline_rounded,
                            label: 'الملف الشخصي',
                            onTap: () => _navigateTo(const ProfileScreen()),
                          ),
                          const SizedBox(width: 8),
                          _IconBtn(
                            icon: Icons.history_rounded,
                            label: 'السجل',
                            onTap: () => _navigateTo(const HistoryScreen()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Title
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleFade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('وقفة',
                            style: TextStyle(
                                fontSize: 46,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1)),
                        const SizedBox(height: 8),
                        Text('مستشارك المالي الذكي\nيحذرك قبل أن تقع في الدين',
                            style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white54,
                                height: 1.6)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Feature cards
                ...List.generate(
                    3,
                    (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SlideTransition(
                            position: _cardSlides[i],
                            child: FadeTransition(
                              opacity: _cardFades[i],
                              child: _FeatureCard(
                                icon: _features[i].$1,
                                title: _features[i].$2,
                                subtitle: _features[i].$3,
                                color: _features[i].$4,
                              ),
                            ),
                          ),
                        )),

                const Spacer(),

                // CTA Button
                SlideTransition(
                  position: _buttonSlide,
                  child: FadeTransition(
                    opacity: _buttonFade,
                    child: Column(
                      children: [
                        _PulseButton(
                          onTap: () => _navigateTo(const InputScreen()),
                        ),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                              'سجلك محفوظ محلياً، والتحليل السحابي لا يعمل إلا بموافقتك',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white24)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: Semantics(
        button: true,
        label: widget.label,
        child: Tooltip(
          message: widget.label,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Icon(widget.icon, color: Colors.white54, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _FeatureCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) => _c.reverse(),
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(widget.subtitle,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PulseButton({required this.onTap});

  @override
  State<_PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<_PulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    _glow = Tween<double>(begin: 0.3, end: 0.6)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.stop();
        HapticFeedback.mediumImpact();
      },
      onTapUp: (_) {
        _c.repeat(reverse: true);
        widget.onTap();
      },
      onTapCancel: () => _c.repeat(reverse: true),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.info],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(_glow.value),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text('ابدأ التحليل',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
