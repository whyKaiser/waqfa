import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// ملف المستخدم التخصيصي — أساس "التخصيص جوهر التجربة".
/// كل تحليل وتوصية تتكيّف مع هذي البيانات.
class UserProfile {
  final String ageRange;
  final String incomeType;
  final List<String> goals;
  final String riskAppetite;

  const UserProfile({
    this.ageRange = '',
    this.incomeType = '',
    this.goals = const [],
    this.riskAppetite = '',
  });

  bool get isComplete =>
      ageRange.isNotEmpty && incomeType.isNotEmpty && goals.isNotEmpty;

  UserProfile copyWith({
    String? ageRange,
    String? incomeType,
    List<String>? goals,
    String? riskAppetite,
  }) =>
      UserProfile(
        ageRange: ageRange ?? this.ageRange,
        incomeType: incomeType ?? this.incomeType,
        goals: goals ?? this.goals,
        riskAppetite: riskAppetite ?? this.riskAppetite,
      );

  Map<String, dynamic> toJson() => {
        'ageRange': ageRange,
        'incomeType': incomeType,
        'goals': goals,
        'riskAppetite': riskAppetite,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        ageRange: j['ageRange'] ?? '',
        incomeType: j['incomeType'] ?? '',
        goals: (j['goals'] as List?)?.map((e) => e.toString()).toList() ?? [],
        riskAppetite: j['riskAppetite'] ?? '',
      );

  /// نص يُحقن في برومبت الذكاء الاصطناعي ليخصّص التحليل.
  String toPromptContext() {
    if (!isComplete && ageRange.isEmpty && goals.isEmpty) return '';
    final parts = <String>[];
    if (ageRange.isNotEmpty) parts.add('الفئة العمرية: $ageRange');
    if (incomeType.isNotEmpty) parts.add('نوع الدخل: $incomeType');
    if (goals.isNotEmpty) parts.add('الأهداف المالية: ${goals.join("، ")}');
    if (riskAppetite.isNotEmpty) parts.add('ميوله للمخاطرة: $riskAppetite');
    return parts.isEmpty ? '' : '\nملف المستخدم (خصّص نصيحتك بناءً عليه):\n- ${parts.join("\n- ")}';
  }
}

class ProfileService {
  static const _key = 'user_profile';
  static UserProfile _cache = const UserProfile();

  static Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      _cache = const UserProfile();
      return _cache;
    }
    try {
      _cache = UserProfile.fromJson(jsonDecode(raw));
    } catch (_) {
      _cache = const UserProfile();
    }
    return _cache;
  }

  static Future<void> save(UserProfile profile) async {
    _cache = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  /// نسخة متزامنة من آخر ملف محمّل (يُستخدم داخل البرومبت).
  static UserProfile get cached => _cache;
}
