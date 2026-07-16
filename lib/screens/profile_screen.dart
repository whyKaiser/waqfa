import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';

/// شاشة الملف التخصيصي — تجعل التخصيص جوهر التجربة.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _accent = AppColors.primary;

  String _age = '';
  String _income = '';
  String _risk = '';
  final Set<String> _goals = {};
  bool _loaded = false;

  static const _ages = ['أقل من 25', '25 - 34', '35 - 44', '45+'];
  static const _incomes = ['راتب ثابت', 'دخل حر', 'طالب', 'متقاعد'];
  static const _allGoals = ['ادخار', 'سداد ديون', 'شراء سيارة', 'الزواج', 'السفر', 'الاستثمار', 'تملّك سكن'];
  static const _risks = ['متحفّظ', 'متوازن', 'مغامر'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ProfileService.load();
    setState(() {
      _age = p.ageRange;
      _income = p.incomeType;
      _risk = p.riskAppetite;
      _goals.addAll(p.goals);
      _loaded = true;
    });
  }

  Future<void> _save() async {
    await ProfileService.save(UserProfile(
      ageRange: _age,
      incomeType: _income,
      goals: _goals.toList(),
      riskAppetite: _risk,
    ));
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ ملفك — التحليلات الجاية بتتخصّص لك')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('ملفك التخصيصي'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'كل ما عرّفنا عنك أكثر، صارت توصيات وقفة أدق وأخصّ لك.',
                      style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    _section('فئتك العمرية', _ages, _age, (v) => setState(() => _age = v)),
                    _section('نوع دخلك', _incomes, _income, (v) => setState(() => _income = v)),
                    _multiSection('أهدافك المالية', _allGoals),
                    _section('ميولك للمخاطرة', _risks, _risk, (v) => setState(() => _risk = v)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('حفظ الملف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _section(String title, List<String> options, String selected, ValueChanged<String> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final on = selected == o;
            return _chip(o, on, () { HapticFeedback.selectionClick(); onPick(o); });
          }).toList(),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _multiSection(String title, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final on = _goals.contains(o);
            return _chip(o, on, () {
              HapticFeedback.selectionClick();
              setState(() => on ? _goals.remove(o) : _goals.add(o));
            });
          }).toList(),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: on ? _accent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? _accent : Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: on ? Colors.white : Colors.white60,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
