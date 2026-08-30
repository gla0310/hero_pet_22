import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../database/db_helper.dart';
import '../../models/admission.dart';
import '../../utils/date_helper.dart';
import '../../utils/image_picker_helper.dart';
import '../../utils/whatsapp_helper.dart';
import '../../utils/send_to_client_prompt.dart';
import '../forms/fill_form_screen.dart';
import '../home_screen.dart';

/// شاشة تسجيل الدخول الموحّدة: تُستخدم لأي من الحالات الثلاث
/// (فندقة عادية / فندقة علاجية / إجراء طبي) بنفس الحقول تماماً كما هو مطلوب.
///
/// إذا كانت هناك استمارة إلكترونية نشطة لنوع الحالة المختار، تحل محل صورة
/// عقد الإدخال الورقي: يجب على العميل تعبئتها والتوقيع عليها وتصوير الفاتورة
/// أولاً، ثم يتم تسجيل الدخول فعلياً بعد ذلك مباشرة.
class AddAdmissionScreen extends StatefulWidget {
  final int petId;
  final String petName;
  final String initialKind;

  const AddAdmissionScreen({
    super.key,
    required this.petId,
    required this.petName,
    this.initialKind = AdmissionKind.hotelNormal,
  });

  @override
  State<AddAdmissionScreen> createState() => _AddAdmissionScreenState();
}

class _AddAdmissionScreenState extends State<AddAdmissionScreen> {
  late String _kind;
  DateTime _entryDate = DateTime.now();
  DateTime? _expectedExitDate;
  final _notesController = TextEditingController();
  String? _contractImagePath;
  bool _saving = false;

  Map<String, dynamic>? _activeTemplate;
  int? _formSubmissionId;
  bool _loadingTemplate = true;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _loadTemplate();
  }

  /// يحوّل نوع الحالة المختار في الشاشة إلى مفتاح نوع خدمة الاستمارة المطابق
  String _serviceTypeForKind(String kind) {
    if (kind == AdmissionKind.procedure) return FormServiceType.checkinProcedure;
    if (kind == AdmissionKind.hotelTreatment) return FormServiceType.checkinHotelTreatment;
    return FormServiceType.checkinHotelNormal;
  }

  Future<void> _loadTemplate() async {
    setState(() => _loadingTemplate = true);
    final template = await DBHelper.instance.getActiveTemplateForServiceType(_serviceTypeForKind(_kind));
    if (!mounted) return;
    setState(() {
      _activeTemplate = template;
      _formSubmissionId = null; // تغيّر نوع الحالة يعني إعادة تعبئة الاستمارة المطابقة
      _loadingTemplate = false;
    });
  }

  void _onKindChanged(String? v) {
    if (v == null) return;
    setState(() => _kind = v);
    _loadTemplate();
  }

  Future<void> _pickEntryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) setState(() => _entryDate = date);
  }

  Future<void> _pickExpectedExitDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedExitDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _expectedExitDate = date);
  }

  Future<void> _pickContractImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('التقاط صورة عقد الإدخال بالكاميرا'),
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
    if (path != null) setState(() => _contractImagePath = path);
  }

  Future<void> _openForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FillFormScreen(
          templateId: _activeTemplate!['id'] as int,
          petId: widget.petId,
          invoiceRequired: true,
        ),
      ),
    );
    if (result is int) {
      setState(() => _formSubmissionId = result);
    }
  }

  Future<void> _save() async {
    final usingForm = _activeTemplate != null;

    if (usingForm) {
      if (_formSubmissionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب تعبئة الاستمارة الإلكترونية والتوقيع عليها أولاً')),
        );
        return;
      }
    } else if (_contractImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('صورة عقد الإدخال إلزامية ولا يمكن الحفظ بدونها')),
      );
      return;
    }

    setState(() => _saving = true);

    final bool isProcedure = AdmissionKind.isProcedure(_kind);

    final admission = Admission(
      petId: widget.petId,
      type: isProcedure ? AdmissionType.procedure : AdmissionType.hotel,
      boardingType: isProcedure ? null : _kind, // فندقة عادية / فندقة علاجية
      procedureName: isProcedure ? 'إجراء طبي' : null,
      entryDate:
          '${DateHelper.formatDate(_entryDate)} ${DateHelper.nowDateTime().split(' ').last}',
      expectedExitDate: _expectedExitDate != null ? DateHelper.formatDate(_expectedExitDate!) : null,
      entryContractImage: _contractImagePath,
      status: isProcedure ? PetStatus.inClinic : PetStatus.inHotel,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    final admissionId = await DBHelper.instance.insertAdmission(admission);
    await DBHelper.instance.updatePetStatus(widget.petId, admission.status);

    if (usingForm && _formSubmissionId != null) {
      await DBHelper.instance.updateFormSubmissionAdmissionId(_formSubmissionId!, admissionId);
    }

    setState(() => _saving = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تسجيل دخول "${widget.petName}" — $_kind')),
    );

    // نعرض للموظف مباشرة خانة "إرسال للعميل" (لا تُرسل تلقائياً)
    final pet = await DBHelper.instance.getPetById(widget.petId);
    final client = pet != null ? await DBHelper.instance.getClientById(pet.clientId) : null;
    if (mounted && client != null) {
      final message = WhatsAppHelper.buildCheckinConfirmationMessage(
        petName: widget.petName,
        gender: pet?.gender,
        kind: _kind,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تسجيل دخول — ${widget.petName}')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text('اختر نوع الحالة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...AdmissionKind.all.map(
              (k) => RadioListTile<String>(
                title: Text(k),
                value: k,
                groupValue: _kind,
                onChanged: _onKindChanged,
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('تاريخ الدخول'),
              subtitle: Text(DateHelper.formatDate(_entryDate)),
              trailing: const Icon(Icons.edit),
              onTap: _pickEntryDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('تاريخ الخروج المتوقع'),
              subtitle: Text(_expectedExitDate != null ? DateHelper.formatDate(_expectedExitDate!) : 'اختر تاريخاً'),
              trailing: const Icon(Icons.edit),
              onTap: _pickExpectedExitDate,
            ),
            const Divider(),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات', prefixIcon: Icon(Icons.notes)),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            if (_loadingTemplate)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (_activeTemplate != null) ...[
              Card(
                color: _formSubmissionId != null ? AppColors.success.withOpacity(0.08) : null,
                child: ListTile(
                  leading: Icon(
                    _formSubmissionId != null ? Icons.check_circle : Icons.description_outlined,
                    color: _formSubmissionId != null ? AppColors.success : AppColors.primary,
                  ),
                  title: Text(_activeTemplate!['name']),
                  subtitle: Text(_formSubmissionId != null ? 'تم اعتماد الاستمارة ✓' : 'الاستمارة الإلكترونية *'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: _openForm,
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: Text(_contractImagePath == null ? 'التقاط صورة عقد الإدخال *' : 'تم اختيار صورة العقد ✓'),
                onPressed: _pickContractImage,
              ),
              if (_contractImagePath != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_contractImagePath!), height: 160, fit: BoxFit.cover),
                ),
              ],
            ],
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? 'جاري الحفظ...' : 'تسجيل الدخول'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
