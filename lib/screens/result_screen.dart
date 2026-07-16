import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/financial_decision_engine.dart';
import '../services/financial_prevention_engine.dart';
import '../theme/waqfa_theme.dart';
import 'simulator_screen.dart';
import 'waqfa_plan_screen.dart';

class ResultScreen extends StatefulWidget {
  final double salary;
  final double fixed;
  final double variable;
  final double bnpl;
  final String concern;
  final bool allowCloudAi;

  const ResultScreen({
    super.key,
    required this.salary,
    required this.fixed,
    required this.variable,
    required this.bnpl,
    required this.concern,
    this.allowCloudAi = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  String? _aiAnalysis;
  bool _loading = true;
  bool _analysisUsedCloud = false;
  TrendResult? _trend;
  late AnimationController _animController;
  late Animation<double> _animation;

  late double _remaining;
  late int _bnplRatio;
  late int _totalRatio;
  late _RiskLevel _riskLevel;
  late DecisionAnalysis _decisionAnalysis;
  late FinancialPreventionAnalysis _prevention;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _animation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _calculate();
    _animController.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    // اقرأ السجل السابق بالكامل قبل حفظ التحليل الحالي حتى يبقى الاتجاه صحيحًا.
    await _fetchTrend();
    await _fetchAnalysis();
  }

  Future<void> _fetchTrend() async {
    try {
      final trend = await StorageService.analyzeTrend();
      if (mounted) setState(() => _trend = trend);
    } catch (_) {
      if (mounted) setState(() => _trend = TrendResult.insufficient());
    }
  }

  /// نفس محرك القرار المستخدم في «وقفة قبل تدفع» حتى لا تظهر درجتان
  /// متناقضتان للحالة المالية ذاتها.
  int get _compositeScore => _decisionAnalysis.currentRisk;

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _calculate() {
    final total = widget.fixed + widget.variable + widget.bnpl;
    _remaining = widget.salary - total;
    final safeSalary = widget.salary > 0 ? widget.salary : 1;
    _bnplRatio = ((widget.bnpl / safeSalary) * 100).round();
    _totalRatio = ((total / safeSalary) * 100).round();
    final profile = FinancialProfile(
      salary: widget.salary,
      fixedExpenses: widget.fixed,
      variableExpenses: widget.variable,
      currentBnpl: widget.bnpl,
    );
    _decisionAnalysis = FinancialDecisionEngine.analyze(
      profile,
      proposedInstallment: 0,
    );
    _prevention = FinancialPreventionEngine.analyze(
      profile,
      proposedInstallment: 0,
    );
    if (_compositeScore >= FinancialDecisionEngine.dangerThreshold) {
      _riskLevel = _RiskLevel.danger;
    } else if (_compositeScore >= FinancialDecisionEngine.warningThreshold) {
      _riskLevel = _RiskLevel.warning;
    } else {
      _riskLevel = _RiskLevel.safe;
    }
  }

  Future<void> _saveRecord({String aiText = ''}) async {
    try {
      if (_riskLevel == _RiskLevel.danger) {
        await NotificationService.sendWarning(
          title: "⚠️ تحذير — وضعك المالي في خطر",
          body:
              "مؤشر الضغط المالي مرتفع. افتح وقفة لمعرفة السبب وخطوتك الآمنة الآن.",
        );
      } else if (_riskLevel == _RiskLevel.warning) {
        await NotificationService.sendWarning(
          title: "انتبه — أنت تقترب من المنطقة الخطرة",
          body: "راجع مصاريفك قبل نهاية الشهر.",
        );
      }
    } catch (_) {}

    await StorageService.saveAnalysis(AnalysisRecord(
      date: DateTime.now(),
      salary: widget.salary,
      fixed: widget.fixed,
      variable: widget.variable,
      bnpl: widget.bnpl,
      totalRatio: _totalRatio,
      bnplRatio: _bnplRatio,
      riskLevel: _riskLevel == _RiskLevel.danger
          ? 'danger'
          : _riskLevel == _RiskLevel.warning
              ? 'warning'
              : 'safe',
      aiAnalysis: aiText,
    ));
  }

  Future<void> _fetchAnalysis() async {
    final result = await AiService.analyzeFinances(
      salary: widget.salary,
      fixed: widget.fixed,
      variable: widget.variable,
      bnpl: widget.bnpl,
      concern: widget.concern,
      allowCloud: widget.allowCloudAi,
    );
    if (mounted) {
      setState(() {
        _aiAnalysis = result.text;
        _analysisUsedCloud = result.usedCloud;
        _loading = false;
      });
      try {
        await _saveRecord(aiText: result.text);
      } catch (_) {
        // Keep the result visible even if local persistence fails.
      }
    }
  }

  String _buildReport() {
    final riskLabel = _riskLevel == _RiskLevel.danger
        ? 'خطر'
        : _riskLevel == _RiskLevel.warning
            ? 'تحذير'
            : 'جيد';
    final b = StringBuffer();
    b.writeln('📊 تقرير وقفة المالي');
    b.writeln('━━━━━━━━━━━━━━');
    b.writeln('الحالة: $riskLabel');
    b.writeln('نسبة المصاريف: $_totalRatio% من الراتب');
    b.writeln('نسبة أقساط BNPL: $_bnplRatio%');
    b.writeln('المتبقي: ${_remaining > 0 ? _remaining.toInt() : 0} ريال');
    b.writeln('');
    b.writeln(_analysisUsedCloud
        ? '🔎 تحليل الذكاء الاصطناعي السحابي:'
        : '🔎 التحليل المحلي الآمن:');
    b.writeln(_aiAnalysis ?? 'قيد التحليل...');
    b.writeln('');
    b.writeln('— تم إنشاؤه بواسطة تطبيق وقفة');
    return b.toString();
  }

  void _copyReport() {
    Clipboard.setData(ClipboardData(text: _buildReport()));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ تقريرك — تقدر تشاركه أو تحفظه')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('نتيجة التحليل'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loading ? null : _copyReport,
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'مشاركة التقرير',
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (_, __) => _RiskGauge(
                  riskScore: _compositeScore,
                  riskLevel: _riskLevel,
                  progress: _animation.value,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.analytics_outlined,
                      size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  const Text('مؤشر وقائي تجريبي — ليس تقييمًا ائتمانيًا',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
              if (_trend != null && _trend!.worsening) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB347).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFFFB347).withOpacity(0.3)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.trending_up_rounded,
                            color: Color(0xFFFFB347), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(_trend!.message,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    height: 1.6))),
                      ]),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                      child: _StatCard(
                          label: 'نسبة BNPL',
                          value: '$_bnplRatio%',
                          color: _bnplRatio > 20
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF6BCB77))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatCard(
                          label: 'المصاريف',
                          value: '$_totalRatio%',
                          color: _totalRatio > 75
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF6BCB77))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatCard(
                          label: 'المتبقي',
                          value: '${_remaining > 0 ? _remaining.toInt() : 0}',
                          color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 20),
              _ExpenseChart(
                salary: widget.salary,
                fixed: widget.fixed,
                variable: widget.variable,
                bnpl: widget.bnpl,
                remaining: _remaining,
              ),
              const SizedBox(height: 20),
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
                    Row(children: [
                      const Icon(Icons.psychology_outlined,
                          color: Color(0xFF6C63FF), size: 20),
                      const SizedBox(width: 8),
                      Text(
                          _analysisUsedCloud
                              ? 'تحليل الذكاء الاصطناعي السحابي'
                              : widget.allowCloudAi
                                  ? 'تحليل محلي احتياطي — تعذّر الاتصال السحابي'
                                  : 'تحليل محلي — لم تُرسل بياناتك',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white38)),
                    ]),
                    const SizedBox(height: 12),
                    _loading
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                    color: Color(0xFF6C63FF))))
                        : Text(_aiAnalysis ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white70, height: 1.8)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _PreventionSnapshot(prevention: _prevention),
              const SizedBox(height: 16),
              // جدار حماية القرار — لحظة العرض الرئيسية أمام لجنة التحكيم
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SimulatorScreen(
                        salary: widget.salary,
                        fixed: widget.fixed,
                        variable: widget.variable,
                        bnpl: widget.bnpl,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.shield_outlined, size: 20),
                  label: const Text('وقفة قبل تدفع — اختبر قرارك'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WaqfaColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WaqfaPlanScreen(
                        initialProfile: FinancialProfile(
                          salary: widget.salary,
                          fixedExpenses: widget.fixed,
                          variableExpenses: widget.variable,
                          currentBnpl: widget.bnpl,
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('ابنِ خطة وقفة لهدفك'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('تحليل جديد'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RiskLevel { safe, warning, danger }

class _RiskGauge extends StatelessWidget {
  final int riskScore;
  final _RiskLevel riskLevel;
  final double progress;
  const _RiskGauge(
      {required this.riskScore,
      required this.riskLevel,
      required this.progress});

  @override
  Widget build(BuildContext context) {
    final color = switch (riskLevel) {
      _RiskLevel.danger => const Color(0xFFFF6B6B),
      _RiskLevel.warning => const Color(0xFFFFB347),
      _RiskLevel.safe => const Color(0xFF6BCB77),
    };
    final label = switch (riskLevel) {
      _RiskLevel.danger => 'خطر',
      _RiskLevel.warning => 'تحذير',
      _RiskLevel.safe => 'جيد',
    };
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(children: [
        SizedBox(
          width: 160,
          height: 160,
          child: CustomPaint(
            painter: _GaugePainter(
                value: (riskScore / 100).clamp(0.0, 1.0) * progress,
                color: color),
            child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text('$riskScore/100',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  Text(label,
                      style: TextStyle(
                          fontSize: 14, color: color.withOpacity(0.8))),
                ])),
          ),
        ),
        const SizedBox(height: 12),
        const Text('مؤشر الضغط المالي',
            style: TextStyle(fontSize: 13, color: Colors.white38)),
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
    final radius = size.width / 2 - 12;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = Colors.white.withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * value,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}

class _ExpenseChart extends StatelessWidget {
  final double salary, fixed, variable, bnpl, remaining;
  const _ExpenseChart(
      {required this.salary,
      required this.fixed,
      required this.variable,
      required this.bnpl,
      required this.remaining});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('مصاريف ثابتة', fixed, const Color(0xFF6C63FF)),
      ('مصاريف متغيرة', variable, const Color(0xFF48CAE4)),
      ('أقساط BNPL', bnpl, const Color(0xFFFF6B6B)),
      ('المتبقي', remaining > 0 ? remaining : 0, const Color(0xFF6BCB77)),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('توزيع راتبك',
            style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
              children: items.map((item) {
            final pct = (item.$2 / salary).clamp(0.0, 1.0);
            return Flexible(
                flex: math.max(1, (pct * 1000).round()),
                child: Container(height: 12, color: item.$3));
          }).toList()),
        ),
        const SizedBox(height: 16),
        ...items.map((item) {
          final pct = salary > 0 ? ((item.$2 / salary) * 100).round() : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: item.$3, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(item.$1,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white60))),
              Text('$pct%',
                  style: TextStyle(
                      fontSize: 13,
                      color: item.$3,
                      fontWeight: FontWeight.w500)),
            ]),
          );
        }),
      ]),
    );
  }
}

class _PreventionSnapshot extends StatelessWidget {
  final FinancialPreventionAnalysis prevention;

  const _PreventionSnapshot({required this.prevention});

  @override
  Widget build(BuildContext context) {
    final forecast = prevention.currentForecast;
    final probability = (forecast.criticalProbability * 100).round();
    final date = forecast.fallDay == null
        ? 'لا يظهر خلال 90 يومًا'
        : _dateAfter(forecast.fallDay!);
    final safeDaily = prevention.safeDailySpend.round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WaqfaColors.amadLavender.withOpacity(.16),
            WaqfaColors.primary.withOpacity(.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WaqfaColors.amadLavender.withOpacity(.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.radar_rounded,
                  color: WaqfaColors.amadLavender, size: 20),
              SizedBox(width: 8),
              Text(
                'نافذة الوقاية الحالية',
                style: TextStyle(
                  color: WaqfaColors.amadSand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _line(
            Icons.event_busy_outlined,
            'تاريخ السقوط المالي',
            date,
            forecast.fallDay == null ? WaqfaColors.safe : WaqfaColors.danger,
          ),
          _line(
            Icons.percent_rounded,
            'احتمال الضغط في المحاكاة',
            '$probability% (${forecast.criticalPaths}/${forecast.totalPaths} مسار)',
            probability >= 60 ? WaqfaColors.danger : WaqfaColors.warning,
          ),
          _line(
            Icons.account_balance_wallet_outlined,
            'حد الإنفاق اليومي الآمن',
            '$safeDaily ريال',
            WaqfaColors.cyan,
          ),
          const SizedBox(height: 7),
          Text(
            forecast.disclosure,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String label, String value, Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );

  String _dateAfter(int day) {
    final date = DateTime.now().add(Duration(days: day + 1));
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard(
      {required this.label, required this.value, required this.color});

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
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white38),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
