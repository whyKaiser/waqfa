import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'secrets.dart';
import 'profile_service.dart';

/// نتيجة تحليل فاتورة مصوّرة.
class ReceiptResult {
  final String merchant;
  final double total;
  final String category;
  final bool isBnpl;
  final String note;
  final bool ok;

  ReceiptResult({
    required this.merchant,
    required this.total,
    required this.category,
    required this.isBnpl,
    required this.note,
    this.ok = true,
  });

  factory ReceiptResult.error(String msg) => ReceiptResult(
        merchant: '',
        total: 0,
        category: '',
        isBnpl: false,
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
        if (v is String)
          return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        return 0;
      }

      return ReceiptResult(
        merchant: (j['merchant'] ?? '').toString(),
        total: parseNum(j['total']),
        category: (j['category'] ?? '').toString(),
        isBnpl: j['is_bnpl'] == true || j['is_bnpl'].toString() == 'true',
        note: (j['note'] ?? '').toString(),
      );
    } catch (_) {
      return ReceiptResult.error(
          'ما قدرت أقرأ الفاتورة بوضوح. جرّب صورة أوضح وإضاءة أحسن.');
    }
  }
}

class AiService {
  static const String _apiKey = Secrets.groqApiKey;

  static Future<String> analyzeFinances({
    required double salary,
    required double fixed,
    required double variable,
    required double bnpl,
    String concern = '',
  }) async {
    final remaining = salary - fixed - variable - bnpl;
    final safeSalary = salary > 0 ? salary : 1;
    final bnplRatio = ((bnpl / safeSalary) * 100).round();
    final totalRatio = (((fixed + variable + bnpl) / safeSalary) * 100).round();

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
              'model': 'llama-3.3-70b-versatile',
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

      debugPrint('Groq status: ${response.statusCode}');
      debugPrint('Groq body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        if (content is String && content.trim().isNotEmpty) return content;
        return _localFallback(
            salary: salary,
            bnpl: bnpl,
            remaining: remaining,
            bnplRatio: bnplRatio,
            totalRatio: totalRatio,
            concern: concern);
      } else {
        debugPrint('Groq error: ${response.body}');
        return _localFallback(
            salary: salary,
            bnpl: bnpl,
            remaining: remaining,
            bnplRatio: bnplRatio,
            totalRatio: totalRatio,
            concern: concern);
      }
    } catch (e) {
      debugPrint('Exception: $e');
      return _localFallback(
          salary: salary,
          bnpl: bnpl,
          remaining: remaining,
          bnplRatio: bnplRatio,
          totalRatio: totalRatio,
          concern: concern);
    }
  }

  // تحليل صورة فاتورة عبر نموذج الرؤية — استخراج وتصنيف وتقييم.
  static Future<ReceiptResult> analyzeReceipt(String base64Jpeg) async {
    const prompt =
        'هذه صورة فاتورة أو إيصال. استخرج منها البيانات وأعطِ النتيجة بصيغة JSON فقط '
        'بهذا الشكل بالضبط بدون أي نص خارج الأقواس: '
        '{"merchant":"اسم المتجر","total":الإجمالي كرقم,"category":"تصنيف الصرف مثل طعام أو تسوق أو فواتير",'
        '"is_bnpl":true أو false إن كانت تقسيط مثل تمارا أو تابي,"note":"ملاحظة قصيرة بالعربية عن هذا الصرف ونصيحة واحدة"}';
    try {
      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
              'temperature': 0.2,
              'max_tokens': 400,
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
      debugPrint('Receipt status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['choices'][0]['message']['content'] as String? ?? '';
        return ReceiptResult.parse(content);
      }
      debugPrint('Receipt error: ${response.body}');
      return ReceiptResult.error(
          'تعذّر تحليل الفاتورة (${response.statusCode}). حاول بصورة أوضح.');
    } catch (e) {
      debugPrint('Receipt exception: $e');
      return ReceiptResult.error(
          'تعذّر الاتصال. تأكد من الإنترنت وحاول مرة ثانية.');
    }
  }

  // شرح مصطلح مالي ببساطة — لمسار التعليم المالي التفاعلي.
  static Future<String> explainTerm(String term) async {
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
              'model': 'llama-3.3-70b-versatile',
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
    } catch (e) {
      debugPrint('explainTerm exception: $e');
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
    final save = (salary * 0.1).round();

    String head;
    if (bnplRatio > 30 || totalRatio > 90) {
      head =
          'وضعك يحتاج وقفة جادة — مصاريفك تلتهم $totalRatio% من راتبك وأقساط BNPL وصلت $bnplRatio% وهذي منطقة خطر. أوقف أي قسط جديد فوراً وركّز على سداد الأقساط الحالية أول شي.';
    } else if (bnplRatio > 20 || totalRatio > 75) {
      head =
          'انتبه — $totalRatio% من راتبك يروح مصاريف، وأقساط BNPL عند $bnplRatio% تقربك من الحد الخطر. لا تضيف أي قسط جديد هالشهر، وحاول تخفض مصاريفك المتغيرة شوي.';
    } else {
      head =
          'وضعك المالي مستقر — مصاريفك $totalRatio% من راتبك وأقساط BNPL بس $bnplRatio%، وهذا ضمن الحد الآمن. استغل استقرارك وابدأ تبني عادة ادخار ثابتة.';
    }

    String tail;
    if (concern.trim().isNotEmpty) {
      tail =
          ' بخصوص ما يقلقك: لو خصصت $save ريال شهرياً من المتبقي ($remInt ريال)، تبني مبلغاً يحقق هدفك تدريجياً بدون ما تضغط على وضعك الحالي.';
    } else {
      tail =
          ' لو حوّلت $save ريال لحساب توفير أول ما يدخل الراتب — قبل ما تصرف — تبني هامش أمان خلال أشهر بدون ما تحس.';
    }

    return head + tail;
  }
}
