import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'result_screen.dart';
import 'connect_screen.dart';
import 'receipt_scan_screen.dart';
import '../theme/app_theme.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _salaryCtrl = TextEditingController();
  final _fixedCtrl = TextEditingController();
  final _variableCtrl = TextEditingController();
  final _bnplCtrl = TextEditingController();
  final _concernCtrl = TextEditingController();
  bool _navigating = false; // يمنع فتح شاشتين نتيجة بنقرة مزدوجة سريعة
  bool _allowCloudAi = false;

  @override
  void dispose() {
    _salaryCtrl.dispose();
    _fixedCtrl.dispose();
    _variableCtrl.dispose();
    _bnplCtrl.dispose();
    _concernCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectAccounts() async {
    HapticFeedback.lightImpact();
    final data = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(builder: (_) => const ConnectScreen()),
    );
    if (data == null || !mounted) return;
    setState(() {
      _salaryCtrl.text = (data['salary'] ?? 0).toInt().toString();
      _fixedCtrl.text = (data['fixed'] ?? 0).toInt().toString();
      _variableCtrl.text = (data['variable'] ?? 0).toInt().toString();
      _bnplCtrl.text = (data['bnpl'] ?? 0).toInt().toString();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('تم تحميل بيانات النموذج التجريبي — راجعها واضغط حلّل')),
    );
  }

  Future<void> _scanReceipt() async {
    HapticFeedback.lightImpact();
    final data = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptScanScreen()),
    );
    if (data == null || !mounted) return;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) return;
    final isBnpl = data['isBnpl'] == true;
    final ctrl = isBnpl ? _bnplCtrl : _variableCtrl;
    final current = double.tryParse(ctrl.text) ?? 0;
    setState(() => ctrl.text = (current + amount).toInt().toString());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'أُضيف ${amount.toInt()} ريال إلى ${isBnpl ? "أقساط BNPL" : "المصاريف المتغيرة"}')),
    );
  }

  Future<void> _analyze() async {
    if (_navigating) return;
    final salary = double.tryParse(_salaryCtrl.text) ?? 0;
    if (salary == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل راتبك أولاً')),
      );
      return;
    }
    _navigating = true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          salary: salary,
          fixed: double.tryParse(_fixedCtrl.text) ?? 0,
          variable: double.tryParse(_variableCtrl.text) ?? 0,
          bnpl: double.tryParse(_bnplCtrl.text) ?? 0,
          concern: _concernCtrl.text,
          allowCloudAi: _allowCloudAi,
        ),
      ),
    );
    _navigating = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('بياناتك المالية'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ربط تلقائي عبر المصرفية المفتوحة
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _connectAccounts,
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('جرّب ربط الحسابات (نموذج تجريبي)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    side: const BorderSide(color: AppColors.info, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _scanReceipt,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('صوّر فاتورة وأضِفها تلقائياً'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Row(children: [
                Expanded(child: Divider(color: Colors.white12)),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('أو أدخل يدوياً',
                        style: TextStyle(color: Colors.white24, fontSize: 12))),
                Expanded(child: Divider(color: Colors.white12)),
              ]),
              const SizedBox(height: 16),
              _InputField(
                controller: _salaryCtrl,
                label: 'الراتب الشهري',
                hint: 'مثال: 8000',
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _InputField(
                      controller: _fixedCtrl,
                      label: 'مصاريف ثابتة',
                      hint: 'إيجار، فواتير...',
                      icon: Icons.home_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InputField(
                      controller: _variableCtrl,
                      label: 'مصاريف متغيرة',
                      hint: 'أكل، تسوق...',
                      icon: Icons.shopping_bag_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InputField(
                controller: _bnplCtrl,
                label: 'أقساط BNPL (تمارا، تابي...)',
                hint: 'مثال: 1500',
                icon: Icons.credit_card_outlined,
                highlight: true,
              ),
              const SizedBox(height: 16),
              _InputField(
                controller: _concernCtrl,
                label: 'أي قلق مالي؟ (اختياري)',
                hint: 'مثال: خايف ما أكفي آخر الشهر...',
                icon: Icons.chat_bubble_outline,
                isNumber: false,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: SwitchListTile.adaptive(
                  value: _allowCloudAi,
                  onChanged: (value) => setState(() => _allowCloudAi = value),
                  activeColor: AppColors.primary,
                  title: const Text(
                    'تحليل سحابي اختياري',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'عند تفعيله تُرسل أرقامك وبيانات ملفك التخصيصي إلى Groq لإنشاء نصيحة. عند إيقافه يعمل التحليل المحلي فقط.',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 11, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _analyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'حلّل وضعي',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isNumber;
  final bool highlight;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isNumber = true,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            textAlign: TextAlign.right,
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            inputFormatters: isNumber
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                : null,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              suffix: isNumber
                  ? const Text(
                      'ريال',
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
