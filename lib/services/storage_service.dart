import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AnalysisRecord {
  final DateTime date;
  final double salary;
  final double fixed;
  final double variable;
  final double bnpl;
  final int totalRatio;
  final int bnplRatio;
  final String riskLevel;
  final String aiAnalysis;

  AnalysisRecord({
    required this.date,
    required this.salary,
    required this.fixed,
    required this.variable,
    required this.bnpl,
    required this.totalRatio,
    required this.bnplRatio,
    required this.riskLevel,
    this.aiAnalysis = '',
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'salary': salary,
    'fixed': fixed,
    'variable': variable,
    'bnpl': bnpl,
    'totalRatio': totalRatio,
    'bnplRatio': bnplRatio,
    'riskLevel': riskLevel,
    'aiAnalysis': aiAnalysis,
  };

  factory AnalysisRecord.fromJson(Map<String, dynamic> j) => AnalysisRecord(
    date: DateTime.parse(j['date']),
    salary: j['salary'],
    fixed: j['fixed'],
    variable: j['variable'],
    bnpl: j['bnpl'],
    totalRatio: j['totalRatio'],
    bnplRatio: j['bnplRatio'],
    riskLevel: j['riskLevel'],
    aiAnalysis: j['aiAnalysis'] ?? '',
  );
}

class StorageService {
  static const _key = 'analyses';

  static Future<void> saveAnalysis(AnalysisRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAnalyses();
    list.insert(0, record);
    final trimmed = list.take(20).toList();
    await prefs.setString(_key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  static Future<List<AnalysisRecord>> getAnalyses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => AnalysisRecord.fromJson(e)).toList();
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
