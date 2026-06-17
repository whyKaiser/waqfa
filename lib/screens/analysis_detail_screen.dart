import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/storage_service.dart';

class AnalysisDetailScreen extends StatelessWidget {
  final AnalysisRecord record;

  const AnalysisDetailScreen({super.key, required this.record});

  Color get _riskColor => switch (record.riskLevel) {
    'danger' => const Color(0xFFFF6B6B),
    'warning' => const Color(0xFFFFB347),
    _ => const Color(0xFF6BCB77),
  };

  String get _riskLabel => switch (record.riskLevel) {
    'danger' => 'خطر',
    'warning' => 'تحذير',
    _ => 'جيد',
  };

  String _formatDate(DateTime date) {
    final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
      'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = record.salary - record.fixed - record.variable - record.bnpl;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_formatDate(record.date)),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // مؤشر دائري
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(children: [
                  SizedBox(
                    width: 140, height: 140,
                    child: CustomPaint(
                      painter: _GaugePainter(
                        value: (record.totalRatio / 100).clamp(0.0, 1.0),
                        color: _riskColor,
                      ),
                      child: Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${record.totalRatio}%',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _riskColor)),
                          Text(_riskLabel,
                              style: TextStyle(fontSize: 13, color: _riskColor.withOpacity(0.8))),
                        ],
                      )),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('نسبة المصاريف من الراتب',
                      style: TextStyle(fontSize: 13, color: Colors.white38)),
                ]),
              ),
              const SizedBox(height: 16),

              // أرقام
              Row(children: [
                Expanded(child: _StatCard(label: 'الراتب', value: '${record.salary.toInt()}', color: Colors.white70)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(label: 'المتبقي', value: '${remaining > 0 ? remaining.toInt() : 0}',
                    color: remaining > 0 ? const Color(0xFF6BCB77) : const Color(0xFFFF6B6B))),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(label: 'BNPL', value: '${record.bnplRatio}%',
                    color: record.bnplRatio > 20 ? const Color(0xFFFF6B6B) : const Color(0xFF6BCB77))),
              ]),
              const SizedBox(height: 16),

              // توزيع المصاريف
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('توزيع الراتب',
                        style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 16),
                    _ExpenseRow(label: 'مصاريف ثابتة', amount: record.fixed, salary: record.salary, color: const Color(0xFF6C63FF)),
                    _ExpenseRow(label: 'مصاريف متغيرة', amount: record.variable, salary: record.salary, color: const Color(0xFF48CAE4)),
                    _ExpenseRow(label: 'أقساط BNPL', amount: record.bnpl, salary: record.salary, color: const Color(0xFFFF6B6B)),
                    _ExpenseRow(label: 'المتبقي', amount: remaining > 0 ? remaining : 0, salary: record.salary, color: const Color(0xFF6BCB77)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // تحليل الذكاء الاصطناعي
              if (record.aiAnalysis.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.psychology_outlined, color: Color(0xFF6C63FF), size: 18),
                        SizedBox(width: 8),
                        Text('تحليل الذكاء الاصطناعي',
                            style: TextStyle(fontSize: 13, color: Colors.white38)),
                      ]),
                      const SizedBox(height: 12),
                      Text(record.aiAnalysis,
                          style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.8)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // تنبيه
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _riskColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _riskColor.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_riskLabel == 'خطر' ? Icons.warning_rounded :
                    _riskLabel == 'تحذير' ? Icons.error_outline_rounded :
                    Icons.check_circle_outline_rounded,
                        color: _riskColor, size: 22),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      _riskLabel == 'خطر'
                          ? 'وضعك المالي في خطر — أوقف أي أقساط جديدة وركّز على السداد'
                          : _riskLabel == 'تحذير'
                          ? 'أنت تقترب من المنطقة الخطرة — لا تضيف أقساط جديدة'
                          : 'وضعك المالي جيد — استمر وحاول تزيد نسبة التوفير',
                      style: TextStyle(fontSize: 13, color: _riskColor, height: 1.6),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final String label;
  final double amount, salary;
  final Color color;

  const _ExpenseRow({required this.label, required this.amount, required this.salary, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = ((amount / salary) * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.white60))),
            Text('${amount.toInt()} ريال', style: const TextStyle(fontSize: 13, color: Colors.white60)),
            const SizedBox(width: 8),
            Text('$pct%', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (amount / salary).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white38), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false,
        Paint()..color = Colors.white.withOpacity(0.08)..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * value, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}
