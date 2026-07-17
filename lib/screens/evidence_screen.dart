import 'package:flutter/material.dart';

import '../services/risk_benchmark.dart';

class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({super.key});

  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  late final BenchmarkMetrics _metrics;

  static const _accent = Color(0xFF6C63FF);
  static const _cyan = Color(0xFF48CAE4);
  static const _safe = Color(0xFF6BCB77);
  static const _warning = Color(0xFFFFB347);
  static const _danger = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _metrics = RiskBenchmark.run();
  }

  String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text('كيف اختبرنا وقفة؟'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _intro(),
            const SizedBox(height: 14),
            _resultSummary(),
            const SizedBox(height: 14),
            _meaning(),
            const SizedBox(height: 14),
            _method(),
            const SizedBox(height: 14),
            _coverage(),
            const SizedBox(height: 14),
            _nextStep(),
            const SizedBox(height: 14),
            _technicalDetails(context),
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
            Icon(Icons.verified_outlined, color: _cyan),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'دليل أولي على منطق التنبيه',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 9),
          Text(
            'اختبرنا نفس محرك المخاطر الذي يراه المستخدم على ${_metrics.totalScenarios} حالة مالية اصطناعية، ثم راقبنا كل حالة يوميًا لمدة 90 يومًا.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 7, runSpacing: 7, children: [
            _chip('${_metrics.totalScenarios} حالة اصطناعية', _accent),
            _chip('90 يومًا', _cyan),
            _chip('نفس محرك التطبيق', _safe),
          ]),
        ]),
      );

  Widget _resultSummary() => _section(
        'ماذا وجدنا؟',
        Icons.fact_check_outlined,
        Column(children: [
          _resultRow(
            icon: Icons.warning_amber_rounded,
            color: _safe,
            title:
                'اكتشف ${_metrics.truePositives} من ${_metrics.criticalScenarios} حالة حرجة',
            subtitle: 'قارن التنبيه بنتيجة محاكاة مستقلة للتدفق النقدي.',
          ),
          const SizedBox(height: 10),
          _resultRow(
            icon: _metrics.falseNegatives == 0
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            color: _metrics.falseNegatives == 0 ? _safe : _danger,
            title: _metrics.falseNegatives == 0
                ? 'لم يفوّت حالة حرجة في هذه العينة'
                : 'فوّت ${_metrics.falseNegatives} حالات حرجة',
            subtitle: 'هذه نتيجة للعينة الاصطناعية وليست ضمانًا للمستقبل.',
          ),
          const SizedBox(height: 10),
          _resultRow(
            icon: Icons.notifications_active_outlined,
            color: _warning,
            title: 'أعطى ${_metrics.falsePositives} تنبيهًا احترازيًا زائدًا',
            subtitle: 'حالات نبه عنها المحرك ولم تصبح حرجة في المحاكاة.',
          ),
        ]),
      );

  Widget _meaning() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cyan.withOpacity(.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cyan.withOpacity(.22)),
        ),
        child:
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lightbulb_outline_rounded, color: _cyan, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'المعنى: وقفة يفضّل التنبيه المبكر على تفويت الخطر، لذلك قد يظهر تنبيه احترازي زائد. قبل الاستخدام المصرفي نحتاج Pilot حقيقي لمعايرة هذا التوازن.',
              style:
                  TextStyle(color: Colors.white70, fontSize: 12, height: 1.65),
            ),
          ),
        ]),
      );

  Widget _method() => _section(
        'كيف تم الاختبار؟',
        Icons.route_outlined,
        Column(children: [
          _methodStep(
            1,
            'ولّدنا حالات متنوعة',
            'دخل ومصاريف وأقساط وتوقيتات وصدمات مالية افتراضية.',
          ),
          _methodStep(
            2,
            'محرك وقفة اتخذ القرار',
            'رأى بيانات لحظة القرار فقط، دون معرفة الصدمة المستقبلية.',
          ),
          _methodStep(
            3,
            'محاكاة مستقلة كشفت النتيجة',
            'قارنّا التنبيه بما حدث فعليًا خلال 90 يومًا محاكى.',
            isLast: true,
          ),
        ]),
      );

  Widget _coverage() {
    const labels = [
      'مستقر',
      'تكدّس أقساط',
      'ضغط توقيت',
      'دخل متذبذب',
      'هش للطوارئ',
    ];
    return _section(
      'الحالات التي غطاها الاختبار',
      Icons.diversity_3_outlined,
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: labels.map((label) => _chip(label, _accent)).toList(),
      ),
    );
  }

  Widget _nextStep() => _section(
        'ما الخطوة التالية؟',
        Icons.rocket_launch_outlined,
        const Text(
          'تشغيل Pilot محدود ببيانات حقيقية مجهولة الهوية وبعد موافقة المستخدمين، ثم قياس دقة التنبيه والانحياز وهل غيّر التدخل القرار فعلًا.',
          style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.7),
        ),
      );

  Widget _technicalDetails(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.045),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: _accent,
            collapsedIconColor: Colors.white38,
            title: const Row(children: [
              Icon(Icons.data_object_rounded, color: _accent, size: 19),
              SizedBox(width: 8),
              Text(
                'التفاصيل التقنية',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ]),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _technicalRow('Seed ثابت', '${_metrics.seed}'),
              _technicalRow('عتبة التنبيه', '${_metrics.alertThreshold}/100'),
              _technicalRow(
                'اكتشاف الحالات الحرجة',
                _pct(_metrics.criticalRecall),
              ),
              _technicalRow(
                'معدل الإيجابيات الكاذبة',
                _pct(_metrics.falsePositiveRate),
              ),
              _technicalRow(
                'الأيام حتى أول ضغط مكتشف',
                'وسيط ${_metrics.medianLeadTimeDays.toStringAsFixed(0)} أيام',
              ),
              _technicalRow(
                'مصفوفة النتائج',
                'صحيح خطر ${_metrics.truePositives} · زائد ${_metrics.falsePositives} · فائت ${_metrics.falseNegatives} · صحيح آمن ${_metrics.trueNegatives}',
                isLast: true,
              ),
            ],
          ),
        ),
      );

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
            child: Text(
              _metrics.disclosure,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                height: 1.6,
              ),
            ),
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
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _resultRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withOpacity(.18)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ]),
          ),
        ]),
      );

  Widget _methodStep(
    int number,
    String title,
    String description, {
    bool isLast = false,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: _accent.withOpacity(.17),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                color: _accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ]),
          ),
        ]),
      );

  Widget _technicalRow(String label, String value, {bool isLast = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(.06)),
                ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ),
        ]),
      );

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(.22)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11)),
      );
}
