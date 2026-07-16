import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/behavioral_learning_service.dart';
import '../services/decision_outcome_service.dart';
import '../services/financial_decision_engine.dart';
import '../services/financial_prevention_engine.dart';
import '../services/future_ledger_service.dart';
import '../theme/waqfa_theme.dart';

/// وقفة قبل تدفع: جدار حماية يحاكي أثر قرار الشراء قبل الالتزام به.
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
  late final FinancialProfile _profile;
  late double _installment;
  DecisionOutcome? _recordedOutcome;
  bool _recordingOutcome = false;
  bool _preventionBusy = false;
  bool _ledgerSaved = false;
  double _appliedVariableCut = 0;
  MinimumSavingIntervention? _adoptedIntervention;
  FinancialPreventionAnalysis? _prevention;
  InterventionStrategy _intervention = InterventionStrategy.coolingOff;

  static const _danger = Color(0xFFFF6B6B);
  static const _warning = Color(0xFFFFB347);
  static const _safe = Color(0xFF6BCB77);
  static const _accent = WaqfaColors.primary;

  @override
  void initState() {
    super.initState();
    _profile = FinancialProfile(
      salary: widget.salary,
      fixedExpenses: widget.fixed,
      variableExpenses: widget.variable,
      currentBnpl: widget.bnpl,
    );
    _installment = (widget.salary * .08).clamp(100, 1200).toDouble();
    BehavioralLearningService.recommend().then((value) {
      if (mounted) setState(() => _intervention = value);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPrevention());
  }

  FinancialProfile get _effectiveProfile => FinancialProfile(
        salary: _profile.salary,
        fixedExpenses: _profile.fixedExpenses,
        variableExpenses: (_profile.variableExpenses - _appliedVariableCut)
            .clamp(0, double.infinity),
        currentBnpl: _profile.currentBnpl,
      );

  DecisionAnalysis get _analysis => FinancialDecisionEngine.analyze(
        _effectiveProfile,
        proposedInstallment: _installment,
      );

  Color _riskColor(int score) =>
      score >= FinancialDecisionEngine.dangerThreshold
          ? _danger
          : score >= FinancialDecisionEngine.warningThreshold
              ? _warning
              : _safe;

  Future<void> _refreshPrevention({bool keepLedgerState = false}) async {
    final installment = _installment;
    final profile = _effectiveProfile;
    if (mounted) setState(() => _preventionBusy = true);
    final result = await Future(
      () => FinancialPreventionEngine.analyze(
        profile,
        proposedInstallment: installment,
      ),
    );
    if (!mounted || (_installment - installment).abs() > .01) return;
    setState(() {
      _prevention = result;
      _preventionBusy = false;
      if (!keepLedgerState) _ledgerSaved = false;
    });
  }

  Future<void> _recordFuture(
    FutureDecisionType type,
    String label, {
    bool applyPlan = false,
  }) async {
    final prevention = _prevention;
    if (prevention == null) return;
    final intervention = prevention.intervention;
    final adjusted = switch (type) {
      FutureDecisionType.cancelled => 0.0,
      FutureDecisionType.delayed => _installment,
      FutureDecisionType.reduced => intervention.adjustedInstallment,
      FutureDecisionType.planAccepted => intervention.adjustedInstallment,
    };
    final paymentCountAfter = intervention.delayDays >= 30
        ? (prevention.installmentPaymentsWithinHorizon - 1).clamp(0, 3)
        : prevention.installmentPaymentsWithinHorizon;
    final avoided =
        ((_installment * prevention.installmentPaymentsWithinHorizon) -
                (adjusted * paymentCountAfter))
            .clamp(0, double.infinity)
            .toDouble();
    final afterRecovery = prevention.recovery.afterDecisionDays ?? 90;
    final interventionRecovery =
        prevention.recovery.afterInterventionDays ?? 90;

    await FutureLedgerService.record(
      FutureLedgerEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.now(),
        type: type,
        decisionLabel: label,
        originalInstallment: _installment,
        adjustedInstallment: adjusted,
        avoidedCommitmentWithin90Days: avoided,
        riskBefore: intervention.riskBefore,
        riskAfter: type == FutureDecisionType.cancelled
            ? _analysis.currentRisk
            : intervention.riskAfter,
        fragileDaysAvoided: prevention.recovery.avoidedFragileDays,
        recoveryDaysImproved:
            (afterRecovery - interventionRecovery).clamp(0, 90),
      ),
    );

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    if (applyPlan) {
      setState(() {
        _installment = intervention.adjustedInstallment;
        _appliedVariableCut = intervention.monthlyVariableCut;
        _adoptedIntervention = intervention;
        _ledgerSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم اعتماد أقل تدخل وحفظ أثر القرار محليًا'),
        ),
      );
      await _refreshPrevention(keepLedgerState: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;
    final color = _riskColor(analysis.proposedRisk);
    final maxInstallment = (widget.salary * .35).clamp(500, 4000).toDouble();
    final passedShocks = analysis.shocks.where((s) => s.survives).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text('وقفة قبل تدفع'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _hero(analysis, color),
            const SizedBox(height: 14),
            _installmentSlider(maxInstallment),
            const SizedBox(height: 14),
            _beforeAfter(analysis),
            const SizedBox(height: 14),
            _preventionCard(),
            const SizedBox(height: 14),
            _cashFlow(analysis),
            const SizedBox(height: 14),
            _section(
              icon: Icons.manage_search_rounded,
              title: 'لماذا تغيّرت النتيجة؟',
              child: Column(
                children: analysis.factors.map((f) => _factorRow(f)).toList(),
              ),
            ),
            const SizedBox(height: 14),
            _section(
              icon: Icons.psychology_alt_outlined,
              title:
                  'تدخل متعلم: ${BehavioralLearningService.label(_intervention)}',
              color: _accent,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      BehavioralLearningService.message(
                        _intervention,
                        installment: _installment,
                        dailyAllowance: analysis.dailyAllowance,
                        totalBnpl: widget.bnpl + _installment,
                      ),
                      style: const TextStyle(
                          color: Colors.white70, height: 1.7, fontSize: 13),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'يوازن محليًا بين التجربة والنتائج السابقة، دون حفظ هويتك أو مبالغك.',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ]),
            ),
            const SizedBox(height: 14),
            _section(
              icon: Icons.shield_outlined,
              title: 'اختبار تحمّل الطوارئ: $passedShocks من 3',
              color: passedShocks >= 2 ? _safe : _danger,
              child: Column(
                children: analysis.shocks.map(_shockRow).toList(),
              ),
            ),
            const SizedBox(height: 14),
            if (analysis.alternatives.isNotEmpty)
              _section(
                icon: Icons.auto_awesome_rounded,
                title: 'بدائل وقفة الآمنة',
                color: _safe,
                child: Column(
                  children: analysis.alternatives
                      .map((a) => _alternativeRow(a))
                      .toList(),
                ),
              ),
            const SizedBox(height: 14),
            _decisionFeedback(),
          ]),
        ),
      ),
    );
  }

  Widget _hero(DecisionAnalysis a, Color color) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color.withOpacity(.22), color.withOpacity(.06)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(.45)),
        ),
        child: Column(children: [
          const Text('مؤشر القرار',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text('${a.proposedRisk}/100',
              style: TextStyle(
                  color: color, fontSize: 42, fontWeight: FontWeight.w800)),
          Text(a.level,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(a.verdict,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, height: 1.6, fontSize: 13)),
        ]),
      );

  Widget _decisionFeedback() => _section(
        icon: Icons.how_to_reg_outlined,
        title: 'بعد تنبيه وقفة، وش قررت؟',
        color: const Color(0xFF48CAE4),
        child: _recordedOutcome != null
            ? const Row(children: [
                Icon(Icons.check_circle, color: _safe, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم تسجيل القرار محليًا بدون حفظ المبلغ أو هويتك.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              ])
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _outcomeChip('أجّلت', DecisionOutcome.delayed, _warning),
                  _outcomeChip('خفّضت القسط', DecisionOutcome.reduced, _safe),
                  _outcomeChip('ألغيت', DecisionOutcome.cancelled, _safe),
                  _outcomeChip(
                      'كملت الشراء', DecisionOutcome.continued, _danger),
                ],
              ),
      );

  Widget _outcomeChip(String label, DecisionOutcome outcome, Color color) {
    return ActionChip(
      label: Text(label),
      labelStyle: TextStyle(color: color, fontSize: 12),
      backgroundColor: color.withOpacity(.10),
      side: BorderSide(color: color.withOpacity(.28)),
      onPressed: _recordingOutcome
          ? null
          : () async {
              setState(() => _recordingOutcome = true);
              try {
                await DecisionOutcomeService.record(outcome);
                await BehavioralLearningService.record(
                  _intervention,
                  outcome != DecisionOutcome.continued,
                );
                if (outcome != DecisionOutcome.continued) {
                  final ledgerType = switch (outcome) {
                    DecisionOutcome.delayed => FutureDecisionType.delayed,
                    DecisionOutcome.reduced => FutureDecisionType.reduced,
                    DecisionOutcome.cancelled => FutureDecisionType.cancelled,
                    DecisionOutcome.continued =>
                      FutureDecisionType.planAccepted,
                  };
                  await _recordFuture(ledgerType, 'قرار شراء محاكى');
                }
                if (!mounted) return;
                HapticFeedback.mediumImpact();
                setState(() => _recordedOutcome = outcome);
              } finally {
                if (mounted && _recordedOutcome == null) {
                  setState(() => _recordingOutcome = false);
                }
              }
            },
    );
  }

  Widget _installmentSlider(double max) => _section(
        icon: Icons.shopping_cart_checkout_rounded,
        title: 'القسط الذي تفكر فيه',
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('جرّب القرار قبل الالتزام',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            Text('${_installment.round()} ريال/شهر',
                style: const TextStyle(
                    color: _accent, fontWeight: FontWeight.w700)),
          ]),
          Slider(
            value: _installment.clamp(0, max),
            min: 0,
            max: max,
            divisions: 40,
            activeColor: _accent,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() {
                _installment = value;
                _appliedVariableCut = 0;
                _adoptedIntervention = null;
                _ledgerSaved = false;
              });
            },
            onChangeEnd: (_) => _refreshPrevention(),
          ),
        ]),
      );

  Widget _preventionCard() {
    final prevention = _prevention;
    if (_preventionBusy || prevention == null) {
      return _section(
        icon: Icons.auto_graph_rounded,
        title: 'محرك الوقاية الاستباقي',
        color: WaqfaColors.amadLavender,
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'نبني 72 مسارًا ماليًا قابلًا للتكرار…',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final forecast = prevention.proposedForecast;
    final intervention = prevention.intervention;
    final adopted = _adoptedIntervention;
    final probability = (forecast.criticalProbability * 100).round();
    final recovery = prevention.recovery.afterDecisionDays;
    final recoveryAfter = prevention.recovery.afterInterventionDays;
    final fallText = forecast.fallDay == null
        ? 'لا تظهر نافذة سقوط مالي خلال 90 يومًا'
        : 'اليوم ${forecast.fallDay! + 1} · ${_dateAfter(forecast.fallDay!)}';

    return _section(
      icon: Icons.health_and_safety_outlined,
      title: 'إنذار وقفة الاستباقي',
      color: WaqfaColors.amadCoral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _metric(
                  'تاريخ السقوط',
                  fallText,
                  forecast.fallDay == null ? _safe : _danger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'احتمال الضغط',
                  '$probability%',
                  probability >= 60 ? _danger : _warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'تكلفة 90 يومًا',
                  '${prevention.decisionCostWithinHorizon.round()} ر.س',
                  WaqfaColors.amadClay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _ledgerSaved && adopted != null
                ? 'تم اعتماد أقل تدخل'
                : intervention.title,
            style: const TextStyle(
              color: WaqfaColors.amadSand,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _ledgerSaved && adopted != null
                ? 'القسط ${adopted.adjustedInstallment.round()} ريال شهريًا مع حماية '
                    '${adopted.monthlyVariableCut.round()} ريال من الصرف المتغير. '
                    'الأرقام أعلاه تمثل وضعك بعد تطبيق الخطة.'
                : intervention.explanation,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.65,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'زمن التعافي: ${_recoveryText(recovery)} ← بعد التدخل ${_recoveryText(recoveryAfter)} · '
            'تجنّب ${prevention.recovery.avoidedFragileDays} يوم هش',
            style: const TextStyle(color: WaqfaColors.cyan, fontSize: 11),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: forecast.bands
                .map(
                  (band) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.045),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${band.label}: ${band.firstCriticalDay == null ? "مستقر" : "اليوم ${band.firstCriticalDay! + 1}"}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _ledgerSaved || intervention.numberOfChanges == 0
                  ? null
                  : () => _recordFuture(
                        FutureDecisionType.planAccepted,
                        'أقل تدخل منقذ',
                        applyPlan: true,
                      ),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(_ledgerSaved ? 'تم اعتماد الخطة' : 'اعتمد أقل تدخل'),
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'افتراضات المحاكاة وحدودها',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
            children: [
              Text(
                forecast.disclosure,
                style: const TextStyle(
                  color: Colors.white38,
                  height: 1.55,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _recoveryText(int? days) =>
      days == null ? 'لم يتعافَ خلال الأفق' : '$days يوم';

  String _dateAfter(int day) {
    final date = DateTime.now().add(Duration(days: day + 1));
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _beforeAfter(DecisionAnalysis a) => Row(children: [
        Expanded(
            child: _metric('قبل القرار', '${a.currentRisk}/100',
                _riskColor(a.currentRisk))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_back_rounded, color: Colors.white30),
        ),
        Expanded(
            child: _metric('بعد القرار', '${a.proposedRisk}/100',
                _riskColor(a.proposedRisk))),
        const SizedBox(width: 8),
        Expanded(
            child: _metric(
                'التغيّر',
                '${a.riskIncrease >= 0 ? "+" : ""}${a.riskIncrease}',
                a.riskIncrease > 10 ? _danger : _safe)),
      ]);

  Widget _cashFlow(DecisionAnalysis a) => _section(
        icon: Icons.timeline_rounded,
        title: 'توأمك المالي - توقع 90 يومًا',
        color: const Color(0xFF48CAE4),
        child: Column(children: [
          Row(
            children: List.generate(
                3,
                (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(end: i < 2 ? 8 : 0),
                        child: _metric(
                            'شهر ${i + 1}',
                            '${a.ninetyDayBalances[i].round()}',
                            a.ninetyDayBalances[i] >= 0 ? _safe : _danger),
                      ),
                    )),
          ),
          const SizedBox(height: 10),
          Text('المتبقي اليومي المتوقع: ${a.dailyAllowance.round()} ريال',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 5),
          Text(
            a.firstCriticalDay == null
                ? 'لم ترصد المحاكاة عجزًا خلال 90 يومًا'
                : 'أول ضغط حرج متوقع: اليوم ${a.firstCriticalDay! + 1}',
            style: TextStyle(
              color: a.firstCriticalDay == null ? _safe : _danger,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${a.daysBelowSafetyReserve} يومًا تحت احتياطي الأمان',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ]),
      );

  Widget _factorRow(RiskFactor f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: (f.impact > 0 ? _danger : _safe).withOpacity(.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${f.impact > 0 ? "+" : ""}${f.impact}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: f.impact > 0 ? _danger : _safe, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(f.title,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(f.explanation,
                    style: const TextStyle(
                        color: Colors.white38, height: 1.5, fontSize: 11)),
              ])),
        ]),
      );

  Widget _shockRow(ShockResult s) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Icon(s.survives ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: s.survives ? _safe : _danger, size: 19),
          const SizedBox(width: 8),
          Expanded(
              child: Text('${s.name} (${s.amount.round()} ريال)',
                  style: const TextStyle(color: Colors.white60, fontSize: 12))),
          Text(
              s.survives
                  ? 'يتحمّل'
                  : 'عجز ${s.balanceAfterShock.abs().round()}',
              style:
                  TextStyle(color: s.survives ? _safe : _danger, fontSize: 11)),
        ]),
      );

  Widget _alternativeRow(SafeAlternative a) => InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _installment = a.installment);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _riskColor(a.riskScore).withOpacity(.14),
              child: Text('${a.riskScore}',
                  style:
                      TextStyle(color: _riskColor(a.riskScore), fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(a.title,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text(a.explanation,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                ])),
            const Icon(Icons.chevron_left_rounded, color: Colors.white24),
          ]),
        ),
      );

  Widget _section(
          {required IconData icon,
          required String title,
          required Widget child,
          Color color = _accent}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.045),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13))),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _metric(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(.04),
            borderRadius: BorderRadius.circular(11)),
        child: Column(children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      );
}
