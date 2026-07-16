import 'package:flutter/material.dart';

import '../services/future_ledger_service.dart';
import '../theme/waqfa_theme.dart';

class ImpactLedgerScreen extends StatefulWidget {
  const ImpactLedgerScreen({super.key});

  @override
  State<ImpactLedgerScreen> createState() => _ImpactLedgerScreenState();
}

class _ImpactLedgerScreenState extends State<ImpactLedgerScreen> {
  List<FutureLedgerEntry> _entries = const [];
  FutureLedgerSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      FutureLedgerService.load(),
      FutureLedgerService.summary(),
    ]);
    if (!mounted) return;
    setState(() {
      _entries = results.first as List<FutureLedgerEntry>;
      _summary = results.last as FutureLedgerSummary;
      _loading = false;
    });
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: WaqfaColors.surface,
          title: const Text('مسح سجل الأثر؟'),
          content: const Text(
            'سيُحذف تاريخ القرارات من هذا الجهاز. لا يمكن التراجع.',
            style: TextStyle(color: WaqfaColors.textSecondary, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              key: const Key('confirm-clear-impact-ledger'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'مسح السجل',
                style: TextStyle(color: WaqfaColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await FutureLedgerService.clear();
    if (!mounted) return;
    setState(() => _loading = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الأثر البديل'),
        actions: [
          if (!_loading && _entries.isNotEmpty)
            IconButton(
              key: const Key('clear-impact-ledger'),
              tooltip: 'مسح السجل',
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
                ? const _EmptyLedger()
                : _LedgerContent(entries: _entries, summary: _summary!),
      ),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: WaqfaColors.amadLavender.withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.alt_route_rounded,
                size: 42,
                color: WaqfaColors.amadLavender,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'ما فيه قرارات مسجلة بعد',
              key: Key('empty-impact-ledger'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'عندما تخفّض قسطًا أو تؤجل قرارًا، تسجل وقفة أثر المسار البديل هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: WaqfaColors.textSecondary,
                fontSize: 13,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 18),
            const _CounterfactualNotice(),
          ],
        ),
      ),
    );
  }
}

class _LedgerContent extends StatelessWidget {
  final List<FutureLedgerEntry> entries;
  final FutureLedgerSummary summary;

  const _LedgerContent({required this.entries, required this.summary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _SummaryCard(summary: summary),
        const SizedBox(height: 12),
        const _CounterfactualNotice(),
        const SizedBox(height: 22),
        const Text(
          'القرارات',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LedgerEntryCard(entry: entry),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final FutureLedgerSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('impact-ledger-summary'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WaqfaColors.primary.withOpacity(.25),
            WaqfaColors.amadLavender.withOpacity(.10),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WaqfaColors.primary.withOpacity(.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline_rounded, color: WaqfaColors.cyan),
              SizedBox(width: 9),
              Text(
                'أثر قرارات وقفة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            '${_money(summary.avoidedCommitmentsWithin90Days)} ر.س',
            style: const TextStyle(
              color: WaqfaColors.cyan,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            'إجمالي ضغط التزامات متجنب خلال 90 يومًا',
            style: TextStyle(color: WaqfaColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'القرارات',
                  value: '${summary.decisions}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: 'نقاط خطر أقل',
                  value: '${summary.riskPointsReduced}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: 'أيام هشاشة أقل',
                  value: '${summary.fragileDaysAvoided}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.055),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: WaqfaColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterfactualNotice extends StatelessWidget {
  const _CounterfactualNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('counterfactual-notice'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: WaqfaColors.amadClay.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WaqfaColors.amadClay.withOpacity(.28)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: WaqfaColors.amadClay),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'هذه أرقام تقديرية مضادة للواقع: تقارن ما كان قد يحدث بمسار القرار الجديد. ليست مالًا مدخرًا فعليًا ولا ضمانًا لنتيجة مستقبلية.',
              style: TextStyle(
                color: WaqfaColors.textSecondary,
                fontSize: 11,
                height: 1.65,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerEntryCard extends StatelessWidget {
  final FutureLedgerEntry entry;

  const _LedgerEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final reduced = entry.riskReduction > 0;
    final impactColor = reduced ? WaqfaColors.safe : WaqfaColors.warning;
    return Container(
      key: Key('impact-entry-${entry.id}'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.045),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: impactColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _iconFor(entry.type),
                  color: impactColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.decisionLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_typeLabel(entry.type)} · ${_date(entry.date)}',
                      style: const TextStyle(
                        color: WaqfaColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: impactColor.withOpacity(.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  reduced ? '-${entry.riskReduction} خطر' : 'أثر وقائي',
                  style: TextStyle(
                    color: impactColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _EntryValue(
                  label: 'القسط قبل',
                  value: '${_money(entry.originalInstallment)} ر.س',
                ),
              ),
              const Icon(
                Icons.arrow_back_rounded,
                color: WaqfaColors.textSecondary,
                size: 17,
              ),
              Expanded(
                child: _EntryValue(
                  label: 'القسط بعد',
                  value: '${_money(entry.adjustedInstallment)} ر.س',
                  color: impactColor,
                ),
              ),
              Expanded(
                child: _EntryValue(
                  label: 'ضغط 90 يومًا',
                  value:
                      '${_money(entry.avoidedCommitmentWithin90Days)} ر.س أقل',
                  color: WaqfaColors.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _EntryValue({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: WaqfaColors.textSecondary,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color ?? WaqfaColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

IconData _iconFor(FutureDecisionType type) => switch (type) {
      FutureDecisionType.delayed => Icons.schedule_rounded,
      FutureDecisionType.reduced => Icons.tune_rounded,
      FutureDecisionType.cancelled => Icons.block_rounded,
      FutureDecisionType.planAccepted => Icons.task_alt_rounded,
    };

String _typeLabel(FutureDecisionType type) => switch (type) {
      FutureDecisionType.delayed => 'قرار مؤجل',
      FutureDecisionType.reduced => 'التزام مخفّض',
      FutureDecisionType.cancelled => 'قرار ملغى',
      FutureDecisionType.planAccepted => 'خطة وقفة',
    };

String _money(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _date(DateTime value) {
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
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
