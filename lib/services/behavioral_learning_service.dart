import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

enum InterventionStrategy { totalCost, dailyBudget, coolingOff }

class InterventionStats {
  final InterventionStrategy strategy;
  final int trials;
  final int saferChoices;

  const InterventionStats({
    required this.strategy,
    required this.trials,
    required this.saferChoices,
  });

  double get observedRate => trials == 0 ? 0 : saferChoices / trials;
}

/// متعلم بسيط على الجهاز من نوع UCB1 (multi-armed bandit).
/// يوازن بين تجربة تدخلات جديدة واستخدام التدخل الذي ارتبط سابقًا بخيار
/// أكثر أمانًا. لا يخزن مبالغ أو هوية، ولا يدعي أثرًا قبل توفر مشاهدات فعلية.
class BehavioralLearningService {
  static const _prefix = 'intervention_learning_';

  static Future<InterventionStrategy> recommend() async {
    final stats = await loadStats();
    final untried = stats.where((item) => item.trials == 0).toList();
    if (untried.isNotEmpty) return untried.first.strategy;

    final totalTrials = stats.fold<int>(0, (sum, item) => sum + item.trials);
    InterventionStats best = stats.first;
    var bestScore = double.negativeInfinity;
    for (final item in stats) {
      final exploitation = item.saferChoices / item.trials;
      final exploration = math.sqrt(2 * math.log(totalTrials) / item.trials);
      final score = exploitation + exploration;
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return best.strategy;
  }

  static Future<void> record(
      InterventionStrategy strategy, bool saferChoice) async {
    final prefs = await SharedPreferences.getInstance();
    final trialsKey = '$_prefix${strategy.name}_trials';
    final successKey = '$_prefix${strategy.name}_safer';
    await prefs.setInt(trialsKey, (prefs.getInt(trialsKey) ?? 0) + 1);
    if (saferChoice) {
      await prefs.setInt(successKey, (prefs.getInt(successKey) ?? 0) + 1);
    }
  }

  static Future<List<InterventionStats>> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    return InterventionStrategy.values
        .map((strategy) => InterventionStats(
              strategy: strategy,
              trials: prefs.getInt('$_prefix${strategy.name}_trials') ?? 0,
              saferChoices: prefs.getInt('$_prefix${strategy.name}_safer') ?? 0,
            ))
        .toList();
  }

  static String message(
    InterventionStrategy strategy, {
    required double installment,
    required double dailyAllowance,
    required double totalBnpl,
  }) {
    switch (strategy) {
      case InterventionStrategy.totalCost:
        return 'الأقساط الصغيرة تتراكم: مجموع التزاماتك سيصبح ${totalBnpl.round()} ريال شهريًا. قارن الإجمالي باحتياجك الحقيقي.';
      case InterventionStrategy.dailyBudget:
        return 'بعد هذا القسط سيتبقى لك ${math.max(dailyAllowance, 0).round()} ريال يوميًا حتى الراتب. هل يكفي للطعام والتنقل والطوارئ؟';
      case InterventionStrategy.coolingOff:
        return 'فعّل مهلة 24 ساعة قبل تأكيد قسط ${installment.round()} ريال؛ التأجيل القصير يقلل أثر الاندفاع دون أن يغلق خيار الشراء.';
    }
  }

  static String label(InterventionStrategy strategy) => switch (strategy) {
        InterventionStrategy.totalCost => 'إظهار التكلفة المجمعة',
        InterventionStrategy.dailyBudget => 'تحويله إلى ميزانية يومية',
        InterventionStrategy.coolingOff => 'مهلة تهدئة 24 ساعة',
      };
}
