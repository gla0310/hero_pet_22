import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import '../../core/app_colors.dart';
import '../../database/db_helper.dart';
import '../../utils/image_picker_helper.dart';

/// View a previously submitted form: preview/print/share the PDF file, and view
/// and add attachments (such as invoice photos) linked to it.
class FormSubmissionViewScreen extends StatefulWidget {
  final Map<String, dynamic> submission;

  const FormSubmissionViewScreen({super.key, required this.submission});

  @override
  State<FormSubmissionViewScreen> createState() => _FormSubmissionViewScreenState();
}

class _FormSubmissionViewScreenState extends State<FormSubmissionViewScreen> {
  late Future<List<Map<String, dynamic>>> _attachmentsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _attachmentsFuture = DBHelper.instance.getFormAttachments(widget.submission['id'] as int);
  }

  Future<void> _addAttachment() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo with Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final path = await ImagePickerHelper.pickAndSaveImage(source: source);
    if (path == null) return;
    await DBHelper.instance.addFormAttachment(widget.submission['id'] as int, path);
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final pdfPath = s['pdf_path'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text(s['template_name'])),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['template_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('Submission Date: ${s['submitted_at']}'),
                  if (s['staff_name'] != null) Text('Staff: ${s['staff_name']}'),
                  if (s['civil_id'] != null) Text('ID/Residency Number: ${s['civil_id']}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (pdfPath != null && File(pdfPath).existsSync())
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Preview / Print / Share PDF'),
                onPressed: () => Printing.layoutPdf(
                  onLayout: (format) async => File(pdfPath).readAsBytesSync(),
                ),
              ),
            )
          else
            const Text('Could not find the PDF file for this form', style: TextStyle(color: AppColors.danger)),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                onPressed: _addAttachment,
                icon: const Icon(Icons.add),
                label: const Text('Attach Document'),
              ),
            ],
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _attachmentsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final attachments = snapshot.data!;
              if (attachments.isEmpty) return const Text('No attachments');
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: attachments.length,
                itemBuilder: (context, i) {
                  final path = attachments[i]['file_path'] as String;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: File(path).existsSync()
                        ? Image.file(File(path), fit: BoxFit.cover)
                        : Container(color: Colors.grey.shade200),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
