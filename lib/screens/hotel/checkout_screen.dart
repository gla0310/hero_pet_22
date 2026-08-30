import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/admission.dart';
import '../../models/admission_note.dart';
import '../../utils/date_helper.dart';
import '../../utils/image_picker_helper.dart';
import '../../utils/whatsapp_helper.dart';
import '../../utils/send_to_client_prompt.dart';
import '../forms/fill_form_screen.dart';
import '../home_screen.dart';

/// شاشة تسجيل الخروج/التسليم الموحّدة — تعمل لأي نوع (فندقة عادية/علاجية أو إجراء طبي)
/// وتنتهي دائماً بالحالة "تم التسليم" كما هو مطلوب.
///
/// إذا كانت هناك استمارة إلكترونية نشطة لخروج هذا النوع من الفندقة، تظهر
/// مباشرة عند فتح الشاشة (مع ملاحظات التواجد إن وُجدت) وتحل محل صورة عقد
/// الاستلام الورقي، ويتم تسجيل الخروج تلقائياً بعد اعتمادها.
class CheckoutScreen extends StatefulWidget {
  final Admission admission;
  final String petName;

  const CheckoutScreen({super.key, required this.admission, required this.petName});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _notesController = TextEditingController();
  String? _receiptImagePath;
  bool _saving = false;

  Map<String, dynamic>? _activeTemplate;
  bool _loadingTemplate = true;
  bool _formTriggered = false;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  String _serviceType() {
    if (widget.admission.isHotel) {
      return widget.admission.boardingType == BoardingType.treatment
          ? FormServiceType.checkoutHotelTreatment
          : FormServiceType.checkoutHotelNormal;
    }
    return FormServiceType.checkoutProcedure;
  }

  Future<void> _loadTemplate() async {
    final serviceType = _serviceType();
    final template = await DBHelper.instance.getActiveTemplateForServiceType(serviceType);
    if (!mounted) return;
    setState(() {
      _activeTemplate = template;
      _loadingTemplate = false;
    });
    // تظهر الاستمارة مباشرة بمجرد فتح الشاشة إن وُجدت
    if (template != null && !_formTriggered) {
      _formTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFormAndCheckout());
    }
  }

  Future<void> _openFormAndCheckout() async {
    final notes = widget.admission.id != null
        ? await DBHelper.instance.getNotesForAdmission(widget.admission.id!)
        : const <AdmissionNote>[];

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FillFormScreen(
          templateId: _activeTemplate!['id'] as int,
          petId: widget.admission.petId,
          admissionId: widget.admission.id,
          invoiceRequired: false,
          admissionNotes: notes,
        ),
      ),
    );
    if (result is int && mounted) {
      await _finalizeCheckout();
    }
  }

  Future<void> _pickReceiptImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('التقاط صورة عقد الاستلام'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final path = await ImagePickerHelper.pickAndSaveImage(source: source);
    if (path != null) setState(() => _receiptImagePath = path);
  }

  Future<void> _finalizeCheckout() async {
    setState(() => _saving = true);

    final updated = widget.admission.copyWith(
      actualExitDate: DateHelper.nowDateTime(),
      exitContractImage: _receiptImagePath,
      status: PetStatus.delivered, // "تم التسليم" موحّدة لكل الحالات
      notes: _notesController.text.trim().isEmpty ? widget.admission.notes : _notesController.text.trim(),
    );

    await DBHelper.instance.updateAdmission(updated);
    await DBHelper.instance.updatePetStatus(widget.admission.petId, PetStatus.delivered);

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تسليم "${widget.petName}" لصاحبها')),
    );

    // نعرض للموظف مباشرة خانة "إرسال للعميل" (لا تُرسل تلقائياً)
    final pet = await DBHelper.instance.getPetById(widget.admission.petId);
    final client = pet != null ? await DBHelper.instance.getClientById(pet.clientId) : null;
    if (mounted && client != null) {
      final kind = widget.admission.isHotel
          ? (widget.admission.boardingType == BoardingType.treatment ? AdmissionKind.hotelTreatment : AdmissionKind.hotelNormal)
          : AdmissionKind.procedure;
      final message = WhatsAppHelper.buildCheckoutConfirmationMessage(
        petName: widget.petName,
        gender: pet?.gender,
        kind: kind,
      );
      await SendToClientPrompt.show(context: context, phone: client.phone, message: message);
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _checkout() async {
    if (_receiptImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('صورة عقد الاستلام إلزامية ولا يمكن إنهاء العملية بدونها')),
      );
      return;
    }
    await _finalizeCheckout();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingTemplate || _activeTemplate != null) {
      // الاستمارة تُفتح تلقائياً؛ نعرض مؤشر تحميل بسيط في هذه الأثناء
      return Scaffold(
        appBar: AppBar(title: Text('تسجيل خروج — ${widget.petName}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('تسجيل خروج — ${widget.petName}')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text('تاريخ ووقت الخروج: ${DateHelper.nowDateTime()}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات', prefixIcon: Icon(Icons.notes)),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: Text(_receiptImagePath == null ? 'التقاط صورة عقد الاستلام *' : 'تم اختيار صورة عقد الاستلام ✓'),
              onPressed: _pickReceiptImage,
            ),
            if (_receiptImagePath != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_receiptImagePath!), height: 160, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle),
              label: Text(_saving ? 'جاري الحفظ...' : 'تأكيد تسجيل الخروج'),
              onPressed: _saving ? null : _checkout,
            ),
          ],
        ),
      ),
    );
  }
}
