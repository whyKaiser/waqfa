import 'dart:convert';

import 'package:waqfa/services/risk_benchmark.dart';
import 'package:waqfa/services/temporal_risk_engine.dart';

void main(List<String> arguments) {
  final threshold = arguments.isEmpty
      ? TemporalRiskEngine.defaultAlertThreshold
      : int.parse(arguments.first);
  final metrics = RiskBenchmark.run(alertThreshold: threshold);
  const encoder = JsonEncoder.withIndent('  ');
  // ignore: avoid_print
  print(encoder.convert(metrics.toJson()));
}
