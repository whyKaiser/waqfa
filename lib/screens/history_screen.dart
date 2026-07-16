import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import 'analysis_detail_screen.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AnalysisRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await StorageService.getAnalyses();
    if (mounted) setState(() { _records = records; _loading = false; });
  }

  Color _riskColor(String level) => switch (level) {
    'danger' => AppColors.danger,
    'warning' => AppColors.copper,
    _ => AppColors.success,
  };

  String _riskLabel(String level) => switch (level) {
    'danger' => 'خطر',
    'warning' => 'تحذير',
    _ => 'جيد',
  };

  String _formatDate(DateTime date) {
    final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
      'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('سجل التحليلات'),
        centerTitle: true,
        actions: _records.isEmpty ? null : [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white38),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('حذف كل السجل؟', style: TextStyle(color: Colors.white, fontSize: 17)),
                    content: const Text('راح تفقد كل تحليلاتك السابقة ورسم الاتجاه. ما تقدر تتراجع.',
                        style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.6)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                ),
              );
              if (confirm != true) return;
              await StorageService.clearAll();
              _load();
            },
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _records.isEmpty
            ? Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            const Text('ما في تحليلات بعد',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('ابدأ تحليلك الأول من الصفحة الرئيسية',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ))
            : Column(
          children: [
            if (_records.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: _TrendChart(records: _records.reversed.toList()),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: _records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final r = _records[i];
                  final color = _riskColor(r.riskLevel);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, PageRouteBuilder(
                        pageBuilder: (_, animation, __) => AnalysisDetailScreen(record: r),
                        transitionsBuilder: (_, animation, __, child) => SlideTransition(
                          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                        transitionDuration: const Duration(milliseconds: 300),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: Text('${r.totalRatio}%',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(_formatDate(r.date),
                                    style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(_riskLabel(r.riskLevel),
                                      style: TextStyle(fontSize: 11, color: color)),
                                ),
                              ]),
                              const SizedBox(height: 4),
                              Text('راتب ${r.salary.toInt()} | BNPL ${r.bnplRatio}%',
                                  style: const TextStyle(fontSize: 12, color: Colors.white38)),
                            ],
                          )),
                          const Icon(Icons.chevron_left, color: Colors.white24, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<AnalysisRecord> records;
  const _TrendChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final maxRatio = records.map((r) => r.totalRatio).reduce((a, b) => a > b ? a : b);
    return Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('الاتجاه', style: TextStyle(fontSize: 11, color: Colors.white30)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: records.take(8).map((r) {
                final h = (r.totalRatio / (maxRatio == 0 ? 1 : maxRatio));
                final color = r.riskLevel == 'danger'
                    ? AppColors.danger
                    : r.riskLevel == 'warning'
                    ? AppColors.copper
                    : AppColors.success;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FractionallySizedBox(
                      heightFactor: h.clamp(0.1, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
