import 'dart:convert';

import 'package:waqfa/services/financial_decision_engine.dart';
import 'package:waqfa/services/risk_benchmark.dart';

void main(List<String> arguments) {
  final threshold = arguments.isEmpty
      ? FinancialDecisionEngine.warningThreshold
      : int.parse(arguments.first);
  final metrics = RiskBenchmark.run(alertThreshold: threshold);
  const encoder = JsonEncoder.withIndent('  ');
  // ignore: avoid_print
  print(encoder.convert(metrics.toJson()));
}
