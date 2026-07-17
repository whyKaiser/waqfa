import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_service.dart';
import '../services/financial_decision_engine.dart';
import '../services/financial_prevention_engine.dart';
import '../services/goal_plan_engine.dart';
import '../theme/waqfa_theme.dart';

class WaqfaPlanScreen extends StatefulWidget {
  final FinancialProfile? initialProfile;

  const WaqfaPlanScreen({super.key, this.initialProfile});

  @override
  State<WaqfaPlanScreen> createState() => _WaqfaPlanScreenState();
}

class _WaqfaPlanScreenState extends State<WaqfaPlanScreen> {
  late final TextEditingController _salary;
  late final TextEditingController _fixed;
  late final TextEditingController _variable;
  late final TextEditingController _bnpl;
  final _target = TextEditingController(text: '6000');

  GoalType _goal = GoalType.travel;
  int _days = 90;
  bool _allowCloud = false;
  bool _loading = false;
  GoalPlan? _plan;
  FinancialPreventionAnalysis? _prevention;
  GoalPlanNarrative? _narrative;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile ??
        const FinancialProfile(
          salary: 8000,
          fixedExpenses: 3500,
          variableExpenses: 1500,
          currentBnpl: 1800,
        );
    _salary = TextEditingController(text: profile.salary.round().toString());
    _fixed =
        TextEditingController(text: profile.fixedExpenses.round().toString());
    _variable = TextEditingController(
      text: profile.variableExpenses.round().toString(),
    );
    _bnpl = TextEditingController(text: profile.currentBnpl.round().toString());
  }

  @override
  void dispose() {
    _salary.dispose();
    _fixed.dispose();
    _variable.dispose();
    _bnpl.dispose();
    _target.dispose();
    super.dispose();
  }

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  Future<void> _buildPlan() async {
    if (_loading) return;
    final values = [_salary, _fixed, _variable, _bnpl, _target]
        .map(_number)
        .toList(growable: false);
    if (values.any(
      (value) =>
          value == null || !value.isFinite || value < 0 || value > 100000000,
    )) {
      _message('تحقق من المبالغ المدخلة.');
      return;
    }
    if (values[0]! <= 0 || values[4]! <= 0) {
      _message('أدخل دخلًا وهدفًا أكبر من صفر.');
      return;
    }

    setState(() => _loading = true);
    try {
      final profile = FinancialProfile(
        salary: values[0]!,
        fixedExpenses: values[1]!,
        variableExpenses: values[2]!,
        currentBnpl: values[3]!,
      );
      final plan = GoalPlanEngine.build(
        profile: profile,
        goalType: _goal,
        targetAmount: values[4]!,
        targetDays: _days,
      );
      final prevention = FinancialPreventionEngine.analyze(
        profile,
        proposedInstallment: plan.plannedMonthlyContribution,
      );
      final narrative = await AiService.buildGoalPlanNarrative(
        plan: plan,
        allowCloud: _allowCloud,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _plan = plan;
        _prevention = prevention;
        _narrative = narrative;
      });
    } on ArgumentError catch (_) {
      if (mounted) _message('البيانات غير مكتملة أو غير منطقية.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('خطة وقفة')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _intro(),
            const SizedBox(height: 14),
            _goalPicker(),
            const SizedBox(height: 14),
            _financialInputs(),
            const SizedBox(height: 14),
            _durationPicker(),
            const SizedBox(height: 10),
            _cloudToggle(),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loading ? null : _buildPlan,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_loading ? 'يبني الخطة...' : 'ابنِ خطتي المحسوبة'),
            ),
            if (_plan != null && _prevention != null && _narrative != null) ...[
              const SizedBox(height: 22),
              _resultHero(_plan!),
              const SizedBox(height: 12),
              _metrics(_plan!),
              const SizedBox(height: 12),
              _riskWindow(_prevention!),
              const SizedBox(height: 12),
              _adjustment(_plan!),
              const SizedBox(height: 12),
              _narrativeCard(_narrative!),
              const SizedBox(height: 12),
              _weeklyPlan(_narrative!),
              const SizedBox(height: 10),
              const Text(
                'الأرقام من محركات وقفة المحلية. الصياغة السحابية — إن فُعّلت — تشرحها فقط ولا تغيّرها.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _intro() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              WaqfaColors.primary.withOpacity(.22),
              WaqfaColors.amadLavender.withOpacity(.10),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WaqfaColors.primary.withOpacity(.28)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'حوّل هدفك إلى أرقام قابلة للتنفيذ',
              style: TextStyle(
                color: WaqfaColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'وقفة يحمي احتياطي الأمان، يختبر الموعد، ويقترح أصغر تعديل إذا كانت الخطة تضغطك.',
              style: TextStyle(
                color: WaqfaColors.textSecondary,
                fontSize: 12,
                height: 1.65,
              ),
            ),
          ],
        ),
      );

  Widget _goalPicker() => _section(
        title: 'وش هدفك؟',
        icon: Icons.flag_outlined,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: GoalType.values.map((goal) {
            final selected = goal == _goal;
            return ChoiceChip(
              selected: selected,
              label: Text(_goalLabel(goal)),
              onSelected: (_) => setState(() => _goal = goal),
              selectedColor: WaqfaColors.primary.withOpacity(.28),
              side: BorderSide(
                color: selected
                    ? WaqfaColors.primary
                    : Colors.white.withOpacity(.10),
              ),
            );
          }).toList(),
        ),
      );

  Widget _financialInputs() => _section(
        title: 'البيانات والهدف',
        icon: Icons.calculate_outlined,
        child: Column(
          children: [
            Row(children: [
              Expanded(child: _moneyField(_salary, 'الدخل')),
              const SizedBox(width: 9),
              Expanded(child: _moneyField(_target, 'مبلغ الهدف')),
            ]),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: _moneyField(_fixed, 'الثابت')),
              const SizedBox(width: 9),
              Expanded(child: _moneyField(_variable, 'المتغير')),
              const SizedBox(width: 9),
              Expanded(child: _moneyField(_bnpl, 'الأقساط')),
            ]),
          ],
        ),
      );

  Widget _moneyField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(?:\.\d{0,2})?')),
        ],
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'ر.س',
          isDense: true,
        ),
      );

  Widget _durationPicker() => _section(
        title: 'مدة الخطة',
        icon: Icons.calendar_month_outlined,
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 أيام')),
            ButtonSegment(value: 30, label: Text('30 يوم')),
            ButtonSegment(value: 90, label: Text('90 يوم')),
          ],
          selected: {_days},
          onSelectionChanged: (value) => setState(() => _days = value.first),
          showSelectedIcon: false,
        ),
      );

  Widget _cloudToggle() => Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.04),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: SwitchListTile.adaptive(
          value: _allowCloud,
          onChanged: (value) => setState(() => _allowCloud = value),
          activeColor: WaqfaColors.primary,
          title: const Text(
            'صياغة ذكية اختيارية',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _allowCloud
                ? 'ترسل القيم المحسوبة إلى ${AiService.providerName} لصياغة الشرح.'
                : 'الخطة تعمل محليًا بالكامل دون إرسال بيانات.',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
      );

  Widget _resultHero(GoalPlan plan) {
    final color = switch (plan.feasibility) {
      GoalFeasibility.feasible => WaqfaColors.safe,
      GoalFeasibility.feasibleWithVariableReduction ||
      GoalFeasibility.feasibleWithExtension =>
        WaqfaColors.warning,
      GoalFeasibility.unreachable => WaqfaColors.danger,
    };
    final title = switch (plan.feasibility) {
      GoalFeasibility.feasible => 'هدفك ممكن بأمان',
      GoalFeasibility.feasibleWithVariableReduction => 'ممكن بتعديل صغير',
      GoalFeasibility.feasibleWithExtension => 'ممكن بوقت أطول',
      GoalFeasibility.unreachable => 'الخطة تحتاج إعادة ضبط',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Column(children: [
        Icon(Icons.route_rounded, color: color, size: 30),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${plan.targetAmount.round()} ريال خلال ${plan.effectiveTargetDays} يومًا',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ]),
    );
  }

  Widget _metrics(GoalPlan plan) => Row(children: [
        Expanded(
          child: _metric(
            'احمِ شهريًا',
            '${plan.plannedMonthlyContribution.round()}',
            WaqfaColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metric(
            'صرف يومي آمن',
            '${plan.safeDailySpend.round()}',
            WaqfaColors.safe,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metric(
            'احتياطي محمي',
            '${plan.safetyReserve.round()}',
            WaqfaColors.amadClay,
          ),
        ),
      ]);

  Widget _riskWindow(FinancialPreventionAnalysis analysis) {
    final forecast = analysis.proposedForecast;
    final probability = (forecast.criticalProbability * 100).round();
    final fallText = forecast.fallDay == null
        ? 'لا تظهر نافذة سقوط مالي داخل 90 يومًا'
        : 'نافذة السقوط المالي: اليوم ${forecast.fallDay! + 1} · ${_dateAfter(forecast.fallDay!)}';
    final recovery = analysis.recovery.afterDecisionDays;
    return _section(
      title: 'اختبار الخطة قبل اعتمادها',
      icon: Icons.radar_rounded,
      color: forecast.hasMaterialRisk ? WaqfaColors.warning : WaqfaColors.safe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fallText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'احتمال الضغط داخل المحاكاة: $probability% · زمن التعافي: ${recovery == null ? "أكثر من 90 يومًا" : "$recovery يومًا"}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            forecast.confidenceLabel,
            style: const TextStyle(color: Colors.white30, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _adjustment(GoalPlan plan) {
    final adjustment = plan.minimumAdjustment;
    final text = switch (adjustment.recommendedKind) {
      GoalAdjustmentKind.none => 'لا تحتاج تعديلًا؛ حافظ على التحويل الأسبوعي.',
      GoalAdjustmentKind.reduceVariableSpending =>
        'خفّض المصروف المتغير ${adjustment.requiredVariableExpenseReduction.round()} ريال شهريًا.',
      GoalAdjustmentKind.extendDuration =>
        'مدّد الخطة ${adjustment.minimumExtensionDays} يومًا فقط.',
      GoalAdjustmentKind.unavailable =>
        'خفّض مبلغ الهدف أو أضف دخلًا مؤكدًا ثم أعد الحساب.',
    };
    return _section(
      title: 'أقل تعديل يجعل الخطة ممكنة',
      icon: Icons.tune_rounded,
      color: WaqfaColors.amadClay,
      child: Text(
        text,
        style:
            const TextStyle(color: Colors.white70, fontSize: 12, height: 1.6),
      ),
    );
  }

  Widget _narrativeCard(GoalPlanNarrative narrative) => _section(
        title: narrative.usedCloud
            ? 'شرح ذكي مبني على أرقام المحرك'
            : 'شرح محلي مبني على أرقام المحرك',
        icon: Icons.psychology_alt_outlined,
        color: WaqfaColors.amadLavender,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              narrative.diagnosis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              narrative.minimumSavingIntervention,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.6,
              ),
            ),
          ],
        ),
      );

  Widget _weeklyPlan(GoalPlanNarrative narrative) => _section(
        title: 'خطتك الأسبوعية',
        icon: Icons.checklist_rounded,
        color: WaqfaColors.safe,
        child: Column(
          children: narrative.recommendedPlan.map((week) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: WaqfaColors.primary.withOpacity(.17),
                    child: Text(
                      '${week.week}',
                      style: const TextStyle(
                        color: WaqfaColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'هدف الأسبوع ${week.targetAmount.round()} ريال',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          week.actions.join(' '),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
    Color color = WaqfaColors.primary,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.045),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withOpacity(.085)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _metric(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.045),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withOpacity(.07)),
        ),
        child: Column(children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ]),
      );

  String _goalLabel(GoalType goal) => switch (goal) {
        GoalType.travel => 'سفر',
        GoalType.car => 'سيارة',
        GoalType.emergencyFund => 'احتياطي طوارئ',
        GoalType.debtReduction => 'تخفيف دين',
        GoalType.purchase => 'شراء جهاز',
        GoalType.marriage => 'زواج',
        GoalType.other => 'هدف آخر',
      };

  String _dateAfter(int day) {
    final date = DateTime.now().add(Duration(days: day + 1));
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
