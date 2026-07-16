import '../lib/services/risk_benchmark.dart';

void main() {
  print('threshold\trecall\tfalse_alert\talerts\tlead_days\trisk_drop');
  for (var threshold = 30; threshold <= 80; threshold += 5) {
    final metrics = RiskBenchmark.run(alertThreshold: threshold);
    print('$threshold\t'
        '${(metrics.criticalRecall * 100).toStringAsFixed(1)}\t'
        '${(metrics.falseAlertRate * 100).toStringAsFixed(1)}\t'
        '${metrics.alerts}\t'
        '${metrics.medianLeadTimeDays.toStringAsFixed(1)}\t'
        '${metrics.meanRiskReductionPoints.toStringAsFixed(1)}');
  }
}
