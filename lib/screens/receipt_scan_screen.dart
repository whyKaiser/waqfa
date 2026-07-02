import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_service.dart';

/// تصوير فاتورة وتحليلها بالرؤية — استخراج المبلغ والتصنيف ونصيحة،
/// مع إمكانية إضافة المبلغ مباشرة لمصاريفك أو أقساطك.
class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  static const _accent = Color(0xFF6C63FF);
  final _picker = ImagePicker();

  Uint8List? _image;
  bool _loading = false;
  ReceiptResult? _result;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1280, imageQuality: 70);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() { _image = bytes; _result = null; _loading = true; });
      final res = await AiService.analyzeReceipt(base64Encode(bytes));
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() { _result = res; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح الصورة. حاول مرة ثانية.')),
      );
    }
  }

  void _useAmount() {
    final r = _result;
    if (r == null || !r.ok || r.total <= 0) return;
    Navigator.pop(context, {'amount': r.total, 'isBnpl': r.isBnpl});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('صوّر فاتورتك'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'صوّر أي فاتورة أو إيصال، ووقفة يقرأها ويصنّف صرفك تلقائياً.',
                style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _image == null
                    ? const Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.receipt_long_outlined, color: Colors.white24, size: 56),
                          SizedBox(height: 8),
                          Text('لا توجد صورة بعد', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ]),
                      )
                    : Image.memory(_image!, fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _btn('كاميرا', Icons.camera_alt_outlined, () => _pick(ImageSource.camera))),
                const SizedBox(width: 12),
                Expanded(child: _btn('من المعرض', Icons.photo_library_outlined, () => _pick(ImageSource.gallery))),
              ]),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Column(children: [
                    CircularProgressIndicator(color: _accent),
                    SizedBox(height: 12),
                    Text('يقرأ الفاتورة...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ])),
                ),
              if (_result != null && !_loading) _resultCard(_result!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: _loading ? null : onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _resultCard(ReceiptResult r) {
    if (!r.ok) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(r.note, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5))),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (r.isBnpl)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFF6B6B).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Text('تقسيط BNPL', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          const Spacer(),
          Text('${r.total.toInt()} ريال', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        if (r.merchant.isNotEmpty) _row(Icons.store_outlined, 'المتجر', r.merchant),
        if (r.category.isNotEmpty) _row(Icons.category_outlined, 'التصنيف', r.category),
        const SizedBox(height: 6),
        if (r.note.isNotEmpty)
          Text(r.note, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.7)),
        if (r.total > 0) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _useAmount,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(r.isBnpl ? 'أضِف لأقساط BNPL' : 'أضِف لمصاريفي'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6BCB77),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: Colors.white38, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13))),
      ]),
    );
  }
}
