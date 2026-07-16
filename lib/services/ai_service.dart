import 'dart:convert';
import 'package:http/http.dart' as http;
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

class AiService {
  static const String _model = 'qwen/qwen3.6-27b';
  static const String _apiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => _apiKey.trim().isNotEmpty;

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
        '''أنت مستشار مالي سعودي متخصص في حماية الشباب من الديون. حلل الوضع المالي التالي وأعطِ تقييماً شخصياً باللغة العربية العامية السعودية البسيطة.

البيانات:
- الراتب الشهري: $salary ريال
- المصاريف الثابتة: $fixed ريال
- المصاريف المتغيرة: $variable ريال
- أقساط BNPL (تمارا، تابي): $bnpl ريال
- المتبقي: $remaining ريال
- نسبة BNPL من الراتب: $bnplRatio%
- نسبة المصاريف الكلية: $totalRatio%
${concern.isNotEmpty ? '- قلق المستخدم: $concern' : ''}$profileCtx

اكتب تحليلاً مفيداً بالعربية الفصحى البسيطة (4-5 جمل فقط). ابدأ بأهم ملاحظة على أرقامه، راعِ أهدافه وفئته العمرية ونوع دخله في نصيحتك، ثم إذا ذكر قلقاً مالياً قدّم له خطوات عملية محددة تحقق هدفه مع وضعه الحالي — كم يوفر شهرياً، متى يصل للهدف، وكيف يعدّل مصاريفه. بدون مقدمات أو تحيات، فقرة واحدة متصلة.''';

    try {
      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'reasoning_effort': 'none',
              'reasoning_format': 'hidden',
              'temperature': 0.6,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'أنت مستشار مالي سعودي. تكتب فقرة واحدة قصيرة (4-5 جمل) بالعربية العامية السعودية البسيطة. '
                          'ممنوع منعاً باتاً: أي حسابات رياضية، أرقام خطوة بخطوة، قوائم مرقمة، عناوين، أو مقدمات وتحيات. '
                          'فقط نص نصيحة متصل ومباشر.'
                },
                {'role': 'user', 'content': prompt}
              ],
              'max_tokens': 350,
            }),
            // شبكة معلّقة (تتصل ولا ترد) ما ترمي استثناء — بدون مهلة يلف السبنر للأبد
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        if (content is String && content.trim().isNotEmpty) {
          return FinancialAnalysisResult(text: content, usedCloud: true);
        }
        return localResult();
      } else {
        return localResult();
      }
    } catch (_) {
      return localResult();
    }
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
    try {
      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'reasoning_effort': 'none',
              'reasoning_format': 'hidden',
              'temperature': 0.2,
              'max_tokens': 400,
              'response_format': {'type': 'json_object'},
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': prompt},
                    {
                      'type': 'image_url',
                      'image_url': {'url': 'data:image/jpeg;base64,$base64Jpeg'}
                    },
                  ],
                }
              ],
            }),
            // مهلة أطول: رفع صورة أبطأ من طلب نصي
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['choices'][0]['message']['content'] as String? ?? '';
        return ReceiptResult.parse(content);
      }
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
      return ReceiptResult.error(
        'تعذّر تحليل الفاتورة الآن (${response.statusCode}). حاول مرة ثانية.',
      );
    } catch (_) {
      return ReceiptResult.error(
          'تعذّر الاتصال. تأكد من الإنترنت وحاول مرة ثانية.');
    }
  }

  // شرح مصطلح مالي ببساطة — لمسار التعليم المالي التفاعلي.
  static Future<String> explainTerm(String term) async {
    if (!isConfigured) return _termFallback(term);
    final prompt =
        'اشرح المصطلح المالي "$term" لشاب سعودي مبتدئ، بالعربية البسيطة، '
        'في 3-4 جمل قصيرة فقط، مع مثال واقعي واحد من الحياة اليومية. '
        'بدون مقدمات ولا عناوين ولا قوائم — فقرة واحدة متصلة.';
    try {
      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'reasoning_effort': 'none',
              'reasoning_format': 'hidden',
              'temperature': 0.6,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'أنت معلّم مالي سعودي تشرح المصطلحات ببساطة شديدة لمبتدئين. '
                          'فقرة واحدة قصيرة، بدون حسابات أو قوائم أو عناوين.'
                },
                {'role': 'user', 'content': prompt}
              ],
              'max_tokens': 300,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        if (content is String && content.trim().isNotEmpty) return content;
      }
    } catch (_) {}
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
          'الاستثمار يعني تشغّل فلوسك لتنمو مع الوقت بدل ما تبقى ساكنة، مثل الأسهم أو الصناديق. فيه مخاطرة، فابدأ بمبلغ صغير تقدر تتحمّل خسارته وتعلّم بالتدريج.',
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
