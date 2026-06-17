import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

/// محاكي "ماذا لو؟" — يجسّد جوهر فكرة وقفة: نوقفك قبل لا تقع.
/// المستخدم/اللجنة يحرّك السلايدر ويشوف نسبته والـ gauge تتغيّر لحظياً.
class SimulatorScreen extends StatefulWidget {
  final double salary;
  final double fixed;
  final double variable;
  final double bnpl;

  const SimulatorScreen({
    super.key,
    required this.salary,
    required this.fixed,
    required this.variable,
    required this.bnpl,
  });

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  late double _bnpl;
  late double _variable;

  static const _danger = Color(0xFFFF6B6B);
  static const _warning = Color(0xFFFFB347);
  static const _safe = Color(0xFF6BCB77);
  static const _accent = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _bnpl = widget.bnpl;
    _variable = widget.variable;
  }

  double get _total => widget.fixed + _variable + _bnpl;
  double get _remaining => widget.salary - _total;
  int get _bnplRatio => ((_bnpl / widget.salary) * 100).round();
  int get _totalRatio => ((_total / widget.salary) * 100).round();

  int get _risk {
    if (_bnplRatio > 30 || _totalRatio > 90) return 2; // خطر
    if (_bnplRatio > 20 || _totalRatio > 75) return 1; // تحذير
    return 0; // آمن
  }

  Color get _color => switch (_risk) { 2 => _danger, 1 => _warning, _ => _safe };
  String get _label => switch (_risk) { 2 => 'خطر', 1 => 'تحذير', _ => 'آمن' };

  String get _verdict {
    final diff = (_bnpl - widget.bnpl).round();
    if (diff > 0) {
      return 'لو أضفت قسط بقيمة $diff ريال، أقساطك توصل $_bnplRatio% من راتبك — وضعك يصير "$_label".';
    } else if (diff < 0) {
      return 'لو قلّلت أقساطك بـ ${-diff} ريال، تنزل لـ $_bnplRatio% — وضعك يصير "$_label".';
    }
    return 'هذا وضعك الحالي: أقساط $_bnplRatio%، مصاريف $_totalRatio% — "$_label".';
  }

  @override
  Widget build(BuildContext context) {
    final maxBnpl = (widget.salary * 0.9).clamp(1000, double.infinity);
    final maxVar = (widget.salary * 0.9).clamp(1000, double.infinity);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('محاكي: ماذا لو؟'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'حرّك الأرقام وشوف وضعك يتغيّر لحظياً — قبل ما تقرر',
                style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Live gauge
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _color.withOpacity(0.3)),
                ),
                child: Column(children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: CustomPaint(
                      painter: _SimGauge(
                        value: (_totalRatio / 100).clamp(0.0, 1.0),
                        color: _color,
                      ),
                      child: Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: _color),
                            child: Text('$_totalRatio%'),
                          ),
                          Text(_label, style: TextStyle(fontSize: 16, color: _color.withOpacity(0.85), fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('نسبة المصاريف من راتبك', style: TextStyle(fontSize: 12, color: Colors.white38)),
                ]),
              ),
              const SizedBox(height: 16),
              // Verdict
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _color.withOpacity(0.25)),
                ),
                child: Row(children: [
                  Icon(_risk == 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded, color: _color, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_verdict, style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.6))),
                ]),
              ),
              const SizedBox(height: 24),
              _slider(
                label: 'أقساط BNPL',
                value: _bnpl,
                max: maxBnpl.toDouble(),
                color: _danger,
                onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _bnpl = v); },
              ),
              const SizedBox(height: 16),
              _slider(
                label: 'مصاريف متغيرة',
                value: _variable,
                max: maxVar.toDouble(),
                color: _accent,
                onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _variable = v); },
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _miniStat('المتبقي', '${_remaining > 0 ? _remaining.toInt() : 0}', _remaining > 0 ? Colors.white70 : _danger)),
                const SizedBox(width: 10),
                Expanded(child: _miniStat('نسبة BNPL', '$_bnplRatio%', _bnplRatio > 20 ? _danger : _safe)),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () { HapticFeedback.lightImpact(); setState(() { _bnpl = widget.bnpl; _variable = widget.variable; }); },
                  child: const Text('إرجاع لوضعي الحالي', style: TextStyle(color: Colors.white38)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider({required String label, required double value, required double max, required Color color, required ValueChanged<double> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.white60)),
          Text('${value.toInt()} ريال', style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w700)),
        ]),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 5,
          ),
          child: Slider(value: value.clamp(0, max), min: 0, max: max, onChanged: onChanged),
        ),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white38)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _SimGauge extends CustomPainter {
  final double value;
  final Color color;
  _SimGauge({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false,
        Paint()..color = Colors.white.withOpacity(0.08)..style = PaintingStyle.stroke..strokeWidth = 15..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep * value, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 15..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_SimGauge old) => old.value != value || old.color != color;
}
