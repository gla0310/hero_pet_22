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

/// Screen for filling out and signing the electronic form - used directly by
/// the client on the iPad. Opens automatically or when tapping "Electronic Form"
/// depending on the service type (boarding check-in/check-out or medical procedure).
class FillFormScreen extends StatefulWidget {
  final int templateId;
  final int petId;
  final int? admissionId;
  final int? visitId;

  /// At check-in: the invoice photo is required to complete the form.
  /// At check-out: optional.
  final bool invoiceRequired;

  /// Boarding notes taken during the stay (shown at check-out only, if present)
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

  // Answers for dynamic fields: field id -> controller (text) or bool (Checkbox)
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
        const SnackBar(content: Text('You must agree to the terms and conditions')),
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
            SnackBar(content: Text('The field "${f['label']}" is required')),
          );
          return;
        }
      } else {
        if ((_textAnswers[id]?.text.trim() ?? '').isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('The field "${f['label']}" is required')),
          );
          return;
        }
      }
    }
    if (_signatureEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A signature is required to submit the form')),
      );
      return;
    }
    if (widget.invoiceRequired && _invoiceImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An invoice photo is required to complete the form')),
      );
      return;
    }

    setState(() => _submitting = true);
    final stopwatch = Stopwatch()..start();

    // Save the signature image
    final signatureBytes = await _signaturePadStateKey.currentState!.exportPng();
    if (signatureBytes == null) {
      setState(() => _submitting = false);
      return;
    }
    debugPrint('⏱ [Form] Signature export: ${stopwatch.elapsedMilliseconds}ms');
    stopwatch.reset();

    final signaturePath = await ImagePickerHelper.saveBytesAsImage(signatureBytes, prefix: 'signature');
    debugPrint('⏱ [Form] Signature file save: ${stopwatch.elapsedMilliseconds}ms');
    stopwatch.reset();

    // Build the list of answers
    final answers = <Map<String, String>>[];
    for (final f in _fields) {
      final id = f['id'] as int;
      final label = f['label'] as String;
      if (f['field_type'] == 'checkbox') {
        answers.add({'label': label, 'value': (_checkboxAnswers[id] == true) ? 'Yes' : 'No'});
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
    debugPrint('⏱ [Form] PDF generation: ${stopwatch.elapsedMilliseconds}ms');
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
    debugPrint('⏱ [Form] Database save: ${stopwatch.elapsedMilliseconds}ms');

    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form submitted and saved')));
    Navigator.pop(context, submissionId);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_template == null || _client == null || _pet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Failed to load form data')),
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
                  _infoRow('Client Name', _client!.name),
                  _infoRow('Phone Number', _client!.phone),
                  _infoRow('Pet Name', _pet!.name),
                  _infoRow('Pet File Number', '#${_pet!.id}'),
                  _infoRow('Date and Time', DateHelper.nowDateTime()),
                ],
              ),
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Notes During Boarding Stay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            const Text('Terms and Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
              title: const Text('I agree to the terms and conditions *'),
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
            ),
          ],
          if (_fields.isNotEmpty) ...[
            const Divider(height: 30),
            const Text('Additional Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
          const Text('Electronic Signature *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
              label: const Text('Clear Signature'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.invoiceRequired ? 'Invoice Photo *' : 'Invoice Photo (optional)',
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
            label: Text(_invoiceImagePath == null ? 'Take Invoice Photo' : 'Retake Photo'),
            onPressed: _captureInvoice,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              icon: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_submitting ? 'Submitting...' : 'Submit'),
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
