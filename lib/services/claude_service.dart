import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'secrets.dart';
import 'profile_service.dart';

class ClaudeService {
  static const String _apiKey = Secrets.groqApiKey;

  static Future<String> analyzeFinances({
    required double salary,
    required double fixed,
    required double variable,
    required double bnpl,
    String concern = '',
  }) async {
    final remaining = salary - fixed - variable - bnpl;
    final bnplRatio = ((bnpl / salary) * 100).round();
    final totalRatio = (((fixed + variable + bnpl) / salary) * 100).round();

    final profileCtx = (await ProfileService.load()).toPromptContext();

    final prompt = '''أنت مستشار مالي سعودي متخصص في حماية الشباب من الديون. حلل الوضع المالي التالي وأعطِ تقييماً شخصياً باللغة العربية العامية السعودية البسيطة.

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
      final response = await http.post(
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
      );

      debugPrint('Groq status: ${response.statusCode}');
      debugPrint('Groq body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        if (content is String && content.trim().isNotEmpty) return content;
        return _localFallback(salary: salary, bnpl: bnpl, remaining: remaining,
            bnplRatio: bnplRatio, totalRatio: totalRatio, concern: concern);
      } else {
        debugPrint('Groq error: ${response.body}');
        return _localFallback(salary: salary, bnpl: bnpl, remaining: remaining,
            bnplRatio: bnplRatio, totalRatio: totalRatio, concern: concern);
      }
    } catch (e) {
      debugPrint('Exception: $e');
      return _localFallback(salary: salary, bnpl: bnpl, remaining: remaining,
          bnplRatio: bnplRatio, totalRatio: totalRatio, concern: concern);
    }
  }

  // شرح مصطلح مالي ببساطة — لمسار التعليم المالي التفاعلي.
  static Future<String> explainTerm(String term) async {
    final prompt =
        'اشرح المصطلح المالي "$term" لشاب سعودي مبتدئ، بالعربية البسيطة، '
        'في 3-4 جمل قصيرة فقط، مع مثال واقعي واحد من الحياة اليومية. '
        'بدون مقدمات ولا عناوين ولا قوائم — فقرة واحدة متصلة.';
    try {
      final response = await http.post(
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
      );
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
