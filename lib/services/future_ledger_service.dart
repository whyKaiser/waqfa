import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

enum FutureDecisionType { delayed, reduced, cancelled, planAccepted }

class FutureLedgerEntry {
  final String id;
  final DateTime date;
  final FutureDecisionType type;
  final String decisionLabel;
  final double originalInstallment;
  final double adjustedInstallment;
  final double avoidedCommitmentWithin90Days;
  final int riskBefore;
  final int riskAfter;
  final int fragileDaysAvoided;
  final int recoveryDaysImproved;

  const FutureLedgerEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.decisionLabel,
    required this.originalInstallment,
    required this.adjustedInstallment,
    required this.avoidedCommitmentWithin90Days,
    required this.riskBefore,
    required this.riskAfter,
    required this.fragileDaysAvoided,
    required this.recoveryDaysImproved,
  });

  int get riskReduction => math.max(0, riskBefore - riskAfter);

  Map<String, Object> toJson() => {
        'schema_version': 1,
        'id': id,
        'date': date.toIso8601String(),
        'type': type.name,
        'decision_label': decisionLabel,
        'original_installment': originalInstallment,
        'adjusted_installment': adjustedInstallment,
        'avoided_commitment_90_days': avoidedCommitmentWithin90Days,
        'risk_before': riskBefore,
        'risk_after': riskAfter,
        'fragile_days_avoided': fragileDaysAvoided,
        'recovery_days_improved': recoveryDaysImproved,
      };

  factory FutureLedgerEntry.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? '';
    return FutureLedgerEntry(
      id: json['id']?.toString() ?? '',
      date: DateTime.parse(json['date'].toString()),
      type: FutureDecisionType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => FutureDecisionType.planAccepted,
      ),
      decisionLabel: json['decision_label']?.toString() ?? 'قرار مالي',
      originalInstallment:
          (json['original_installment'] as num? ?? 0).toDouble(),
      adjustedInstallment:
          (json['adjusted_installment'] as num? ?? 0).toDouble(),
      avoidedCommitmentWithin90Days:
          (json['avoided_commitment_90_days'] as num? ?? 0).toDouble(),
      riskBefore: (json['risk_before'] as num? ?? 0).toInt(),
      riskAfter: (json['risk_after'] as num? ?? 0).toInt(),
      fragileDaysAvoided: (json['fragile_days_avoided'] as num? ?? 0).toInt(),
      recoveryDaysImproved:
          (json['recovery_days_improved'] as num? ?? 0).toInt(),
    );
  }
}

class FutureLedgerSummary {
  final int decisions;
  final double avoidedCommitmentsWithin90Days;
  final int riskPointsReduced;
  final int fragileDaysAvoided;
  final int recoveryDaysImproved;

  const FutureLedgerSummary({
    required this.decisions,
    required this.avoidedCommitmentsWithin90Days,
    required this.riskPointsReduced,
    required this.fragileDaysAvoided,
    required this.recoveryDaysImproved,
  });
}

/// Local prototype ledger. Values are never described as real savings unless
/// the user actually transfers money; they are counterfactual 90-day effects.
class FutureLedgerService {
  static const _key = 'alternative_future_ledger_v1';
  static const _maxEntries = 50;

  static Future<void> record(FutureLedgerEntry entry) async {
    _validate(entry);
    final prefs = await SharedPreferences.getInstance();
    final entries = await load();
    entries.insert(0, entry);
    await prefs.setString(
      _key,
      jsonEncode(
        entries.take(_maxEntries).map((item) => item.toJson()).toList(),
      ),
    );
  }

  static Future<List<FutureLedgerEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <FutureLedgerEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <FutureLedgerEntry>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => FutureLedgerEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <FutureLedgerEntry>[];
    }
  }

  static Future<FutureLedgerSummary> summary() async {
    final entries = await load();
    return FutureLedgerSummary(
      decisions: entries.length,
      avoidedCommitmentsWithin90Days: entries.fold<double>(
        0,
        (sum, item) => sum + item.avoidedCommitmentWithin90Days,
      ),
      riskPointsReduced: entries.fold<int>(
        0,
        (sum, item) => sum + item.riskReduction,
      ),
      fragileDaysAvoided: entries.fold<int>(
        0,
        (sum, item) => sum + item.fragileDaysAvoided,
      ),
      recoveryDaysImproved: entries.fold<int>(
        0,
        (sum, item) => sum + item.recoveryDaysImproved,
      ),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static void _validate(FutureLedgerEntry entry) {
    final monetaryValues = [
      entry.originalInstallment,
      entry.adjustedInstallment,
      entry.avoidedCommitmentWithin90Days,
    ];
    if (entry.id.trim().isEmpty ||
        monetaryValues.any((value) => !value.isFinite || value < 0) ||
        entry.riskBefore < 0 ||
        entry.riskAfter < 0 ||
        entry.fragileDaysAvoided < 0 ||
        entry.recoveryDaysImproved < 0) {
      throw ArgumentError('Future ledger entry is invalid.');
    }
  }
}
