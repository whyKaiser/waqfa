import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/claude_service.dart';

/// التعليم المالي التفاعلي — يشرح المصطلحات ببساطة عبر الذكاء الاصطناعي.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static const _terms = [
    ('BNPL', 'اشترِ الآن وادفع لاحقاً', Icons.credit_card_outlined, Color(0xFFFF6B6B)),
    ('التورق', 'تمويل متوافق مع الشريعة', Icons.swap_horiz_rounded, Color(0xFF48CAE4)),
    ('الادخار', 'تأمين مستقبلك المالي', Icons.savings_outlined, Color(0xFF6BCB77)),
    ('الاستثمار', 'تنمية فلوسك مع الوقت', Icons.trending_up_rounded, Color(0xFFFFB347)),
    ('الميزانية الشخصية', 'توزيع دخلك بذكاء', Icons.pie_chart_outline, Color(0xFF6C63FF)),
    ('نسبة الدين إلى الدخل', 'مقياس صحتك المالية', Icons.balance_outlined, Color(0xFFFF6B6B)),
  ];

  void _open(BuildContext context, String term) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15151F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TermSheet(term: term),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('تعلّم المال'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'مصطلحات مالية يشرحها لك وقفة ببساطة — اضغط أي واحد.',
              style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.6),
            ),
            const SizedBox(height: 20),
            ..._terms.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => _open(context, t.$1),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: t.$4.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: Icon(t.$3, color: t.$4, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(t.$2, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          ]),
                        ),
                        const Icon(Icons.chevron_left_rounded, color: Colors.white24),
                      ]),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _TermSheet extends StatefulWidget {
  final String term;
  const _TermSheet({required this.term});

  @override
  State<_TermSheet> createState() => _TermSheetState();
}

class _TermSheetState extends State<_TermSheet> {
  String? _text;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final r = await ClaudeService.explainTerm(widget.term);
    if (mounted) setState(() => _text = r);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              const Icon(Icons.school_outlined, color: Color(0xFF6C63FF), size: 22),
              const SizedBox(width: 10),
              Text(widget.term, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            _text == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
                  )
                : Text(_text!, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.9)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
