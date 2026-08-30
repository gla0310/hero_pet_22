import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/client.dart';
import '../../models/pet.dart';
import '../../models/admission_note.dart';
import '../../utils/date_helper.dart';
import '../../utils/form_pdf_generator.dart';
import '../../utils/image_picker_helper.dart';
import '../../widgets/signature_pad.dart';

/// شاشة تعبئة الاستمارة الإلكترونية والتوقيع عليها - يستخدمها العميل مباشرة
/// على الآيباد. تُفتح تلقائياً أو عند الضغط على "الاستمارة الإلكترونية"
/// حسب نوع الخدمة (دخول/خروج فندقة أو إجراء طبي).
class FillFormScreen extends StatefulWidget {
  final int templateId;
  final int petId;
  final int? admissionId;
  final int? visitId;

  /// عند تسجيل الدخول: صورة الفاتورة إلزامية لإكمال الاستمارة.
  /// عند تسجيل الخروج: اختيارية.
  final bool invoiceRequired;

  /// ملاحظات الفندقة أثناء التواجد (تُعرض عند الخروج فقط إن وُجدت)
  final List<AdmissionNote>? admissionNotes;

  const FillFormScreen({
    super.key,
    required this.templateId,
    required this.petId,
    this.admissionId,
    this.visitId,
    this.invoiceRequired = true,
    this.admissionNotes,
  });

  @override
  State<FillFormScreen> createState() => _FillFormScreenState();
}

class _FillFormScreenState extends State<FillFormScreen> {
  bool _loading = true;
  Map<String, dynamic>? _template;
  List<Map<String, dynamic>> _fields = [];
  Client? _client;
  Pet? _pet;

  bool _termsAccepted = false;

  // إجابات الحقول الديناميكية: field id -> controller (نص) أو bool (Checkbox)
  final Map<int, TextEditingController> _textAnswers = {};
  final Map<int, bool> _checkboxAnswers = {};

  final _signatureKey = GlobalKey();
  final _signaturePadStateKey = GlobalKey<SignaturePadState>();

  String? _invoiceImagePath;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _textAnswers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final template = await DBHelper.instance.getFormTemplateById(widget.templateId);
    final fields = await DBHelper.instance.getFormFields(widget.templateId);
    final pet = await DBHelper.instance.getPetById(widget.petId);
    Client? client;
    if (pet != null) {
      client = await DBHelper.instance.getClientById(pet.clientId);
    }

    if (!mounted) return;
    setState(() {
      _template = template;
      _fields = fields;
      _pet = pet;
      _client = client;
      for (final f in fields) {
        final id = f['id'] as int;
        if (f['field_type'] == 'checkbox') {
          _checkboxAnswers[id] = false;
        } else {
          _textAnswers[id] = TextEditingController();
        }
      }
      _loading = false;
    });
  }

  bool get _signatureEmpty => _signaturePadStateKey.currentState?.isEmpty ?? true;

  Future<void> _captureInvoice() async {
    final path = await ImagePickerHelper.pickAndSaveImage(source: ImageSource.camera);
    if (path != null) setState(() => _invoiceImagePath = path);
  }

  Future<void> _submit() async {
    if (_client == null || _pet == null || _template == null) return;

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب الموافقة على الشروط والأحكام')),
      );
      return;
    }
    for (final f in _fields) {
      final required = (f['required'] as int) == 1;
      if (!required) continue;
      final id = f['id'] as int;
      if (f['field_type'] == 'checkbox') {
        if (_checkboxAnswers[id] != true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('الحقل "${f['label']}" إلزامي')),
          );
          return;
        }
      } else {
        if ((_textAnswers[id]?.text.trim() ?? '').isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('الحقل "${f['label']}" إلزامي')),
          );
          return;
        }
      }
    }
    if (_signatureEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('التوقيع إلزامي لاعتماد الاستمارة')),
      );
      return;
    }
    if (widget.invoiceRequired && _invoiceImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('صورة الفاتورة إلزامية لإكمال الاستمارة')),
      );
      return;
    }

    setState(() => _submitting = true);
    final stopwatch = Stopwatch()..start();

    // حفظ صورة التوقيع
    final signatureBytes = await _signaturePadStateKey.currentState!.exportPng();
    if (signatureBytes == null) {
      setState(() => _submitting = false);
      return;
    }
    debugPrint('⏱ [استمارة] تصدير التوقيع: ${stopwatch.elapsedMilliseconds}ms');
    stopwatch.reset();

    final signaturePath = await ImagePickerHelper.saveBytesAsImage(signatureBytes, prefix: 'signature');
    debugPrint('⏱ [استمارة] حفظ ملف التوقيع: ${stopwatch.elapsedMilliseconds}ms');
    stopwatch.reset();

    // بناء قائمة الإجابات
    final answers = <Map<String, String>>[];
    for (final f in _fields) {
      final id = f['id'] as int;
      final label = f['label'] as String;
      if (f['field_type'] == 'checkbox') {
        answers.add({'label': label, 'value': (_checkboxAnswers[id] == true) ? 'نعم' : 'لا'});
      } else {
        answers.add({'label': label, 'value': _textAnswers[id]?.text.trim() ?? ''});
      }
    }

    final submittedAt = DateHelper.nowDateTime();
    final serviceLabel = FormServiceType.label(_template!['service_type']);

    final pdfPath = await FormPdfGenerator.generate(
      templateName: _template!['name'],
      serviceTypeLabel: serviceLabel,
      clientName: _client!.name,
      clientPhone: _client!.phone,
      civilId: _client!.civilId,
      petName: _pet!.name,
      termsText: _template!['terms_text'],
      termsAccepted: _termsAccepted,
      answers: answers,
      signatureBytes: signatureBytes,
      submittedAt: submittedAt,
    );
    debugPrint('⏱ [استمارة] إنشاء PDF: ${stopwatch.elapsedMilliseconds}ms');
    stopwatch.reset();

    final submissionId = await DBHelper.instance.insertFormSubmission(
      templateId: widget.templateId,
      templateName: _template!['name'],
      serviceType: _template!['service_type'],
      clientId: _client!.id!,
      petId: _pet!.id,
      admissionId: widget.admissionId,
      visitId: widget.visitId,
      civilId: _client!.civilId,
      answersJson: jsonEncode(answers),
      signaturePath: signaturePath,
      pdfPath: pdfPath,
    );

    if (_invoiceImagePath != null) {
      await DBHelper.instance.addFormAttachment(submissionId, _invoiceImagePath!);
    }
    debugPrint('⏱ [استمارة] حفظ قاعدة البيانات: ${stopwatch.elapsedMilliseconds}ms');

    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعتماد الاستمارة وحفظها')));
    Navigator.pop(context, submissionId);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_template == null || _client == null || _pet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطأ')),
        body: const Center(child: Text('تعذّر تحميل بيانات الاستمارة')),
      );
    }

    final serviceLabel = FormServiceType.label(_template!['service_type']);
    final termsText = _template!['terms_text'] as String?;
    final notes = widget.admissionNotes ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(_template!['name'])),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(serviceLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const Divider(),
                  _infoRow('اسم العميل', _client!.name),
                  _infoRow('رقم الجوال', _client!.phone),
                  _infoRow('اسم الأليف', _pet!.name),
                  _infoRow('رقم ملف الأليف', '#${_pet!.id}'),
                  _infoRow('التاريخ والوقت', DateHelper.nowDateTime()),
                ],
              ),
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('ملاحظات أثناء التواجد في الفندقة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: notes
                    .map((n) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text('• ${n.text}  (${n.dateTime})'),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (termsText != null && termsText.isNotEmpty) ...[
            const Divider(height: 30),
            const Text('الشروط والأحكام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(termsText),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('أوافق على الشروط والأحكام *'),
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
            ),
          ],
          if (_fields.isNotEmpty) ...[
            const Divider(height: 30),
            const Text('بيانات إضافية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ..._fields.map((f) {
              final id = f['id'] as int;
              final required = (f['required'] as int) == 1;
              final label = '${f['label']}${required ? ' *' : ''}';
              if (f['field_type'] == 'checkbox') {
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label),
                  value: _checkboxAnswers[id] ?? false,
                  onChanged: (v) => setState(() => _checkboxAnswers[id] = v ?? false),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _textAnswers[id],
                  decoration: InputDecoration(labelText: label),
                  maxLines: f['field_type'] == 'textarea' ? 4 : 1,
                ),
              );
            }),
          ],
          const Divider(height: 30),
          const Text('التوقيع الإلكتروني *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SignaturePad(
              key: _signaturePadStateKey,
              repaintKey: _signatureKey,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _signaturePadStateKey.currentState?.clear()),
              icon: const Icon(Icons.refresh),
              label: const Text('مسح التوقيع'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.invoiceRequired ? 'صورة الفاتورة *' : 'صورة الفاتورة (اختياري)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_invoiceImagePath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(_invoiceImagePath!),
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: Text(_invoiceImagePath == null ? 'تصوير الفاتورة بالكاميرا' : 'إعادة التصوير'),
            onPressed: _captureInvoice,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              icon: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_submitting ? 'جاري الاعتماد...' : 'اعتماد'),
              onPressed: _submitting ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: AppColors.textLight))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
