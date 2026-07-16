import 'package:flutter/material.dart';

import '../services/decision_outcome_service.dart';
import '../services/risk_benchmark.dart';
import '../theme/app_theme.dart';

class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({super.key});

  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  late final BenchmarkMetrics _metrics;
  DecisionOutcomeSummary? _outcomes;

  static const _accent = AppColors.primary;
  static const _cyan = AppColors.info;
  static const _safe = AppColors.success;
  static const _warning = AppColors.copper;

  @override
  void initState() {
    super.initState();
    _metrics = RiskBenchmark.run();
    DecisionOutcomeService.loadSummary().then((value) {
      if (mounted) setState(() => _outcomes = value);
    });
  }

  String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text('مختبر التحقق'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _intro(),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _metric('الحالات', '${_metrics.totalScenarios}', _accent),
                _metric('اكتشاف الحالات الحرجة', _pct(_metrics.criticalRecall),
                    _safe),
                _metric('الإنذارات الزائدة', _pct(_metrics.falseAlertRate),
                    _warning),
                _metric(
                    'وسيط الإنذار المبكر',
                    '${_metrics.medianLeadTimeDays.toStringAsFixed(0)} أيام',
                    _cyan),
                _metric(
                    'خفض المؤشر عند تنصيف القسط',
                    '${_metrics.meanRiskReductionPoints.toStringAsFixed(1)} نقاط',
                    _safe),
                _metric('نتائج حرجة تجنبتها المحاكاة',
                    _pct(_metrics.criticalOutcomeAvoidanceRate), _cyan),
              ],
            ),
            const SizedBox(height: 14),
            _confusionMatrix(),
            const SizedBox(height: 14),
            _archetypes(),
            const SizedBox(height: 14),
            _behaviorEvidence(),
            const SizedBox(height: 14),
            _disclosure(),
          ],
        ),
      ),
    );
  }

  Widget _intro() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accent.withOpacity(.20), _cyan.withOpacity(.08)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _accent.withOpacity(.28)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.science_outlined, color: _cyan),
            SizedBox(width: 8),
            Text('اختبار رجعي قابل لإعادة التشغيل',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ]),
          const SizedBox(height: 8),
          Text(
            '100 سيناريو مالي اصطناعي، خمسة أنماط، ومحاكاة يومية لمدة 90 يومًا. Seed: ${_metrics.seed}، عتبة التنبيه: ${_metrics.alertThreshold}/100.',
            style: const TextStyle(
                color: Colors.white60, fontSize: 12, height: 1.6),
          ),
        ]),
      );

  Widget _metric(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
      );

  Widget _confusionMatrix() => _section(
        'مصفوفة النتائج',
        Icons.grid_view_rounded,
        Wrap(spacing: 8, runSpacing: 8, children: [
          _pill('اكتشاف صحيح ${_metrics.truePositives}', _safe),
          _pill('إنذار زائد ${_metrics.falsePositives}', _warning),
          _pill(
              'حالة فائتة ${_metrics.falseNegatives}', AppColors.danger),
          _pill('أمان صحيح ${_metrics.trueNegatives}', _cyan),
        ]),
      );

  Widget _archetypes() {
    const labels = {
      'stable': 'مستقر',
      'bnplStack': 'تراكم أقساط',
      'timingSqueeze': 'أزمة توقيت',
      'variableIncome': 'دخل متذبذب',
      'shockSensitive': 'هش للطوارئ',
    };
    return _section(
      'تغطية الأنماط المالية',
      Icons.diversity_3_outlined,
      Column(
        children: _metrics.archetypeBreakdown.entries.map((entry) {
          final values = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(children: [
              Expanded(
                child: Text(labels[entry.key] ?? entry.key,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
              ),
              Text('${values['total']} حالة',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 12),
              Text('${values['critical']} حرجة',
                  style: const TextStyle(color: _warning, fontSize: 11)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _behaviorEvidence() {
    final data = _outcomes;
    return _section(
      'حلقة قياس التدخل السلوكي',
      Icons.psychology_alt_outlined,
      data == null
          ? const Center(child: CircularProgressIndicator())
          : data.total == 0
              ? const Text(
                  'لم تُسجل قرارات بعد. بعد كل محاكاة يستطيع المستخدم تسجيل هل أجّل أو خفّض أو ألغى أو أكمل الشراء.',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 12, height: 1.6),
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('تم تسجيل ${data.total} قرارات محلية مجهولة الهوية.',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                    'اختار بديلًا أكثر أمانًا: ${_pct(data.saferDecisionRate)}',
                    style: const TextStyle(
                        color: _safe,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'هذا قياس تفاعل داخل النموذج، وليس دليلًا على خفض التعثر.',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ]),
    );
  }

  Widget _disclosure() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _warning.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _warning.withOpacity(.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, color: _warning, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(_metrics.disclosure,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 11, height: 1.6)),
          ),
        ]),
      );

  Widget _section(String title, IconData icon, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.045),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: _accent, size: 19),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11)),
      );
}
