import 'dart:convert';
import 'generative_ai_provider.dart';
import 'goal_plan_engine.dart';
import 'profile_service.dart';

/// نتيجة تحليل فاتورة مصوّرة.
class ReceiptResult {
  final String merchant;
  final double total;
  final String category;
  final bool isBnpl;
  final double monthlyInstallment;
  final String note;
  final bool ok;

  ReceiptResult({
    required this.merchant,
    required this.total,
    required this.category,
    required this.isBnpl,
    this.monthlyInstallment = 0,
    required this.note,
    this.ok = true,
  });

  factory ReceiptResult.error(String msg) => ReceiptResult(
        merchant: '',
        total: 0,
        category: '',
        isBnpl: false,
        monthlyInstallment: 0,
        note: msg,
        ok: false,
      );

  /// يستخرج JSON من رد النموذج بتسامح (يتجاهل أي نص حوله).
  factory ReceiptResult.parse(String content) {
    try {
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start == -1 || end <= start)
        return ReceiptResult.error('ما قدرت أقرأ الفاتورة. جرّب صورة أوضح.');
      final j =
          jsonDecode(content.substring(start, end + 1)) as Map<String, dynamic>;
      double parseNum(dynamic v) {
        if (v is num) return v.toDouble();
        if (v is String) {
          const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
          const easternDigits = '۰۱۲۳۴۵۶۷۸۹';
          var normalized =
              v.replaceAll('٫', '.').replaceAll('٬', '').replaceAll(',', '');
          for (var i = 0; i < 10; i++) {
            normalized = normalized
                .replaceAll(arabicDigits[i], '$i')
                .replaceAll(easternDigits[i], '$i');
          }
          final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(normalized);
          return match == null ? 0 : double.tryParse(match.group(0)!) ?? 0;
        }
        return 0;
      }

      final total = parseNum(j['total']);
      if (!total.isFinite || total <= 0) {
        return ReceiptResult.error(
          'ما قدرت أحدد إجمالي الفاتورة. صوّر المبلغ النهائي بوضوح وحاول مرة ثانية.',
        );
      }

      return ReceiptResult(
        merchant: (j['merchant'] ?? '').toString(),
        total: total,
        category: (j['category'] ?? '').toString(),
        isBnpl: j['is_bnpl'] == true || j['is_bnpl'].toString() == 'true',
        monthlyInstallment: parseNum(j['monthly_installment']),
        note: (j['note'] ?? '').toString(),
      );
    } catch (_) {
      return ReceiptResult.error(
          'ما قدرت أقرأ الفاتورة بوضوح. جرّب صورة أوضح وإضاءة أحسن.');
    }
  }
}

class FinancialAnalysisResult {
  final String text;
  final bool usedCloud;

  const FinancialAnalysisResult({
    required this.text,
    required this.usedCloud,
  });
}

class GoalPlanNarrativeWeek {
  final int week;
  final List<String> actions;
  final double targetAmount;
  final double safeDailySpend;
  final String reason;

  const GoalPlanNarrativeWeek({
    required this.week,
    required this.actions,
    required this.targetAmount,
    required this.safeDailySpend,
    required this.reason,
  });
}

class GoalPlanNarrative {
  final String goalType;
  final String diagnosis;
  final String mainProblem;
  final List<String> riskFactors;
  final List<String> questionsToAsk;
  final List<GoalPlanNarrativeWeek> recommendedPlan;
  final String minimumSavingIntervention;
  final String recoveryTimeExplanation;
  final List<String> warnings;
  final String nextStep;
  final List<String> calculatedValuesUsed;
  final bool usedCloud;

  const GoalPlanNarrative({
    required this.goalType,
    required this.diagnosis,
    required this.mainProblem,
    required this.riskFactors,
    required this.questionsToAsk,
    required this.recommendedPlan,
    required this.minimumSavingIntervention,
    required this.recoveryTimeExplanation,
    required this.warnings,
    required this.nextStep,
    required this.calculatedValuesUsed,
    required this.usedCloud,
  });
}

class AiService {
  static const String _model = 'qwen/qwen3.6-27b';
  static const String _apiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );
  static final GenerativeAiProvider _defaultProvider =
      GroqGenerativeAiProvider(apiKey: _apiKey, model: _model);
  static GenerativeAiProvider _provider = _defaultProvider;

  static bool get isConfigured => _provider.isConfigured;
  static String get providerName => _provider.name;

  /// Allows a bank pilot, backend proxy, or tests to replace Groq without
  /// changing financial product logic.
  static void configureProvider(GenerativeAiProvider provider) {
    _provider = provider;
  }

  static void useDefaultProvider() {
    _provider = _defaultProvider;
  }

  static Future<FinancialAnalysisResult> analyzeFinances({
    required double salary,
    required double fixed,
    required double variable,
    required double bnpl,
    String concern = '',
    bool allowCloud = false,
  }) async {
    final remaining = salary - fixed - variable - bnpl;
    final safeSalary = salary > 0 ? salary : 1;
    final bnplRatio = ((bnpl / safeSalary) * 100).round();
    final totalRatio = (((fixed + variable + bnpl) / safeSalary) * 100).round();

    FinancialAnalysisResult localResult() => FinancialAnalysisResult(
          text: _localFallback(
            salary: salary,
            bnpl: bnpl,
            remaining: remaining,
            bnplRatio: bnplRatio,
            totalRatio: totalRatio,
            concern: concern,
          ),
          usedCloud: false,
        );

    if (!allowCloud || !isConfigured) {
      return localResult();
    }

    final profileCtx = (await ProfileService.load()).toPromptContext();

    final prompt =
        '''أنت مساعد وقاية مالية يشرح نتيجة محسوبة مسبقًا، ولست مستشارًا ماليًا مرخصًا. لخّص الوضع التالي بلغة عربية سعودية بسيطة دون اختراع أي رقم.

البيانات:
- الراتب الشهري: $salary ريال
- المصاريف الثابتة: $fixed ريال
- المصاريف المتغيرة: $variable ريال
- أقساط BNPL (تمارا، تابي): $bnpl ريال
- المتبقي: $remaining ريال
- نسبة BNPL من الراتب: $bnplRatio%
- نسبة المصاريف الكلية: $totalRatio%
${concern.isNotEmpty ? '- قلق المستخدم: $concern' : ''}$profileCtx

اكتب شرحًا من 4-5 جمل فقط. استخدم الأرقام أعلاه كما هي، واشرح أهم عامل وخطوة عامة آمنة. لا تحسب مبلغ ادخار أو مدة هدف من نفسك، ولا تقترح استثمارًا أو تمويلًا، ولا تعط ضمانًا. بدون مقدمات أو تحيات.''';

    final response = await _provider.generateText(
      AiTextRequest(
        systemPrompt:
            'أنت مساعد وقاية مالية، ولست مستشارًا ماليًا مرخصًا. اشرح فقط القيم المحسوبة المقدمة لك، '
            'ولا تخترع أرقامًا أو ضمانات أو توصيات استثمارية. اكتب 4-5 جمل عربية واضحة.',
        userPrompt: prompt,
        temperature: .5,
        maxTokens: 350,
      ),
    );
    if (response.ok && response.content.trim().isNotEmpty) {
      return FinancialAnalysisResult(
        text: response.content.trim(),
        usedCloud: true,
      );
    }
    return localResult();
  }

  /// Turns a deterministic [GoalPlan] into a structured explanation. The
  /// provider may rewrite language only; every amount shown in the returned
  /// plan is copied from the engine output.
  static Future<GoalPlanNarrative> buildGoalPlanNarrative({
    required GoalPlan plan,
    bool allowCloud = false,
  }) async {
    final local = _localGoalNarrative(plan);
    if (!allowCloud || !isConfigured) return local;

    final calculated = {
      'goalType': plan.goalType.name,
      'targetAmount': plan.targetAmount,
      'requestedTargetDays': plan.requestedTargetDays,
      'effectiveTargetDays': plan.effectiveTargetDays,
      'plannedMonthlyContribution': plan.plannedMonthlyContribution,
      'safetyReserve': plan.safetyReserve,
      'safeDailySpend': plan.safeDailySpend,
      'feasibility': plan.feasibility.name,
      'minimumAdjustment': {
        'kind': plan.minimumAdjustment.recommendedKind.name,
        'variableReduction':
            plan.minimumAdjustment.requiredVariableExpenseReduction,
        'extensionDays': plan.minimumAdjustment.minimumExtensionDays,
      },
      'weeklyPlan': plan.weeklySteps
          .map(
            (step) => {
              'week': step.weekNumber,
              'targetAmount': step.contributionTarget,
              'safeDailySpend': plan.safeDailySpend,
              'action': step.action,
            },
          )
          .toList(),
    };
    final response = await _provider.generateText(
      AiTextRequest(
        requireJson: true,
        maxTokens: 900,
        temperature: .2,
        systemPrompt:
            'أنت مساعد وقاية مالية، ولست مستشارًا ماليًا مرخصًا. الأرقام محسوبة من محرك وقفة. '
            'ممنوع تغييرها أو حساب أرقام جديدة أو تقديم استثمار أو تمويل أو ضمان. أخرج JSON فقط.',
        userPrompt:
            '''حوّل البيانات المحسوبة التالية إلى شرح عربي واضح. انسخ الأرقام كما هي فقط:
${jsonEncode(calculated)}

أعد JSON بهذا الشكل:
{"diagnosis":"","mainProblem":"","riskFactors":[],"questionsToAsk":[],"recommendedPlan":[],"warnings":[],"nextStep":""}
لا تضف حقائق أو أرقامًا غير موجودة.''',
      ),
    );
    if (!response.ok) return local;
    return _parseGoalNarrative(response.content, plan) ?? local;
  }

  static GoalPlanNarrative? _parseGoalNarrative(
    String content,
    GoalPlan plan,
  ) {
    try {
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      final json = jsonDecode(content.substring(start, end + 1));
      if (json is! Map) return null;
      final data = Map<String, dynamic>.from(json);
      List<String> strings(dynamic value) => value is List
          ? value
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList()
          : <String>[];
      final diagnosis = data['diagnosis']?.toString().trim() ?? '';
      final mainProblem = data['mainProblem']?.toString().trim() ?? '';
      final nextStep = data['nextStep']?.toString().trim() ?? '';
      if (diagnosis.isEmpty || mainProblem.isEmpty || nextStep.isEmpty) {
        return null;
      }
      final local = _localGoalNarrative(plan);
      return GoalPlanNarrative(
        goalType: plan.goalType.name,
        diagnosis: diagnosis,
        mainProblem: mainProblem,
        riskFactors: strings(data['riskFactors']),
        questionsToAsk: strings(data['questionsToAsk']),
        // Numeric actions stay engine-owned even when cloud wording succeeds.
        recommendedPlan: local.recommendedPlan,
        minimumSavingIntervention: local.minimumSavingIntervention,
        recoveryTimeExplanation: local.recoveryTimeExplanation,
        warnings: strings(data['warnings']),
        nextStep: nextStep,
        calculatedValuesUsed: local.calculatedValuesUsed,
        usedCloud: true,
      );
    } catch (_) {
      return null;
    }
  }

  static GoalPlanNarrative _localGoalNarrative(GoalPlan plan) {
    final diagnosis = switch (plan.feasibility) {
      GoalFeasibility.feasible =>
        'الهدف ممكن ضمن المدة المطلوبة مع حماية احتياطي الأمان.',
      GoalFeasibility.feasibleWithVariableReduction =>
        'الهدف ممكن بعد تعديل صغير في المصروف المتغير.',
      GoalFeasibility.feasibleWithExtension =>
        'الهدف ممكن، لكن الموعد المطلوب يضغط الهامش الآمن.',
      GoalFeasibility.unreachable =>
        'الهدف غير قابل للتمويل بأمان من البيانات الحالية.',
    };
    final adjustment = switch (plan.minimumAdjustment.recommendedKind) {
      GoalAdjustmentKind.none => 'لا يحتاج الهدف إلى تعديل إضافي.',
      GoalAdjustmentKind.reduceVariableSpending =>
        'خفض المصروف المتغير ${plan.minimumAdjustment.requiredVariableExpenseReduction.round()} ريال شهريًا.',
      GoalAdjustmentKind.extendDuration =>
        'مدّد المدة ${plan.minimumAdjustment.minimumExtensionDays} يومًا لتصبح ${plan.effectiveTargetDays} يومًا.',
      GoalAdjustmentKind.unavailable =>
        'خفّض مبلغ الهدف أو أضف دخلًا ثابتًا قبل اعتماد الخطة.',
    };
    final weeks = plan.weeklySteps
        .map(
          (step) => GoalPlanNarrativeWeek(
            week: step.weekNumber,
            actions: [step.action, step.checkpoint],
            targetAmount: step.contributionTarget,
            safeDailySpend: plan.safeDailySpend,
            reason: 'يحافظ على احتياطي ${plan.safetyReserve.round()} ريال.',
          ),
        )
        .toList(growable: false);
    return GoalPlanNarrative(
      goalType: plan.goalType.name,
      diagnosis: diagnosis,
      mainProblem: plan.meetsRequestedDeadline
          ? 'المطلوب هو الالتزام بالمساهمة دون لمس الاحتياطي.'
          : 'الموعد أقصر من قدرة الفائض الآمن الحالي.',
      riskFactors: [
        'المساهمة الشهرية المطلوبة ${plan.requiredMonthlyContribution.round()} ريال.',
        'احتياطي الأمان المحمي ${plan.safetyReserve.round()} ريال.',
      ],
      questionsToAsk: const [
        'هل المبلغ والموعد ما زالا مناسبين؟',
        'هل يوجد مصروف غير أساسي يمكن تخفيفه مؤقتًا؟',
      ],
      recommendedPlan: weeks,
      minimumSavingIntervention: adjustment,
      recoveryTimeExplanation:
          'الخطة لا تستخدم احتياطي الأمان؛ أي تعثر في خطوة يعيد الحساب بدل مضاعفة الضغط.',
      warnings: const [
        'هذه خطة نموذج أولي وليست ضمانًا للوصول إلى الهدف.',
        'لا تعتمد على دخل غير مؤكد قبل دخوله فعليًا.',
      ],
      nextStep: plan.isReachable
          ? 'ابدأ أول تحويل ثم راجع الخطة نهاية الأسبوع.'
          : 'عدّل المبلغ أو المدة وأعد الحساب.',
      calculatedValuesUsed: const [
        'targetAmount',
        'effectiveTargetDays',
        'plannedMonthlyContribution',
        'safetyReserve',
        'safeDailySpend',
        'weeklyPlan',
      ],
      usedCloud: false,
    );
  }

  // تحليل صورة فاتورة عبر نموذج الرؤية — استخراج وتصنيف وتقييم.
  static Future<ReceiptResult> analyzeReceipt(String base64Jpeg) async {
    if (!isConfigured) {
      return ReceiptResult.error(
        'ميزة تحليل الفواتير غير مهيأة في هذه النسخة. ثبّت نسخة وقفة المحدثة.',
      );
    }

    const prompt =
        'هذه صورة فاتورة أو إيصال. استخرج منها البيانات وأعطِ النتيجة بصيغة JSON فقط '
        'بهذا الشكل بالضبط بدون أي نص خارج الأقواس: '
        '{"merchant":"اسم المتجر","total":الإجمالي كرقم,"category":"تصنيف الصرف مثل طعام أو تسوق أو فواتير",'
        '"is_bnpl":true أو false إن كانت تقسيط مثل تمارا أو تابي,'
        '"monthly_installment":القسط الشهري كرقم إن كان ظاهرًا وإلا 0,'
        '"note":"ملاحظة قصيرة بالعربية عن هذا الصرف ونصيحة واحدة"}. '
        'لا تخمّن القسط الشهري ولا تعتبر إجمالي الشراء قسطًا شهريًا.';
    final response = await _provider.analyzeImage(
      AiImageRequest(
        prompt: prompt,
        base64Jpeg: base64Jpeg,
        temperature: .2,
        maxTokens: 400,
      ),
    );
    if (response.ok) return ReceiptResult.parse(response.content);
    if (response.statusCode == 401 || response.statusCode == 403) {
      return ReceiptResult.error(
        'خدمة تحليل الفواتير غير مهيأة في هذه النسخة. ثبّت نسخة وقفة المحدثة.',
      );
    }
    if (response.statusCode == 413) {
      return ReceiptResult.error(
        'حجم الصورة كبير. التقط الفاتورة من مسافة أقرب وحاول مرة ثانية.',
      );
    }
    if (response.statusCode == 429) {
      return ReceiptResult.error(
        'خدمة التحليل مشغولة الآن. انتظر لحظة وحاول مرة ثانية.',
      );
    }
    if (response.statusCode > 0) {
      return ReceiptResult.error(
        'تعذّر تحليل الفاتورة الآن (${response.statusCode}). حاول مرة ثانية.',
      );
    }
    if (response.errorCode == 'not_configured') {
      return ReceiptResult.error(
        'خدمة تحليل الفواتير غير مهيأة في هذه النسخة. ثبّت نسخة وقفة المحدثة.',
      );
    }
    return ReceiptResult.error(
      'تعذّر الاتصال. تأكد من الإنترنت وحاول مرة ثانية.',
    );
  }

  // شرح مصطلح مالي ببساطة — لمسار التعليم المالي التفاعلي.
  static Future<String> explainTerm(String term) async {
    if (!isConfigured) return _termFallback(term);
    final prompt =
        'اشرح المصطلح المالي "$term" لشاب سعودي مبتدئ، بالعربية البسيطة، '
        'في 3-4 جمل قصيرة فقط، مع مثال واقعي واحد من الحياة اليومية. '
        'بدون مقدمات ولا عناوين ولا قوائم — فقرة واحدة متصلة.';
    final response = await _provider.generateText(
      AiTextRequest(
        systemPrompt:
            'أنت معلّم مالي سعودي تشرح المصطلحات ببساطة، دون توصية استثمارية شخصية.',
        userPrompt: prompt,
        temperature: .5,
        maxTokens: 300,
      ),
    );
    if (response.ok && response.content.trim().isNotEmpty) {
      return response.content.trim();
    }
    return _termFallback(term);
  }

  static String _termFallback(String term) {
    const fallbacks = {
      'BNPL':
          'BNPL يعني "اشترِ الآن وادفع لاحقاً" — مثل تمارا وتابي. تقسّم سعر المنتج على دفعات بدون فوائد ظاهرة، بس لو تراكمت عليك أقساط كثيرة من أكثر من متجر، تلقى نفسك مدين بمبالغ كبيرة بدون ما تحس.',
      'التورق':
          'التورق طريقة تمويل متوافقة مع الشريعة: تشتري سلعة بالتقسيط من البنك ثم تبيعها نقداً لتحصل على كاش. مفيدة وقت الحاجة، بس تبقى دين لازم تسدده بالأقساط.',
      'الادخار':
          'الادخار يعني تحجز جزء من دخلك قبل ما تصرفه، حتى لو مبلغ بسيط شهرياً. القاعدة الذهبية: ادفع لنفسك أولاً — حوّل مبلغ ثابت لحساب توفير أول ما يدخل الراتب.',
      'الاستثمار':
          'الاستثمار يعني توظيف المال بهدف نموه مع الوقت، مثل الأسهم أو الصناديق. العائد غير مضمون وقد ينخفض رأس المال، وتختلف الملاءمة حسب الهدف والمدة والقدرة على تحمّل المخاطر. هذا شرح تعليمي وليس توصية شخصية.',
      'الميزانية الشخصية':
          'الميزانية الشخصية يعني تعرف وين تروح فلوسك قبل ما تروح — تقسّم راتبك أول الشهر: التزامات ثابتة، مصاريف يومية، وادخار. مثال بسيط: قاعدة 50/30/20 — نصف الراتب للضروريات، 30% لرغباتك، و20% توفير وسداد ديون.',
      'نسبة الدين إلى الدخل':
          'نسبة الدين إلى الدخل تقيس كم من راتبك يروح لسداد الأقساط والديون كل شهر. مثال: راتبك 8000 وأقساطك 2000 يعني نسبتك 25%. كل ما زادت النسبة عن الثلث، صار وضعك أخطر وقلّت قدرتك على التحمّل لو صار طارئ.',
    };
    return fallbacks[term] ??
        'مصطلح مالي مهم. تعذّر جلب الشرح الآن — تأكد من اتصالك بالإنترنت وحاول مرة ثانية.';
  }

  // تحليل احتياطي محلي — يشتغل لو فشل الاتصال بالـ API لأي سبب.
  // يضمن إن العرض ما يطلع رسالة خطأ أبداً أمام اللجنة.
  static String _localFallback({
    required double salary,
    required double bnpl,
    required double remaining,
    required int bnplRatio,
    required int totalRatio,
    String concern = '',
  }) {
    final remInt = remaining > 0 ? remaining.toInt() : 0;
    final targetSave = salary * 0.1;
    final affordableSave = remaining > 0 ? remaining * 0.5 : 0.0;
    final save =
        (targetSave < affordableSave ? targetSave : affordableSave).round();

    String head;
    if (bnplRatio > 30) {
      head =
          'وضعك يحتاج وقفة جادة — مصاريفك تلتهم $totalRatio% من راتبك وأقساط BNPL وصلت $bnplRatio% وهذي منطقة خطر. أوقف أي قسط جديد فوراً وركّز على سداد الأقساط الحالية أول شي.';
    } else if (totalRatio > 90) {
      head =
          'وضعك يحتاج وقفة جادة — مصاريفك تلتهم $totalRatio% من راتبك وما بقي لك هامش آمن للطوارئ. أوقف الالتزامات الجديدة وابدأ بخفض أكبر مصروف متغيّر عندك.';
    } else if (bnplRatio > 20) {
      head =
          'انتبه — $totalRatio% من راتبك يروح مصاريف، وأقساط BNPL عند $bnplRatio% تقربك من الحد الخطر. لا تضيف أي قسط جديد هالشهر، وحاول تخفض مصاريفك المتغيرة شوي.';
    } else if (totalRatio > 75) {
      head =
          'انتبه — $totalRatio% من راتبك يروح للمصاريف، وهذا يترك لك هامشًا ضعيفًا لأي طارئ. راجع أكبر بند متغيّر قبل ما تضيف التزامًا جديدًا.';
    } else {
      head =
          'وضعك المالي مستقر — مصاريفك $totalRatio% من راتبك وأقساط BNPL بس $bnplRatio%، وهذا ضمن الحد الآمن. استغل استقرارك وابدأ تبني عادة ادخار ثابتة.';
    }

    String tail;
    if (save <= 0) {
      tail =
          ' ما عندك فائض آمن للادخار الآن؛ أغلق العجز أولًا بخفض المصروف أو إعادة ترتيب الالتزامات، وبعدها ابدأ بمبلغ صغير.';
    } else if (concern.trim().isNotEmpty) {
      tail =
          ' بخصوص ما يقلقك: لو خصصت $save ريال شهرياً من المتبقي ($remInt ريال)، تبني مبلغاً يحقق هدفك تدريجياً بدون ما تضغط على وضعك الحالي.';
    } else {
      tail =
          ' لو حوّلت $save ريال لحساب توفير أول ما يدخل الراتب — قبل ما تصرف — تبني هامش أمان خلال أشهر بدون ما تحس.';
    }

    return head + tail;
  }
}
