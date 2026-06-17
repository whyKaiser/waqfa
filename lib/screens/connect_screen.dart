import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// محاكاة المصرفية المفتوحة — دمج بيانات من مصادر متعددة.
/// (نموذج تجريبي: يحاكي السحب الآمن من بنك + محفظة + مزوّدي BNPL)
/// يرجّع للشاشة السابقة خريطة الأرقام المجمّعة لتعبئة الإدخال تلقائياً.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _Source {
  final String name;
  final String detail;
  final IconData icon;
  final Color color;
  int status = 0; // 0 pending, 1 connecting, 2 connected
  _Source(this.name, this.detail, this.icon, this.color);
}

class _ConnectScreenState extends State<ConnectScreen> {
  static const _accent = Color(0xFF6C63FF);

  // أرقام تجريبية مجمّعة (تطابق سيناريو العرض → حالة تحذير)
  static const _salary = 8000.0;
  static const _fixed = 3500.0;
  static const _variable = 1500.0;
  static const _bnpl = 1800.0;

  late final List<_Source> _sources;
  bool _connecting = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _sources = [
      _Source('بنك الإنماء', 'الراتب والمصاريف الثابتة', Icons.account_balance_outlined, const Color(0xFF6C63FF)),
      _Source('STC Pay', 'المصاريف والمحفظة', Icons.account_balance_wallet_outlined, const Color(0xFF48CAE4)),
      _Source('تمارا وتابي', 'أقساط BNPL', Icons.credit_card_outlined, const Color(0xFFFF6B6B)),
    ];
  }

  Future<void> _connectAll() async {
    setState(() => _connecting = true);
    for (var i = 0; i < _sources.length; i++) {
      if (!mounted) return;
      setState(() => _sources[i].status = 1);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _sources[i].status = 2);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _done = true);
  }

  void _useData() {
    Navigator.pop(context, {
      'salary': _salary,
      'fixed': _fixed,
      'variable': _variable,
      'bnpl': _bnpl,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('ربط حساباتك'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accent.withOpacity(0.2)),
                ),
                child: const Row(children: [
                  Icon(Icons.lock_outline, color: _accent, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'وقفة يجمع بياناتك من مصادرك المالية عبر المصرفية المفتوحة، باتصال آمن ومشفّر. بياناتك تبقى لك.',
                      style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.6),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              ..._sources.map(_sourceTile),
              const Spacer(),
              if (_done)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6BCB77).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF6BCB77).withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.check_circle, color: Color(0xFF6BCB77), size: 22),
                    SizedBox(width: 12),
                    Expanded(child: Text('تم استيراد بياناتك بنجاح من 3 مصادر',
                        style: TextStyle(fontSize: 13, color: Colors.white70))),
                  ]),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _connecting && !_done ? null : (_done ? _useData : _connectAll),
                  icon: Icon(_done ? Icons.analytics_outlined : Icons.sync_rounded, size: 20),
                  label: Text(_done ? 'حلّل بياناتي الآن' : (_connecting ? 'جاري الربط...' : 'اربط الكل')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _done ? const Color(0xFF6BCB77) : _accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white.withOpacity(0.1),
                    disabledForegroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceTile(_Source s) {
    Widget trailing;
    switch (s.status) {
      case 1:
        trailing = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54));
        break;
      case 2:
        trailing = const Icon(Icons.check_circle, color: Color(0xFF6BCB77), size: 24);
        break;
      default:
        trailing = const Icon(Icons.circle_outlined, color: Colors.white24, size: 24);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(s.status == 2 ? 0.07 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.status == 2 ? const Color(0xFF6BCB77).withOpacity(0.3) : Colors.white.withOpacity(0.08)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: s.color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(s.icon, color: s.color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text(s.detail, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
        ),
        trailing,
      ]),
    );
  }
}
